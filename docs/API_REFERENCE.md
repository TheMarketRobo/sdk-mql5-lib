# SDK API Reference

## CTheMarketRobo_Bot_Base

The main abstract base class for creating trading robots.

### Constructor

```cpp
CTheMarketRobo_Bot_Base(string robot_version_uuid, IRobotConfig* robot_config)
```

**Parameters:**
- `robot_version_uuid`: Programmer-defined UUID assigned by TheMarketRobo platform (36 characters)
- `robot_config`: Pointer to your robot's configuration class implementing `IRobotConfig`

**Description:** Creates the SDK base class with programmer-defined robot version and configuration.

**Example:**
```cpp
class CMyRobot : public CTheMarketRobo_Bot_Base
{
public:
    CMyRobot() : CTheMarketRobo_Bot_Base(
        "550e8400-e29b-41d4-a716-446655440000",  // UUID from platform
        new CMyRobotConfig()                      // Config with schema
    ) {}
};
```

---

### Lifecycle Methods

#### on_init

```cpp
virtual int on_init(string api_key, long magic_number)
```

**Parameters:**
- `api_key`: Customer-provided API key from TheMarketRobo platform (input parameter)
- `magic_number`: Customer-provided MT5 magic number for trade identification (input parameter)

**Returns:** `INIT_SUCCEEDED` or `INIT_FAILED`

**Description:** Initializes the SDK, establishes session with server, and starts the timer.

**Note:** The API base URL is now hardcoded in the SDK (`SDK_API_BASE_URL` constant).

---

#### on_deinit

```cpp
virtual void on_deinit(const int reason)
```

**Parameters:**
- `reason`: MQL5 deinitialization reason code

**Description:** Terminates the session gracefully and cleans up SDK resources.

---

#### on_timer

```cpp
virtual void on_timer()
```

**Description:** Handles periodic tasks including heartbeats and proactive token refresh.

---

#### on_chart_event

```cpp
virtual void on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam)
```

**Parameters:**
- `id`: Event identifier
- `lparam`: Long parameter
- `dparam`: Double parameter
- `sparam`: String parameter (contains JSON for SDK events)

**Description:** Processes SDK chart events for configuration and symbol changes.

---

### Feature Configuration Methods

Call these **BEFORE** `on_init()` for best results.

#### set_token_refresh_threshold

```cpp
void set_token_refresh_threshold(int seconds)
```

**Parameters:**
- `seconds`: Number of seconds before token expiration to trigger proactive refresh

**Default:** 300 seconds (5 minutes)  
**Range:** 60 - 3600 seconds

---

#### set_enable_config_change_requests

```cpp
void set_enable_config_change_requests(bool enable)
```

**Parameters:**
- `enable`: When `false`, SDK ignores config change requests from server

**Default:** `true` (enabled)

---

#### set_enable_symbol_change_requests

```cpp
void set_enable_symbol_change_requests(bool enable)
```

**Parameters:**
- `enable`: When `false`, SDK ignores symbol change requests from server

**Default:** `true` (enabled)

---

#### print_sdk_configuration

```cpp
void print_sdk_configuration() const
```

**Description:** Prints current SDK configuration to the terminal for debugging.

---

### Abstract Methods (Must Implement)

#### on_tick

```cpp
virtual void on_tick() = 0
```

**Description:** Your main trading logic. Only called when session is active.

---

#### on_config_changed

```cpp
virtual void on_config_changed(string event_json) = 0
```

**Parameters:**
- `event_json`: JSON string containing configuration change details

**Description:** Called when server changes a configuration parameter.

---

#### on_symbol_changed

```cpp
virtual void on_symbol_changed(string event_json) = 0
```

**Parameters:**
- `event_json`: JSON string containing symbol change details

**Description:** Called when server changes symbol trading status.

---

## IRobotConfig Interface

Abstract base class for robot configuration with schema support.

### Schema Definition Methods (Override)

#### define_schema

```cpp
virtual void define_schema() = 0
```

**Description:** Define your configuration fields using `m_schema.add_field()` with `CConfigField` factory methods.

---

#### apply_defaults

```cpp
virtual void apply_defaults() = 0
```

**Description:** Set member variables to default values using `m_schema.get_default_*()` methods.

---

### Configuration Methods (Override)

#### to_json

```cpp
virtual string to_json() = 0
```

**Returns:** JSON string representation of current configuration values

---

#### update_from_json

```cpp
virtual bool update_from_json(const CJAVal &config_json) = 0
```

**Parameters:**
- `config_json`: JSON object from server

**Returns:** `true` if update successful

---

#### update_field

```cpp
virtual bool update_field(string field_name, string new_value) = 0
```

