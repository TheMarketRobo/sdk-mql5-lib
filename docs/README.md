# TheMarketRobo SDK Documentation

## Overview

TheMarketRobo SDK is a comprehensive framework for building MQL5 Expert Advisors (EAs) with built-in authentication, session management, and real-time configuration updates. The SDK simplifies the development process by handling complex authentication flows, session lifecycle, and event management behind the scenes.

## Architecture

The SDK follows a clean architecture pattern with the following key components:

### Core Components

1. **CTheMarketRobo_Bot_Base** - Abstract base class for all trading robots
2. **CSDK_Context** - Service container managing all SDK components
3. **Session Management** - Handles authentication and session lifecycle
4. **Configuration Management** - Real-time config updates from server
5. **Event System** - Chart events for SDK communication

### Directory Structure

```
SDK/
├── docs/                 # Documentation
├── Interfaces/          # Abstract interfaces
├── Core/               # Core SDK components
├── Services/           # External service integrations
├── Utils/              # Utility classes and helpers
├── Models/             # Data models and DTOs
└── TheMarketRobo_SDK.mqh  # Main include file
```

## Getting Started

### 1. Include the SDK

```cpp
#include <TheMarketRobo/SDK/TheMarketRobo_SDK.mqh>
```

### 2. Create Your Robot Configuration

```cpp
class CMy_Bot_Config : public Irobot_Config
{
public:
    double max_risk_per_trade;
    int max_trades_per_day;
    bool enable_news_filter;

    // Implement required methods...
};
```

### 3. Create Your Robot Class

```cpp
class CMy_Bot : public CTheMarketRobo_Bot_Base
{
private:
    CMy_Bot_Config m_config;

public:
    CMy_Bot() : CTheMarketRobo_Bot_Base(&m_config) {}

    void on_tick() override {
        // Your trading logic here
    }

    void on_config_changed(string event_json) override {
        // Handle config changes
    }

    void on_symbol_changed(string event_json) override {
        // Handle symbol changes
    }
};
```

### 4. Setup MQL5 Entry Points

```cpp
CMy_Bot* g_bot;

int OnInit() {
    g_bot = new CMy_Bot();
    return g_bot.on_init(InpApiKey, "1.0.0", InpMagicNumber, InpBaseApiUrl);
}

void OnDeinit(const int reason) {
    g_bot.on_deinit(reason);
    delete g_bot;
}

void OnTimer() {
    g_bot.on_timer();
}

void OnTick() {
    g_bot.on_tick();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    g_bot.on_chart_event(id, lparam, dparam, sparam);
}
```

## Authentication & Session Management

The SDK automatically handles authentication and session management:

### Automatic Features

- **API Key Validation**: Validates API key on initialization
- **Session Establishment**: Creates secure session with server
- **Token Refresh**: Automatically refreshes authentication tokens
- **Session Monitoring**: Monitors session health via heartbeats
- **Automatic Removal**: Removes EA if authentication fails

### Session States

1. **Initializing**: SDK is setting up components
2. **Connecting**: Establishing connection with server
3. **Active**: Session is active and authenticated
4. **Terminating**: Session is being closed
5. **Terminated**: Session has ended

## Event Handling

The SDK uses MQL5 Chart Events for communication:

### SDK Events

| Event ID | Description |
|----------|-------------|
| `SDK_EVENT_CONFIG_CHANGED` | Configuration updated from server |
| `SDK_EVENT_SYMBOL_CHANGED` | Trading symbol status changed |
| `SDK_EVENT_TERMINATION_START` | Session termination initiated |
| `SDK_EVENT_TERMINATION_END` | Session termination completed |
| `SDK_EVENT_TOKEN_REFRESH` | Authentication token refreshed |

### Event Data Format

All events use JSON format:

```json
{
  "field": "max_risk_per_trade",
  "old_value": "1.5",
  "new_value": "2.0"
}
```

## Configuration Management

### Implementing Irobot_Config

