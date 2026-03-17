# TheMarketRobo SDK — Indicator Integration Checklist

**Pre-release verification for Custom Indicators**

This checklist is for programmers who have integrated the TheMarketRobo SDK into a **Custom Indicator** (e.g. with AI assistance) and need to verify the integration before release. It covers code correctness, programmer obligations, and **full testing of server connection scenarios using a test license**. It applies **only to indicators**, not to Expert Advisors.

---

## References

- [SDK Integration Booklet](SDK_INTEGRATION_BOOKLET.md) — Indicator quick start (§6.5), DLL usage (§17), lifecycle
- [API Reference](API_REFERENCE.md) — `CTheMarketRobo_Base` (indicator constructor, `on_init(api_key)`, `on_calculate`)
- [Programmer Obligations](../PROGRAMMER_OBLIGATIONS.md) — Mandatory branding, log level, prohibited conduct
- [README (docs)](README.md) — Architecture, indicator vs robot, DLL requirement

---

## Part 1 — Code and structure (indicator-specific)

Use this section to confirm the integration matches the SDK contract for indicators.

- [ ] **Include path**  
  `#include <themarketrobo/TheMarketRobo_SDK.mqh>` (lowercase folder name).

- [ ] **Constructor**  
  Indicator uses the **one-argument** constructor only:  
  `CTheMarketRobo_Base(indicator_version_uuid)`.  
  No second argument (no `IRobotConfig`).

- [ ] **No robot-only code**  
  No `IRobotConfig` class, no `magic_number`, no `on_init(api_key, magic_number)`.  
  Use `on_init(api_key)` only.

- [ ] **Indicator version UUID**  
  UUID is exactly 36 characters and matches the **indicator** version UUID from the Vendor Portal (not a robot UUID).

- [ ] **Input parameter**  
  API key is provided via an input (e.g. `input string InpApiKey = "";`). Not hardcoded.

- [ ] **OnInit**  
  Creates indicator instance, then calls `indicator.on_init(InpApiKey)`.  
  No magic number passed.  
  Returns `INIT_SUCCEEDED` / `INIT_FAILED` (or `INIT_PARAMETERS_INCORRECT` if API key empty).

- [ ] **OnDeinit**  
  Calls `indicator.on_deinit(reason)` then `delete indicator` and sets pointer to `NULL`.

- [ ] **OnTimer**  
  Implemented and forwards to `indicator.on_timer()` (required for heartbeats).

- [ ] **OnChartEvent**  
  Implemented and forwards to `indicator.on_chart_event(id, lparam, dparam, sparam)`.

- [ ] **OnCalculate**  
  Forwards to `indicator.on_calculate(...)` and returns its result (e.g. `rates_total`).  
  Indicator buffers (e.g. `SetIndexBuffer`, `IndicatorSetInteger`) are set in `OnInit` as usual.

- [ ] **Pointer checks**  
  Before every call to the indicator instance, use `CheckPointer(indicator) != POINTER_INVALID` (or equivalent).

- [ ] **Config/symbol change**  
  Indicators do not use config or symbol change requests; no need to call `set_enable_config_change_requests` / `set_enable_symbol_change_requests` (they are not used for indicators).

---

## Part 2 — Programmer obligations and delivery

Must be satisfied before distributing the indicator to customers.

- [ ] **Log level for final product**  
  SDK log level is set to **`SDK_LOG_ERROR`** (errors only).  
  Use `SDKSetLogLevel(SDK_LOG_ERROR)` or `indicator.set_log_level(SDK_LOG_ERROR)` before `on_init()`, or an input with default `SDK_LOG_ERROR`.  
  Higher verbosity (`SDK_LOG_ALL`, `SDK_LOG_INFO`, `SDK_LOG_WARNING`) is used only during development.  
  See [PROGRAMMER_OBLIGATIONS.md §4.12](../PROGRAMMER_OBLIGATIONS.md).

