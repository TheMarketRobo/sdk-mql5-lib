//+------------------------------------------------------------------+
//|                                              Csession_Symbol.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSESSION_SYMBOL_MQH
#define CSESSION_SYMBOL_MQH

#include <Object.mqh>
#include "../Services/Json.mqh"

/**
 * @class Csession_Symbol
 * @brief Represents a single symbol's data for a session.
 *
 * This class holds the properties of a trading symbol, such as its name,
 * trading status, and other market data. It is used to construct the
 * `session_symbols` array for the `/start` endpoint.
 */
class Csession_Symbol : public CObject
{
private:
    string m_symbol;
    bool m_active_to_trade;
    double m_spread;
    double m_lot_size;
    double m_pip_value;
    double m_margin_required;

public:
    Csession_Symbol(string symbol);
    ~Csession_Symbol();

    void populate_data();

    CJAVal* to_json();
    
    string get_symbol_name() const { return m_symbol; }
    bool is_active_to_trade() const { return m_active_to_trade; }
    void set_active_to_trade(bool active) { m_active_to_trade = active; }
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
Csession_Symbol::Csession_Symbol(string symbol) : m_symbol(symbol)
{
    m_active_to_trade = false;
    m_spread = 0.0;
    m_lot_size = 0.0;
    m_pip_value = 0.0;
    m_margin_required = 0.0;
}

Csession_Symbol::~Csession_Symbol()
{
}

/**
 * @brief Populates the symbol's market data using MQL5 functions.
 */
void Csession_Symbol::populate_data()
{
    // Ensure the symbol is selected in Market Watch to get data
    if(!SymbolInfoInteger(m_symbol, SYMBOL_SELECT))
    {
        SymbolSelect(m_symbol, true);
    }
    
    // Allow a small delay for the terminal to update symbol data
    Sleep(50);

    m_active_to_trade = (bool)SymbolInfoInteger(m_symbol, SYMBOL_VISIBLE);
    m_spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * _Point;
    m_lot_size = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    
    // Pip value calculation can be complex, this is a simplified version
    MqlTick last_tick;
    SymbolInfoTick(m_symbol, last_tick);
    double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tick_size > 0)
    {
        m_pip_value = tick_value * (_Point / tick_size);
    }

    // Margin required for 1 lot
    double margin;
    if(OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, 1.0, last_tick.ask, margin))
    {
        m_margin_required = margin;
    }
}


/**
 * @brief Converts the session symbol data to a JSON object.
 * @return A CJAVal object.
 */
CJAVal* Csession_Symbol::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    CJAVal* symbol_val = new CJAVal();
    symbol_val.set_string(m_symbol);
    json.Add("symbol", symbol_val);
    
    CJAVal* active_val = new CJAVal();
    active_val.set_bool(m_active_to_trade);
    json.Add("active_to_trade", active_val);
    
    CJAVal* spread_val = new CJAVal();
    spread_val.set_double(m_spread);
    json.Add("spread", spread_val);
    
    CJAVal* lot_size_val = new CJAVal();
    lot_size_val.set_double(m_lot_size);
    json.Add("lot_size", lot_size_val);
    
    CJAVal* pip_value_val = new CJAVal();
    pip_value_val.set_double(m_pip_value);
    json.Add("pip_value", pip_value_val);
    
    CJAVal* margin_val = new CJAVal();
    margin_val.set_double(m_margin_required);
    json.Add("margin_required", margin_val);

    return json;
}

#endif
//+------------------------------------------------------------------+
