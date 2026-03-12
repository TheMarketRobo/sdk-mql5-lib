# Quick Start Guide

## Get Started in 5 Minutes

This guide will help you create your first trading robot using TheMarketRobo SDK.

### Prerequisites

- MetaTrader 5 installed
- Valid TheMarketRobo API key
- Robot version UUID from TheMarketRobo platform
- Basic MQL5 knowledge
- **Indicators only:** "Allow DLL imports" must be enabled in MT5 (the SDK uses `kernel32.dll` and `wininet.dll` for HTTP communication in indicators; EAs use the built-in `WebRequest()` instead)

**For local testing:** Generate a new **test license** from your Vendor Portal and use its API key with the staging API (`https://api.staging.themarketrobo.com`). Do not use production licenses for development.

**Robot config schema:** The configuration you define for your robot **MUST** follow the [Robot Config Component Schema](schemas/robot_config_component_schema/README.md). The Vendor Portal validates it before you can submit. **Config change and symbol change support are optional** — you can disable them with `set_enable_config_change_requests(false)` and `set_enable_symbol_change_requests(false)` if you do not need remote updates.

### Step 1: Create Your Robot Configuration

Create a new file `MyBotConfig.mqh`:

```cpp
#include <themarketrobo/TheMarketRobo_SDK.mqh>

class CMyRobotConfig : public IRobotConfig
{
private:
    // Actual configuration values
    double m_max_risk;
    int    m_max_trades;
    bool   m_use_news_filter;
    string m_trading_mode;

public:
    CMyRobotConfig()
    {
        define_schema();
        apply_defaults();
    }

protected:
    // Define configuration fields using schema
    virtual void define_schema() override
    {
        m_schema.add_field(
            CConfigField::create_decimal("max_risk", "Max Risk %", true, 1.5)
                .with_range(0.1, 5.0)
                .with_precision(1)
                .with_description("Maximum risk per trade")
                .with_group("Risk Management", 1)
        );
        
        m_schema.add_field(
            CConfigField::create_integer("max_trades", "Max Trades/Day", true, 10)
                .with_range(0, 100)
                .with_group("Risk Management", 2)
        );
        
        m_schema.add_field(
            CConfigField::create_boolean("use_news_filter", "News Filter", true, true)
                .with_description("Filter trades during news events")
                .with_group("Features", 1)
        );
        
        m_schema.add_field(
            CConfigField::create_radio("trading_mode", "Trading Mode", true, "moderate")
                .with_option("conservative", "Conservative")
                .with_option("moderate", "Moderate")
                .with_option("aggressive", "Aggressive")
                .with_group("Strategy", 1)
        );
    }
    
    // Apply default values from schema
    virtual void apply_defaults() override
    {
        m_max_risk = m_schema.get_default_double("max_risk");
        m_max_trades = m_schema.get_default_int("max_trades");
        m_use_news_filter = m_schema.get_default_bool("use_news_filter");
        m_trading_mode = m_schema.get_default_string("trading_mode");
    }

public:
    // Serialize to JSON
    virtual string to_json() override
    {
        return StringFormat(
            "{\"max_risk\":%.2f,\"max_trades\":%d,\"use_news_filter\":%s,\"trading_mode\":\"%s\"}",
            m_max_risk, m_max_trades, 
            m_use_news_filter ? "true" : "false",
            m_trading_mode
        );
    }

    // Update from server JSON
    virtual bool update_from_json(const CJAVal &config_json) override
    {
        if(config_json.has_key("max_risk"))
            m_max_risk = config_json["max_risk"].get_double();
        if(config_json.has_key("max_trades"))
            m_max_trades = (int)config_json["max_trades"].get_long();
        if(config_json.has_key("use_news_filter"))
            m_use_news_filter = config_json["use_news_filter"].get_bool();
        if(config_json.has_key("trading_mode"))
            m_trading_mode = config_json["trading_mode"].get_string();
        return true;
    }

    // Update a specific field
    virtual bool update_field(string field_name, string new_value) override
    {
        if(field_name == "max_risk")
            m_max_risk = StringToDouble(new_value);
        else if(field_name == "max_trades")
            m_max_trades = (int)StringToInteger(new_value);
        else if(field_name == "use_news_filter")
            m_use_news_filter = (new_value == "true");
        else if(field_name == "trading_mode")
            m_trading_mode = new_value;
        else 
            return false;
        return true;
    }

    // Get field value as string
    virtual string get_field_as_string(string field_name) override
    {
        if(field_name == "max_risk")
            return DoubleToString(m_max_risk, 2);
        if(field_name == "max_trades")
            return IntegerToString(m_max_trades);
        if(field_name == "use_news_filter")
            return m_use_news_filter ? "true" : "false";
        if(field_name == "trading_mode")
            return m_trading_mode;
        return "";
    }
    
    // Getters for trading logic
    double get_max_risk() const { return m_max_risk; }
    int    get_max_trades() const { return m_max_trades; }
    bool   use_news_filter() const { return m_use_news_filter; }
    string get_trading_mode() const { return m_trading_mode; }
};
```

