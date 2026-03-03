# SDK API Reference

## CTheMarketRobo_Bot_Base / CTheMarketRobo_Base

The main abstract base class for creating trading robots (Expert Advisors) and Custom Indicators.
Note: While `CTheMarketRobo_Bot_Base` acts as an alias, `CTheMarketRobo_Base` is the unified parent class.

### Constructor — Expert Advisor (Robot)

```cpp
CTheMarketRobo_Base(string robot_version_uuid, IRobotConfig* robot_config)
```

**Parameters:**
- `robot_version_uuid`: Programmer-defined UUID assigned by TheMarketRobo platform (36 characters)
- `robot_config`: Pointer to your robot's configuration class implementing `IRobotConfig`

**Description:** Creates the SDK base class for a Robot with programmer-defined robot version and configuration.

### Constructor — Custom Indicator

```cpp
CTheMarketRobo_Base(string robot_version_uuid)
```

**Parameters:**
- `robot_version_uuid`: Programmer-defined UUID assigned by TheMarketRobo platform (36 characters)

**Description:** Creates the SDK base class for an Indicator. Indicators do not use remote configurations.

**Destructor:** `~CTheMarketRobo_Base()` — Frees `m_sdk_context` and `m_robot_config` (if dynamic). Call `on_deinit()` before destroying the instance (e.g. from `OnDeinit`).

---

### Lifecycle Methods

#### on_init

```cpp
// For Robots (Expert Advisors):
virtual int on_init(string api_key, long magic_number)

// For Custom Indicators:
virtual int on_init(string api_key)
```

**Parameters:**
- `api_key`: Customer-provided API key from TheMarketRobo platform (input parameter)
- `magic_number`: (Robots only) Customer-provided MT5 magic number for trade identification (input parameter)

**Returns:** `INIT_SUCCEEDED` or `INIT_FAILED`

**Description:** Initializes the SDK, establishes session with server, and starts the timer. Indicators automatically have `PRODUCT_TYPE_INDICATOR` set, bypass magic numbers, and disable config/symbol change requests.

**Note:** The API base URL is now hardcoded in the SDK (`SDK_API_BASE_URL` constant). Robot configuration must follow the [Robot Config Component Schema](schemas/robot_config_component_schema/README.md); the Vendor Portal validates it at submission.

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

**Description:** Processes SDK chart events. The SDK handles: `SDK_EVENT_CONFIG_CHANGED`, `SDK_EVENT_SYMBOL_CHANGED` (Robots only), `SDK_EVENT_TERMINATION_START`, `SDK_EVENT_TERMINATION_END`, `SDK_EVENT_TERMINATION_REQUESTED`, `SDK_EVENT_TOKEN_REFRESH`. For config/symbol events, only Robots receive callbacks; `sparam` contains the event JSON.

---

### Feature Configuration Methods

Call these **BEFORE** `on_init()` for best results.

#### set_token_refresh_threshold

```cpp
void set_token_refresh_threshold(int seconds)
```

**Parameters:**
- `seconds`: Number of seconds before token expiration to trigger proactive refresh

**Default:** 60 seconds (`SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD` in CSDKConstants.mqh)  
**Range:** 60–3600 seconds  

**Note:** If set equal to or greater than the JWT expiration time (e.g. 300 seconds), refresh will trigger immediately.

---

#### set_enable_config_change_requests

```cpp
void set_enable_config_change_requests(bool enable)
```

**Parameters:**
- `enable`: When `false`, SDK ignores config change requests from server

**Default:** `true` (enabled)

**Note:** Config change support is **not mandatory**. Disable it if your robot does not need remote config updates. Call before `on_init()`.

---

#### set_enable_symbol_change_requests

```cpp
void set_enable_symbol_change_requests(bool enable)
```

**Parameters:**
- `enable`: When `false`, SDK ignores symbol change requests from server

**Default:** `true` (enabled)

**Note:** Symbol change support is **not mandatory**. Disable it if you do not need to react to remote symbol enable/disable. Call before `on_init()`.

---

#### print_sdk_configuration

```cpp
void print_sdk_configuration() const
```

**Description:** Prints current SDK configuration to the terminal for debugging.

---