- [ ] **Product identification**  
  No vendor or third-party names, links, or URLs in the indicator (UI, comments, alerts, objects).  
  Product is identified only as **The Market Robo** with the sole URL **https://www.themarketrobo.com/**.

- [ ] **No redirects**  
  No links or references to the programmer’s site, social media, or messaging (Telegram, Discord, etc.).

- [ ] **No time- or condition-based third-party promotion**  
  No alerts, messages, or behaviour that trigger after a time or condition and promote the programmer or any third party.  
  No “time bombs” or expiry messages that direct users away from the platform.

- [ ] **Copyright / link**  
  `#property copyright` and `#property link` (if used) do not replace or contradict The Market Robo / TMKR GLOBAL, LLC identification.  
  No removal or alteration of SDK/Company branding.

- [ ] **No external URLs or executables**  
  No `ShellExecuteW` or other means to open a browser or executable to any URL other than the sole permitted one (and only where necessary for product identification).

- [ ] **SDK not bypassed for platform distribution**  
  The version distributed via or in connection with The Market Robo platform does **not** have the SDK disabled (e.g. `SDK_ENABLED` commented out) for the purpose of avoiding session/heartbeat/licensing.

- [ ] **SDK source unchanged**  
  No modification to SDK files (e.g. `CSDKConstants.mqh`, `SDK_API_BASE_URL`) to redirect traffic or change platform identity.

---

## Part 3 — DLL and MT5 setup (indicators only)

Indicators use Windows DLLs for HTTP; EAs do not.

- [ ] **Allow DLL imports**  
  Documented or communicated to the user: for the indicator to connect, **“Allow DLL imports”** must be checked in MetaTrader 5 (indicator **Properties → Common** tab).  
  Verified that when unchecked, the failure is clear (e.g. session does not start; Experts tab shows relevant error).

- [ ] **DLLs used**  
  Acknowledged that the SDK uses `kernel32.dll` and `wininet.dll` only when running as an indicator (see [README](../README.md), [SDK_INTEGRATION_BOOKLET.md §17](SDK_INTEGRATION_BOOKLET.md)).

---

## Part 4 — Test license and allowed URL

All connection tests must use a **test license** and the **staging** API.

- [ ] **Test license**  
  A **test license** has been created in the Vendor Portal and its **API key** is used for all tests below.  
  Production licenses are **not** used for development/testing.

- [ ] **Staging URL**  
  Staging base URL is **`https://api.staging.themarketrobo.com`** (no trailing slash).  
  MT5 **Tools → Options → Expert Advisors** has this URL added under **“Allow WebRequest for listed URL”** (or equivalent).  
  Note: For indicators, HTTP is done via DLL (wininet); the allowed list may still be relevant depending on your MT5 build. Ensure no request is blocked.

---

## Part 5 — Server connection scenarios (test license)

Test each scenario with the indicator attached and **Allow DLL imports** enabled (unless testing the “DLL disabled” case). Use the **test license** API key and staging environment.

### 5.1 — Successful session start

- [ ] **Valid test API key, DLL allowed**  
  Attach indicator with correct test license API key.  
  **Expected:** Session starts; Experts tab shows success (e.g. “SDK session started successfully!” or equivalent).  
  No `INIT_FAILED` or session start error.

- [ ] **Heartbeats**  
  Leave indicator running for at least 2–3 heartbeat intervals (e.g. 2–3 minutes if interval is 60 s).  
  **Expected:** No heartbeat errors in Experts tab; session remains active.

- [ ] **Timer**  
  Confirm that `OnTimer` is called (SDK sets a 1-second timer).  
  **Expected:** Heartbeats and token refresh run via timer; no need to call `EventSetTimer()` yourself.

### 5.2 — Invalid or missing API key

- [ ] **Empty API key**  
  Attach indicator with empty API key.  
  **Expected:** Initialization fails with a clear error (e.g. “API Key is required!”) and appropriate return code (e.g. `INIT_PARAMETERS_INCORRECT` or `INIT_FAILED`).  
  No crash, no successful session.

