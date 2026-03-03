# TheMarketRobo SDK Documentation

## Overview

TheMarketRobo SDK is a comprehensive framework for building MQL5 **Expert Advisors (EAs)** and **Custom Indicators** with built-in authentication, session management, and real-time configuration updates. The SDK supports both product types through a single base class (`CTheMarketRobo_Base`). Indicator support is included alongside EA support; indicators use the same session and heartbeat flow but do not use remote configuration or symbol change requests. The SDK simplifies development by handling authentication flows, session lifecycle, and event management behind the scenes.

## Architecture

The SDK follows a clean architecture pattern with the following key components:

### Core Components

1. **CTheMarketRobo_Base** - Abstract base class for all trading robots (Expert Advisors) and Custom Indicators
2. **CSDKContext** - Service container managing all SDK components
3. **Session Management** - Handles authentication and session lifecycle
4. **Configuration Management** - Real-time config updates from server with schema validation
5. **Event System** - Chart events for SDK communication

### Directory Structure

```
themarketrobo/                    # SDK root (e.g. MQL5/Include/themarketrobo/)
├── docs/                         # Documentation
├── Interfaces/                   # Abstract interfaces (IRobotConfig)
├── Core/                         # Core SDK components
│   ├── CSDKConstants.mqh         # SDK constants and configuration
│   ├── CSDKOptions.mqh           # Feature toggles
│   ├── CSDKContext.mqh           # Main service container
│   ├── CSessionManager.mqh        # Session lifecycle
│   ├── CHeartbeatManager.mqh     # Heartbeat communication
│   ├── CTokenManager.mqh         # JWT token management
│   ├── CConfigurationManager.mqh # Config change handling
│   └── CSymbolManager.mqh        # Symbol change handling
├── Services/                     # External service integrations
│   ├── Json.mqh                  # JSON parser
│   ├── CHttpService.mqh          # HTTP client
│   └── CDataCollectorService.mqh # Data collection
├── Models/                       # Data models
│   ├── CConfigField.mqh         # Config field definition
│   ├── CConfigSchema.mqh        # Config schema container
│   ├── CSessionSymbol.mqh        # Symbol data
│   └── CFinalStats.mqh          # Session statistics
├── Utils/                        # Utility classes
│   └── CSDK_Events.mqh          # Event definitions
├── CTheMarketRobo_Base.mqh       # Unified base class (EAs and Indicators)
├── CTheMarketRobo_Bot_Base.mqh  # Backwards-compat alias for CTheMarketRobo_Base
└── TheMarketRobo_SDK.mqh         # Main include file
```

## Getting Started — Expert Advisor

### 1. Include the SDK

Use the **lowercase** folder name `themarketrobo` so the path matches the repository and works on case-sensitive systems:

```cpp
#include <themarketrobo/TheMarketRobo_SDK.mqh>
```

### 2. Define Input Parameters (Customer-Provided)

```cpp
// These are provided by the customer, not hardcoded
input string InpApiKey = "";           // API Key from TheMarketRobo
input long   InpMagicNumber = 12345;   // Magic Number for trade identification
```

### 3. Create Your Robot Configuration with Schema

```cpp
class CMyRobotConfig : public IRobotConfig
{
private:
    // Actual config values
    int    m_max_trades;
    double m_stop_loss_percent;
    bool   m_use_trailing_stop;
    string m_trading_mode;

public:
    CMyRobotConfig()
    {
        define_schema();   // Define field types and constraints
        apply_defaults();  // Set initial values from schema
    }

protected:
    virtual void define_schema() override
    {
        // Integer field with range
        m_schema.add_field(
            CConfigField::create_integer("max_trades", "Maximum Trades", true, 5)
                .with_range(1, 20)
                .with_description("Maximum concurrent trades")
                .with_group("Risk Management", 1)
        );
        
        // Decimal field
        m_schema.add_field(
            CConfigField::create_decimal("stop_loss_percent", "Stop Loss %", true, 1.5)
                .with_range(0.5, 5.0)
                .with_precision(1)
                .with_group("Risk Management", 2)
        );
        
        // Boolean field
        m_schema.add_field(
            CConfigField::create_boolean("use_trailing_stop", "Use Trailing Stop", true, false)
                .with_group("Features", 1)
        );
        
        // Radio field with options
        m_schema.add_field(
            CConfigField::create_radio("trading_mode", "Trading Mode", true, "moderate")
                .with_option("conservative", "Conservative")
                .with_option("moderate", "Moderate")
                .with_option("aggressive", "Aggressive")
                .with_group("Strategy", 1)
        );
    }
    
    virtual void apply_defaults() override
    {
        m_max_trades = m_schema.get_default_int("max_trades");
        m_stop_loss_percent = m_schema.get_default_double("stop_loss_percent");
        m_use_trailing_stop = m_schema.get_default_bool("use_trailing_stop");
        m_trading_mode = m_schema.get_default_string("trading_mode");
    }

public:
    // Implement remaining abstract methods...
    virtual string to_json() override { /* serialize to JSON */ }
    virtual bool update_from_json(const CJAVal &config_json) override { /* update from server */ }
    virtual bool update_field(string field_name, string new_value) override { /* update specific field */ }
    virtual string get_field_as_string(string field_name) override { /* get field value */ }
};
```