### Step 2: Create Your Trading Robot

Create a new file `MyTradingBot.mq5`:

```cpp
#include "MyBotConfig.mqh"

//--- Customer-provided input parameters
input string InpApiKey = "";           // API Key (from TheMarketRobo)
input long   InpMagicNumber = 12345;   // Magic Number

//--- Programmer-defined robot version UUID
#define ROBOT_VERSION_UUID "550e8400-e29b-41d4-a716-446655440000"

//--- Global variables
CMyRobot* robot = NULL;

//+------------------------------------------------------------------+
//| Expert Advisor Class                                             |
//+------------------------------------------------------------------+
// CTheMarketRobo_Base is the unified base class; CTheMarketRobo_Bot_Base is an alias for backwards compatibility.
class CMyRobot : public CTheMarketRobo_Base
{
private:
    CMyRobotConfig* m_config;

public:
    CMyRobot() : CTheMarketRobo_Base(ROBOT_VERSION_UUID, new CMyRobotConfig())
    {
        m_config = (CMyRobotConfig*)m_robot_config;
    }

    virtual void on_tick() override
    {
        if(m_config.use_news_filter() && is_buy_signal())
        {
            Print("Buy signal detected! Risk: ", m_config.get_max_risk(), "%");
            // Add your buy order logic here
        }
    }

    // Optional: react after SDK has applied config changes (config already updated in m_robot_config)
    virtual void on_config_changed(string event_json) override
    {
        CJAVal event;
        if(event.parse(event_json))
        {
            string field = event["field"].get_string();
            string value = event["new_value"].get_string();
            PrintFormat("Config updated: %s = %s", field, value);
        }
    }

    // Optional: react after SDK has applied symbol changes (e.g. close positions when symbol disabled)
    virtual void on_symbol_changed(string event_json) override
    {
        CJAVal event;
        if(event.parse(event_json))
        {
            string symbol = event["symbol"].get_string();
            bool active = event["active_to_trade"].get_bool();
            PrintFormat("Symbol %s: %s", symbol, active ? "ACTIVE" : "INACTIVE");
        }
    }

private:
    bool is_buy_signal()
    {
        double ma = iMA(Symbol(), PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE);
        double price = iClose(Symbol(), PERIOD_H1, 0);
        return price > ma;
    }
};

//+------------------------------------------------------------------+
//| MQL5 Entry Points                                                |
//+------------------------------------------------------------------+
int OnInit()
{
    robot = new CMyRobot();
    if(CheckPointer(robot) == POINTER_INVALID)
        return INIT_FAILED;
    
    // Optional: Configure SDK features (config/symbol change support are optional)
    robot.set_enable_config_change_requests(true);   // set false to ignore remote config changes
    robot.set_enable_symbol_change_requests(true);  // set false to ignore remote symbol changes
    robot.set_token_refresh_threshold(300);
    
    // Initialize with customer inputs
    return robot.on_init(InpApiKey, InpMagicNumber);
}

void OnDeinit(const int reason)
{
    if(CheckPointer(robot) != POINTER_INVALID)
    {
        robot.on_deinit(reason);
        delete robot;
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

### Step 3: Configure Your Robot

1. **Get your robot version UUID:**
   - Register your robot on TheMarketRobo platform
   - Copy the assigned UUID
   - Replace `ROBOT_VERSION_UUID` in your code

2. **Ensure the SDK is available:**
   - This repo uses the SDK as a submodule at `Include/themarketrobo`. Clone with `--recursive` or run `git submodule update --init --recursive`.
   - The correct include path is `#include <themarketrobo/TheMarketRobo_SDK.mqh>` (folder name is lowercase).

3. **Compile the Expert Advisor:**
   - Press F7 in MetaEditor
   - Fix any compilation errors

### Step 4: Run Your Robot

1. **Attach to a chart:**
   - Open a chart (EURUSD recommended for testing)
   - Drag your compiled EA onto the chart
   - Enter your API key in the input parameters (use a **test license** API key from your Vendor Portal for local testing)
   - Set your preferred magic number
   - Click "OK"

2. **Monitor the logs:**
   - Check the Experts tab for messages
   - Look for "SDK session started successfully!"

### What's Different from the Old API?

