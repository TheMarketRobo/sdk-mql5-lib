//+------------------------------------------------------------------+
//|                                       Cdata_Collector_Service.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CDATA_COLLECTOR_SERVICE_MQH
#define CDATA_COLLECTOR_SERVICE_MQH

#include <Object.mqh>
#include "Json.mqh"
#include "../Models/Csession_Symbol.mqh"

/**
 * @class Cdata_Collector_Service
 * @brief Service to collect static and dynamic data from the MQL5 environment.
 */
class Cdata_Collector_Service : public CObject
{
private:
    void add_json_string(CJAVal* json, string key, string value);
    void add_json_long(CJAVal* json, string key, long value);
    void add_json_bool(CJAVal* json, string key, bool value);

public:
    Cdata_Collector_Service();
    ~Cdata_Collector_Service();

    CJAVal* get_static_fields(long expert_magic_number);
    CArrayObj* get_session_symbols();
    CJAVal* get_dynamic_data();
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
Cdata_Collector_Service::Cdata_Collector_Service() {}
Cdata_Collector_Service::~Cdata_Collector_Service() {}

/**
 * @brief Gathers static fields about the account, terminal, and MQL program.
 * @param expert_magic_number The magic number of the expert advisor.
 * @return A CJAVal object containing all static fields.
 */
CJAVal* Cdata_Collector_Service::get_static_fields(long expert_magic_number)
{
    CJAVal* static_fields = new CJAVal(JA_OBJECT);
    if(static_fields == NULL) return NULL;

    // Account Information
    add_json_string(static_fields, "account_number", (string)AccountInfoInteger(ACCOUNT_LOGIN));
    add_json_string(static_fields, "broker", AccountInfoString(ACCOUNT_COMPANY));
    add_json_string(static_fields, "server", AccountInfoString(ACCOUNT_SERVER));
    add_json_string(static_fields, "account_name", AccountInfoString(ACCOUNT_NAME));
    add_json_string(static_fields, "account_currency", AccountInfoString(ACCOUNT_CURRENCY));
    add_json_long(static_fields, "account_trade_mode", AccountInfoInteger(ACCOUNT_TRADE_MODE));
    add_json_long(static_fields, "account_leverage", AccountInfoInteger(ACCOUNT_LEVERAGE));
    add_json_long(static_fields, "account_limit_orders", AccountInfoInteger(ACCOUNT_LIMIT_ORDERS));
    add_json_long(static_fields, "account_margin_so_mode", (long)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE));
    add_json_bool(static_fields, "account_trade_allowed", (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED));
    add_json_bool(static_fields, "account_trade_expert", (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT));
    add_json_long(static_fields, "account_margin_mode", (long)AccountInfoInteger(ACCOUNT_MARGIN_MODE));
    add_json_long(static_fields, "account_currency_digits", AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS));
    add_json_bool(static_fields, "account_fifo_close", (bool)AccountInfoInteger(ACCOUNT_FIFO_CLOSE));
    add_json_bool(static_fields, "account_hedge_allowed", (bool)AccountInfoInteger(ACCOUNT_HEDGE_ALLOWED));

    // MQL Program Information
    add_json_string(static_fields, "mql_program_name", MQLInfoString(MQL_PROGRAM_NAME));
    add_json_long(static_fields, "mql_program_type", MQLInfoInteger(MQL_PROGRAM_TYPE));
    add_json_string(static_fields, "mql_program_path", MQLInfoString(MQL_PROGRAM_PATH));
    add_json_bool(static_fields, "mql_trade_allowed", (bool)MQLInfoInteger(MQL_TRADE_ALLOWED));
    add_json_bool(static_fields, "mql_optimization", (bool)MQLInfoInteger(MQL_OPTIMIZATION));

    // Terminal Information
    add_json_string(static_fields, "terminal_path", TerminalInfoString(TERMINAL_PATH));
    add_json_string(static_fields, "terminal_data_path", TerminalInfoString(TERMINAL_DATA_PATH));
    add_json_string(static_fields, "terminal_commondata_path", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
    add_json_long(static_fields, "terminal_build", TerminalInfoInteger(TERMINAL_BUILD));
    add_json_string(static_fields, "terminal_language", TerminalInfoString(TERMINAL_LANGUAGE));
    add_json_string(static_fields, "terminal_name", TerminalInfoString(TERMINAL_COMPANY));
    add_json_long(static_fields, "terminal_maxbars", (long)TerminalInfoInteger(TERMINAL_MAXBARS));
    
    // Expert specific
    add_json_long(static_fields, "expert_magic", expert_magic_number);

    return static_fields;
}

/**
 * @brief Gathers all available symbols and their market data.
 * @return A CArrayObj list of Csession_Symbol objects.
 */
CArrayObj* Cdata_Collector_Service::get_session_symbols()
{
    CArrayObj* symbols_list = new CArrayObj();
    if(symbols_list == NULL) return NULL;

    int total_symbols = SymbolsTotal(false);
    for(int i = 0; i < total_symbols; i++)
    {
        string symbol_name = SymbolName(i, false);
        Csession_Symbol* symbol = new Csession_Symbol(symbol_name);
        if(symbol != NULL)
        {
            symbol.populate_data();
            symbols_list.Add(symbol);
        }
    }
    return symbols_list;
}

/**
 * @brief Gathers dynamic data for the heartbeat.
 * @return A CJAVal object with dynamic data. (Not fully implemented in this step)
 */
CJAVal* Cdata_Collector_Service::get_dynamic_data()
{
    CJAVal* dynamic_data = new CJAVal(JA_OBJECT);
    // TODO: Implement the collection of dynamic data (balance, equity, positions, etc.)
    return dynamic_data;
}

//+------------------------------------------------------------------+
//| Private Helper Implementations                                   |
//+------------------------------------------------------------------+
void Cdata_Collector_Service::add_json_string(CJAVal* json, string key, string value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_string(value);
    json.Add(key, val);
}

void Cdata_Collector_Service::add_json_long(CJAVal* json, string key, long value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_long(value);
    json.Add(key, val);
}

void Cdata_Collector_Service::add_json_bool(CJAVal* json, string key, bool value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_bool(value);
    json.Add(key, val);
}


#endif
//+------------------------------------------------------------------+
