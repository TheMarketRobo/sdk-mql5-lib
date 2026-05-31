# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Multi-phase work

Large multi-phase work uses the **`phased-execution`** skill (`/phased-execution`) — one phase per session.
Plans live in the hub repo's `docs/plans/<slug>.md`, per-phase handoffs in `docs/handoffs/<slug>/`, durable
facts in the memory index. See the hub `CLAUDE.md` + `.claude/rules/phased-execution.md`.

## What This Repo Is

The TheMarketRobo SDK for MQL4/MQL5 — a connectivity and lifecycle management library (not trading logic) that connects MetaTrader Expert Advisors and Custom Indicators to the TheMarketRobo platform. This is a git submodule (`TheMarketRobo/sdk-mql5-lib`) consumed by the parent sample repo at `Include/themarketrobo/`.

The parent repo (`mql5-sample-lib`) contains sample integrations and MetaQuotes standard library files. SDK development happens here; integration examples live in the parent.

## Language

MQL4/MQL5 (C++-like). Files are `.mqh` headers — no standalone compilation. Compilation requires MetaEditor (MetaTrader IDE); there is no CLI build system. The only way to test is to compile in MetaEditor and attach to a chart.

## Directory Map

- `TheMarketRobo_SDK.mqh` — single public include (pulls in everything)
- `TMR_Platform.mqh` — MQL4/MQL5 compatibility layer (sentinels, wrappers, guards)
- `TMR_AutoWire.mqh` — boilerplate-elimination macros for event-handler wiring
- `CTheMarketRobo_Base.mqh` / `CTheMarketRobo_Bot_Base.mqh` — public entry-point classes
- `Core/` — managers + `CSDKContext` (service container) + `CSDKConstants` (`SDK_ENABLED` toggle) + generated error catalog
- `Services/` — `CHttpService`, `CWinINetHttpService`, `CDataCollectorService`, `Json.mqh` (CJAVal)
- `Models/` — pure data structs (`CConfigField`, `CConfigSchema`, `CSessionSymbol`, `CFinalStats`)
- `Interfaces/IRobotConfig.mqh` — abstract base for vendor config
- `Utils/` — `CSDKLogger`, `CSDKUserErrors`, `CSDK_Events`
- `docs/` — `API_REFERENCE.md`, `MQL4_CROSS_PLATFORM.md`, `STRATEGY_TESTER_GUIDE.md`, integration booklets, schemas

## Detailed guides (`.claude/rules/`)

Path-scoped deep-dives (auto-load when you touch the matching files; also read them directly when relevant):

- **`architecture.md`** — include chain, `CSDKContext` service container + timer loop, HTTP dispatch by product type, event system, indicator session persistence. *(editing `Core/**`, `Services/**`, the public include)*
- **`cross-platform.md`** — `TMR_Platform.mqh` sentinel+guard pattern, 3-layer secure termination, `Sleep()` restriction. *(editing `TMR_Platform.mqh` or any `.mq4`)*
- **`backend-contract.md`** — the 4 `/robot/*` endpoints, `static_fields` schema (`additionalProperties: false`), MQL4-omitted fields, heartbeat/token/product-type invariants. *(editing session/heartbeat/token managers)*

## Naming Conventions

- Classes: `C` prefix (`CTokenManager`, `CSessionSymbol`)
- Interfaces: `I` prefix (`IRobotConfig`) — implemented as classes with pure virtual functions, not `interface` keyword
- Member variables: `m_` prefix (`m_jwt`, `m_session_id`)
- Global variables: `g_` prefix, always `NULL`-initialized
- Input parameters: `Inp` prefix (`InpApiKey`, `InpDepth`)
- SDK log messages: Always prefixed with `"SDK Info: "`, `"SDK Warning: "`, `"SDK Error: "`
- User-facing errors: Shown via `Alert()` through `SDKUserError()` / `SDKUserErrorWithDetails()`

## SDK Integration Tool

The backend (`aws/src/endpoints/common/sdk-integrator/`) provides an automated SDK integration service accessible from the Vendor Portal. It parses vendor MQL source code and produces SDK-integrated output:

- **Template path** (simple indicators): Deterministic code generation, ~200ms, free
- **Deterministic mapper** (large EAs with 30+ inputs): Heuristic-based config schema, instant, free
- **LLM path** (complex indicators, small EAs): AI-powered via Anthropic Claude API for semantic understanding

The tool uses the same SDK patterns documented here. When modifying SDK classes or methods, the integration tool's prompts and validators should also be updated (`aws/src/endpoints/common/sdk-integrator/src/lib/`).

## Key Things to Know

- **Log level for production**: Final products must set `SDK_LOG_ERROR` before `on_init()`. Debug/info logging is for development only.
- **Indicator DLL requirement**: End users must enable "Allow DLL imports" for indicators. EAs need no DLLs.
- **Config schema**: Only robots have configs. The schema must match the [Robot Config Component Schema](docs/schemas/robot_config_component_schema/README.md) — the Vendor Portal validates it at submission.
- Heartbeat sequence / token refresh / server-side product-type rules → see `.claude/rules/backend-contract.md`.
