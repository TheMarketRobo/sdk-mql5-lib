//+------------------------------------------------------------------+
//|                                        CDataCollectorService.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CDATA_COLLECTOR_SERVICE_MQH
#define CDATA_COLLECTOR_SERVICE_MQH

#include <Object.mqh>
#include "Json.mqh"
#include "../Models/CSessionSymbol.mqh"

/**
 * @class CDataCollectorService
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
class CDataCollectorService : public CObject
{
private:
    double m_initial_balance;
    double m_initial_equity;
    double m_peak_balance;
    double m_peak_equity;
    bool   m_initialized;

    void add_json_string(CJAVal* json, string key, string value);
    void add_json_long(CJAVal* json, string key, long value);
    void add_json_int(CJAVal* json, string key, int value);
    void add_json_bool(CJAVal* json, string key, bool value);
    void add_json_double(CJAVal* json, string key, double value);
    
    string get_account_trade_mode_string(int mode);
    string get_account_margin_so_mode_string(int mode);
    string get_account_margin_mode_string(int mode);

public:
    CDataCollectorService();
    ~CDataCollectorService();

    void initialize(double initial_balance, double initial_equity);
    bool is_account_data_available();
    bool wait_for_account_data(int timeout_seconds = 10);
    
    CJAVal* get_static_fields(long expert_magic_number);
    CArrayObj* get_session_symbols();
    CJAVal* get_dynamic_data();
    
    double get_initial_balance() const;
    double get_initial_equity() const;
    double get_current_balance() const;
    double get_current_equity() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDataCollectorService::CDataCollectorService()
{
    m_initial_balance = 0.0;
    m_initial_equity = 0.0;
    m_peak_balance = 0.0;
    m_peak_equity = 0.0;
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CDataCollectorService::~CDataCollectorService() {}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
double CDataCollectorService::get_initial_balance() const { return m_initial_balance; }
double CDataCollectorService::get_initial_equity() const { return m_initial_equity; }
double CDataCollectorService::get_current_balance() const { return AccountInfoDouble(ACCOUNT_BALANCE); }
double CDataCollectorService::get_current_equity() const { return AccountInfoDouble(ACCOUNT_EQUITY); }

//+------------------------------------------------------------------+
//| Wait for account data to be available (with timeout)              |
//| This is useful when starting during OnInit                        |
//+------------------------------------------------------------------+
bool CDataCollectorService::wait_for_account_data(int timeout_seconds)
{
    Print("SDK Info: Waiting for account data to be available...");
    
    datetime start_time = TimeLocal();
    int wait_count = 0;
    
    while(!is_account_data_available())
    {
        if(TimeLocal() - start_time >= timeout_seconds)
        {
            Print("SDK Warning: Timeout waiting for account data after ", timeout_seconds, " seconds");
            return false;
        }
        
        // Sleep for 100ms and check again
        Sleep(100);
        wait_count++;
        
        if(wait_count % 10 == 0) // Every second
        {
            Print("SDK Debug: Still waiting for account data... (", wait_count / 10, "s)");
        }
    }
    
    // Account data is now available
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    Print("SDK Info: Account data available. Balance: ", balance, ", Equity: ", equity);
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize with starting values                                   |
//+------------------------------------------------------------------+
void CDataCollectorService::initialize(double initial_balance, double initial_equity)
{
    m_initial_balance = initial_balance;
    m_initial_equity = initial_equity;
    m_peak_balance = initial_balance;
    m_peak_equity = initial_equity;
    m_initialized = true;
}

//+------------------------------------------------------------------+
//| Get static fields matching static_data/v1.json                    |
//+------------------------------------------------------------------+
CJAVal* CDataCollectorService::get_static_fields(long expert_magic_number)
{
    CJAVal* static_fields = new CJAVal(JA_OBJECT);
    if(static_fields == NULL) return NULL;

    // Account Information
    add_json_long(static_fields, "account_login", AccountInfoInteger(ACCOUNT_LOGIN));
    add_json_string(static_fields, "account_trade_mode", 
                    get_account_trade_mode_string((int)AccountInfoInteger(ACCOUNT_TRADE_MODE)));
    add_json_long(static_fields, "account_leverage", AccountInfoInteger(ACCOUNT_LEVERAGE));
    add_json_long(static_fields, "account_limit_orders", AccountInfoInteger(ACCOUNT_LIMIT_ORDERS));
    add_json_string(static_fields, "account_margin_so_mode",
                    get_account_margin_so_mode_string((int)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)));
    add_json_bool(static_fields, "account_trade_allowed", (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED));
    add_json_bool(static_fields, "account_trade_expert", (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT));
    add_json_string(static_fields, "account_margin_mode",
                    get_account_margin_mode_string((int)AccountInfoInteger(ACCOUNT_MARGIN_MODE)));
    add_json_long(static_fields, "account_currency_digits", AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS));
    add_json_bool(static_fields, "account_fifo_close", (bool)AccountInfoInteger(ACCOUNT_FIFO_CLOSE));
    add_json_bool(static_fields, "account_hedge_allowed", (bool)AccountInfoInteger(ACCOUNT_HEDGE_ALLOWED));
    add_json_string(static_fields, "account_name", AccountInfoString(ACCOUNT_NAME));
    add_json_string(static_fields, "account_server", AccountInfoString(ACCOUNT_SERVER));
    add_json_string(static_fields, "account_currency", AccountInfoString(ACCOUNT_CURRENCY));
    add_json_string(static_fields, "account_company", AccountInfoString(ACCOUNT_COMPANY));

    // Terminal Information
    add_json_long(static_fields, "terminal_build", TerminalInfoInteger(TERMINAL_BUILD));
    add_json_bool(static_fields, "terminal_community_account", (bool)TerminalInfoInteger(TERMINAL_COMMUNITY_ACCOUNT));
    add_json_bool(static_fields, "terminal_community_connection", (bool)TerminalInfoInteger(TERMINAL_COMMUNITY_CONNECTION));
    add_json_bool(static_fields, "terminal_connected", (bool)TerminalInfoInteger(TERMINAL_CONNECTED));
    add_json_bool(static_fields, "terminal_dlls_allowed", (bool)TerminalInfoInteger(TERMINAL_DLLS_ALLOWED));
    add_json_bool(static_fields, "terminal_trade_allowed", (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED));
    add_json_bool(static_fields, "terminal_email_enabled", (bool)TerminalInfoInteger(TERMINAL_EMAIL_ENABLED));
    add_json_bool(static_fields, "terminal_ftp_enabled", (bool)TerminalInfoInteger(TERMINAL_FTP_ENABLED));
    add_json_bool(static_fields, "terminal_notifications_enabled", (bool)TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED));
    add_json_long(static_fields, "terminal_maxbars", TerminalInfoInteger(TERMINAL_MAXBARS));
    add_json_bool(static_fields, "terminal_mqid", (bool)TerminalInfoInteger(TERMINAL_MQID));
    add_json_long(static_fields, "terminal_codepage", TerminalInfoInteger(TERMINAL_CODEPAGE));
    add_json_long(static_fields, "terminal_cpu_cores", TerminalInfoInteger(TERMINAL_CPU_CORES));
    add_json_long(static_fields, "terminal_memory_physical", TerminalInfoInteger(TERMINAL_MEMORY_PHYSICAL));
    add_json_long(static_fields, "terminal_memory_total", TerminalInfoInteger(TERMINAL_MEMORY_TOTAL));
    add_json_long(static_fields, "terminal_memory_available", TerminalInfoInteger(TERMINAL_MEMORY_AVAILABLE));
    add_json_long(static_fields, "terminal_memory_used", TerminalInfoInteger(TERMINAL_MEMORY_USED));
    add_json_bool(static_fields, "terminal_x64", (bool)TerminalInfoInteger(TERMINAL_X64));
    add_json_string(static_fields, "terminal_path", TerminalInfoString(TERMINAL_PATH));
    add_json_string(static_fields, "terminal_data_path", TerminalInfoString(TERMINAL_DATA_PATH));
    add_json_string(static_fields, "terminal_commondata_path", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
    add_json_string(static_fields, "terminal_name", TerminalInfoString(TERMINAL_NAME));
    add_json_string(static_fields, "terminal_language", TerminalInfoString(TERMINAL_LANGUAGE));

    // MQL Program Information
    add_json_string(static_fields, "mql_program_name", MQLInfoString(MQL_PROGRAM_NAME));
    add_json_int(static_fields, "mql_program_type", (int)MQLInfoInteger(MQL_PROGRAM_TYPE));
    add_json_string(static_fields, "mql_program_path", MQLInfoString(MQL_PROGRAM_PATH));
    add_json_int(static_fields, "mql_trade_allowed", (int)MQLInfoInteger(MQL_TRADE_ALLOWED));
    add_json_int(static_fields, "mql_optimization", (int)MQLInfoInteger(MQL_OPTIMIZATION));
    add_json_int(static_fields, "expert_magic", (int)expert_magic_number);

    return static_fields;
}

//+------------------------------------------------------------------+
//| Enum conversion helpers                                           |
//+------------------------------------------------------------------+
string CDataCollectorService::get_account_trade_mode_string(int mode)
{
    switch(mode)
    {
        case ACCOUNT_TRADE_MODE_REAL:    return "REAL";
        case ACCOUNT_TRADE_MODE_DEMO:    return "DEMO";
        case ACCOUNT_TRADE_MODE_CONTEST: return "CONTEST";
        default: return "DEMO";
    }
}

string CDataCollectorService::get_account_margin_so_mode_string(int mode)
{
    switch(mode)
    {
        case ACCOUNT_STOPOUT_MODE_PERCENT: return "PERCENT";
        case ACCOUNT_STOPOUT_MODE_MONEY:   return "MONEY";
        default: return "PERCENT";
    }
}

string CDataCollectorService::get_account_margin_mode_string(int mode)
{
    switch(mode)
    {
        case ACCOUNT_MARGIN_MODE_RETAIL_NETTING: return "NETTING";
        case ACCOUNT_MARGIN_MODE_RETAIL_HEDGING: return "HEDGING";
        case ACCOUNT_MARGIN_MODE_EXCHANGE:       return "EXCHANGE";
        default: return "NETTING";
    }
}

//+------------------------------------------------------------------+
//| Get session symbols                                               |
//+------------------------------------------------------------------+
CArrayObj* CDataCollectorService::get_session_symbols()
{
    CArrayObj* symbols_list = new CArrayObj();
    if(symbols_list == NULL) return NULL;

    // STRICT REQUIREMENT: Only collect symbols from the "Market Watch" (watchlist)
    // We use SymbolsTotal(true) and SymbolName(i, true) to ensure this.
    // Do NOT change 'true' to 'false' as that would collect ALL available symbols (thousands),
    // causing massive payload size and timeout issues.
    int total_symbols = SymbolsTotal(true);
    Print("SDK Debug: Found ", total_symbols, " symbols in Market Watch (Watchlist).");
    for(int i = 0; i < total_symbols; i++)
    {
        if(i % 100 == 0) Print("SDK Debug: Processing watchlist symbol ", i, " / ", total_symbols);
        string symbol_name = SymbolName(i, true);
        CSessionSymbol* symbol = new CSessionSymbol(symbol_name);
        if(symbol != NULL)
        {
            symbol.populate_data();
            symbols_list.Add(symbol);
        }
    }
    return symbols_list;
}

//+------------------------------------------------------------------+
//| Check if account data is available (terminal connected)           |
//+------------------------------------------------------------------+
bool CDataCollectorService::is_account_data_available()
{
    // Check if terminal is connected to the trade server
    if(!TerminalInfoInteger(TERMINAL_CONNECTED))
    {
        return false;
    }
    
    // Check if account info is valid (login != 0 means we have account data)
    if(AccountInfoInteger(ACCOUNT_LOGIN) == 0)
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get dynamic data matching RobotDynamicData schema                 |
//+------------------------------------------------------------------+
CJAVal* CDataCollectorService::get_dynamic_data()
{
    CJAVal* dynamic_data = new CJAVal(JA_OBJECT);
    if(dynamic_data == NULL) return NULL;

    // Check if account data is available
    bool data_available = is_account_data_available();
    
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double current_margin = AccountInfoDouble(ACCOUNT_MARGIN);
    double current_margin_free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double current_margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

    // Debug: Log the raw values being read
    static datetime last_debug_log = 0;
    if(TimeLocal() - last_debug_log >= 60) // Log every 60 seconds
    {
        Print("SDK Debug: Dynamic data - Connected: ", data_available,
              ", Balance: ", current_balance,
              ", Equity: ", current_equity,
              ", Margin: ", current_margin,
              ", MarginFree: ", current_margin_free,
              ", MarginLevel: ", current_margin_level);
        last_debug_log = TimeLocal();
    }
    
    // If not connected and values are 0, try to wait or warn
    if(!data_available && current_balance == 0)
    {
        Print("SDK Warning: Terminal not connected or account data not available yet. Values may be 0.");
    }

    add_json_double(dynamic_data, "account_balance", NormalizeDouble(current_balance, 2));
    add_json_double(dynamic_data, "account_equity", NormalizeDouble(current_equity, 2));
    add_json_double(dynamic_data, "account_margin", NormalizeDouble(current_margin, 2));
    add_json_double(dynamic_data, "account_margin_free", NormalizeDouble(current_margin_free, 2));
    add_json_double(dynamic_data, "account_margin_level", NormalizeDouble(current_margin_level, 2));

    double balance_profit = 0.0;
    double equity_profit = 0.0;
    
    if(m_initialized)
    {
        balance_profit = current_balance - m_initial_balance;
        equity_profit = current_equity - m_initial_equity;
    }
    
    add_json_double(dynamic_data, "balance_profit", NormalizeDouble(balance_profit, 2));
    add_json_double(dynamic_data, "equity_profit", NormalizeDouble(equity_profit, 2));

    if(current_balance > m_peak_balance) m_peak_balance = current_balance;
    if(current_equity > m_peak_equity) m_peak_equity = current_equity;
    
    double balance_drawdown = 0.0;
    double equity_drawdown = 0.0;
    
    if(m_peak_balance > 0)
    {
        balance_drawdown = ((m_peak_balance - current_balance) / m_peak_balance) * 100.0;
        if(balance_drawdown < 0) balance_drawdown = 0.0;
    }
    
    if(m_peak_equity > 0)
    {
        equity_drawdown = ((m_peak_equity - current_equity) / m_peak_equity) * 100.0;
        if(equity_drawdown < 0) equity_drawdown = 0.0;
    }
    
    add_json_double(dynamic_data, "balance_drawdown", NormalizeDouble(balance_drawdown, 2));
    add_json_double(dynamic_data, "equity_drawdown", NormalizeDouble(equity_drawdown, 2));

    return dynamic_data;
}

//+------------------------------------------------------------------+
//| Private Helper Implementations                                   |
//+------------------------------------------------------------------+
void CDataCollectorService::add_json_string(CJAVal* json, string key, string value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_string(value);
    json.Add(key, val);
}

void CDataCollectorService::add_json_long(CJAVal* json, string key, long value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_long(value);
    json.Add(key, val);
}

void CDataCollectorService::add_json_int(CJAVal* json, string key, int value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_long((long)value);
    json.Add(key, val);
}

void CDataCollectorService::add_json_bool(CJAVal* json, string key, bool value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_bool(value);
    json.Add(key, val);
}

void CDataCollectorService::add_json_double(CJAVal* json, string key, double value)
{
    CJAVal* val = new CJAVal();
    if(val == NULL) return;
    val.set_double(value);
    json.Add(key, val);
}

#endif
//+------------------------------------------------------------------+

