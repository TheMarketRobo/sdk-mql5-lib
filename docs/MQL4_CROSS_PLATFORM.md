# MQL4 Cross-Platform Support & Indicator Security

This document covers how the SDK supports both MetaTrader 4 (build 600+) and MetaTrader 5 from a single codebase, with particular focus on the indicator termination security model introduced for MQL4.

---

## Platform Detection

The MQL5 compiler defines `__MQL5__`; the MQL4 compiler defines `__MQL4__`. The SDK uses these in `TMR_Platform.mqh` to handle all platform differences at compile time. A single constant `TMR_PLATFORM` is set to `"mt4"` or `"mt5"` and sent to the backend in the session start payload.

---

## What Works Identically on Both Platforms

| Feature | Notes |
|---------|-------|
| Classes, inheritance, virtual functions | MQL4 build 600+ has full OOP support |
| `OnInit`, `OnDeinit`, `OnTick`, `OnTimer`, `OnChartEvent`, `OnCalculate` | Same event handler names and signatures |
| `AccountInfoInteger/Double/String` | Same functions, same enum values (except 4 MQL5-only account properties) |
| `TerminalInfoInteger/String` | Same functions (except `TERMINAL_X64` — MQL5 only) |
| `MQLInfoString/MQLInfoInteger` | Identical on both platforms |
| `SymbolInfoTick`, `SymbolsTotal`, `SymbolName` | Identical |
| `EventSetTimer`, `EventKillTimer`, `EventChartCustom` | Identical |
| `ExpertRemove` | Identical — works for EAs on both platforms |
| `CheckPointer`, `POINTER_INVALID` | Identical |
| `CHARTEVENT_CUSTOM` | Identical |
| `IsStopped` | Identical |
| `FileOpen`, `FileWrite`, `FileRead`, `FileDelete`, `FileIsExist` | Identical — used for session persistence and kill files |

---

## MQL5-Only Enum Values (Sentinel Pattern)

Certain enum constants don't exist in MQL4. The SDK defines them as `-1` sentinels on MQL4 and checks them at runtime with `TMR_Is*PropertyAvailable()` guards before calling `AccountInfoInteger()` / `TerminalInfoInteger()` / `SymbolInfoString()`.

### Account Properties (MQL5-only)

| Constant | MQL4 Sentinel | Guard Function |
|----------|--------------|----------------|
| `ACCOUNT_MARGIN_MODE` | -1 | `TMR_IsAccountPropertyAvailable()` |
| `ACCOUNT_CURRENCY_DIGITS` | -1 | `TMR_IsAccountPropertyAvailable()` |
| `ACCOUNT_FIFO_CLOSE` | -1 | `TMR_IsAccountPropertyAvailable()` |
| `ACCOUNT_HEDGE_ALLOWED` | -1 | `TMR_IsAccountPropertyAvailable()` |

Also: `ACCOUNT_MARGIN_MODE_RETAIL_NETTING`, `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`, `ACCOUNT_MARGIN_MODE_EXCHANGE` are defined as 0/1/2 on MQL4 (only used inside the guarded block).

### Terminal Properties (MQL5-only)

| Constant | MQL4 Sentinel |
|----------|--------------|
| `TERMINAL_X64` | -1 |

All other `TERMINAL_*` properties exist on both platforms.

### Symbol String Properties (MQL5-only)

`SYMBOL_COUNTRY`, `SYMBOL_CATEGORY`, `SYMBOL_BASIS`, `SYMBOL_ISIN`, `SYMBOL_PAGE`, `SYMBOL_FORMULA`, `SYMBOL_SECTOR_NAME`, `SYMBOL_INDUSTRY_NAME`, `SYMBOL_BANK`, `SYMBOL_EXCHANGE` — all set to `-1` on MQL4, guarded by `TMR_IsSymbolStringPropertyAvailable()`.

Properties that **do** exist in MQL4: `SYMBOL_PATH`, `SYMBOL_CURRENCY_PROFIT`, `SYMBOL_CURRENCY_MARGIN`, `SYMBOL_DESCRIPTION`.

### Order Type Aliases