### Virtual Callbacks (Override in Robot or Indicator)

These methods have **default empty implementations** (not pure virtual). Override them in your EA or Indicator as needed.

#### on_tick

```cpp
virtual void on_tick() {}  // Default: no-op. Override in Robot.
```

**Description:** Main trading logic for Expert Advisors. Called when session is active. Indicators do not use this.

---

#### on_calculate

```cpp
virtual int on_calculate(const int rates_total, const int prev_calculated,
                         const datetime &time[], const double &open[],
                         const double &high[], const double &low[],
                         const double &close[], const long &tick_volume[],
                         const long &volume[], const int &spread[]) { return rates_total; }
```

**Description:** Main indicator logic. Override when building a Custom Indicator. Return `rates_total`. Robots use the default no-op.

---

#### on_config_changed

```cpp
virtual void on_config_changed(string event_json) {}  // Override in Robot.
```

**Parameters:** `event_json` — JSON string with configuration change details (e.g. field, old_value, new_value, or request_id/summary).

**Description:** Called when the server has sent a configuration change request and the SDK has applied it (via your `update_field()`). **Robots only**; Indicators do not receive this event. **Optional:** Override only if you need to react (e.g. recalculate, log); the config object already holds the new values. To support config changes at all, you must implement `IRobotConfig::update_field()` and `validate_field()`; see the section *Config change and symbol change — request/response* below.

---

#### on_symbol_changed

```cpp
virtual void on_symbol_changed(string event_json) {}  // Override in Robot.
```

**Parameters:** `event_json` — JSON string with symbol change details (e.g. `symbol`, `active_to_trade`).

**Description:** Called when the server has sent a symbol change request and the SDK has applied it (SymbolSelect). **Robots only**; Indicators do not receive this event. **Optional:** Override only if you need to react (e.g. close positions when a symbol is disabled). You can disable symbol change requests with `set_enable_symbol_change_requests(false)`.

---

#### on_termination_requested

```cpp
virtual void on_termination_requested(string event_json);
```

**Parameters:** `event_json` — JSON string with a `reason` field (server-requested termination).

**Description:** Called when the server requested session termination (e.g. from heartbeat response). Default behavior: Alert the user; for Robots call `ExpertRemove()`; for Indicators call `EventKillTimer()` and print a message. Override to customize behavior.

---

### Public Getters (Read-Only)

#### get_robot_version_uuid

```cpp
string get_robot_version_uuid() const
```

**Returns:** The version UUID passed to the constructor (robot or indicator).

---

#### get_token_refresh_threshold

```cpp
int get_token_refresh_threshold() const
```

**Returns:** Current token refresh threshold in seconds (before expiration).

---

#### is_indicator_mode / is_robot_mode

```cpp
bool is_indicator_mode() const
bool is_robot_mode() const
```

**Returns:** `true` if the instance was initialized as an Indicator or Robot respectively. Useful inside shared code or `on_termination_requested`.

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

#### get_schema_json

```cpp
string get_schema_json()
```

**Returns:** Schema serialized as a JSON string.

---

#### get_field_definition

```cpp
CConfigField* get_field_definition(string key)
```

**Parameters:** `key` — Field key (e.g. `"max_trades"`).

**Returns:** Pointer to the `CConfigField` for that key, or `NULL` if not found.

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

**Dependencies:** Use `CConfigDependency` (Models/CConfigField.mqh) to show a field only when another field matches a condition. Example: `dep.set_bool_value("use_trailing_stop", CONDITION_EQUALS, true);` then `.with_depends_on(dep)` on the dependent field. Conditions: `CONDITION_EQUALS`, `CONDITION_NOT_EQUALS`, `CONDITION_GREATER_THAN`, `CONDITION_LESS_THAN`, etc.

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

Container for robot configuration schema. Defined in `Models/CConfigSchema.mqh`.

### Methods

```cpp
void add_field(CConfigField* field)
CConfigField* get_field(string key)
CConfigField* get_field_by_index(int index)
int get_field_count()
void get_field_keys(string &keys[])

// Default value getters (key = field key string, e.g. "max_trades")
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
CJAVal* to_json()           // Returns JSON object (caller must delete)
string to_json_string()     // Returns JSON string
```

