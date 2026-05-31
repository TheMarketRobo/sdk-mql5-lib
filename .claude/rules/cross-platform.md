---
paths:
  - "**/TMR_Platform.mqh"
  - "**/*.mq4"
  - "**/Services/CDataCollectorService.mqh"
---
> MQL4/MQL5 compatibility layer (extracted verbatim from CLAUDE.md, 2026-05-31 split). Read when editing `TMR_Platform.mqh` or anything that touches platform-specific APIs. Full reference: `docs/MQL4_CROSS_PLATFORM.md`.

# MQL4/MQL5 Cross-Platform

`TMR_Platform.mqh` uses a sentinel + guard pattern:

1. **Sentinel defines** (`#ifdef __MQL4__`): MQL5-only enum constants get `#define CONSTANT_NAME (-1)`
2. **Guard functions**: `TMR_IsAccountPropertyAvailable(id)` returns `id >= 0` — false for sentinels
3. **Use sites**: Always check guard before calling `AccountInfoInteger(CONSTANT)` etc.

Three categories of sentinels:
- **Account**: `ACCOUNT_MARGIN_MODE`, `ACCOUNT_CURRENCY_DIGITS`, `ACCOUNT_FIFO_CLOSE`, `ACCOUNT_HEDGE_ALLOWED`
- **Terminal**: `TERMINAL_X64` only — all other TERMINAL_* exist in MQL4
- **Symbol strings**: 10 properties (COUNTRY, CATEGORY, BASIS, ISIN, PAGE, FORMULA, SECTOR_NAME, INDUSTRY_NAME, BANK, EXCHANGE)

**Chart operations & Secure Termination**: `ChartIndicatorDelete/Total/Name` exist in MQL4 but are restricted to EAs and scripts only (docs.mql4.com/chart_operations). The SDK uses a 3-layer secure termination for indicators:
1. **Layer 1**: Try real `ChartIndicatorDelete` — works for self-deletion on many MT4 builds (asynchronous queue mechanism)
2. **Layer 2**: Functional death — `SetIndexStyle(i, DRAW_NONE)` on all buffers, `m_killed` flag blocks `on_timer()`/`on_calculate()`, renames to "TMR: DISABLED"
3. **Layer 3**: Persistent kill file (`TMR_killed_{chartId}_{apiKeyPrefix}.dat`) — checked during `init_common()`, blocks restart on timeframe change. Cleared only on destructive deinit (user manually removes indicator).

**Sleep()**: Cannot be called from custom indicators on either platform. The `wait_for_account_data()` loop in `CDataCollectorService` becomes a busy-wait in indicator context (still terminates via `TimeLocal()` timeout).