MQL4 uses `OP_BUY`/`OP_SELL`; MQL5 uses `ORDER_TYPE_BUY`/`ORDER_TYPE_SELL`. The SDK defines:
```cpp
#ifdef __MQL4__
   #define ORDER_TYPE_BUY   OP_BUY
   #define ORDER_TYPE_SELL  OP_SELL
#endif
```

---

## Functions Without MQL4 Equivalent

### OrderCalcMargin

MQL5's `OrderCalcMargin()` has no MQL4 equivalent. The wrapper `TMR_OrderCalcMargin()` returns `false` on MQL4 with `margin = 0.0`. The backend treats 0 as "not available."

### WebRequest (Indicators)

`WebRequest()` cannot be called from indicators on **either** platform (error 4014 on MQL5, similar on MQL4). The SDK routes indicator HTTP traffic through `CWinINetHttpService` using `kernel32.dll` + `wininet.dll` DLL imports. EAs use `WebRequest()` directly — no DLLs needed.

### Sleep (Indicators)

`Sleep()` cannot be called from custom indicators on either platform. The `wait_for_account_data()` loop in `CDataCollectorService` becomes a busy-wait in indicator context but still terminates via `TimeLocal()` timeout.

---

## Indicator Termination Security (3-Layer Defense)

When the server terminates an indicator session (customer clicks "End Session," auth failure, token expiry, or heartbeat failure threshold), the SDK must ensure the indicator **stops producing output** and **cannot restart**.

On MQL5, `ChartIndicatorDelete()` removes the indicator cleanly. On MQL4, chart operations are officially restricted to EAs and scripts, so the SDK implements a defense-in-depth strategy.

### Layer 1: Try `ChartIndicatorDelete`

Despite the general MQL4 restriction, `ChartIndicatorDelete()` **does** exist in MQL4 and works for **self-deletion** on many MT4 builds. This is because the function is asynchronous — it queues a removal command that executes after the current event handler returns.

```
TMR_ChartIndicatorDelete(chart_id, sub_window, indicator_name)
  → Calls real ChartIndicatorDelete()
  → If true: ChartRedraw() + return true (indicator fully removed)
  → If false: return false → Layer 2 activates
```

### Layer 2: Functional Death

If `ChartIndicatorDelete` fails, the indicator is made non-functional:

1. **`m_killed = true`** — All future `on_timer()` and `on_calculate()` calls return immediately
2. **`SetIndexStyle(i, DRAW_NONE)`** on every buffer — All drawn lines, arrows, and histograms disappear from the chart
3. **`IndicatorShortName("TMR: DISABLED")`** — The indicator's name in the chart list changes to "TMR: DISABLED"
4. **`ChartRedraw(0)`** — Forces the chart to repaint immediately

The indicator remains on the chart visually (as an entry in the indicator list) but produces zero output.

**Developer requirement:** Call `set_indicator_buffer_count(N)` during `OnInit()` so the SDK knows how many buffers to clear.

**Developer requirement:** Check `is_killed()` at the top of `OnCalculate()`:
```cpp
if(CheckPointer(g_indicator) != POINTER_INVALID && g_indicator.is_killed())
    return rates_total;
```

### Layer 3: Persistent Kill File

The indicator's deinit/reinit cycle fires on timeframe changes (`REASON_CHARTCHANGE`). Without Layer 3, the indicator would reinitialize with a new session. The kill file prevents this:

- **On termination:** SDK writes `TMR_killed_{chartId}_{apiKeyPrefix}.dat` to the MQL data folder
- **On reinit:** `init_common()` checks for the kill file before `try_restore_session()`. If found, it sets `m_killed = true` and returns `INIT_SUCCEEDED` (so timer/events fire but do nothing)
- **On manual removal:** When the user right-clicks and deletes the indicator (`REASON_REMOVE`), `on_deinit()` calls `clear_kill_file()`, allowing a fresh session if re-added later

**Kill file naming:** `TMR_killed_{ChartID}_{first 8 chars of API key}.dat` — same pattern as the session state file but with a different prefix.

---

## Complete Termination Flow

