# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

The TheMarketRobo SDK for MQL4/MQL5 — a connectivity and lifecycle management library (not trading logic) that connects MetaTrader Expert Advisors and Custom Indicators to the TheMarketRobo platform. This is a git submodule (`TheMarketRobo/sdk-mql5-lib`) consumed by the parent sample repo at `Include/themarketrobo/`.

The parent repo (`mql5-sample-lib`) contains sample integrations and MetaQuotes standard library files. SDK development happens here; integration examples live in the parent.

## Language

MQL4/MQL5 (C++-like). Files are `.mqh` headers — no standalone compilation. Compilation requires MetaEditor (MetaTrader IDE); there is no CLI build system. The only way to test is to compile in MetaEditor and attach to a chart.

## Architecture

### Include Chain

`TheMarketRobo_SDK.mqh` is the single public include. It pulls in everything:

```
TheMarketRobo_SDK.mqh
├── Core/CSDKConstants.mqh        (SDK_ENABLED toggle, constants, enums)
├── TMR_Platform.mqh              (MQL4/MQL5 compat: sentinels, wrappers)
├── Services/Json.mqh             (CJAVal JSON parser)
├── Models/*                      (Pure data: CConfigField, CConfigSchema, CSessionSymbol, CFinalStats)
├── Interfaces/IRobotConfig.mqh   (Abstract base for vendor config)
├── Utils/*                       (CSDKLogger, CSDK_Events, CSDKUserErrors)
└── [#ifdef SDK_ENABLED only:]
    ├── Services/CHttpService.mqh          (WebRequest vs WinINet dispatch)
    ├── Services/CWinINetHttpService.mqh   (DLL-based HTTP for indicators)
    ├── Services/CDataCollectorService.mqh (Account/terminal telemetry)
    ├── Core/CTokenManager.mqh             (JWT decode, expiry, refresh)
    ├── Core/CSessionManager.mqh           (POST /robot/start, /robot/end)
    ├── Core/CHeartbeatManager.mqh         (Periodic POST /robot/heartbeat)
    ├── Core/CConfigurationManager.mqh     (Config change validation)
    ├── Core/CSymbolManager.mqh            (Symbol change tracking)
    ├── Core/CSDKContext.mqh               (Service container)
    └── CTheMarketRobo_Base.mqh            (Public entry point class)
```

When `SDK_ENABLED` is not defined, `CTheMarketRobo_Base` compiles as a no-op stub — zero network code, zero DLL imports.

### Service Container Pattern

`CSDKContext` is the central orchestrator. It owns all manager instances and drives the timer loop:

```
CSDKContext.on_timer()
  → TokenManager: check if refresh needed → POST /robot/refresh
  → HeartbeatManager: check if send needed → POST /robot/heartbeat
    → ConfigurationManager: attach pending config change results
    → SymbolManager: attach pending symbol change results
    → DataCollectorService: collect dynamic data (balance, equity, margin)
```

Managers never call each other directly — they communicate through CSDKContext or via the event system.

### HTTP Dispatch (Product Type)

`CHttpService.post()` routes by product type:
- **Robot (EA)**: Uses built-in `WebRequest()` — no DLL needed
- **Indicator**: Uses `CWinINetHttpService` (kernel32.dll + wininet.dll) — because `WebRequest()` returns error 4014 from indicator context on both MQL4 and MQL5

### Event System

SDK components communicate via MQL's custom chart event mechanism (`CSDK_Events.mqh`):
- Events are `CHARTEVENT_CUSTOM + offset` constants (1000-1005)
- `Fire_*_Event()` helpers serialize structs to JSON and call `EventChartCustom()`
- `CTheMarketRobo_Base::on_chart_event()` dispatches by event ID to handlers
- Used for: config changes, symbol changes, termination requests, token refresh results

### Session Persistence (Indicators Only)

Indicators undergo non-destructive deinit/reinit on chart changes, timeframe changes, and recompiles. The SDK saves session state (JWT, session_id) to a file on non-destructive deinit and restores it on reinit, avoiding a new `/robot/start` call. Destructive deinit (indicator removed from chart) sends `/robot/end`.

## MQL4/MQL5 Cross-Platform

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

## Naming Conventions

- Classes: `C` prefix (`CTokenManager`, `CSessionSymbol`)
- Interfaces: `I` prefix (`IRobotConfig`) — implemented as classes with pure virtual functions, not `interface` keyword
- Member variables: `m_` prefix (`m_jwt`, `m_session_id`)
- Global variables: `g_` prefix, always `NULL`-initialized
- Input parameters: `Inp` prefix (`InpApiKey`, `InpDepth`)
- SDK log messages: Always prefixed with `"SDK Info: "`, `"SDK Warning: "`, `"SDK Error: "`
- User-facing errors: Shown via `Alert()` through `SDKUserError()` / `SDKUserErrorWithDetails()`

## Backend API Contract

The SDK talks to 4 endpoints:
- `POST /robot/start` — session init (sends `static_fields`, `session_symbols`, config)
- `POST /robot/heartbeat` — periodic telemetry (sends `dynamic_data`, sequence counter)
- `POST /robot/refresh` — JWT token renewal
- `POST /robot/end` — session termination

Contract schemas live in `aws/contracts/schemas/static_data/v1.json` and `aws/contracts/api/robot/components/robot-start.yaml` (separate repo). The `static_fields` schema has `additionalProperties: false` — any new field sent by the SDK must also be added to the contract.

MQL4 sessions omit 5 MQL5-only fields (`account_margin_mode`, `account_currency_digits`, `account_fifo_close`, `account_hedge_allowed`, `terminal_x64`). These are optional in the schema. The `platform` field (`"mt4"` or `"mt5"`) is also sent.

## SDK Integration Tool

The backend (`aws/src/endpoints/common/sdk-integrator/`) provides an automated SDK integration service accessible from the Vendor Portal. It parses vendor MQL source code and produces SDK-integrated output:

- **Template path** (simple indicators): Deterministic code generation, ~200ms, free
- **Deterministic mapper** (large EAs with 30+ inputs): Heuristic-based config schema, instant, free
- **LLM path** (complex indicators, small EAs): AI-powered via Anthropic Claude API for semantic understanding

The tool uses the same SDK patterns documented here. When modifying SDK classes or methods, the integration tool's prompts and validators should also be updated (`aws/src/endpoints/common/sdk-integrator/src/lib/`).

## Key Things to Know

- **Log level for production**: Final products must set `SDK_LOG_ERROR` before `on_init()`. Debug/info logging is for development only.
- **Heartbeat sequence**: Monotonically increasing counter. Server returns 409 on mismatch; SDK resyncs from response.
- **Token refresh**: Proactive — happens `SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD` (60s) before JWT expiry, not after.
- **Product type**: Determined server-side from database via `robot_version_uuid`, not from SDK payload.
- **Indicator DLL requirement**: End users must enable "Allow DLL imports" for indicators. EAs need no DLLs.
- **Config schema**: Only robots have configs. The schema must match the [Robot Config Component Schema](docs/schemas/robot_config_component_schema/README.md) — the Vendor Portal validates it at submission.