### 4. Create Your Robot Class

Your EA can extend either `CTheMarketRobo_Base` or the alias `CTheMarketRobo_Bot_Base`; both refer to the same unified base class.

```cpp
class CMyRobot : public CTheMarketRobo_Base
{
public:
    // Programmer sets robot_version_uuid and config in constructor
    CMyRobot() : CTheMarketRobo_Base(
        "550e8400-e29b-41d4-a716-446655440000",  // Programmer-defined UUID
        new CMyRobotConfig()                      // Programmer-defined config
    ) {}

    virtual void on_tick() override
    {
        // Your trading logic here
    }

    virtual void on_config_changed(string event_json) override
    {
        // Handle config changes
    }

    virtual void on_symbol_changed(string event_json) override
    {
        // Handle symbol changes
    }
};
```

### 5. Setup MQL5 Entry Points

```cpp
CMyRobot* robot = NULL;

int OnInit()
{
    robot = new CMyRobot();
    
    // Optional: Configure SDK features before init
    robot.set_enable_config_change_requests(true);
    robot.set_enable_symbol_change_requests(true);
    robot.set_token_refresh_threshold(300);  // 5 minutes
    
    // Initialize with customer-provided inputs
    return robot.on_init(InpApiKey, InpMagicNumber);
}

void OnDeinit(const int reason)
{
    if(CheckPointer(robot) != POINTER_INVALID)
    {
        robot.on_deinit(reason);
        delete robot;
        robot = NULL;
    }
}

void OnTimer()
{
    if(CheckPointer(robot) != POINTER_INVALID)
        robot.on_timer();
}
void OnTick()
{
    if(CheckPointer(robot) != POINTER_INVALID)
        robot.on_tick();
}
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(CheckPointer(robot) != POINTER_INVALID)
        robot.on_chart_event(id, lparam, dparam, sparam);
}
```

## Getting Started — Custom Indicator

Building a Custom Indicator uses the same SDK and the same base class (`CTheMarketRobo_Base`) with the **one-argument constructor** (indicator version UUID only). Indicators do not use `IRobotConfig` classes and initialize with `on_init(api_key)` (no magic number). Session registration, heartbeats, and termination are still handled by the SDK; config and symbol change requests are not used for indicators.

### 1. Include the SDK and Define Inputs

```cpp
#include <themarketrobo/TheMarketRobo_SDK.mqh>

input string InpApiKey = "";           // API Key from TheMarketRobo
```

### 2. Create Your Indicator Class

```cpp
class CMyIndicator : public CTheMarketRobo_Base
{
public:
    CMyIndicator() : CTheMarketRobo_Base("550e8400-e29b-41d4-a716-446655440000") {}

    virtual int on_calculate(const int rates_total, const int prev_calculated,
                             const datetime &time[], const double &open[],
                             const double &high[], const double &low[],
                             const double &close[], const long &tick_volume[],
                             const long &volume[], const int &spread[]) override
    {
        // Your custom indicator logic here
        return rates_total;
    }
};
```

### 3. Setup MQL5 Entry Points

For indicators, set up your indicator buffers (e.g. `SetIndexBuffer`, `IndicatorSetInteger`) in `OnInit` as usual; create your indicator instance and call `on_init(InpApiKey)`. Forward `OnCalculate`, `OnTimer`, and `OnChartEvent` to the SDK instance so heartbeats and termination work.

```cpp
CMyIndicator* indicator = NULL;

int OnInit()
{
    indicator = new CMyIndicator();
    if(CheckPointer(indicator) == POINTER_INVALID)
        return INIT_FAILED;
    return indicator.on_init(InpApiKey);
}

void OnDeinit(const int reason)
{
    if(CheckPointer(indicator) != POINTER_INVALID)
    {
        indicator.on_deinit(reason);
        delete indicator;
        indicator = NULL;
    }
}

void OnTimer()
{
    if(CheckPointer(indicator) != POINTER_INVALID)
        indicator.on_timer();
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
{
    if(CheckPointer(indicator) != POINTER_INVALID)
        return indicator.on_calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, spread);
    return rates_total;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(CheckPointer(indicator) != POINTER_INVALID)
        indicator.on_chart_event(id, lparam, dparam, sparam);
}
```

## Parameter Categories

### Programmer-Defined (Hardcoded in Robot or Indicator)
- **robot_version_uuid / indicator_version_uuid**: Unique identifier assigned when registering the robot or indicator on TheMarketRobo platform
- **IRobotConfig implementation**: Configuration schema and handling logic (Expert Advisors only; indicators do not use config)

### Customer-Provided (Input Parameters)
- **api_key**: API key from TheMarketRobo platform
- **magic_number**: MT5 magic number for trade identification (Expert Advisors only; indicators omit this)

