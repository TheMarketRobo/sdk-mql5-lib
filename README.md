# TheMarketRobo SDK for MQL5

This directory contains `TheMarketRobo` MQL5 C++ Software Development Kit (SDK). It provides an object-oriented, clean interface to interact with TheMarketRobo ecosystem securely and reliably from within the MetaTrader 5 terminal.

## Integration Documentation

The SDK is heavily documented. Whether you are building an Expert Advisor or a Custom Indicator, you can find start-to-finish guides in the `docs/` folder:

1. 📖 **[SDK Integration Booklet](docs/SDK_INTEGRATION_BOOKLET.md)** - The best place to start. A step-by-step tutorial explaining core concepts and providing full examples for both EAs and Indicators.
2. 🚀 **[Quick Start](docs/QUICK_START.md)** - 5-minute integration templates if you just want to get up and running quickly.
3. 📚 **[API Reference](docs/API_REFERENCE.md)** - Raw documentation on the `CTheMarketRobo_Base` class and its lifecycle hooks.
4. 🏗️ **[Architecture Overview](docs/README.md)** - Deep dive into how the SDK structures its state and syncs with the server.

For advanced developers looking to understand the underlying HTTP calls and JWT session management, check the [API Flow Docs](docs/api/important-notes.md).

## Core Capabilities

By inheriting from `CTheMarketRobo_Base`, your MQL5 application gains:
- **Licensing & Telemetry:** Establishes secure JWT sessions and reports live account margin, PnL, and drawdown without exposing private trade histories.
- **Remote Configuration (EA):** Defines local variable schemas that sync directly with the web platform, allowing realtime hot-swapping of parameters without recompiling.
- **Symbol Control (EA):** Fetches the active pairs allowed by the web interface.
- **Unified Base:** Built to support both event-driven EAs (`OnTick`) and loop-driven Indicators (`OnCalculate`).
