# TheMarketRobo SDK Documentation

## Overview

TheMarketRobo SDK is a comprehensive framework for building MQL5 Expert Advisors (EAs) with built-in authentication, session management, and real-time configuration updates. The SDK simplifies the development process by handling complex authentication flows, session lifecycle, and event management behind the scenes.

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
sdk-mql5-lib/
├── docs/                    # Documentation
├── Interfaces/              # Abstract interfaces (IRobotConfig)
├── Core/                    # Core SDK components
│   ├── CSDKConstants.mqh    # SDK constants and configuration
│   ├── CSDKOptions.mqh      # Feature toggles
│   ├── CSDKContext.mqh      # Main service container
│   ├── CSessionManager.mqh  # Session lifecycle
│   ├── CHeartbeatManager.mqh# Heartbeat communication
│   ├── CTokenManager.mqh    # JWT token management
│   ├── CConfigurationManager.mqh  # Config change handling
│   └── CSymbolManager.mqh   # Symbol change handling
├── Services/                # External service integrations
│   ├── Json.mqh             # JSON parser
│   ├── CHttpService.mqh     # HTTP client
│   └── CDataCollectorService.mqh  # Data collection
├── Models/                  # Data models
│   ├── CConfigField.mqh     # Config field definition
│   ├── CConfigSchema.mqh    # Config schema container
│   ├── CSessionSymbol.mqh   # Symbol data
│   └── CFinalStats.mqh      # Session statistics
├── Utils/                   # Utility classes
│   └── CSDK_Events.mqh      # Event definitions
├── CTheMarketRobo_Bot_Base.mqh  # Base class for robots
└── TheMarketRobo_SDK.mqh    # Main include file
```

## Getting Started — Expert Advisor

### 1. Include the SDK

```cpp
#include <TheMarketRobo/TheMarketRobo_SDK.mqh>
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

```cpp
class CMyRobot : public CTheMarketRobo_Bot_Base
{
public:
    // Programmer sets robot_version_uuid and config in constructor
    CMyRobot() : CTheMarketRobo_Bot_Base(
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
    robot.on_deinit(reason);
    delete robot;
}

void OnTimer() { robot.on_timer(); }
void OnTick() { robot.on_tick(); }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    robot.on_chart_event(id, lparam, dparam, sparam);
}
```

## Getting Started — Custom Indicator

Building a Custom Indicator uses the same SDK but requires less setup. Indicators do not use `IRobotConfig` classes and initialize without a magic number.

### 1. Include the SDK and Define Inputs

```cpp
#include <TheMarketRobo/TheMarketRobo_SDK.mqh>

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

```cpp
CMyIndicator* indicator = NULL;

int OnInit()
{
    indicator = new CMyIndicator();
    return indicator.on_init(InpApiKey);
}

void OnDeinit(const int reason)
{
    indicator.on_deinit(reason);
    delete indicator;
}

void OnTimer() { indicator.on_timer(); }

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
{
    return indicator.on_calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, spread);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    indicator.on_chart_event(id, lparam, dparam, sparam);
}
```

## Parameter Categories

### Programmer-Defined (Hardcoded in Robot)
- **robot_version_uuid**: Unique identifier assigned when registering the robot
- **IRobotConfig implementation**: Configuration schema and handling logic

### Customer-Provided (Input Parameters)
- **api_key**: API key from TheMarketRobo platform
- **magic_number**: MT5 magic number for trade identification

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

### CTheMarketRobo_Bot_Base Methods

#### Constructor
```cpp
CTheMarketRobo_Bot_Base(string robot_version_uuid, IRobotConfig* robot_config)
```

#### Lifecycle Methods
- `on_init(string api_key, long magic_number)` - Initialize SDK (returns INIT_SUCCEEDED/INIT_FAILED)
- `on_deinit(int reason)` - Cleanup resources
- `on_timer()` - Handle timer events
- `on_chart_event(...)` - Handle chart events

#### Feature Configuration
- `set_token_refresh_threshold(int seconds)` - Set proactive token refresh
- `set_enable_config_change_requests(bool enable)` - Toggle config changes
- `set_enable_symbol_change_requests(bool enable)` - Toggle symbol changes

#### Abstract Methods (Must Implement)
- `on_tick()` - Main trading logic
- `on_config_changed(string event_json)` - Handle config updates
- `on_symbol_changed(string event_json)` - Handle symbol changes

### IRobotConfig Interface

#### Schema Definition (Override)
- `define_schema()` - Define configuration fields using CConfigSchema
- `apply_defaults()` - Set member variables from schema defaults

#### Required Methods (Override)
- `to_json()` - Serialize to JSON
- `update_from_json(CJAVal &config_json)` - Update from server JSON
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
