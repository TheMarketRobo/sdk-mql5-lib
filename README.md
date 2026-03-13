# TheMarketRobo SDK for MQL5

This directory contains `TheMarketRobo` MQL5 C++ Software Development Kit (SDK). It provides an object-oriented, clean interface to interact with TheMarketRobo ecosystem securely and reliably from within the MetaTrader 5 terminal.

## Integration Documentation

The SDK is heavily documented. Whether you are building an Expert Advisor or a Custom Indicator, you can find start-to-finish guides in the `docs/` folder:

1. 📖 **[SDK Integration Booklet](docs/SDK_INTEGRATION_BOOKLET.md)** - The best place to start. A step-by-step tutorial explaining core concepts and providing full examples for both EAs and Indicators.
2. 📐 **[Robot Config Component Schema](docs/schemas/robot_config_component_schema/README.md)** - **Robots only.** The configuration you define for your EA **MUST** conform to this schema. The Vendor Portal validates it before you can submit a robot version.
3. 🚀 **[Quick Start](docs/QUICK_START.md)** - 5-minute integration templates if you just want to get up and running quickly.
4. 📚 **[API Reference](docs/API_REFERENCE.md)** - Raw documentation on the `CTheMarketRobo_Base` class and its lifecycle hooks.
5. 🏗️ **[Architecture Overview](docs/README.md)** - Deep dive into how the SDK structures its state and syncs with the server.
6. ⚖️ **[Programmer Obligations](PROGRAMMER_OBLIGATIONS.md)** - Legal obligations and prohibited conduct when using the SDK and distributing products via The Market Robo.

For advanced developers looking to understand the underlying HTTP calls and JWT session management, check the [API Flow Docs](docs/api/important-notes.md).

## Core Capabilities

By inheriting from `CTheMarketRobo_Base`, your MQL5 application gains:
- **Licensing & Telemetry:** Establishes secure JWT sessions and reports live account margin, PnL, and drawdown without exposing private trade histories.
- **Remote Configuration (EA):** Defines local variable schemas that sync directly with the web platform, allowing realtime hot-swapping of parameters without recompiling. Robot config **MUST** follow the [Robot Config Component Schema](docs/schemas/robot_config_component_schema/README.md); the Vendor Portal validates it at submission.
- **Symbol Control (EA):** Fetches the active pairs allowed by the web interface.
- **Config change & symbol change support (EA):** Optional. Vendors can enable or disable remote config/symbol change requests. If enabled, the SDK delivers requests to the robot and reports results in the next heartbeat; the vendor implements `IRobotConfig` (and optionally overrides `on_config_changed` / `on_symbol_changed`) only if they need this behavior.

## Programmer Obligations

**By using this SDK you agree to the [Programmer Obligations and Prohibited Conduct](PROGRAMMER_OBLIGATIONS.md).** In particular:

- **No vendor or third-party redirects.** You must not include any name, link, or address in the product that redirects the customer to the vendor or any third party. The product must always be identified as **The Market Robo** app with the sole official URL **https://www.themarketrobo.com/**.
- **No time- or condition-based third-party promotion.** You must not implement any function or behaviour that triggers after a certain time or condition (e.g. alerts or messages) that introduce or promote third parties or other programmers. See [PROGRAMMER_OBLIGATIONS.md](PROGRAMMER_OBLIGATIONS.md) for the full list of prohibited acts and legal effect.

## DLL Usage (Indicators Only)

Custom Indicators cannot use the built-in `WebRequest()` function (MQL5 error 4014). The SDK works around this by using Windows DLLs for HTTP communication **only when running as an indicator**:

| DLL | Purpose |
|-----|---------|
| `kernel32.dll` | Error handling (`GetLastError`) |
| `wininet.dll` | HTTPS requests (`InternetOpenW`, `HttpSendRequestExW`, etc.) |

**Expert Advisors (EAs/Robots) do NOT use any DLLs** — they use the built-in `WebRequest()`.

### Indicator Setup Requirement

To use the SDK in an indicator, the end user must enable **"Allow DLL imports"** in MetaTrader 5:
1. Right-click the indicator on the chart → **Properties** → **Common** tab
2. Check **"Allow DLL imports"**

If DLL imports are not enabled, HTTP requests from the indicator will fail.

## SDK Enable/Disable Toggle (`SDK_ENABLED`)

The SDK includes a compile-time toggle that lets developers run their robot or indicator **without any SDK functionality**. This is useful for local development, debugging, or distributing standalone versions.

### How It Works

In `Core/CSDKConstants.mqh`, find:

```cpp
#define SDK_ENABLED
```

- **SDK enabled (default):** All SDK features are active — sessions, heartbeats, authentication, DLL imports (indicators).
- **SDK disabled:** Comment out or delete `#define SDK_ENABLED`. All SDK methods become safe no-ops. `on_init()` returns `INIT_SUCCEEDED` immediately. No network calls, no DLL imports, no API URLs in the binary.

### Security

When `SDK_ENABLED` is not defined, the compiled binary contains **zero SDK code** — no DLL references, no API URLs, no dead code. This is a compile-time exclusion, not a runtime check, so there is nothing to decompile or reverse-engineer.

## Log Level (Final Product)

The SDK supports configurable log levels (`SDK_LOG_ALL`, `SDK_LOG_INFO`, `SDK_LOG_WARNING`, `SDK_LOG_ERROR`). **For the final product delivered to customers, the programmer must set the log level to error level (`SDK_LOG_ERROR`).** Use higher verbosity only during development. Set via `SDKSetLogLevel(SDK_LOG_ERROR)` or `set_log_level(SDK_LOG_ERROR)` before `on_init()`, or expose an input parameter with default `SDK_LOG_ERROR`.
