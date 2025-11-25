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
 *
 * ## Static Data (matches contracts/schemas/static_data/v1.json)
 * - Account information (login, company, server, currency, trade mode, etc.)
 * - Terminal information (build, path, memory, CPU, etc.)
 * - MQL program information (name, type, path, etc.)
 *
 * ## Dynamic Data (matches contracts/api/robot/components/robot.yaml#RobotDynamicData)
 * - Account balance, equity, margin, margin_free, margin_level
 * - Performance metrics: balance_profit, equity_profit
 * - Risk metrics: balance_drawdown, equity_drawdown
 */
class Cdata_Collector_Service : public CObject
{
private:
    // Initial values for profit/drawdown calculations
    double m_initial_balance;
    double m_initial_equity;
    double m_peak_balance;
    double m_peak_equity;
    bool   m_initialized;

    // JSON helper methods
    void add_json_string(CJAVal* json, string key, string value);
    void add_json_long(CJAVal* json, string key, long value);
    void add_json_int(CJAVal* json, string key, int value);
    void add_json_bool(CJAVal* json, string key, bool value);
    void add_json_double(CJAVal* json, string key, double value);
    
    // Enum conversion helpers
    string get_account_trade_mode_string(int mode);
    string get_account_margin_so_mode_string(int mode);
    string get_account_margin_mode_string(int mode);

public:
    Cdata_Collector_Service();
    ~Cdata_Collector_Service();

    // Initialize with starting values
    void initialize(double initial_balance, double initial_equity);
    
    // Data collection
    CJAVal* get_static_fields(long expert_magic_number);
    CArrayObj* get_session_symbols();
    CJAVal* get_dynamic_data();
    
    // Getters for initial values
    double get_initial_balance() const { return m_initial_balance; }
    double get_initial_equity() const { return m_initial_equity; }
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
Cdata_Collector_Service::Cdata_Collector_Service()
{
    m_initial_balance = 0.0;
    m_initial_equity = 0.0;
    m_peak_balance = 0.0;
    m_peak_equity = 0.0;
    m_initialized = false;
}

Cdata_Collector_Service::~Cdata_Collector_Service() {}

/**
 * @brief Initialize the collector with starting balance and equity.
 * @param initial_balance Starting account balance
 * @param initial_equity Starting account equity
 */
void Cdata_Collector_Service::initialize(double initial_balance, double initial_equity)
{
    m_initial_balance = initial_balance;
    m_initial_equity = initial_equity;
    m_peak_balance = initial_balance;
    m_peak_equity = initial_equity;
    m_initialized = true;
}

/**
 * @brief Gathers static fields about the account, terminal, and MQL program.
 * @param expert_magic_number The magic number of the expert advisor.
 * @return A CJAVal object containing all static fields.
 * @note Field names match contracts/schemas/static_data/v1.json exactly.
 */
CJAVal* Cdata_Collector_Service::get_static_fields(long expert_magic_number)
{
    CJAVal* static_fields = new CJAVal(JA_OBJECT);
    if(static_fields == NULL) return NULL;

    // ===========================================================================
    // ACCOUNT INFORMATION (Required fields from static_data/v1.json)
    // ===========================================================================
    
    // account_login: integer - Account number/login ID
    add_json_long(static_fields, "account_login", AccountInfoInteger(ACCOUNT_LOGIN));
    
    // account_trade_mode: string enum - "REAL", "DEMO", "CONTEST"
    add_json_string(static_fields, "account_trade_mode", 
                    get_account_trade_mode_string((int)AccountInfoInteger(ACCOUNT_TRADE_MODE)));
    
    // account_leverage: integer
    add_json_long(static_fields, "account_leverage", AccountInfoInteger(ACCOUNT_LEVERAGE));
    
    // account_limit_orders: integer
    add_json_long(static_fields, "account_limit_orders", AccountInfoInteger(ACCOUNT_LIMIT_ORDERS));
    
    // account_margin_so_mode: string enum - "PERCENT", "MONEY"
    add_json_string(static_fields, "account_margin_so_mode",
                    get_account_margin_so_mode_string((int)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)));
    