### SDK Constants (Hardcoded in SDK)
- **base_url**: API endpoint (SDK_API_BASE_URL in CSDKConstants.mqh)

## Feature Configuration

The SDK supports optional features that can be enabled/disabled:

```cpp
// Call BEFORE on_init()
robot.set_enable_config_change_requests(false);  // Disable config changes
robot.set_enable_symbol_change_requests(false);  // Disable symbol changes
robot.set_token_refresh_threshold(600);          // Refresh 10 min before expiry
```

## Event Handling

The SDK uses MQL5 Chart Events for communication:

| Event ID | Description |
|----------|-------------|
| `SDK_EVENT_CONFIG_CHANGED` | Configuration updated from server |
| `SDK_EVENT_SYMBOL_CHANGED` | Trading symbol status changed |
| `SDK_EVENT_TERMINATION_START` | Session termination initiated |
| `SDK_EVENT_TERMINATION_END` | Session termination completed |
| `SDK_EVENT_TERMINATION_REQUESTED` | Server requested session termination |
| `SDK_EVENT_TOKEN_REFRESH` | Authentication token refreshed |

## API Contract Compliance

The SDK produces data structures matching the API contracts exactly:

### Start Request (matches RobotStartRequest)
- api_key, robot_version_uuid, magic_number
- account_currency, initial_balance, initial_equity
- static_fields (matches static_data/v1.json)
- session_symbols (matches session_symbols/v1.json)

### Heartbeat Request (matches RobotHeartbeatRequest)
- sequence, timestamp (ISO 8601)
- dynamic_data (account_balance, account_equity, etc.)
- config_change_results (optional, with status enum)
- symbols_change_results (optional, with status enum)

### Change Result Status Values
- `all_accepted`: All changes were applied
- `all_rejected`: No changes were applied
- `partially_accepted`: Some changes were applied

## API Reference

### CTheMarketRobo_Base / CTheMarketRobo_Bot_Base

The unified base class for both Expert Advisors and Custom Indicators. `CTheMarketRobo_Bot_Base` is a backwards-compatibility alias for `CTheMarketRobo_Base`; both refer to the same class.

#### Constructors

**Expert Advisor (Robot):**
```cpp
CTheMarketRobo_Base(string robot_version_uuid, IRobotConfig* robot_config)
```

**Custom Indicator:**
```cpp
CTheMarketRobo_Base(string indicator_version_uuid)   // One argument only; no config
```

#### Lifecycle Methods

- `on_init(string api_key, long magic_number)` — Initialize SDK for **Robot** (returns INIT_SUCCEEDED/INIT_FAILED)
- `on_init(string api_key)` — Initialize SDK for **Indicator** (no magic number)
- `on_deinit(int reason)` — Cleanup resources
- `on_timer()` — Handle timer events (heartbeats; must be forwarded from MQL5 `OnTimer`)
- `on_chart_event(...)` — Handle chart events (must be forwarded from MQL5 `OnChartEvent`)

#### Feature Configuration
- `set_token_refresh_threshold(int seconds)` - Set proactive token refresh
- `set_enable_config_change_requests(bool enable)` - Toggle config changes
- `set_enable_symbol_change_requests(bool enable)` - Toggle symbol changes

#### Abstract / Override Methods

- **Robot:** `on_tick()` — Main trading logic. `on_config_changed(string event_json)` — Handle config updates. `on_symbol_changed(string event_json)` — Handle symbol changes.
- **Indicator:** Override `on_calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, spread)` — return `rates_total`.

### IRobotConfig Interface

#### Schema Definition (Override)
- `define_schema()` - Define configuration fields using CConfigSchema
- `apply_defaults()` - Set member variables from schema defaults

#### Required Methods (Override)
- `to_json()` - Serialize to JSON
- `update_from_json(const CJAVal &config_json)` - Update from server JSON
- `update_field(string field_name, string new_value)` - Update specific field
- `get_field_as_string(string field_name)` - Get field as string

#### Provided Methods (Use Schema)
- `validate_field(...)` - Uses schema for validation
- `get_field_names(...)` - Gets keys from schema

### CConfigField Factory Methods

```cpp
CConfigField::create_integer(key, label, required, default_value)
CConfigField::create_decimal(key, label, required, default_value)
CConfigField::create_boolean(key, label, required, default_value)
CConfigField::create_radio(key, label, required, default_value)
CConfigField::create_multiple(key, label, required)
```

### CConfigField Fluent Setters

```cpp
.with_description(string)
.with_range(double min, double max)
.with_step(double)
.with_precision(int)
.with_option(string value, string label)
.with_group(string group_name, int order)
```

## Security Considerations

1. **API Key Protection**: Never hardcode API keys - use input parameters
2. **Session Monitoring**: SDK automatically monitors session health
3. **Automatic Removal**: EA removes itself on authentication failures
4. **Token Management**: Proactive token refresh before expiration

## Support

For additional support:
- Review the SDK source code for implementation details
- Contact TheMarketRobo support team

---

*Last updated: 2024*
*SDK Version: 1.00*