| Old API | New API |
|---------|---------|
| `on_init(api_key, version, magic, base_url)` | `on_init(api_key, magic_number)` |
| `Irobot_Config` with manual validation | `IRobotConfig` with schema-based validation |
| base_url as parameter | SDK_API_BASE_URL constant |
| Constructor takes config pointer | Constructor takes UUID + config pointer |

### Parameter Responsibilities

| Parameter | Who Provides | Where Defined |
|-----------|--------------|---------------|
| robot_version_uuid | Programmer | In constructor |
| config schema | Programmer | In IRobotConfig.define_schema() |
| api_key | Customer | Input parameter |
| magic_number | Customer | Input parameter |
| base_url | SDK | CSDKConstants.mqh |

## Next Steps

1. **Add Trading Logic**: Implement your strategy in `on_tick()`
2. **Configure Risk**: Set up proper position sizing
3. **Add More Config Fields**: Extend your schema
4. **Test Thoroughly**: Backtest before going live

## Troubleshooting

**"Invalid robot_version_uuid"**
- UUID must be exactly 36 characters
- Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

**"Failed to start SDK session"**
- Check your API key is correct
- **For local testing:** Use an API key from a **test license** generated in your Vendor Portal, and ensure the staging URL (`https://api.staging.themarketrobo.com`) is in MT5's Allow WebRequest list
- Verify internet connection

**"Schema not initialized"**
- Ensure `define_schema()` is called in constructor

## Full Example (Expert Advisor)

See the complete EA example in:
- `docs/README.md` - Full documentation
- Source files in sdk-mql5-lib/

## Quick Start — Custom Indicator

If you are building a Custom Indicator instead of an Expert Advisor, the process is simpler: indicators use the same SDK base class (`CTheMarketRobo_Base`) with the **one-argument constructor** (indicator version UUID only). They do not support remote configuration or symbol change requests; the SDK still handles session registration, heartbeats, and termination.

### Step 1: Create Your Indicator

Create a new file `MyIndicator.mq5`:

```cpp
#include <themarketrobo/TheMarketRobo_SDK.mqh>

//--- Customer-provided input parameters
input string InpApiKey = "";           // API Key (from TheMarketRobo)

//--- Programmer-defined indicator version UUID (from TheMarketRobo platform)
#define INDICATOR_VERSION_UUID "550e8400-e29b-41d4-a716-446655440000"

//--- Global variables
CMyIndicator* indicator = NULL;

//+------------------------------------------------------------------+
//| Custom Indicator Class                                           |
//+------------------------------------------------------------------+
class CMyIndicator : public CTheMarketRobo_Base
{
public:
    // Pass only the UUID to the constructor (no IRobotConfig for indicators)
    CMyIndicator() : CTheMarketRobo_Base(INDICATOR_VERSION_UUID) {}

    // Override on_calculate instead of on_tick
    virtual int on_calculate(const int rates_total,
                             const int prev_calculated,
                             const datetime &time[],
                             const double   &open[],
                             const double   &high[],
                             const double   &low[],
                             const double   &close[],
                             const long     &tick_volume[],
                             const long     &volume[],
                             const int      &spread[]) override
    {
        // Your custom indicator logic here
        
        return rates_total;
    }
};

//+------------------------------------------------------------------+
//| MQL5 Entry Points                                                |
//+------------------------------------------------------------------+
int OnInit()
{
    indicator = new CMyIndicator();
    if(CheckPointer(indicator) == POINTER_INVALID)
        return INIT_FAILED;
    
    // For chart indicators: call SetIndexBuffer(), IndicatorSetInteger(), etc. here if needed, before or after init.
    // Initialize with customer inputs (Indicators do not use magic numbers)
    return indicator.on_init(InpApiKey);
}

void OnDeinit(const int reason)
{
    if(CheckPointer(indicator) != POINTER_INVALID)
    {
        indicator.on_deinit(reason);
        delete indicator;
    }
}

void OnTimer()
{
    if(CheckPointer(indicator) != POINTER_INVALID)
        indicator.on_timer();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
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

### DLL Imports for Indicators

The SDK uses `kernel32.dll` and `wininet.dll` for HTTP communication in Custom Indicators (since `WebRequest()` is not available). Ensure **"Allow DLL imports"** is checked when attaching the indicator to a chart. Expert Advisors (Robots) do NOT require DLL imports.

### Running Without the SDK (`SDK_ENABLED`)

To run your robot or indicator without any SDK functionality (standalone mode), comment out `#define SDK_ENABLED` in `Core/CSDKConstants.mqh`:

```cpp
// #define SDK_ENABLED   // ← commented out = SDK disabled
```

Your code compiles and runs unchanged — all SDK methods become safe no-ops and `on_init()` returns `INIT_SUCCEEDED` immediately. No network calls or DLL imports are compiled into the binary.

**You're ready to build with TheMarketRobo SDK!**
