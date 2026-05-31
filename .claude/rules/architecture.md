---
paths:
  - "**/Core/**"
  - "**/Services/**"
  - "**/TheMarketRobo_SDK.mqh"
  - "**/CTheMarketRobo_Base.mqh"
  - "**/Utils/CSDK_Events.mqh"
---
> SDK internal architecture (extracted verbatim from CLAUDE.md, 2026-05-31 split). Read when editing managers/services or the public entry class.

# Architecture

## Include Chain

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

## Service Container Pattern

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

## HTTP Dispatch (Product Type)

`CHttpService.post()` routes by product type:
- **Robot (EA)**: Uses built-in `WebRequest()` — no DLL needed
- **Indicator**: Uses `CWinINetHttpService` (kernel32.dll + wininet.dll) — because `WebRequest()` returns error 4014 from indicator context on both MQL4 and MQL5

## Event System

SDK components communicate via MQL's custom chart event mechanism (`CSDK_Events.mqh`):
- Events are `CHARTEVENT_CUSTOM + offset` constants (1000-1005)
- `Fire_*_Event()` helpers serialize structs to JSON and call `EventChartCustom()`
- `CTheMarketRobo_Base::on_chart_event()` dispatches by event ID to handlers
- Used for: config changes, symbol changes, termination requests, token refresh results

## Session Persistence (Indicators Only)

Indicators undergo non-destructive deinit/reinit on chart changes, timeframe changes, and recompiles. The SDK saves session state (JWT, session_id) to a file on non-destructive deinit and restores it on reinit, avoiding a new `/robot/start` call. Destructive deinit (indicator removed from chart) sends `/robot/end`.
