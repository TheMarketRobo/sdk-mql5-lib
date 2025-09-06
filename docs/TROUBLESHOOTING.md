# SDK Troubleshooting Guide

## Common Issues and Solutions

### Authentication Problems

#### "Failed to start SDK session. Check API Key and connection."

**Symptoms:**
- EA fails to initialize
- Error message in logs
- Expert Advisor removed immediately

**Possible Causes:**
1. Invalid API key
2. Network connectivity issues
3. Server maintenance
4. Firewall blocking connections

**Solutions:**
```cpp
// 1. Verify API key format
input string InpApiKey = "sk-your-api-key-here"; // Should start with 'sk-'

// 2. Check network connectivity
// Ensure MetaTrader has internet access

// 3. Verify base URL
input string InpBaseApiUrl = "https://api.themarketrobo.com";

// 4. Check server status
// Visit https://themarketrobo.com/status for server status
```

#### "Failed to refresh authentication token"

**Symptoms:**
- EA running normally then suddenly stops
- Alert message about token refresh failure
- Expert Advisor removed automatically

**Solutions:**
1. Check internet connection stability
2. Verify API key hasn't expired
3. Restart the EA
4. Contact support if issue persists

### Configuration Issues

#### Configuration not updating from server

**Symptoms:**
- Server shows updated configuration
- EA continues using old values
- No config change events received

**Possible Causes:**
1. Invalid `Irobot_Config` implementation
2. JSON parsing errors
3. Network issues during update

**Debug Steps:**
```cpp
// 1. Add logging to validate_field method
virtual bool validate_field(string field_name, string new_value, string &reason) override
{
    PrintFormat("Validating field: %s = %s", field_name, new_value);
    // ... validation logic
}

// 2. Add logging to update_from_json method
virtual bool update_from_json(const CJAVal &config_json) override
{
    Print("Received config update from server");
    // ... update logic
    return success;
}

// 3. Check JSON structure
// Ensure server is sending correct JSON format
```

#### Field validation failures

**Symptoms:**
- Configuration updates rejected
- Validation error messages in logs

**Common Issues:**
```cpp
// Issue: Wrong data type conversion
if(field_name == "max_trades_per_day")
{
    int trades = StringToInteger(new_value); // Correct
    // NOT: int trades = StringToDouble(new_value); // Wrong
}

// Issue: Missing validation for all fields
virtual bool validate_field(string field_name, string new_value, string &reason) override
{
    if(field_name == "my_field")
    {
        // Add validation logic
        return true;
    }

    reason = "Unknown field: " + field_name; // Handle unknown fields
    return false;
}
```

### Event Handling Issues

#### Events not being processed

**Symptoms:**
- Configuration changes not reflected
- Symbol changes not handled
- No response to server events

**Debug Checklist:**
```cpp
// 1. Verify OnChartEvent is implemented
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
        g_bot.on_chart_event(id, lparam, dparam, sparam);
}

// 2. Add event logging
void CMy_Bot::on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    PrintFormat("Chart Event: id=%d, sparam=%s", id, sparam);
    // ... rest of event handling
}

// 3. Verify event constants
#include <TheMarketRobo/SDK/Utils/CSDK_Events.mqh>
// Ensure SDK_EVENT_* constants are defined
```

#### JSON parsing errors

**Symptoms:**
- "Failed to parse config change event JSON"
- Event data not accessible

**Solutions:**
```cpp
void CMy_Bot::on_config_changed(string event_json)
{
    PrintFormat("Raw event JSON: %s", event_json); // Debug: log raw JSON

    CJAVal event_data;
    if(!event_data.parse(event_json))
    {
        Print("Error: Failed to parse event JSON");
        return;
    }

    // Verify expected fields exist
    CJAVal* field_node = event_data["field"];
    if(CheckPointer(field_node) == POINTER_INVALID)
    {
        Print("Error: Missing 'field' in event data");
        return;
    }

    // Safe access to event data
    string field = field_node.get_string();
    // ... rest of processing
}
```

### Trading Logic Issues

#### on_tick() not being called

**Symptoms:**
- No trading activity
- Trading logic not executing

**Possible Causes:**
1. Session not active
2. SDK not properly initialized
3. Timer not set up correctly

**Debug Steps:**
```cpp
// 1. Add session status logging
void CMy_Bot::on_tick()
{
    Print("on_tick() called"); // Debug: confirm method is being called

    // Check session status
    if(!is_session_active()) // SDK method
    {
        Print("Warning: Session not active, skipping trading logic");
        return;
    }

    // ... trading logic
}

// 2. Verify OnTimer is implemented
void OnTimer()
{
    Print("OnTimer called"); // Debug: confirm timer is working
    if(CheckPointer(g_bot) != POINTER_INVALID)
        g_bot.on_timer();
}
```

#### Orders not executing

**Symptoms:**
- Signals generated but no orders placed
- OrderSend() failing

**Common Issues:**
```cpp
// Issue: Wrong order parameters
MqlTradeRequest request = {};
request.symbol = Symbol(); // Correct
// NOT: request.symbol = "EURUSD"; // Wrong if on different chart

// Issue: Invalid lot size
double lot_size = calculate_lot_size();
double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));

// Issue: Missing magic number
request.magic = InpMagicNumber; // Must match input parameter

// Debug: Check OrderSend result
if(OrderSend(request, result))
{
    PrintFormat("Order successful: ticket=%d", result.order);
}
else
{
    PrintFormat("Order failed: error=%d, description=%s",
                GetLastError(), result.comment);
}
```

### Memory and Performance Issues

