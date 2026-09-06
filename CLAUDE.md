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

## CI and local verification

**"No compiler" is not "nothing can be checked."** Until ci-cd-hardening P13 (2026-09-06) this
repo had no `.github/` at all — no CI, no required check — while being **public, anonymously
clonable, and in the build path of every vendor robot** (audit ledger L-7, cited inside N-17). It
now has both.

**Tier 3 — the full required-checks mirror:**

```bash
bash tools/verify-local.sh
```

It mirrors `.github/workflows/ci.yml`'s aggregator, `required-checks`
(`needs: [sdk-tls-flags, secret-defaults, commitlint]`), one local gate per required job — and the
two source gates are **the same scripts CI runs**, not transcriptions of them:

| CI job | Local gate | What it defends |
|---|---|---|
| `sdk-tls-flags` | `tools/gate-sdk-tls-flags.sh` | `TMKR_INSECURE_TLS_DEBUG` is `#define`d nowhere, and every `IGNORE_CERT` mention sits inside a guard region or a comment. This is the SDK-1/MQL-1 defect: `CWinINetHttpService` once set `INTERNET_FLAG_IGNORE_CERT_CN_INVALID \| _DATE_INVALID` unconditionally, so every request — each carrying the vendor API key and the session token — accepted any CA-issued certificate for any hostname |
| `secret-defaults` | `tools/gate-secret-defaults.sh` | No credential-shaped `input string` default (or `.chr`/`.set` profile value) is non-empty. Scans by **name shape**, not by path, so the next site cannot be added silently |
| `commitlint` | the packages ci.yml installs, config pinned at `tools/commitlint.config.cjs`, over `merge-base(origin/main)..HEAD`. An **empty** range reports `NOTE`, never `PASS` |

There is deliberately **no `sdk-version-consistency` job here**: three of that gate's four assertion
sites (the `CLAUDE.md` claim, `.release-please-manifest.json`, the release tag) live in the wrapper
repo, so a copy here could only check the `#define` against itself. **The wrapper owns version
identity; this repo owns the source invariants.**

**Why both repos run the two source gates.** `mql5-sample-lib` scans the union of both trees through
the `Include/themarketrobo` gitlink — but only on a *wrapper* PR, and only at the sha the pointer
pins. A change merged here reaches this repo's `main`, and every clone of it, before any wrapper PR
exists to look. Two checks over the same code from opposite sides of one gitlink is the point, not
duplication.

**Tier 1–2:** `commit-msg` only, and deliberately no `pre-commit`/`pre-push` — there is nothing for
one to run (no linter, no formatter, no compiler on any laptop's PATH), and a hook that runs nothing
is a hook people learn to bypass.

```bash
bash tools/install-hooks.sh          # wires core.hooksPath -> .githooks
bash tools/install-hooks.sh --check  # report only
```

🚨 **Never enable `extensions.worktreeConfig` in this repo.** It is a submodule, and its shared
config carries `core.worktree` — the only line connecting the modules dir to the checkout. Enabling
the extension revokes the exception that makes `core.worktree` readable from the shared config, git
loses the work tree, and `git status` reports **every tracked file as deleted**, in every worktree
of the submodule at once. (Measured 2026-09-06; recovery is `git config --unset
extensions.worktreeConfig`.) `tools/install-hooks.sh` detects the submodule case and writes
`--local` instead — this is why it is a script and not one `git config` line.

`tools/commit-msg.sh`, `tools/lint-workflows.sh` and `tools/lib/verify-local-gate0.sh` are
**byte-identical copies** of hub's masters; `verify-local.sh`'s `gate0` `cmp`s all three. 🚫 Fix a
bug in hub and re-copy — never in place. The verb also red-proves the hook (a bad subject must be
REFUSED) and runs `tools/lint-workflows.sh` (`actionlint` + `zizmor --pedantic` against the
shrink-only `.github/zizmor-baseline.txt`); both are local-only and labelled as such in its header.

**Maintenance contract:** any change to `required-checks`'s `needs:` list, or to a mirrored step's
commands, updates `tools/verify-local.sh`'s header, `.github/required-checks.snapshot` and this
section **in the same PR**. Full fleet contract: hub's `.claude/rules/local-verification.md`.

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
