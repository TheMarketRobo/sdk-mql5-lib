# SDK API Reference

## CTheMarketRobo_Bot_Base

### Constructor

```cpp
CTheMarketRobo_Bot_Base(Irobot_Config* robot_config)
```

**Parameters:**
- `robot_config`: Pointer to your robot's configuration object implementing `Irobot_Config`

**Description:** Initializes the SDK base class with your robot configuration.

### Lifecycle Methods

#### on_init

```cpp
virtual int on_init(string api_key, string robot_version, long magic_number, string base_url)
```

**Parameters:**
- `api_key`: Your robot's API key from TheMarketRobo platform
- `robot_version`: Version string for your robot (e.g., "1.0.0")
- `magic_number`: Unique identifier for trades
- `base_url`: API base URL (default: "https://api.themarketrobo.com")

**Returns:** `INIT_SUCCEEDED` or `INIT_FAILED`

**Description:** Initializes the SDK and establishes session with server.

#### on_deinit

```cpp
virtual void on_deinit(const int reason)
```

**Parameters:**
- `reason`: MQL5 deinitialization reason code

**Description:** Cleans up SDK resources and terminates session.

#### on_timer

```cpp
virtual void on_timer()
```

**Description:** Handles timer events for heartbeats and token refresh.

#### on_chart_event

```cpp
virtual void on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam)
```

**Parameters:**
- `id`: Event identifier
- `lparam`: Long parameter array
- `dparam`: Double parameter array
- `sparam`: String parameter array

**Description:** Processes SDK chart events.

### Abstract Methods (Must Implement)

#### on_tick

```cpp
virtual void on_tick() = 0
```

**Description:** Your main trading logic. Called only when session is active.

#### on_config_changed

```cpp
virtual void on_config_changed(string event_json) = 0
```

**Parameters:**
- `event_json`: JSON string containing configuration change details

**Description:** Handles real-time configuration updates from server.

#### on_symbol_changed

```cpp
virtual void on_symbol_changed(string event_json) = 0
```

**Parameters:**
- `event_json`: JSON string containing symbol change details

**Description:** Handles trading symbol status changes.

## Irobot_Config Interface

### Required Methods

#### validate_field

```cpp
virtual bool validate_field(string field_name, string new_value, string &reason)
```

**Parameters:**
- `field_name`: Name of the field to validate
- `new_value`: New value to validate
- `reason`: Output parameter for validation failure reason

**Returns:** `true` if valid, `false` otherwise

**Description:** Validates a new value for a specific configuration field.

#### to_json

```cpp
virtual string to_json()
```

**Returns:** JSON string representation of the configuration

**Description:** Serializes the configuration to JSON format.

#### update_from_json

```cpp
virtual bool update_from_json(const CJAVal &config_json)
```

**Parameters:**
- `config_json`: JSON object from server

**Returns:** `true` if update successful

**Description:** Updates configuration from server-provided JSON.

#### update_field

```cpp
virtual bool update_field(string field_name, string new_value)
```

**Parameters:**
- `field_name`: Field to update
- `new_value`: New value

**Returns:** `true` if update successful

**Description:** Updates a specific configuration field.

#### get_field_as_string

```cpp
virtual string get_field_as_string(string field_name)
```

**Parameters:**
- `field_name`: Field name

**Returns:** Field value as string

**Description:** Retrieves field value converted to string.

#### get_field_names

```cpp
virtual void get_field_names(string &field_names[])
```

**Parameters:**
- `field_names`: Output array for field names

**Description:** Provides list of all configuration field names.

## SDK Events

### Event Constants

```cpp
#define SDK_EVENT_CONFIG_CHANGED   1001
#define SDK_EVENT_SYMBOL_CHANGED   1002
#define SDK_EVENT_TERMINATION_START 1003
#define SDK_EVENT_TERMINATION_END   1004
#define SDK_EVENT_TOKEN_REFRESH     1005
```

### Event Data Structures

#### Configuration Change Event

```json
{
  "field": "max_risk_per_trade",
  "old_value": "1.5",
  "new_value": "2.0"
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
  "reason": "Authentication failed",
  "success": false,
  "message": "Invalid API key"
}
```

#### Token Refresh Event

```json
{
  "success": true,
  "message": "Token refreshed successfully"
}
```

## Error Codes

### Initialization Errors

- `INIT_FAILED`: SDK initialization failed
- Check logs for specific error messages

### Runtime Errors

- Authentication failures trigger automatic EA removal
- Network issues are handled with automatic retry
- Invalid configurations are rejected with detailed messages

## Constants and Enums

### MQL5 Integration Constants

```cpp
#define TIMER_INTERVAL 1  // Timer interval in seconds
#define HEARTBEAT_INTERVAL 60  // Heartbeat interval in seconds
```

### Session States

```cpp
enum ENUM_SESSION_STATE
{
    SESSION_INITIALIZING,
    SESSION_CONNECTING,
    SESSION_ACTIVE,
    SESSION_TERMINATING,
    SESSION_TERMINATED
};
```
