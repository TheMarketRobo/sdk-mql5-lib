# Running SDK-Integrated Products in MT4/MT5 Strategy Tester

The TheMarketRobo SDK automatically detects MetaTrader 4/5 Strategy
Tester mode and runs offline — no API key needed, no HTTP requests, no
heartbeats. Your EA's `on_tick()` or indicator's `on_calculate()` runs
normally; the SDK's session/auth lifecycle is bypassed.

## Required SDK version

The Strategy Tester bypass requires SDK **v1.1.0** or later.

To check which SDK version is loaded:

1. Attach your EA/Indicator to a chart, or run it in the tester.
2. Look in the Experts log for a line starting:

   ```
   SDK Info: TheMarketRobo SDK v1.1.0 | platform=mt5 | flags=[...] | ...
   ```

3. If you see `v1.0.x` or no version line at all, your SDK headers are
   stale and the Strategy Tester bypass will NOT work.

## Updating the SDK in your MetaTrader install

The SDK lives at:

- **MT5:** `<MT5_DATA_PATH>/MQL5/Include/themarketrobo/`
- **MT4:** `<MT4_DATA_PATH>/MQL4/Include/themarketrobo/`

To find your data path: in MetaTrader, `File → Open Data Folder`.

To update:

1. Close MetaEditor.
2. Replace the entire `themarketrobo/` folder with the latest release from
   the Vendor Portal (or `git pull` if you cloned the sample lib).
3. Open MetaEditor and **recompile** your EA/Indicator with F7. A clean
   rebuild is required — the new `.ex5`/`.ex4` will then contain the
   tester gate.
4. Attach the recompiled product to the Strategy Tester to verify (see
   below).

## Verifying tester mode is detected

When the SDK detects Strategy Tester and successfully shorts out the
HTTP/auth lifecycle, you should see two consecutive log lines:

```
SDK Info: TheMarketRobo SDK v1.1.0 | platform=mt5 | flags=[MQL_TESTER=1, MQL_OPTIMIZATION=0, MQL_VISUAL_MODE=0, MQL_FRAME_MODE=0, MQL_FORWARD=0] | TMR_IsInTester=1 | matched_signal=MQL_TESTER
SDK Info: Strategy Tester detected (mode=tester) — running in offline mode. No authentication, no HTTP, no heartbeats. Your robot logic will execute normally; SDK lifecycle is bypassed.
```

The `matched_signal=` value tells you which detection signal fired
(`MQL_TESTER`, `MQL_OPTIMIZATION`, `MQL_VISUAL_MODE`, `MQL_FRAME_MODE`,
`MQL_FORWARD`, `IsTesting()`, `IsOptimization()`, or `IsVisualMode()`).
At least one of these must be true in any Strategy Tester run.

## When detection fails

If you see the banner with `TMR_IsInTester=0` and `matched_signal=none`
despite running in Strategy Tester, capture the entire banner line
(including all flag values) and report it to TheMarketRobo support.
This is the data point we need to add additional fallback logic — it
indicates an MT4/MT5 build-specific quirk where none of the documented
detection signals fired.

You can confirm you are in the tester (despite the SDK not detecting
it) by checking the log timestamp format:

- **Live chart:** single timestamp, e.g. `2026.05.15 06:50:05`
- **Strategy Tester:** dual timestamp, e.g. `2026.05.15 06:50:05    2026.01.01 00:00:00`
  (real time + simulated time)

## API key in tester

The SDK ignores the `InpApiKey` input parameter completely in tester
mode. You can:

- Leave it empty — no warning, no failure.
- Set it to any string — also ignored.
- Set it to a real production key — also ignored. The SDK never makes
  network calls in tester.

## What still runs in tester

- Vendor's `on_tick()` / `on_calculate()` body — runs every tick exactly
  like in live mode.
- Vendor's `OnInit` body (preserved by the integrator) — runs normally.
  **Note:** if the vendor's `OnInit` contains `if(InpApiKey == "") return
  INIT_FAILED;`, the integrator now modifies that to `if(InpApiKey == ""
  && !TMR_IsInTester()) return INIT_FAILED;` so backtests proceed.
- Indicator buffers, chart objects, panels — all unchanged.

## What does NOT run in tester

- HTTP requests to TheMarketRobo backend (blocked by the tester anyway).
- JWT auth, token refresh, heartbeats.
- Config change push / symbol change push from the server.
- `Alert()`, `MessageBox()`, `SendMail()`, `SendNotification()`,
  `PlaySound()` — these are all blocked by the MT4/MT5 tester itself,
  not by the SDK.
- `OnTimer()` on MQL4 indicators in tester (also a tester-level block).
- `OnChartEvent()` on MQL5 indicators in tester (tester-level block).
- `OnDeinit()` on MQL5 indicators in tester (tester-level — see
  https://www.mql5.com/en/forum/243621).

## Why was this added

Earlier SDK versions (`v1.0.x`) required a valid API key + reachable
backend to start the session. Strategy Tester blocks `WebRequest()` and
DLL access, so the session start would fail noisily and stop the
backtest. From `v1.1.0`, the SDK detects tester and skips the whole
session lifecycle — backtests run as if the SDK were not present.
