# Quick Start Guide

## Get Started in 5 Minutes

This guide will help you create your first trading robot using TheMarketRobo SDK in just a few minutes.

### Prerequisites

- MetaTrader 5 installed
- Valid TheMarketRobo API key
- Basic MQL5 knowledge

### Step 1: Create Your Robot Configuration

Create a new file `MyBotConfig.mqh`:

```cpp
#include <TheMarketRobo/SDK/TheMarketRobo_SDK.mqh>

class CMy_Bot_Config : public Irobot_Config
{
public:
    double max_risk_per_trade;
    int max_trades_per_day;
    bool enable_news_filter;

    CMy_Bot_Config()
    {
        max_risk_per_trade = 1.5;
        max_trades_per_day = 10;
        enable_news_filter = true;
    }

    virtual bool validate_field(string field_name, string new_value, string &reason) override
    {
        if(field_name == "max_risk_per_trade")
        {
            double risk = StringToDouble(new_value);
            if(risk > 0 && risk <= 5.0) return true;
            reason = "Risk must be between 0.1 and 5.0";
            return false;
        }
        if(field_name == "max_trades_per_day")
        {
            int trades = (int)StringToInteger(new_value);
            if(trades >= 0 && trades <= 100) return true;
            reason = "Trades per day must be between 0 and 100";
            return false;
        }
        if(field_name == "enable_news_filter") return true;

        reason = "Unknown field: " + field_name;
        return false;
    }

    virtual string to_json() override
    {
        return StringFormat(
            "{\"max_risk_per_trade\":%.2f,\"max_trades_per_day\":%d,\"enable_news_filter\":%s}",
            max_risk_per_trade, max_trades_per_day, enable_news_filter ? "true" : "false"
        );
    }

    virtual bool update_from_json(const CJAVal &config_json) override
    {
        bool success = true;
        CJAVal* risk_node = config_json["max_risk_per_trade"];
        if(CheckPointer(risk_node) != POINTER_INVALID)
            max_risk_per_trade = risk_node.get_double();
        else success = false;

        CJAVal* trades_node = config_json["max_trades_per_day"];
        if(CheckPointer(trades_node) != POINTER_INVALID)
            max_trades_per_day = (int)trades_node.get_long();
        else success = false;

        CJAVal* news_node = config_json["enable_news_filter"];
        if(CheckPointer(news_node) != POINTER_INVALID)
            enable_news_filter = news_node.get_bool();
        else success = false;

        return success;
    }

    virtual bool update_field(string field_name, string new_value) override
    {
        if(field_name == "max_risk_per_trade")
            max_risk_per_trade = StringToDouble(new_value);
        else if(field_name == "max_trades_per_day")
            max_trades_per_day = (int)StringToInteger(new_value);
        else if(field_name == "enable_news_filter")
            enable_news_filter = (new_value == "true");
        else return false;

        return true;
    }

    virtual string get_field_as_string(string field_name) override
    {
        if(field_name == "max_risk_per_trade")
            return DoubleToString(max_risk_per_trade, 2);
        if(field_name == "max_trades_per_day")
            return IntegerToString(max_trades_per_day);
        if(field_name == "enable_news_filter")
            return enable_news_filter ? "true" : "false";
        return "";
    }

    virtual void get_field_names(string &field_names[]) override
    {
        string names[] = {"max_risk_per_trade", "max_trades_per_day", "enable_news_filter"};
        ArrayCopy(field_names, names);
    }
};
```

### Step 2: Create Your Trading Robot

Create a new file `MyTradingBot.mq5`:

```cpp
#include "MyBotConfig.mqh"

//--- Input parameters
input string InpApiKey = "YOUR_API_KEY_HERE";
input long InpMagicNumber = 12345;
input string InpBaseApiUrl = "https://api.themarketrobo.com";

//--- Global variables
CMy_Bot* g_bot;

//+------------------------------------------------------------------+
//| Expert Advisor Class                                             |
//+------------------------------------------------------------------+
class CMy_Bot : public CTheMarketRobo_Bot_Base
{
private:
    CMy_Bot_Config m_config;

public:
    CMy_Bot() : CTheMarketRobo_Bot_Base(&m_config) {}

    void on_tick() override
    {
        // Your trading logic here
        if(m_config.enable_news_filter && is_buy_signal())
        {
            Print("Buy signal detected!");
            // Add your buy order logic here
        }
    }

    void on_config_changed(string event_json) override
    {
        CJAVal event_data;
        if(event_data.parse(event_json))
        {
            string field = event_data["field"].get_string();
            string new_value = event_data["new_value"].get_string();

            PrintFormat("Config updated: %s = %s", field, new_value);

            // React to configuration changes
            if(field == "max_risk_per_trade")
            {
                PrintFormat("Risk updated to %.2f%%", StringToDouble(new_value));
            }
        }
    }

    void on_symbol_changed(string event_json) override
    {
        CJAVal event_data;
        if(event_data.parse(event_json))
        {
            string symbol = event_data["symbol"].get_string();
            bool active = event_data["active_to_trade"].get_bool();

            PrintFormat("Symbol %s is now %s", symbol, active ? "active" : "inactive");
        }
    }

private:
    bool is_buy_signal()
    {
        // Simple example: check if price is above moving average
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
    g_bot = new CMy_Bot();
    if(CheckPointer(g_bot) == POINTER_INVALID) return INIT_FAILED;

    return g_bot.on_init(InpApiKey, "1.0.0", InpMagicNumber, InpBaseApiUrl);
}

void OnDeinit(const int reason)
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
    {
        g_bot.on_deinit(reason);
        delete g_bot;
    }
}

void OnTimer()
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
        g_bot.on_timer();
}

void OnTick()
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
        g_bot.on_tick();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
        g_bot.on_chart_event(id, lparam, dparam, sparam);
}
```

### Step 3: Configure Your Robot

1. **Get your API Key:**
   - Log into your TheMarketRobo account
   - Go to Settings → API Keys
   - Copy your API key

2. **Update the input parameters:**
   ```cpp
   input string InpApiKey = "sk-your-actual-api-key-here";
   ```

3. **Compile the Expert Advisor:**
   - Press F7 in MetaEditor
   - Fix any compilation errors

### Step 4: Run Your Robot

1. **Attach to a chart:**
   - Open a chart (EURUSD recommended for testing)
   - Drag your compiled EA (.ex5 file) onto the chart
   - Configure the input parameters
   - Click "OK"

2. **Monitor the logs:**
   - Check the Experts tab for messages
   - Look for "SDK session started successfully!"
   - Monitor for any error messages

### Step 5: Test Configuration Updates

1. **Change configuration on the server:**
   - Log into TheMarketRobo dashboard
   - Update your robot's configuration
   - The EA will automatically receive and apply changes

2. **Verify the update:**
   - Check the logs for configuration change messages
   - Verify your trading logic uses the new values

## What Just Happened?

✅ **Authentication**: SDK automatically authenticated with your API key
✅ **Session Management**: Secure session established with the server
✅ **Configuration Sync**: Your robot configuration is now synced with the server
✅ **Real-time Updates**: Changes on the server are automatically applied
✅ **Error Handling**: SDK handles network issues and authentication problems
✅ **Security**: All communication is encrypted and secure

## Next Steps

Now that you have a working robot, you can:

1. **Add Trading Logic**: Implement your trading strategy in `on_tick()`
2. **Configure Risk Management**: Set up proper position sizing and stop losses
3. **Add Indicators**: Use technical indicators for better signals
4. **Test Thoroughly**: Backtest your strategy before going live
5. **Monitor Performance**: Track your robot's performance on the dashboard

## Troubleshooting

### Common Issues

**"Failed to start SDK session"**
- Check your API key is correct
- Verify internet connection
- Ensure the base URL is correct

**No trading activity**
- Check that `enable_trading` is true in your config
- Verify your signal conditions are met
- Look for error messages in the logs

**Configuration not updating**
- Check server-side configuration
- Verify JSON format in your config class
- Look for validation errors in logs

### Getting Help

- Check the logs in MetaTrader's Experts tab
- Review the full documentation in `docs/`
- Contact TheMarketRobo support with error messages

## Full Example Repository

For a complete working example with advanced features, check out:
- `Experts/TheMarketRobo/SDK/Example_Bot.mq5` - Complete implementation
- `docs/EXAMPLES.md` - Additional code examples
- `docs/TROUBLESHOOTING.md` - Solutions to common problems

**Time to completion: 5 minutes**
**Lines of code: ~150**
**Features: Authentication, config sync, error handling**

You're now ready to build powerful trading robots with TheMarketRobo SDK! 🚀