```cpp
class CMy_Bot_Config : public Irobot_Config
{
public:
    double max_risk_per_trade;
    int max_trades_per_day;
    bool enable_news_filter;

    virtual bool validate_field(string field_name, string new_value, string &reason) {
        if(field_name == "max_risk_per_trade") {
            double risk = StringToDouble(new_value);
            if(risk > 0 && risk <= 5.0) return true;
            reason = "Risk must be between 0.1 and 5.0";
            return false;
        }
        // ... other validations
    }

    virtual string to_json() {
        return StringFormat(
            "{\"max_risk_per_trade\":%.2f,\"max_trades_per_day\":%d,\"enable_news_filter\":%s}",
            max_risk_per_trade, max_trades_per_day, enable_news_filter ? "true" : "false"
        );
    }

    virtual bool update_from_json(const CJAVal &config_json) {
        // Update from server JSON
    }

    virtual bool update_field(string field_name, string new_value) {
        // Update specific field
    }

    virtual string get_field_as_string(string field_name) {
        // Return field value as string
    }

    virtual void get_field_names(string &field_names[]) {
        string names[] = {"max_risk_per_trade", "max_trades_per_day", "enable_news_filter"};
        ArrayCopy(field_names, names);
    }
};
```

## Error Handling

### SDK Error Messages

The SDK provides clear error messages for different scenarios:

- **Authentication Failures**: "Failed to start SDK session. Check API Key and connection."
- **Session Termination**: "Session terminated by server. Reason: [reason]"
- **Token Refresh Failures**: "Failed to refresh authentication token"

### Best Practices

1. **Always Check Session Status**: The base class ensures `on_tick()` only runs when session is active
2. **Handle Configuration Changes**: Implement `on_config_changed()` to react to server updates
3. **Monitor Logs**: Check Expert Advisor logs for SDK messages
4. **Graceful Shutdown**: Let the SDK handle deinitialization

## Advanced Features

### Custom Event Handling

```cpp
void CMy_Bot::on_config_changed(string event_json) {
    CJAVal event_data;
    if(event_data.parse(event_json)) {
        string field = event_data["field"].get_string();
        string new_value = event_data["new_value"].get_string();

        PrintFormat("Config changed: %s = %s", field, new_value);

        // React to specific changes
        if(field == "max_risk_per_trade") {
            recalculate_lot_sizes();
        }
    }
}
```

### Trading Logic Integration

```cpp
void CMy_Bot::on_tick() {
    // SDK ensures session is active before calling this

    if(m_config.enable_trading && is_signal_present()) {
        // Execute trade
        execute_buy_order();
    }
}
```

## Troubleshooting

### Common Issues

1. **"Failed to create SDK Context"**
   - Check API key format
   - Verify network connectivity

2. **"Session terminated by server"**
   - Check API key validity
   - Review server-side configuration

3. **Configuration not updating**
   - Ensure `Irobot_Config` implementation is correct
   - Check JSON parsing in `update_from_json()`

### Debug Information

Enable detailed logging by checking:
- Expert Advisor logs in MetaTrader terminal
- Server response codes in SDK messages
- Event data parsing in custom handlers

## API Reference

### CTheMarketRobo_Bot_Base Methods

#### Lifecycle Methods
- `on_init(string api_key, string robot_version_uuid, long magic_number, string base_url)` - Initialize SDK
- `on_deinit(int reason)` - Cleanup resources
- `on_timer()` - Handle timer events
- `on_chart_event(int id, long &lparam[], double &dparam[], string &sparam[])` - Handle chart events

#### Abstract Methods (Must Implement)
- `on_tick()` - Main trading logic
- `on_config_changed(string event_json)` - Handle config updates
- `on_symbol_changed(string event_json)` - Handle symbol changes

### Irobot_Config Interface

#### Required Methods
- `validate_field(string field_name, string new_value, string &reason)` - Validate field values
- `to_json()` - Serialize to JSON
- `update_from_json(CJAVal &config_json)` - Update from server JSON
- `update_field(string field_name, string new_value)` - Update specific field
- `get_field_as_string(string field_name)` - Get field as string
- `get_field_names(string &field_names[])` - Get all field names

## Security Considerations

1. **API Key Protection**: Never hardcode API keys in source code
2. **Session Monitoring**: SDK automatically monitors session health
3. **Automatic Removal**: EA removes itself on authentication failures
4. **Token Management**: Secure token refresh mechanism

## Performance Optimization

1. **Event Processing**: Handle events efficiently to avoid blocking
2. **Memory Management**: SDK handles memory cleanup automatically
3. **Network Efficiency**: Optimized heartbeat and token refresh intervals
4. **Configuration Caching**: Local caching of configuration values

## Support

For additional support and questions:
- Check the example implementation in `Example_Bot.mq5`
- Review the SDK source code for implementation details
- Contact TheMarketRobo support team

---

*Last updated: 2024*
*SDK Version: 1.00*
