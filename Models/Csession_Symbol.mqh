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
 * This class holds the complete properties of a trading symbol, matching
 * the session_symbols/v1.json schema. It includes trading specifications,
 * symbol metadata, and market data collected from MQL5 SymbolInfo* functions.
 *
 * ## Required Fields
 * - symbol: Trading pair symbol (e.g., EURUSD)
 * - active_to_trade: Whether symbol is in watchlist and active for trading
 *
 * ## Optional Fields
 * - Trading specs: spread, lot_size, pip_value, margin_required
 * - Symbol metadata: country, category, basis, isin, page, path
 * - Currency info: currency_profit, currency_margin
 * - Description: description, exchange, formula, sector_name, industry_name, bank
 */
class Csession_Symbol : public CObject
{
private:
    // Required fields
    string m_symbol;
    bool   m_active_to_trade;
    
    // Trading specifications
    double m_spread;
    double m_lot_size;
    double m_pip_value;
    double m_margin_required;
    
    // Symbol metadata (from SymbolInfoString)
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
    Csession_Symbol(string symbol);
    ~Csession_Symbol();

    void populate_data();
    CJAVal* to_json();
    
    // Getters
    string get_symbol_name() const { return m_symbol; }
    bool   is_active_to_trade() const { return m_active_to_trade; }
    
    // Setters
    void set_active_to_trade(bool active) { m_active_to_trade = active; }
    
private:
    void add_json_string(CJAVal* json, string key, string value);
    void add_json_bool(CJAVal* json, string key, bool value);
    void add_json_double(CJAVal* json, string key, double value);
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

Csession_Symbol::~Csession_Symbol()
{
}

/**
 * @brief Populates the symbol's market data using MQL5 SymbolInfo* functions.
 * @note Field mappings match session_symbols/v1.json schema exactly.
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

    // ===========================================================================
    // REQUIRED FIELDS
    // ===========================================================================
    
    // active_to_trade: Determined by SymbolSelect() function in MQL5
    m_active_to_trade = (bool)SymbolInfoInteger(m_symbol, SYMBOL_VISIBLE);

    // ===========================================================================
    // TRADING SPECIFICATIONS
    // ===========================================================================
    
    // spread: Current spread from SymbolInfoInteger(symbol, SYMBOL_SPREAD)
    m_spread = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
    
    // lot_size: Minimum lot size from SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)
    m_lot_size = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    
    // pip_value: Value per pip for the symbol
    MqlTick last_tick;
    SymbolInfoTick(m_symbol, last_tick);
    double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tick_size > 0)
    {
        m_pip_value = tick_value * (_Point / tick_size);
    }

    // margin_required: Margin required for 1 lot from SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL)
    double margin;
    if(OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, 1.0, last_tick.ask, margin))
    {
        m_margin_required = margin;
    }
    
    // ===========================================================================
    // SYMBOL METADATA (from SymbolInfoString)
    // ===========================================================================
    
    // symbol_country: Country of the financial symbol
    m_symbol_country = SymbolInfoString(m_symbol, SYMBOL_COUNTRY);
    
    // symbol_category: Symbol category or sector name
    m_symbol_category = SymbolInfoString(m_symbol, SYMBOL_CATEGORY);
    
    // symbol_basis: Underlying asset for derivatives
    m_symbol_basis = SymbolInfoString(m_symbol, SYMBOL_BASIS);
    
    // symbol_isin: International Securities Identification Number
    m_symbol_isin = SymbolInfoString(m_symbol, SYMBOL_ISIN);
    
    // symbol_page: Web page with symbol information
    m_symbol_page = SymbolInfoString(m_symbol, SYMBOL_PAGE);
    
    // symbol_path: Hierarchical path in the symbol tree structure
    m_symbol_path = SymbolInfoString(m_symbol, SYMBOL_PATH);
    
    // symbol_currency_profit: Currency in which profit is calculated
    m_symbol_currency_profit = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
    
    // symbol_currency_margin: Currency used for margin calculations
    m_symbol_currency_margin = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_MARGIN);
    
    // symbol_description: Detailed description of the symbol
    m_symbol_description = SymbolInfoString(m_symbol, SYMBOL_DESCRIPTION);
    
    // symbol_exchange: Name of the exchange where symbol is traded
    m_symbol_exchange = SymbolInfoString(m_symbol, SYMBOL_EXCHANGE);
    
    // symbol_formula: Mathematical formula for custom/synthetic symbols
    m_symbol_formula = SymbolInfoString(m_symbol, SYMBOL_FORMULA);
    
    // symbol_sector_name: Name of the economic sector
    m_symbol_sector_name = SymbolInfoString(m_symbol, SYMBOL_SECTOR_NAME);
    
    // symbol_industry_name: Name of the industry branch
    m_symbol_industry_name = SymbolInfoString(m_symbol, SYMBOL_INDUSTRY_NAME);
    
    // symbol_bank: Financial institution providing quotes
    m_symbol_bank = SymbolInfoString(m_symbol, SYMBOL_BANK);
}

/**
 * @brief Converts the session symbol data to a JSON object.
 * @return A CJAVal object matching session_symbols/v1.json schema.
 */
CJAVal* Csession_Symbol::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    // ===========================================================================
    // REQUIRED FIELDS
    // ===========================================================================
    
    add_json_string(json, "symbol", m_symbol);
    add_json_bool(json, "active_to_trade", m_active_to_trade);
    
    // ===========================================================================
    // OPTIONAL FIELDS (only include if they have valid values)
    // ===========================================================================
    
    // Trading specifications
    if(m_spread > 0) add_json_double(json, "spread", m_spread);
    if(m_lot_size > 0) add_json_double(json, "lot_size", m_lot_size);
    if(m_pip_value > 0) add_json_double(json, "pip_value", m_pip_value);
    if(m_margin_required > 0) add_json_double(json, "margin_required", m_margin_required);
    
    // Symbol metadata (only include non-empty strings)
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
void Csession_Symbol::add_json_string(CJAVal* json, string key, string value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_string(value);
    json.Add(key, val);
}

void Csession_Symbol::add_json_bool(CJAVal* json, string key, bool value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_bool(value);
    json.Add(key, val);
}

void Csession_Symbol::add_json_double(CJAVal* json, string key, double value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_double(value);
    json.Add(key, val);
}

#endif
//+------------------------------------------------------------------+