    // account_trade_allowed: boolean
    add_json_bool(static_fields, "account_trade_allowed", (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED));
    
    // account_trade_expert: boolean
    add_json_bool(static_fields, "account_trade_expert", (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT));
    
    // account_margin_mode: string enum - "NETTING", "HEDGING", "EXCHANGE"
    add_json_string(static_fields, "account_margin_mode",
                    get_account_margin_mode_string((int)AccountInfoInteger(ACCOUNT_MARGIN_MODE)));
    
    // account_currency_digits: integer
    add_json_long(static_fields, "account_currency_digits", AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS));
    
    // account_fifo_close: boolean
    add_json_bool(static_fields, "account_fifo_close", (bool)AccountInfoInteger(ACCOUNT_FIFO_CLOSE));
    
    // account_hedge_allowed: boolean
    add_json_bool(static_fields, "account_hedge_allowed", (bool)AccountInfoInteger(ACCOUNT_HEDGE_ALLOWED));
    
    // account_name: string
    add_json_string(static_fields, "account_name", AccountInfoString(ACCOUNT_NAME));
    
    // account_server: string - Trade server name
    add_json_string(static_fields, "account_server", AccountInfoString(ACCOUNT_SERVER));
    
    // account_currency: string - ISO 4217 code
    add_json_string(static_fields, "account_currency", AccountInfoString(ACCOUNT_CURRENCY));
    
    // account_company: string - Broker company name
    add_json_string(static_fields, "account_company", AccountInfoString(ACCOUNT_COMPANY));

    // ===========================================================================
    // TERMINAL INFORMATION (Required fields from static_data/v1.json)
    // ===========================================================================
    
    // terminal_build: integer
    add_json_long(static_fields, "terminal_build", TerminalInfoInteger(TERMINAL_BUILD));
    
    // terminal_community_account: boolean
    add_json_bool(static_fields, "terminal_community_account", (bool)TerminalInfoInteger(TERMINAL_COMMUNITY_ACCOUNT));
    
    // terminal_community_connection: boolean
    add_json_bool(static_fields, "terminal_community_connection", (bool)TerminalInfoInteger(TERMINAL_COMMUNITY_CONNECTION));
    
    // terminal_connected: boolean
    add_json_bool(static_fields, "terminal_connected", (bool)TerminalInfoInteger(TERMINAL_CONNECTED));
    
    // terminal_dlls_allowed: boolean
    add_json_bool(static_fields, "terminal_dlls_allowed", (bool)TerminalInfoInteger(TERMINAL_DLLS_ALLOWED));
    
    // terminal_trade_allowed: boolean
    add_json_bool(static_fields, "terminal_trade_allowed", (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED));
    
    // terminal_email_enabled: boolean
    add_json_bool(static_fields, "terminal_email_enabled", (bool)TerminalInfoInteger(TERMINAL_EMAIL_ENABLED));
    
    // terminal_ftp_enabled: boolean
    add_json_bool(static_fields, "terminal_ftp_enabled", (bool)TerminalInfoInteger(TERMINAL_FTP_ENABLED));
    
    // terminal_notifications_enabled: boolean
    add_json_bool(static_fields, "terminal_notifications_enabled", (bool)TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED));
    
    // terminal_maxbars: integer
    add_json_long(static_fields, "terminal_maxbars", TerminalInfoInteger(TERMINAL_MAXBARS));
    
    // terminal_mqid: boolean
    add_json_bool(static_fields, "terminal_mqid", (bool)TerminalInfoInteger(TERMINAL_MQID));
    
    // terminal_codepage: integer
    add_json_long(static_fields, "terminal_codepage", TerminalInfoInteger(TERMINAL_CODEPAGE));
    
    // terminal_cpu_cores: integer
    add_json_long(static_fields, "terminal_cpu_cores", TerminalInfoInteger(TERMINAL_CPU_CORES));
    
    // terminal_memory_physical: integer (MB)
    add_json_long(static_fields, "terminal_memory_physical", TerminalInfoInteger(TERMINAL_MEMORY_PHYSICAL));
    
    // terminal_memory_total: integer (MB)
    add_json_long(static_fields, "terminal_memory_total", TerminalInfoInteger(TERMINAL_MEMORY_TOTAL));
    
    // terminal_memory_available: integer (MB)
    add_json_long(static_fields, "terminal_memory_available", TerminalInfoInteger(TERMINAL_MEMORY_AVAILABLE));
    
    // terminal_memory_used: integer (MB)
    add_json_long(static_fields, "terminal_memory_used", TerminalInfoInteger(TERMINAL_MEMORY_USED));
    
    // terminal_x64: boolean
    add_json_bool(static_fields, "terminal_x64", (bool)TerminalInfoInteger(TERMINAL_X64));
    
    // terminal_path: string
    add_json_string(static_fields, "terminal_path", TerminalInfoString(TERMINAL_PATH));
    
    // terminal_data_path: string
    add_json_string(static_fields, "terminal_data_path", TerminalInfoString(TERMINAL_DATA_PATH));
    
    // terminal_commondata_path: string
    add_json_string(static_fields, "terminal_commondata_path", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
    
    // terminal_name: string
    add_json_string(static_fields, "terminal_name", TerminalInfoString(TERMINAL_NAME));
    
    // terminal_language: string
    add_json_string(static_fields, "terminal_language", TerminalInfoString(TERMINAL_LANGUAGE));

    // ===========================================================================
    // MQL PROGRAM INFORMATION (Optional fields from static_data/v1.json)
    // ===========================================================================
    
    // mql_program_name: string
    add_json_string(static_fields, "mql_program_name", MQLInfoString(MQL_PROGRAM_NAME));
    
    // mql_program_type: integer (1=Expert Advisor)
    add_json_int(static_fields, "mql_program_type", (int)MQLInfoInteger(MQL_PROGRAM_TYPE));
    
    // mql_program_path: string
    add_json_string(static_fields, "mql_program_path", MQLInfoString(MQL_PROGRAM_PATH));
    
    // mql_trade_allowed: integer (0 or 1)
    add_json_int(static_fields, "mql_trade_allowed", (int)MQLInfoInteger(MQL_TRADE_ALLOWED));
    
    // mql_optimization: integer (0 or 1)
    add_json_int(static_fields, "mql_optimization", (int)MQLInfoInteger(MQL_OPTIMIZATION));
    
    // expert_magic: integer - Magic number for the Expert Advisor
    add_json_int(static_fields, "expert_magic", (int)expert_magic_number);

    return static_fields;
}