**Parameters:**
- `field_name`: Field to update
- `new_value`: New value as string

**Returns:** `true` if update successful

---

#### get_field_as_string

```cpp
virtual string get_field_as_string(string field_name) = 0
```

**Parameters:**
- `field_name`: Field name

**Returns:** Field value as string

---

### Provided Methods (Use Schema)

#### validate_field

```cpp
virtual bool validate_field(string field_name, string new_value, string &reason)
```

**Description:** Validates value using schema. Override only if you need custom validation.

---

#### get_field_names

```cpp
virtual void get_field_names(string &field_names[])
```

**Description:** Returns all field names from schema.

---

#### get_schema

```cpp
CConfigSchema* get_schema()
```

**Returns:** Pointer to the configuration schema object.

---

## CConfigField

Factory class for creating configuration field definitions.

### Factory Methods

```cpp
static CConfigField* create_integer(string key, string label, bool required, int default_value)
static CConfigField* create_decimal(string key, string label, bool required, double default_value)
static CConfigField* create_boolean(string key, string label, bool required, bool default_value)
static CConfigField* create_radio(string key, string label, bool required, string default_value)
static CConfigField* create_multiple(string key, string label, bool required)
```

### Fluent Setters

```cpp
CConfigField* with_description(string description)
CConfigField* with_placeholder(string placeholder)
CConfigField* with_tooltip(string tooltip)
CConfigField* with_group(string group_name, int order)
CConfigField* with_disabled(bool disabled)
CConfigField* with_hidden(bool hidden)
CConfigField* with_range(double min_val, double max_val)
CConfigField* with_step(double step_val)
CConfigField* with_precision(int precision_val)  // Decimal only
CConfigField* with_option(string value, string label)  // Radio/Multiple
CConfigField* with_option_numeric(double value, string label)
CConfigField* with_selection_limits(int min_sel, int max_sel)  // Multiple only
CConfigField* with_default_selections(string &selections[])  // Multiple only
CConfigField* with_depends_on(CConfigDependency* dependency)
```

### Usage Example

```cpp
virtual void define_schema() override
{
    m_schema.add_field(
        CConfigField::create_integer("max_trades", "Max Trades", true, 5)
            .with_range(1, 20)
            .with_description("Maximum concurrent trades")
            .with_group("Risk Management", 1)
    );
    
    m_schema.add_field(
        CConfigField::create_decimal("stop_loss", "Stop Loss %", true, 1.5)
            .with_range(0.5, 5.0)
            .with_precision(1)
    );
    
    m_schema.add_field(
        CConfigField::create_radio("mode", "Trading Mode", true, "moderate")
            .with_option("conservative", "Conservative")
            .with_option("moderate", "Moderate")
            .with_option("aggressive", "Aggressive")
    );
}
```

---

## CConfigSchema

Container for robot configuration schema.

### Methods

```cpp
void add_field(CConfigField* field)
CConfigField* get_field(string key)
int get_field_count()
void get_field_keys(string &keys[])

// Default value getters
int get_default_int(string key)
double get_default_double(string key)
bool get_default_bool(string key)
string get_default_string(string key)

// Validation
bool validate_field_value(string key, int value, string &reason)
bool validate_field_value(string key, double value, string &reason)
bool validate_field_value(string key, bool value, string &reason)
bool validate_field_value(string key, string value, string &reason)

// Serialization
string to_json_string()
```

---

## SDK Events

### Event Constants

```cpp
#define SDK_EVENT_CONFIG_CHANGED    1001
#define SDK_EVENT_SYMBOL_CHANGED    1002
#define SDK_EVENT_TERMINATION_START 1003
#define SDK_EVENT_TERMINATION_END   1004
#define SDK_EVENT_TOKEN_REFRESH     1005
```

### Event Data Structures

#### Configuration Change Event

```json
{
  "field": "max_trades",
  "old_value": "5",
  "new_value": "10"
}
```

#### Symbol Change Event

```json
{
  "symbol": "EURUSD",
  "active_to_trade": true
}
```

#### Termination Event

```json
{
  "reason": "Session terminated by server",
  "success": true,
  "message": "Session ended gracefully"
}
```

#### Token Refresh Event

```json
{
  "success": true,
  "message": "Token refreshed successfully"
}
```

---

## SDK Constants

Defined in `CSDKConstants.mqh`:

