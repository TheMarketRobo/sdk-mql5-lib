# TheMarketRobo SDK — AI Agent Integration Prompt

> **Note:** This prompt is the reference document used by the **SDK Integration Tool** in the Vendor Portal. Vendors can use the tool directly instead of following this prompt manually — it automates the entire process for both indicators and EAs.

**Purpose:** This prompt is for an AI agent that will **read and understand the full TheMarketRobo SDK** and **integrate it into a given MQL4 or MQL5 Custom Indicator**. The agent will receive:
1. **The SDK root folder:** `Include/themarketrobo`
2. **The indicator source:** one or more `.mq4` / `.mq5` / `.mqh` files (the Custom Indicator to integrate)

The agent must fully understand the SDK from the provided folder and docs, then implement a correct, minimal integration without breaking existing indicator logic.

> **Platform support:** The SDK works on both MetaTrader 4 (build 600+) and MetaTrader 5. The class code, event handlers, and SDK lifecycle methods are identical. The only platform-specific code is indicator buffer setup syntax.

---

## Your task

Integrate the **TheMarketRobo SDK** into the provided **MQL4 or MQL5 Custom Indicator** so that the indicator:
- Registers a session with TheMarketRobo and sends heartbeats (licensing/telemetry).
- Complies with SDK contracts and programmer obligations.

**Product type:** Custom **Indicator** only (not an Expert Advisor). Indicators use the **one-argument** constructor, **no** `IRobotConfig`, **no** magic number, and **no** config/symbol change requests.

---

## Step 1 — Read and understand the SDK (mandatory)

Before writing any code:

1. **Read these in order:**
   - `Include/themarketrobo/README.md` — overview, capabilities, DLL usage (indicators), `SDK_ENABLED`, log level.
   - `Include/themarketrobo/docs/README.md` — architecture, directory structure, entry points.
   - `Include/themarketrobo/docs/SDK_INTEGRATION_BOOKLET.md` — **§6.5 Quick Start — Your First Indicator** (minimal indicator example), **§9** (MQL5 event wiring), **§17** (DLL usage for indicators), **§18** (`SDK_ENABLED`).
   - `Include/themarketrobo/docs/INDICATOR_INTEGRATION_CHECKLIST.md` — code structure, programmer obligations, DLL and MT5 setup, testing scenarios.
   - `Include/themarketrobo/docs/API_REFERENCE.md` — `CTheMarketRobo_Base` indicator constructor, `on_init(api_key)`, `on_calculate`, lifecycle.

2. **Understand:**
   - **Single include:** `#include <themarketrobo/TheMarketRobo_SDK.mqh>` (lowercase folder name).
   - **Indicator constructor:** `CTheMarketRobo_Base(indicator_version_uuid)` — one argument only; no second config parameter.
   - **Init:** `on_init(api_key)` — no magic number.
   - **Lifecycle:** SDK sets a 1-second timer; you must implement `OnTimer` and forward to the SDK. Do **not** call `EventSetTimer()` or `EventKillTimer()` yourself.
   - **DLL (indicators only):** HTTP is done via `kernel32.dll` and `wininet.dll`. End users must enable **“Allow DLL imports”** in the indicator’s Properties → Common. Document or mention this if you add user-facing text.
   - **Programmer obligations:** No vendor/third-party redirects; product identified only as **The Market Robo** with URL **https://www.themarketrobo.com/**. No time- or condition-based third-party promotion. Final product log level must be **`SDK_LOG_ERROR`** (set before `on_init()`).

---

## Step 2 — Integration requirements (indicator)

Apply the following to the **provided indicator** file(s):

1. **Include**
   - Add: `#include <themarketrobo/TheMarketRobo_SDK.mqh>` (once, at top or with other includes).

2. **Constants / inputs**
   - Add an **indicator version UUID** constant (e.g. placeholder or from Vendor Portal): 36-character UUID.
   - Add an **input** for the API key: `input string InpApiKey = "";` (or equivalent name). Do not hardcode the API key.

3. **Indicator class**
   - Create a **wrapper class** that inherits from `CTheMarketRobo_Base` and takes **only** the indicator version UUID in the constructor.
   - Implement or override **`on_calculate(...)`** so that:
     - It calls the **existing** indicator calculation logic (preserve all current behavior).
     - It returns the same value the original indicator returned (e.g. `rates_total` or the same return from the existing logic).
   - If the existing code already has a class that holds calculation state, the SDK wrapper can **own** an instance of that class and delegate `on_calculate` to it; do not duplicate calculation logic.