### Customer Clicks "End Session"
```
Customer App → POST /sessions/{id}/terminate
  → Backend writes termination request to cache
    → SDK's next heartbeat gets status: "termination_requested"
      → CHeartbeatManager fires Fire_Termination_Requested_Event()
        → CTheMarketRobo_Base::handle_termination_requested_event()
          → For EAs: Alert + ExpertRemove()
          → For Indicators: remove_indicator_from_chart()
            → Layer 1: ChartIndicatorDelete(0, window, name)
              → Success: indicator removed ✓
              → Failure: Layer 2: kill_indicator()
                → SetIndexStyle(all, DRAW_NONE) — draws vanish
                → m_killed = true — OnCalculate blocked
                → Layer 3: write_kill_file()
                  → User changes timeframe → OnDeinit(REASON_CHARTCHANGE)
                    → New OnInit() → check_kill_file() → FOUND → BLOCKED ✓
```

### User Manually Removes Killed Indicator
```
Right-click → Delete Indicator
  → OnDeinit(REASON_REMOVE) — destructive
    → clear_kill_file() — allows fresh start
    → terminate() + clear_session_state()
```

---

## Indicator Buffer Setup (MQL4 vs MQL5)

Buffer setup syntax differs between platforms. This affects sample code only, not the SDK core.

**MQL5:**
```cpp
SetIndexBuffer(0, ZigzagPeakBuffer, INDICATOR_DATA);
SetIndexBuffer(1, ZigzagTroughBuffer, INDICATOR_DATA);
SetIndexBuffer(2, ColorBuffer, INDICATOR_COLOR_INDEX);
IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
IndicatorSetString(INDICATOR_SHORTNAME, short_name);
PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
```

**MQL4:**
```cpp
SetIndexBuffer(0, ZigzagPeakBuffer);
SetIndexBuffer(1, ZigzagTroughBuffer);
SetIndexBuffer(2, ColorBuffer);
SetIndexStyle(0, DRAW_ZIGZAG, STYLE_SOLID, 1, clrDodgerBlue);
SetIndexStyle(1, DRAW_ZIGZAG, STYLE_SOLID, 1, clrRed);
SetIndexEmptyValue(0, 0.0);
IndicatorDigits(Digits);
IndicatorShortName(short_name);
```

**Both platforms must call after buffer setup:**
```cpp
g_indicator.set_indicator_short_name(short_name);
g_indicator.set_indicator_buffer_count(5);
```

---

## Backend Data Differences (MQL4 vs MQL5)

The SDK sends a `platform` field (`"mt4"` or `"mt5"`) in `static_fields`. MQL4 sessions **omit** 5 fields that are MQL5-only:

| Field | MQL5 | MQL4 |
|-------|------|------|
| `account_margin_mode` | Sent | Omitted |
| `account_currency_digits` | Sent | Omitted |
| `account_fifo_close` | Sent | Omitted |
| `account_hedge_allowed` | Sent | Omitted |
| `terminal_x64` | Sent | Omitted |
| `margin_required` (per symbol) | Actual value | Omitted (0) |

These fields are **optional** in the backend contract schema (`contracts/schemas/static_data/v1.json`). The backend stores `static_fields` as unvalidated JSONB and does not reject payloads missing these fields.

---

## Indicator Integration Checklist (MQL4-Specific)

When integrating an indicator for MQL4:

1. Use `.mq4` file extension
2. Use 2-arg `SetIndexBuffer(idx, buf)` + `SetIndexStyle()` for buffers
3. Use `IndicatorDigits()` and `IndicatorShortName()` instead of `IndicatorSetInteger/String`
4. Omit `#property indicator_plots` and `#property indicator_type1` (MQL5-only directives)
5. Split multi-color `#property indicator_color1 clrA, clrB` into separate lines per buffer
6. Call `set_indicator_short_name(short_name)` and `set_indicator_buffer_count(N)` before `on_init()`
7. Check `is_killed()` at the top of `OnCalculate()`
8. Test all termination scenarios (End Session button, auth failure, token expiry)
9. Verify kill file blocks restart on timeframe change
10. Verify manual removal clears kill file and allows fresh session

---

*This document is part of the TheMarketRobo SDK documentation. See also: [API Reference](API_REFERENCE.md), [Integration Booklet](SDK_INTEGRATION_BOOKLET.md), [Indicator Checklist](INDICATOR_INTEGRATION_CHECKLIST.md).*
