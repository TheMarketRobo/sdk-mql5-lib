---
paths:
  - "**/Core/CSessionManager.mqh"
  - "**/Core/CHeartbeatManager.mqh"
  - "**/Core/CTokenManager.mqh"
  - "**/Services/CDataCollectorService.mqh"
  - "**/Services/CHttpService.mqh"
---
> Backend API contract (extracted verbatim from CLAUDE.md, 2026-05-31 split). Read when changing session/heartbeat/refresh payloads — the contract lives in the sibling `aws/` repo with `additionalProperties: false`.

# Backend API Contract

The SDK talks to 4 endpoints:
- `POST /robot/start` — session init (sends `static_fields`, `session_symbols`, config)
- `POST /robot/heartbeat` — periodic telemetry (sends `dynamic_data`, sequence counter)
- `POST /robot/refresh` — JWT token renewal
- `POST /robot/end` — session termination

Contract schemas live in `aws/contracts/schemas/static_data/v1.json` and `aws/contracts/api/robot/components/robot-start.yaml` (separate repo). The `static_fields` schema has `additionalProperties: false` — any new field sent by the SDK must also be added to the contract.

MQL4 sessions omit 5 MQL5-only fields (`account_margin_mode`, `account_currency_digits`, `account_fifo_close`, `account_hedge_allowed`, `terminal_x64`). These are optional in the schema. The `platform` field (`"mt4"` or `"mt5"`) is also sent.

## Operational invariants

- **Heartbeat sequence**: Monotonically increasing counter. Server returns 409 on mismatch; SDK resyncs from response.
- **Token refresh**: Proactive — happens `SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD` (60s) before JWT expiry, not after. v1.3.1: the effective threshold is clamped to half the token's real lifetime (a configured threshold ≥ the lifetime used to make the predicate permanently true → ~1 refresh/sec self-DoS), and failed attempts are paced by `TMKR_TOKEN_REFRESH_RETRY_SECONDS` (30s).
- **Product type**: Determined server-side from database via `robot_version_uuid`, not from SDK payload.

## Start refusals (SDK v1.4.0)

A refused `POST /robot/start` answers RFC 7807 problem+json (`aws/src/endpoints/robot/robot-token/src/lib/problem-details.ts`).
`CTMKR_SessionManager::record_start_refusal()` reads three things and tolerates each being absent:

- top-level `code` — the canonical `TMKR-####`; it decides the reason (`TMKRStartRefusalFor()` in `Utils/CSDKUserErrors.mqh`). Only a body with no valid code falls back to the HTTP status, and a bodyless 401/403 is `TMKR_START_UNKNOWN` — never "key not recognized".
- top-level `detail` — printed to the Experts log only, never put in the Alert.
- `context` — extension members: `active_sessions` + `max_sessions` (`TMKR-4004`), `retry_after` (`TMKR-3050`), `allowed_trade_modes` (a demo-only licence refused with `TMKR-2006`).

**Anti-oracle — do not design around it.** The server answers an unknown key, a malformed key, a soft-deleted licence and a rotated-out key with a byte-identical `TMKR-2001` (header of `robot-token/src/lib/licence-gate.ts`). Keep `TMKR_START_KEY_NOT_RECOGNIZED` as ONE reason and keep its sentence from guessing which case happened.

A new refusal code must land in `aws/contracts/schemas/error_catalog/catalog.json` and be regenerated into `Core/CSDKErrorCatalog.generated.mqh`; an uncatalogued code resolves to `TMKR-9001` server-side.