- [ ] **Invalid API key**  
  Use an invalid or expired key (e.g. random string or wrong key).  
  **Expected:** Session start fails; SDK reports failure (e.g. “Failed to start SDK session” or similar).  
  Indicator does not run with an active session.

### 5.3 — DLL imports disabled (indicator only)

- [ ] **DLL imports unchecked**  
  Attach indicator with valid test API key but **uncheck “Allow DLL imports”** in indicator Properties → Common.  
  **Expected:** HTTP requests fail (no `WebRequest()` in indicators); session does not start.  
  Experts tab shows error from HTTP layer (e.g. CWinINetHttpService or equivalent).  
  Re-checking “Allow DLL imports” and re-attaching allows session to start.

### 5.4 — Network and server behaviour

- [ ] **Staging reachable**  
  With valid test key and DLL allowed, session starts and heartbeats continue.  
  **Expected:** No 4060 or “URL not allowed” type errors when staging URL is correctly allowed.

- [ ] **Token refresh**  
  Let the session run at least until the first token refresh (see SDK constants for threshold, e.g. 60 s before expiry).  
  **Expected:** No “Token refresh failed” or session drop due to expiry; session stays active.

- [ ] **Graceful shutdown**  
  Remove the indicator from the chart (or close the chart).  
  **Expected:** `OnDeinit` runs; SDK sends session end request to the server (`/robot/end` or equivalent); no crash; cleanup (e.g. timer killed, instance deleted).

### 5.5 — Server-requested termination (indicator)

- [ ] **Termination request**  
  If the platform supports sending a termination request to the indicator (e.g. via heartbeat response), trigger it during a test.  
  **Expected:** SDK receives termination request; for indicators the SDK **stops the timer** (`EventKillTimer()`) and alerts/informs the user to remove the indicator.  
  **Not** `ExpertRemove()` (that is for EAs only).  
  Session end is reported to the server.

### 5.6 — Multiple instances and reattach

- [ ] **Two charts**  
  Attach the same indicator to two different charts (same or different symbols), each with the same test API key (if the platform allows).  
  **Expected:** Each instance starts its own session; no cross-chart crash or shared state; both send heartbeats.

- [ ] **Reattach**  
  Remove indicator, then attach again with the same test key.  
  **Expected:** New session starts cleanly; previous session was properly ended on removal.

### 5.7 — Standalone build (SDK disabled)

- [ ] **SDK disabled build**  
  Comment out `#define SDK_ENABLED` in `Core/CSDKConstants.mqh`, recompile, run indicator (with or without API key).  
  **Expected:** `on_init(api_key)` returns `INIT_SUCCEEDED` immediately; no network calls; no DLL usage; indicator logic still runs.  
  Use this only for non-platform builds (e.g. standalone); do **not** distribute this build as the platform-connected product.

---

## Part 6 — Final sign-off

- [ ] All items in **Parts 1–5** that apply to your indicator have been checked.
- [ ] Tests were performed with a **test license** and **staging** API only.
- [ ] Programmer obligations (Part 2) are met for the build you intend to deliver to customers.
- [ ] Log level for the **delivered** indicator is **`SDK_LOG_ERROR`**.

---

## Quick reference — Indicator vs EA

| Item              | Indicator                         | EA (for reference only)        |
|-------------------|-----------------------------------|--------------------------------|
| Constructor       | `CTheMarketRobo_Base(uuid)`        | `CTheMarketRobo_Base(uuid, config)` |
| Init              | `on_init(api_key)`                | `on_init(api_key, magic)`      |
| HTTP              | Via DLL (wininet)                 | `WebRequest()`                 |
| DLL imports       | Must be allowed                   | Not used                       |
| Config/symbol     | Not used                          | Optional                       |
| On termination    | Timer stopped, user removes       | `ExpertRemove()`               |

---

*This checklist is part of the TheMarketRobo SDK documentation. For legal obligations, see [PROGRAMMER_OBLIGATIONS.md](../PROGRAMMER_OBLIGATIONS.md).*