---

## SDK Events

Defined in `Utils/CSDK_Events.mqh`. Event IDs are based on `CHARTEVENT_CUSTOM` so they do not collide with MQL5 built-in events.

### Event Constants

```cpp
#define SDK_EVENT_CONFIG_CHANGED          (CHARTEVENT_CUSTOM + 1000)
#define SDK_EVENT_SYMBOL_CHANGED          (CHARTEVENT_CUSTOM + 1001)
#define SDK_EVENT_TERMINATION_START       (CHARTEVENT_CUSTOM + 1002)
#define SDK_EVENT_TERMINATION_END         (CHARTEVENT_CUSTOM + 1003)
#define SDK_EVENT_TOKEN_REFRESH           (CHARTEVENT_CUSTOM + 1004)
#define SDK_EVENT_TERMINATION_REQUESTED   (CHARTEVENT_CUSTOM + 1005)  // Server requested termination
```

The numeric offset (1000–1005) is used when calling `EventChartCustom()`. The base class switches on the full constant (e.g. `SDK_EVENT_CONFIG_CHANGED`) in `on_chart_event`.

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

## Config change and symbol change — request/response

Config change and symbol change support are **optional**. Disable with `set_enable_config_change_requests(false)` and `set_enable_symbol_change_requests(false)`.

### Config change

1. **Request:** Server sends `robot_config_change_request` in heartbeat (or start) response: `{ "id": "...", "request": [ { "field_name": "key", "new_value": value }, ... ] }`.
2. **SDK:** For each item calls your `validate_field(field_name, new_value_str, reason)`; if valid, calls `update_field(field_name, new_value_str)`. Builds result: per-item `accepted`, `applied_value` or `error_code`/`error_message`; overall `status` (`all_accepted`/`all_rejected`/`partially_accepted`).
3. **Response:** SDK sends result in `config_change_results` on the **next** heartbeat.
4. **Vendor must implement:** `update_field()`, `get_field_as_string()`, `to_json()`, `update_from_json()`, and `define_schema()`/`apply_defaults()` matching the [Robot Config Component Schema](schemas/robot_config_component_schema/README.md). Optionally `validate_field()` (or use schema); optionally override `on_config_changed()` to react.

### Symbol change

1. **Request:** Server sends `session_symbols_change_request`: `{ "id": "...", "request": [ { "symbol": "EURUSD", "active_to_trade": true/false }, ... ] }`.
2. **SDK:** For each item calls `SymbolSelect(symbol_name, requested_active)`, updates internal list, builds result, fires `on_symbol_changed` event.
3. **Response:** SDK sends result in `symbols_change_results` on the **next** heartbeat.
4. **Vendor:** Optionally override `on_symbol_changed()` to react (e.g. close positions when a symbol is disabled).

---

## SDK Constants

Defined in `Core/CSDKConstants.mqh`:

```cpp
// SDK Version
#define SDK_VERSION "1.0.0"

// API Configuration (no trailing slash; endpoints are concatenated, e.g. base_url + "/robot/start")
#define SDK_API_BASE_URL "https://api.staging.themarketrobo.com"

// Default Values
#define SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD 60   // Seconds before token expiry to refresh
#define SDK_DEFAULT_HEARTBEAT_INTERVAL 60       // Fallback heartbeat interval (seconds)
#define SDK_MAX_HEARTBEAT_INTERVAL 300          // Max heartbeat interval (seconds)

// HTTP
#define SDK_HTTP_TIMEOUT 5000  // 5 seconds

// UUID Length
#define SDK_UUID_LENGTH 36

// Error Codes (for config/symbol change result reporting)
#define SDK_ERROR_INVALID_VALUE     "INVALID_VALUE"
#define SDK_ERROR_OUT_OF_RANGE      "OUT_OF_RANGE"
#define SDK_ERROR_FIELD_NOT_FOUND   "FIELD_NOT_FOUND"
#define SDK_ERROR_READ_ONLY_FIELD   "READ_ONLY_FIELD"
#define SDK_ERROR_SYMBOL_NOT_FOUND  "SYMBOL_NOT_FOUND"
#define SDK_ERROR_SYMBOL_UNAVAILABLE "SYMBOL_UNAVAILABLE"
#define SDK_ERROR_TRADING_DISABLED  "TRADING_DISABLED"

// Change Result Status (for heartbeat config/symbol results)
#define SDK_STATUS_ALL_ACCEPTED       "all_accepted"
#define SDK_STATUS_ALL_REJECTED      "all_rejected"
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

**Defined in:** `Core/CSDKConstants.mqh`

---

## Product Types

```cpp
enum ENUM_SDK_PRODUCT_TYPE
{
    PRODUCT_TYPE_ROBOT,      // Expert Advisor (EA)
    PRODUCT_TYPE_INDICATOR   // Custom Indicator
};

