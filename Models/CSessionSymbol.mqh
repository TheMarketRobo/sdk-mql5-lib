//+------------------------------------------------------------------+
//|                                               CSessionSymbol.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSESSION_SYMBOL_MQH
#define CSESSION_SYMBOL_MQH

#include <Object.mqh>
#include "../Services/Json.mqh"

/**
 * @class CSessionSymbol
 * @brief Represents a single symbol's data for a session.
 *
 * This class holds the complete properties of a trading symbol, matching
 * the session_symbols/v1.json schema. It includes trading specifications,
 * symbol metadata, and market data collected from MQL5 SymbolInfo* functions.
 */
class CSessionSymbol : public CObject
{
private:
    string m_symbol;
    bool   m_active_to_trade;
    double m_spread;
    double m_lot_size;
    double m_pip_value;
    double m_margin_required;
    string m_symbol_country;
    string m_symbol_category;
    string m_symbol_basis;
    string m_symbol_isin;
    string m_symbol_page;
    string m_symbol_path;
    string m_symbol_currency_profit;
    string m_symbol_currency_margin;
    string m_symbol_description;
    string m_symbol_exchange;
    string m_symbol_formula;
    string m_symbol_sector_name;
    string m_symbol_industry_name;
    string m_symbol_bank;

public:
    CSessionSymbol(string symbol);
    ~CSessionSymbol();

    void populate_data();
    CJAVal* to_json();
    
    string get_symbol_name() const;
    bool   is_active_to_trade() const;
    void   set_active_to_trade(bool active);
    
private:
    void add_json_string(CJAVal* json, string key, string value);
    void add_json_bool(CJAVal* json, string key, bool value);
    void add_json_double(CJAVal* json, string key, double value);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSessionSymbol::CSessionSymbol(string symbol) : m_symbol(symbol)
{
    m_active_to_trade = false;
    m_spread = 0.0;
    m_lot_size = 0.0;
    m_pip_value = 0.0;
    m_margin_required = 0.0;
    m_symbol_country = "";
    m_symbol_category = "";
    m_symbol_basis = "";
    m_symbol_isin = "";
    m_symbol_page = "";
    m_symbol_path = "";
    m_symbol_currency_profit = "";
    m_symbol_currency_margin = "";
    m_symbol_description = "";
    m_symbol_exchange = "";
    m_symbol_formula = "";
    m_symbol_sector_name = "";
    m_symbol_industry_name = "";
    m_symbol_bank = "";
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSessionSymbol::~CSessionSymbol()
{
}

//+------------------------------------------------------------------+
//| Getters and Setters                                               |
//+------------------------------------------------------------------+
string CSessionSymbol::get_symbol_name() const { return m_symbol; }
bool CSessionSymbol::is_active_to_trade() const { return m_active_to_trade; }
void CSessionSymbol::set_active_to_trade(bool active) { m_active_to_trade = active; }

//+------------------------------------------------------------------+
//| Populate symbol data from terminal                                |
//+------------------------------------------------------------------+
void CSessionSymbol::populate_data()
{
    // Symbol is already selected when iterating with SymbolsTotal(true)

    m_active_to_trade = (bool)SymbolInfoInteger(m_symbol, SYMBOL_VISIBLE);
    m_spread = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
    m_lot_size = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    
    MqlTick last_tick;
    SymbolInfoTick(m_symbol, last_tick);
    double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tick_size > 0)
    {
        m_pip_value = tick_value * (_Point / tick_size);
    }

    double margin;
    if(OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, 1.0, last_tick.ask, margin))
    {
        m_margin_required = margin;
    }
    
    m_symbol_country = SymbolInfoString(m_symbol, SYMBOL_COUNTRY);
    m_symbol_category = SymbolInfoString(m_symbol, SYMBOL_CATEGORY);
    m_symbol_basis = SymbolInfoString(m_symbol, SYMBOL_BASIS);
    m_symbol_isin = SymbolInfoString(m_symbol, SYMBOL_ISIN);
    m_symbol_page = SymbolInfoString(m_symbol, SYMBOL_PAGE);
    m_symbol_path = SymbolInfoString(m_symbol, SYMBOL_PATH);
    m_symbol_currency_profit = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
    m_symbol_currency_margin = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_MARGIN);
    m_symbol_description = SymbolInfoString(m_symbol, SYMBOL_DESCRIPTION);
    m_symbol_exchange = SymbolInfoString(m_symbol, SYMBOL_EXCHANGE);
    m_symbol_formula = SymbolInfoString(m_symbol, SYMBOL_FORMULA);
    m_symbol_sector_name = SymbolInfoString(m_symbol, SYMBOL_SECTOR_NAME);
    m_symbol_industry_name = SymbolInfoString(m_symbol, SYMBOL_INDUSTRY_NAME);
    m_symbol_bank = SymbolInfoString(m_symbol, SYMBOL_BANK);
}

//+------------------------------------------------------------------+
//| Convert to JSON                                                   |
//+------------------------------------------------------------------+
CJAVal* CSessionSymbol::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    add_json_string(json, "symbol", m_symbol);
    add_json_bool(json, "active_to_trade", m_active_to_trade);
    
    if(m_spread > 0) add_json_double(json, "spread", m_spread);
    if(m_lot_size > 0) add_json_double(json, "lot_size", m_lot_size);
    if(m_pip_value > 0) add_json_double(json, "pip_value", m_pip_value);
    if(m_margin_required > 0) add_json_double(json, "margin_required", m_margin_required);
    
    if(m_symbol_country != "") add_json_string(json, "symbol_country", m_symbol_country);
    if(m_symbol_category != "") add_json_string(json, "symbol_category", m_symbol_category);
    if(m_symbol_basis != "") add_json_string(json, "symbol_basis", m_symbol_basis);
    if(m_symbol_isin != "") add_json_string(json, "symbol_isin", m_symbol_isin);
    if(m_symbol_page != "") add_json_string(json, "symbol_page", m_symbol_page);
    if(m_symbol_path != "") add_json_string(json, "symbol_path", m_symbol_path);
    if(m_symbol_currency_profit != "") add_json_string(json, "symbol_currency_profit", m_symbol_currency_profit);
    if(m_symbol_currency_margin != "") add_json_string(json, "symbol_currency_margin", m_symbol_currency_margin);
    if(m_symbol_description != "") add_json_string(json, "symbol_description", m_symbol_description);
    if(m_symbol_exchange != "") add_json_string(json, "symbol_exchange", m_symbol_exchange);
    if(m_symbol_formula != "") add_json_string(json, "symbol_formula", m_symbol_formula);
    if(m_symbol_sector_name != "") add_json_string(json, "symbol_sector_name", m_symbol_sector_name);
    if(m_symbol_industry_name != "") add_json_string(json, "symbol_industry_name", m_symbol_industry_name);
    if(m_symbol_bank != "") add_json_string(json, "symbol_bank", m_symbol_bank);

    return json;
}

//+------------------------------------------------------------------+
//| Private Helper Implementations                                   |
//+------------------------------------------------------------------+
void CSessionSymbol::add_json_string(CJAVal* json, string key, string value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_string(value);
    json.Add(key, val);
}

void CSessionSymbol::add_json_bool(CJAVal* json, string key, bool value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_bool(value);
    json.Add(key, val);
}

void CSessionSymbol::add_json_double(CJAVal* json, string key, double value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_double(value);
    json.Add(key, val);
}

#endif
//+------------------------------------------------------------------+