4. **MQL5 event handlers**
   - **OnInit:**  
     - Validate API key (if empty, return `INIT_PARAMETERS_INCORRECT` or `INIT_FAILED` and optionally alert).  
     - Set log level: `SDKSetLogLevel(SDK_LOG_ERROR);` (or `indicator.set_log_level(SDK_LOG_ERROR);`) before init.  
     - Create the SDK-based indicator instance, then call `indicator.on_init(InpApiKey)`.  
     - Do **not** pass a magic number.  
     - Keep any existing indicator setup (e.g. `SetIndexBuffer`, `IndicatorSetInteger`) as-is; run SDK init after or alongside as appropriate.
   - **OnDeinit:**  
     - Call `indicator.on_deinit(reason)`, then `delete indicator` and set pointer to `NULL`.
   - **OnTimer:**  
     - Forward to `indicator.on_timer()` (required for heartbeats). Use `CheckPointer(indicator) != POINTER_INVALID` before calling.
   - **OnChartEvent:**  
     - Forward to `indicator.on_chart_event(id, lparam, dparam, sparam)` (required for SDK events).
   - **OnCalculate:**  
     - Forward to `indicator.on_calculate(...)` and return its return value. Preserve all existing parameters and buffer behavior.

5. **Pointer checks**
   - Before every call to the indicator instance, ensure it is valid (e.g. `CheckPointer(indicator) != POINTER_INVALID`).

6. **No robot-only code**
   - Do **not** add `IRobotConfig`, magic number, `on_init(api_key, magic_number)`, or config/symbol change handling. Indicators do not use these.

---

## Step 3 — Compliance and delivery

- **Log level:** For the build intended for customers, set SDK log level to **`SDK_LOG_ERROR`** before `on_init()` (programmer obligation).
- **Identification:** Do not add vendor or third-party names/links; product is **The Market Robo** — **https://www.themarketrobo.com/**.
- **DLL:** If you add any user-facing instructions, note that “Allow DLL imports” must be enabled for the indicator (Properties → Common).
- **SDK source:** Do not modify files under `Include/themarketrobo` (no changes to `CSDKConstants.mqh`, URLs, or SDK logic).

---

## Step 4 — Verification (reference)

After integration, the result should satisfy (for checklist details see `docs/INDICATOR_INTEGRATION_CHECKLIST.md`):

- Include path: `themarketrobo/TheMarketRobo_SDK.mqh` (lowercase folder).
- Constructor: one-arg only `CTheMarketRobo_Base(indicator_version_uuid)`.
- Init: `on_init(InpApiKey)` only.
- OnInit / OnDeinit / OnTimer / OnChartEvent / OnCalculate correctly wired; pointer checks in place.
- Log level set to `SDK_LOG_ERROR` for the delivered product.
- No robot-only features (no config class, no magic number).

---

## Quick reference — Indicator vs EA

| Item        | Indicator (this task)              | EA (not this task)                    |
|------------|-------------------------------------|----------------------------------------|
| Constructor| `CTheMarketRobo_Base(uuid)`         | `CTheMarketRobo_Base(uuid, config)`   |
| Init       | `on_init(api_key)`                  | `on_init(api_key, magic)`             |
| Config     | None                                | `IRobotConfig`                         |
| HTTP       | Via DLL (wininet)                   | `WebRequest()`                         |
| DLL        | User must allow DLL imports         | Not used                               |

---

## Summary

You will be given:
- The **SDK folder** `Include/themarketrobo` (with `README.md` and `docs/`).
- The **indicator** file(s) (`.mq5` / `.mqh`).

You must:
1. **Read and understand** the SDK from the provided folder and the listed docs.
2. **Integrate** the SDK into the indicator by adding the single include, API key input, indicator version UUID, a wrapper class extending `CTheMarketRobo_Base` with one-arg constructor, and correct wiring of OnInit, OnDeinit, OnTimer, OnChartEvent, and OnCalculate, while **preserving all existing indicator behavior**.
3. **Comply** with programmer obligations (log level, branding, no third-party redirects) and document “Allow DLL imports” if adding user-facing text.

Use the SDK as a black box; do not modify SDK files. Implement only in the indicator source.