/**
 * @brief Converts account trade mode integer to string enum.
 * @param mode ACCOUNT_TRADE_MODE value (0=DEMO, 1=CONTEST, 2=REAL)
 * @return String enum value: "REAL", "DEMO", or "CONTEST"
 */
string Cdata_Collector_Service::get_account_trade_mode_string(int mode)
{
    switch(mode)
    {
        case ACCOUNT_TRADE_MODE_REAL:    return "REAL";
        case ACCOUNT_TRADE_MODE_DEMO:    return "DEMO";
        case ACCOUNT_TRADE_MODE_CONTEST: return "CONTEST";
        default: return "DEMO";
    }
}

/**
 * @brief Converts margin stop-out mode integer to string enum.
 * @param mode ACCOUNT_MARGIN_SO_MODE value
 * @return String enum value: "PERCENT" or "MONEY"
 */
string Cdata_Collector_Service::get_account_margin_so_mode_string(int mode)
{
    switch(mode)
    {
        case ACCOUNT_STOPOUT_MODE_PERCENT: return "PERCENT";
        case ACCOUNT_STOPOUT_MODE_MONEY:   return "MONEY";
        default: return "PERCENT";
    }
}

/**
 * @brief Converts margin mode integer to string enum.
 * @param mode ACCOUNT_MARGIN_MODE value
 * @return String enum value: "NETTING", "HEDGING", or "EXCHANGE"
 */