#define SDK_PRODUCT_TYPE_ROBOT     "robot"
#define SDK_PRODUCT_TYPE_INDICATOR "indicator"
```

---

## Heartbeat States

```cpp
enum ENUM_SDK_HEARTBEAT_STATE
{
    SDK_HEARTBEAT_IDLE,             // Waiting for next heartbeat
    SDK_HEARTBEAT_SENDING,          // Heartbeat is being sent
    SDK_HEARTBEAT_WAITING_CONFIRM,  // Waiting for server confirmation
    SDK_HEARTBEAT_FAILED            // Last heartbeat failed
};
```

---

## Error Handling

### Initialization Errors

- `"Invalid robot_version_uuid"` - UUID must be exactly 36 characters
- `"API Key is required"` - Customer must provide API key
- `"Robot configuration is not valid"` - Config object is NULL
- `"Failed to start SDK session"` - Network or auth error. **For local testing**, use an API key from a **test license** generated in your Vendor Portal and ensure the staging URL is in MT5's Allow WebRequest list.

### Runtime Errors

- **Robots:** Authentication failures trigger automatic EA removal (`ExpertRemove()`). Token expiration triggers proactive refresh (threshold from `SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD` or `set_token_refresh_threshold`).
- **Indicators:** On auth failure or token refresh failure the SDK stops the timer (`EventKillTimer()`) and alerts the user to remove the indicator; there is no self-removal API for indicators.
- Network issues are handled with retry logic (e.g. heartbeat 409 sequence sync).
- Invalid configurations are rejected with detailed messages; session may not become active if initial config validation fails (Robots only).

### Best Practices

1. Always validate robot_version_uuid format before using
2. Use input parameters for customer-provided values (api_key, magic_number)
3. For local testing, generate a new **test license** from your Vendor Portal and use its API key with the staging API
4. Handle `on_config_changed` and `on_symbol_changed` callbacks
5. Monitor Expert Advisor logs for SDK messages

---

## Complete Example

Use the **lowercase** include path `themarketrobo` so it matches the repository folder and works on case-sensitive systems:

```cpp
#include <themarketrobo/TheMarketRobo_SDK.mqh>

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

class CMyRobot : public CTheMarketRobo_Base
{
public:
    CMyRobot() : CTheMarketRobo_Base("550e8400-e29b-41d4-a716-446655440000", new CMyConfig()) {}
    virtual void on_tick() override { /* Trading logic */ }
    virtual void on_config_changed(string json) override { Print("Config changed: ", json); }
    virtual void on_symbol_changed(string json) override { Print("Symbol changed: ", json); }
};

CMyRobot* robot = NULL;

int OnInit()
{
    robot = new CMyRobot();
    if(CheckPointer(robot) == POINTER_INVALID) return INIT_FAILED;
    robot.set_token_refresh_threshold(60);  // Optional; default is 60
    return robot.on_init(InpApiKey, InpMagicNumber);
}

void OnDeinit(const int reason)
{
    if(CheckPointer(robot) != POINTER_INVALID) { robot.on_deinit(reason); delete robot; robot = NULL; }
}
void OnTimer()
{
    if(CheckPointer(robot) != POINTER_INVALID) robot.on_timer();
}
void OnTick()
{
    if(CheckPointer(robot) != POINTER_INVALID) robot.on_tick();
}
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(CheckPointer(robot) != POINTER_INVALID) robot.on_chart_event(id, lparam, dparam, sparam);
}
```