#### Memory leaks

**Symptoms:**
- Increasing memory usage over time
- MetaTrader performance degradation

**Prevention:**
```cpp
// 1. Always delete dynamic objects
void OnDeinit(const int reason)
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
    {
        g_bot.on_deinit(reason);
        delete g_bot; // Important: delete the bot
    }
}

// 2. Check pointer validity
void OnTimer()
{
    if(CheckPointer(g_bot) != POINTER_INVALID) // Always check
        g_bot.on_timer();
}
```

#### High CPU usage

**Symptoms:**
- MetaTrader consuming excessive CPU
- Slow response times

**Optimization Tips:**
```cpp
// 1. Avoid heavy calculations in on_tick()
void CMy_Bot::on_tick()
{
    static datetime last_calculation = 0;
    if(TimeCurrent() - last_calculation < 60) return; // Throttle calculations

    // Heavy calculations here
    last_calculation = TimeCurrent();
}

// 2. Use efficient data structures
// Prefer arrays over dynamic lists for frequently accessed data
```

### Network and Connectivity Issues

#### Intermittent connection problems

**Symptoms:**
- Sporadic authentication failures
- Token refresh failures
- Configuration updates failing

**Solutions:**
```cpp
// 1. Implement retry logic
int retry_count = 0;
const int MAX_RETRIES = 3;

bool connect_with_retry()
{
    while(retry_count < MAX_RETRIES)
    {
        if(connect_to_server())
            return true;

        retry_count++;
        Sleep(1000 * retry_count); // Exponential backoff
    }
    return false;
}

// 2. Add connection monitoring
void check_connection_health()
{
    static datetime last_success = TimeCurrent();

    if(is_connected())
    {
        last_success = TimeCurrent();
    }
    else if(TimeCurrent() - last_success > 300) // 5 minutes
    {
        Print("Warning: Connection lost for 5+ minutes");
        // Trigger reconnection logic
    }
}
```

### Compilation Errors

#### Include path issues

**Symptoms:**
- Compilation errors about missing files
- "File not found" errors

**Solutions:**
```cpp
// Correct include paths
#include <TheMarketRobo/SDK/TheMarketRobo_SDK.mqh>
// NOT: #include <TheMarketRobo/TheMarketRobo_SDK.mqh>

// Ensure all required includes are present
#include <TheMarketRobo/SDK/Utils/CSDK_Events.mqh>
```

#### Type mismatch errors

**Symptoms:**
- Compilation errors about incompatible types

**Common Fixes:**
```cpp
// Issue: Wrong parameter types
virtual bool validate_field(string field_name, string new_value, string &reason)
// NOT: virtual bool validate_field(string field_name, string new_value, string reason)

// Issue: Missing const qualifiers
virtual bool update_from_json(const CJAVal &config_json)
// NOT: virtual bool update_from_json(CJAVal &config_json)

// Issue: Wrong return types
virtual string to_json() // Correct
// NOT: virtual void to_json() // Wrong
```

## Debug Logging

### Enable Comprehensive Logging

```cpp
// Add to your robot class
#define DEBUG_MODE true

void debug_log(string message)
{
    if(DEBUG_MODE)
        Print("[DEBUG] " + message);
}

// Use throughout your code
void CMy_Bot::on_config_changed(string event_json)
{
    debug_log("Config change event received: " + event_json);
    // ... rest of method
}
```

### Log Levels

```cpp
enum ENUM_LOG_LEVEL
{
    LOG_ERROR,    // Critical errors only
    LOG_WARNING,  // Warnings and errors
    LOG_INFO,     // General information
    LOG_DEBUG     // Detailed debug information
};

void log_message(string message, ENUM_LOG_LEVEL level = LOG_INFO)
{
    static ENUM_LOG_LEVEL current_level = LOG_INFO;

    if(level <= current_level)
    {
        string prefix = "";
        switch(level)
        {
            case LOG_ERROR: prefix = "[ERROR] "; break;
            case LOG_WARNING: prefix = "[WARNING] "; break;
            case LOG_DEBUG: prefix = "[DEBUG] "; break;
        }
        Print(prefix + message);
    }
}
```

## Getting Help

### Information to Provide When Reporting Issues

1. **SDK Version:** Check the version in your include files
2. **MetaTrader Version:** Help → About → Version
3. **Operating System:** Windows version and architecture
4. **Complete Error Logs:** Copy all relevant error messages
5. **Configuration:** Your `Irobot_Config` implementation
6. **Steps to Reproduce:** Detailed steps to reproduce the issue

### Support Resources

1. Check this troubleshooting guide first
2. Review the examples in `docs/EXAMPLES.md`
3. Consult the API reference in `docs/API_REFERENCE.md`
4. Contact TheMarketRobo support with the information above

## Performance Benchmarks

### Expected Performance Metrics

- **Initialization Time:** < 2 seconds
- **Memory Usage:** < 50MB additional
- **CPU Usage:** < 5% average
- **Network Usage:** < 1MB per hour (normal operation)

### Monitoring Performance

```cpp
void monitor_performance()
{
    static ulong last_check = 0;
    if(GetTickCount() - last_check < 60000) return; // Check every minute

    // Memory usage
    PrintFormat("Memory usage: %d MB", TerminalInfoInteger(TERMINAL_MEMORY_USED) / 1024 / 1024);

    // CPU usage (approximate)
    static ulong last_cpu_time = GetTickCount();
    ulong current_time = GetTickCount();
    // Note: Actual CPU monitoring requires Windows API calls

    last_check = current_time;
}
```
