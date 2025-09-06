# SDK Usage Examples

## Basic Robot Implementation

### Complete Robot Class

```cpp
#include <TheMarketRobo/SDK/TheMarketRobo_SDK.mqh>

// Configuration class
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
        {
            max_risk_per_trade = StringToDouble(new_value);
            return true;
        }
        if(field_name == "max_trades_per_day")
        {
            max_trades_per_day = (int)StringToInteger(new_value);
            return true;
        }
        if(field_name == "enable_news_filter")
        {
            enable_news_filter = (new_value == "true");
            return true;
        }
        return false;
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

// Main robot class
class CMy_Bot : public CTheMarketRobo_Bot_Base
{
private:
    CMy_Bot_Config m_config;

public:
    CMy_Bot() : CTheMarketRobo_Bot_Base(&m_config) {}

    void on_tick() override
    {
        // Your trading logic here
        if(m_config.enable_trading && is_buy_signal())
        {
            execute_buy_order();
        }
    }

    void on_config_changed(string event_json) override
    {
        CJAVal event_data;
        if(event_data.parse(event_json))
        {
            string field = event_data["field"].get_string();
            string old_value = event_data["old_value"].get_string();
            string new_value = event_data["new_value"].get_string();

            PrintFormat("Config changed: %s from %s to %s", field, old_value, new_value);

            // React to specific changes
            if(field == "max_risk_per_trade")
            {
                recalculate_lot_sizes();
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

            if(!active)
            {
                close_all_positions_on_symbol(symbol);
            }
        }
    }

private:
    bool is_buy_signal()
    {
        // Your signal logic here
        return false;
    }

    void execute_buy_order()
    {
        // Your order execution logic here
    }

    void recalculate_lot_sizes()
    {
        // Recalculate based on new risk settings
    }

    void close_all_positions_on_symbol(string symbol)
    {
        // Close positions on inactive symbol
    }
};
```

### MQL5 Entry Points

```cpp
// Input parameters
input string InpApiKey = "YOUR_API_KEY_HERE";
input long InpMagicNumber = 12345;
input string InpBaseApiUrl = "https://api.themarketrobo.com";

// Global variables
CMy_Bot* g_bot;

// Initialization
int OnInit()
{
    g_bot = new CMy_Bot();
    if(CheckPointer(g_bot) == POINTER_INVALID) return INIT_FAILED;

    return g_bot.on_init(InpApiKey, "1.0.0", InpMagicNumber, InpBaseApiUrl);
}

// Deinitialization
void OnDeinit(const int reason)
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
    {
        g_bot.on_deinit(reason);
        delete g_bot;
    }
}

// Timer events (for SDK heartbeats)
void OnTimer()
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
        g_bot.on_timer();
}

// Main trading logic
void OnTick()
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
        g_bot.on_tick();
}

// SDK event handling
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(CheckPointer(g_bot) != POINTER_INVALID)
        g_bot.on_chart_event(id, lparam, dparam, sparam);
}
```

## Advanced Configuration Examples

### Complex Configuration with Validation

```cpp
class CAdvanced_Bot_Config : public Irobot_Config
{
public:
    double max_risk_per_trade;
    int max_trades_per_day;
    bool enable_news_filter;
    string trading_symbols[10];
    int trading_hours_start;
    int trading_hours_end;

    CAdvanced_Bot_Config()
    {
        max_risk_per_trade = 1.5;
        max_trades_per_day = 10;
        enable_news_filter = true;
        trading_hours_start = 8;  // 8 AM
        trading_hours_end = 18;   // 6 PM

        // Default symbols
        trading_symbols[0] = "EURUSD";
        trading_symbols[1] = "GBPUSD";
    }

    virtual bool validate_field(string field_name, string new_value, string &reason) override
    {
        if(field_name == "max_risk_per_trade")
        {
            double risk = StringToDouble(new_value);
            if(risk >= 0.1 && risk <= 10.0) return true;
            reason = "Risk must be between 0.1 and 10.0 percent";
            return false;
        }

        if(field_name == "trading_hours_start" || field_name == "trading_hours_end")
        {
            int hour = (int)StringToInteger(new_value);
            if(hour >= 0 && hour <= 23) return true;
            reason = "Trading hour must be between 0 and 23";
            return false;
        }

        return true; // Accept other fields
    }

    virtual string to_json() override
    {
        string symbols_json = "[";
        for(int i = 0; i < ArraySize(trading_symbols); i++)
        {
            if(trading_symbols[i] != "")
            {
                if(i > 0) symbols_json += ",";
                symbols_json += "\"" + trading_symbols[i] + "\"";
            }
        }
        symbols_json += "]";

        return StringFormat(
            "{\"max_risk_per_trade\":%.2f,\"max_trades_per_day\":%d,\"enable_news_filter\":%s,\"trading_symbols\":%s,\"trading_hours_start\":%d,\"trading_hours_end\":%d}",
            max_risk_per_trade, max_trades_per_day, enable_news_filter ? "true" : "false",
            symbols_json, trading_hours_start, trading_hours_end
        );
    }

    virtual bool update_from_json(const CJAVal &config_json) override
    {
        // Implementation for updating from JSON
        return true;
    }

    virtual bool update_field(string field_name, string new_value) override
    {
        if(field_name == "max_risk_per_trade")
            max_risk_per_trade = StringToDouble(new_value);
        else if(field_name == "max_trades_per_day")
            max_trades_per_day = (int)StringToInteger(new_value);
        else if(field_name == "enable_news_filter")
            enable_news_filter = (new_value == "true");
        else if(field_name == "trading_hours_start")
            trading_hours_start = (int)StringToInteger(new_value);
        else if(field_name == "trading_hours_end")
            trading_hours_end = (int)StringToInteger(new_value);
        else
            return false;

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
        if(field_name == "trading_hours_start")
            return IntegerToString(trading_hours_start);
        if(field_name == "trading_hours_end")
            return IntegerToString(trading_hours_end);

        return "";
    }

    virtual void get_field_names(string &field_names[]) override
    {
        string names[] = {
            "max_risk_per_trade",
            "max_trades_per_day",
            "enable_news_filter",
            "trading_hours_start",
            "trading_hours_end"
        };
        ArrayCopy(field_names, names);
    }
};
```