string Cdata_Collector_Service::get_account_margin_mode_string(int mode)
{
    switch(mode)
    {
        case ACCOUNT_MARGIN_MODE_RETAIL_NETTING: return "NETTING";
        case ACCOUNT_MARGIN_MODE_RETAIL_HEDGING: return "HEDGING";
        case ACCOUNT_MARGIN_MODE_EXCHANGE:       return "EXCHANGE";
        default: return "NETTING";
    }
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
 * @return A CJAVal object with dynamic data matching RobotDynamicData schema.
 * @note Fields: account_balance, account_equity, account_margin, account_margin_free,
 *       account_margin_level, balance_profit, equity_profit, balance_drawdown, equity_drawdown
 */
CJAVal* Cdata_Collector_Service::get_dynamic_data()
{
    CJAVal* dynamic_data = new CJAVal(JA_OBJECT);
    if(dynamic_data == NULL) return NULL;

    // Get current account values
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double current_margin = AccountInfoDouble(ACCOUNT_MARGIN);
    double current_margin_free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double current_margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

    // ===========================================================================
    // ACCOUNT VALUES (Required fields from RobotDynamicData)
    // ===========================================================================
    
    // account_balance: decimal(18,2)
    add_json_double(dynamic_data, "account_balance", NormalizeDouble(current_balance, 2));
    
    // account_equity: decimal(18,2)
    add_json_double(dynamic_data, "account_equity", NormalizeDouble(current_equity, 2));
    
    // account_margin: decimal(18,2)
    add_json_double(dynamic_data, "account_margin", NormalizeDouble(current_margin, 2));
    
    // account_margin_free: decimal(18,2)
    add_json_double(dynamic_data, "account_margin_free", NormalizeDouble(current_margin_free, 2));
    
    // account_margin_level: decimal(18,2)
    add_json_double(dynamic_data, "account_margin_level", NormalizeDouble(current_margin_level, 2));

    // ===========================================================================
    // PERFORMANCE METRICS (Required fields from RobotDynamicData)
    // ===========================================================================
    
    // Calculate profit/loss
    double balance_profit = 0.0;
    double equity_profit = 0.0;
    
    if(m_initialized)
    {
        balance_profit = current_balance - m_initial_balance;
        equity_profit = current_equity - m_initial_equity;
    }
    
    // balance_profit: decimal(18,2) - Profit/loss based on balance
    add_json_double(dynamic_data, "balance_profit", NormalizeDouble(balance_profit, 2));
    
    // equity_profit: decimal(18,2) - Profit/loss based on equity
    add_json_double(dynamic_data, "equity_profit", NormalizeDouble(equity_profit, 2));

    // ===========================================================================
    // RISK METRICS (Required fields from RobotDynamicData)
    // ===========================================================================
    
    // Update peak values
    if(current_balance > m_peak_balance) m_peak_balance = current_balance;
    if(current_equity > m_peak_equity) m_peak_equity = current_equity;
    
    // Calculate drawdowns
    double balance_drawdown = 0.0;
    double equity_drawdown = 0.0;
    
    if(m_peak_balance > 0)
    {
        balance_drawdown = ((m_peak_balance - current_balance) / m_peak_balance) * 100.0;
        if(balance_drawdown < 0) balance_drawdown = 0.0; // Drawdown cannot be negative
    }
    
    if(m_peak_equity > 0)
    {
        equity_drawdown = ((m_peak_equity - current_equity) / m_peak_equity) * 100.0;
        if(equity_drawdown < 0) equity_drawdown = 0.0; // Drawdown cannot be negative
    }
    
    // balance_drawdown: double - Maximum drawdown percentage from peak balance
    add_json_double(dynamic_data, "balance_drawdown", NormalizeDouble(balance_drawdown, 2));
    
    // equity_drawdown: double - Maximum drawdown percentage from peak equity
    add_json_double(dynamic_data, "equity_drawdown", NormalizeDouble(equity_drawdown, 2));

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

void Cdata_Collector_Service::add_json_int(CJAVal* json, string key, int value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_long((long)value);
    json.Add(key, val);
}

void Cdata_Collector_Service::add_json_bool(CJAVal* json, string key, bool value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_bool(value);
    json.Add(key, val);
}

void Cdata_Collector_Service::add_json_double(CJAVal* json, string key, double value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_double(value);
    json.Add(key, val);
}


#endif
//+------------------------------------------------------------------+