```cpp
// SDK Version
#define SDK_VERSION "1.0.0"

// API Configuration
#define SDK_API_BASE_URL "http://api.staging.themarketrobo.com/"

// Default Values
#define SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD 300  // 5 minutes
#define SDK_DEFAULT_HEARTBEAT_INTERVAL 60        // 1 minute
#define SDK_MAX_HEARTBEAT_INTERVAL 300           // 5 minutes max

// UUID Length
#define SDK_UUID_LENGTH 36

// Error Codes
#define SDK_ERROR_INVALID_VALUE     "INVALID_VALUE"
#define SDK_ERROR_OUT_OF_RANGE      "OUT_OF_RANGE"
#define SDK_ERROR_FIELD_NOT_FOUND   "FIELD_NOT_FOUND"
#define SDK_ERROR_READ_ONLY_FIELD   "READ_ONLY_FIELD"
#define SDK_ERROR_SYMBOL_NOT_FOUND  "SYMBOL_NOT_FOUND"
#define SDK_ERROR_SYMBOL_UNAVAILABLE "SYMBOL_UNAVAILABLE"
#define SDK_ERROR_TRADING_DISABLED  "TRADING_DISABLED"

// Change Result Status
#define SDK_STATUS_ALL_ACCEPTED       "all_accepted"
#define SDK_STATUS_ALL_REJECTED       "all_rejected"
#define SDK_STATUS_PARTIALLY_ACCEPTED "partially_accepted"
```

---

## Session States

```cpp
enum ENUM_SDK_SESSION_STATE
{
    SDK_SESSION_NONE,       // No session
    SDK_SESSION_STARTING,   // Session is being started
    SDK_SESSION_ACTIVE,     // Session is active
    SDK_SESSION_REFRESHING, // Token is being refreshed
    SDK_SESSION_ENDING,     // Session is being terminated
    SDK_SESSION_ENDED       // Session has ended
};
```

---

## Error Handling

### Initialization Errors

- `"Invalid robot_version_uuid"` - UUID must be exactly 36 characters
- `"API Key is required"` - Customer must provide API key
- `"Robot configuration is not valid"` - Config object is NULL
- `"Failed to start SDK session"` - Network or auth error

### Runtime Errors

- Authentication failures trigger automatic EA removal
- Token expiration triggers automatic refresh
- Network issues are handled with retry logic
- Invalid configurations are rejected with detailed messages

### Best Practices

1. Always validate robot_version_uuid format before using
2. Use input parameters for customer-provided values (api_key, magic_number)
3. Handle `on_config_changed` and `on_symbol_changed` callbacks
4. Monitor Expert Advisor logs for SDK messages

---

## Complete Example

```cpp
#include <TheMarketRobo/TheMarketRobo_SDK.mqh>

input string InpApiKey = "";           // API Key
input long   InpMagicNumber = 12345;   // Magic Number

class CMyConfig : public IRobotConfig
{
private:
    int m_max_trades;
    double m_risk;

public:
    CMyConfig() { define_schema(); apply_defaults(); }
    
protected:
    virtual void define_schema() override
    {
        m_schema.add_field(CConfigField::create_integer("max_trades", "Max", true, 5).with_range(1, 20));
        m_schema.add_field(CConfigField::create_decimal("risk", "Risk %", true, 1.5).with_range(0.5, 5.0));
    }
    
    virtual void apply_defaults() override
    {
        m_max_trades = m_schema.get_default_int("max_trades");
        m_risk = m_schema.get_default_double("risk");
    }

public:
    virtual string to_json() override { return StringFormat("{\"max_trades\":%d,\"risk\":%.2f}", m_max_trades, m_risk); }
    virtual bool update_from_json(const CJAVal &j) override { m_max_trades = (int)j["max_trades"].get_long(); m_risk = j["risk"].get_double(); return true; }
    virtual bool update_field(string f, string v) override { if(f=="max_trades") m_max_trades=(int)StringToInteger(v); else if(f=="risk") m_risk=StringToDouble(v); return true; }
    virtual string get_field_as_string(string f) override { if(f=="max_trades") return IntegerToString(m_max_trades); if(f=="risk") return DoubleToString(m_risk,2); return ""; }
};

class CMyRobot : public CTheMarketRobo_Bot_Base
{
public:
    CMyRobot() : CTheMarketRobo_Bot_Base("550e8400-e29b-41d4-a716-446655440000", new CMyConfig()) {}
    virtual void on_tick() override { /* Trading logic */ }
    virtual void on_config_changed(string json) override { Print("Config changed: ", json); }
    virtual void on_symbol_changed(string json) override { Print("Symbol changed: ", json); }
};

CMyRobot* robot = NULL;

int OnInit()
{
    robot = new CMyRobot();
    robot.set_token_refresh_threshold(300);
    return robot.on_init(InpApiKey, InpMagicNumber);
}

void OnDeinit(const int reason) { robot.on_deinit(reason); delete robot; }
void OnTimer() { robot.on_timer(); }
void OnTick() { robot.on_tick(); }
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    robot.on_chart_event(id, lparam, dparam, sparam);
}
```