## Event Handling Examples

### Detailed Config Change Handling

```cpp
void CMy_Bot::on_config_changed(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json))
    {
        Print("Error: Failed to parse config change event");
        return;
    }

    string field = event_data["field"].get_string();
    string old_value = event_data["old_value"].get_string();
    string new_value = event_data["new_value"].get_string();

    PrintFormat("Configuration Update: %s changed from %s to %s",
                field, old_value, new_value);

    // Handle specific configuration changes
    if(field == "max_risk_per_trade")
    {
        handle_risk_change(StringToDouble(new_value));
    }
    else if(field == "max_trades_per_day")
    {
        handle_trade_limit_change((int)StringToInteger(new_value));
    }
    else if(field == "enable_news_filter")
    {
        handle_news_filter_change(new_value == "true");
    }
}

void CMy_Bot::handle_risk_change(double new_risk)
{
    PrintFormat("Risk management updated to %.2f%%", new_risk);
    // Recalculate position sizes
    update_position_sizing();
    // Adjust existing positions if necessary
    adjust_open_positions();
}

void CMy_Bot::handle_trade_limit_change(int new_limit)
{
    PrintFormat("Daily trade limit set to %d", new_limit);
    // Update trade counter
    reset_daily_trade_counter();
}

void CMy_Bot::handle_news_filter_change(bool enabled)
{
    PrintFormat("News filter %s", enabled ? "enabled" : "disabled");
    // Update news monitoring
    update_news_monitoring(enabled);
}
```

### Symbol Status Change Handling

```cpp
void CMy_Bot::on_symbol_changed(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json))
    {
        Print("Error: Failed to parse symbol change event");
        return;
    }

    string symbol = event_data["symbol"].get_string();
    bool active = event_data["active_to_trade"].get_bool();

    if(active)
    {
        PrintFormat("Symbol %s is now available for trading", symbol);
        // Resume trading on this symbol
        resume_symbol_trading(symbol);
    }
    else
    {
        PrintFormat("Symbol %s is no longer available for trading", symbol);
        // Close all positions and stop trading
        emergency_close_symbol(symbol);
        disable_symbol_trading(symbol);
    }
}
```

## Trading Logic Examples

### Simple Trend Following Strategy

```cpp
void CMy_Bot::on_tick()
{
    // Check if trading is enabled and within trading hours
    if(!m_config.enable_trading || !is_within_trading_hours())
        return;

    // Check daily trade limit
    if(get_today_trade_count() >= m_config.max_trades_per_day)
        return;

    string symbol = Symbol();

    // Check if symbol is active for trading
    if(!is_symbol_active_for_trading(symbol))
        return;

    // Simple trend following logic
    double ma_fast = iMA(symbol, PERIOD_H1, 10, 0, MODE_SMA, PRICE_CLOSE);
    double ma_slow = iMA(symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE);

    if(ma_fast > ma_slow && is_buy_signal_confirmed())
    {
        execute_buy_order();
    }
    else if(ma_fast < ma_slow && is_sell_signal_confirmed())
    {
        execute_sell_order();
    }
}

bool CMy_Bot::is_within_trading_hours()
{
    MqlDateTime dt;
    TimeCurrent(dt);

    int current_hour = dt.hour;
    return current_hour >= m_config.trading_hours_start &&
           current_hour < m_config.trading_hours_end;
}

bool CMy_Bot::is_symbol_active_for_trading(string symbol)
{
    // Check if symbol is in the active trading list
    for(int i = 0; i < ArraySize(m_config.trading_symbols); i++)
    {
        if(m_config.trading_symbols[i] == symbol)
            return true;
    }
    return false;
}
```

### Risk Management Integration

```cpp
void CMy_Bot::execute_buy_order()
{
    double lot_size = calculate_lot_size();
    double stop_loss = calculate_stop_loss();
    double take_profit = calculate_take_profit();

    // Execute market buy order
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = lot_size;
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    request.sl = stop_loss;
    request.tp = take_profit;
    request.magic = m_config.magic_number;

    if(OrderSend(request, result))
    {
        PrintFormat("Buy order executed: %s, Volume: %.2f", Symbol(), lot_size);
        increment_trade_counter();
    }
    else
    {
        PrintFormat("Failed to execute buy order: %s", GetLastError());
    }
}

double CMy_Bot::calculate_lot_size()
{
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * (m_config.max_risk_per_trade / 100.0);
    double stop_loss_pips = 50; // Example stop loss in pips

    // Calculate lot size based on risk
    double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lot_size = risk_amount / (stop_loss_pips * tick_value * 10);

    // Apply minimum and maximum lot size constraints
    double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

    return MathMax(min_lot, MathMin(max_lot, lot_size));
}
```
