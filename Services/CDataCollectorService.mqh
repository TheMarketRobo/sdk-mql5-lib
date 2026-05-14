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
#include "../Utils/CSDKLogger.mqh"
#include "../TMR_Platform.mqh"

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
class CTMKR_DataCollectorService : public CObject
{
private:
    double m_initial_balance;
    double m_initial_equity;
    double m_peak_balance;
    double m_peak_equity;
    bool   m_initialized;

    void add_json_string(CTMKR_JAVal* json, string tmkr_key, string tmkr_value);
    void add_json_long(CTMKR_JAVal* json, string tmkr_key, long tmkr_value);
    void add_json_int(CTMKR_JAVal* json, string tmkr_key, int tmkr_value);
    void add_json_bool(CTMKR_JAVal* json, string tmkr_key, bool tmkr_value);
    void add_json_double(CTMKR_JAVal* json, string tmkr_key, double tmkr_value);
    
    string get_account_trade_mode_string(int tmkr_mode);
    string get_account_margin_so_mode_string(int tmkr_mode);
    string get_account_margin_mode_string(int tmkr_mode);

public:
    CTMKR_DataCollectorService();
    ~CTMKR_DataCollectorService();

    void initialize(double initial_balance, double initial_equity);
    bool is_account_data_available();
    bool wait_for_account_data(int timeout_seconds = 10);
    
    CTMKR_JAVal* get_static_fields(long expert_magic_number = 0);
    CArrayObj* get_session_symbols();
    CTMKR_JAVal* get_dynamic_data();
    
    double get_initial_balance() const;
    double get_initial_equity() const;
    double get_current_balance() const;
    double get_current_equity() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_DataCollectorService::CDataCollectorService()
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
CTMKR_DataCollectorService::~CTMKR_DataCollectorService() {}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
double CTMKR_DataCollectorService::get_initial_balance() const { return m_initial_balance; }
double CTMKR_DataCollectorService::get_initial_equity() const { return m_initial_equity; }
double CTMKR_DataCollectorService::get_current_balance() const { return AccountInfoDouble(ACCOUNT_BALANCE); }
double CTMKR_DataCollectorService::get_current_equity() const { return AccountInfoDouble(ACCOUNT_EQUITY); }

//+------------------------------------------------------------------+
//| Wait for account data to be available (with timeout)              |
//| This is useful when starting during OnInit                        |
//+------------------------------------------------------------------+
bool CTMKR_DataCollectorService::wait_for_account_data(int timeout_seconds)
{
    if(SDKShouldLogInfo()) Print("SDK Info: Waiting for account data to be available...");
    
    datetime start_time = TimeLocal();
    int wait_count = 0;
    
    while(!is_account_data_available())
    {
        if(TimeLocal() - start_time >= timeout_seconds)
        {
            if(SDKShouldLogWarning()) Print("SDK Warning: Timeout waiting for account data after ", timeout_seconds, " seconds");
            return false;
        }
        
        // Note: Sleep() is a no-op in custom indicator context (both MQL4/MQL5).
        // In that case this becomes a busy-wait, but TimeLocal() timeout ensures termination.
        Sleep(100);
        wait_count++;
        
        if(wait_count % 10 == 0) // Every second
        {
            if(SDKShouldLogDebug()) Print("SDK Debug: Still waiting for account data... (", wait_count / 10, "s)");
        }
    }
    
    // Account data is now available
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(SDKShouldLogInfo()) Print("SDK Info: Account data available. Balance: ", balance, ", Equity: ", equity);
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize with starting values                                   |
//+------------------------------------------------------------------+
void CTMKR_DataCollectorService::initialize(double initial_balance, double initial_equity)
{
    m_initial_balance = initial_balance;
    m_initial_equity = initial_equity;
    m_peak_balance = initial_balance;
    m_peak_equity = initial_equity;
    m_initialized = true;
}

//+------------------------------------------------------------------+
//| Get static fields matching static_data/v1.json                    |
//| expert_magic_number: pass the EA magic number for robots,         |
//|                      or 0 for indicators (no order tracking).     |
//+------------------------------------------------------------------+
CTMKR_JAVal* CTMKR_DataCollectorService::get_static_fields(long expert_magic_number)
{
    CTMKR_JAVal* static_fields = new CTMKR_JAVal(TMKR_JA_OBJECT);
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
    if(TMR_IsAccountPropertyAvailable(ACCOUNT_MARGIN_MODE))
        add_json_string(static_fields, "account_margin_mode",
                        get_account_margin_mode_string((int)AccountInfoInteger(ACCOUNT_MARGIN_MODE)));
    if(TMR_IsAccountPropertyAvailable(ACCOUNT_CURRENCY_DIGITS))
        add_json_long(static_fields, "account_currency_digits", AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS));
    if(TMR_IsAccountPropertyAvailable(ACCOUNT_FIFO_CLOSE))
        add_json_bool(static_fields, "account_fifo_close", (bool)AccountInfoInteger(ACCOUNT_FIFO_CLOSE));
    if(TMR_IsAccountPropertyAvailable(ACCOUNT_HEDGE_ALLOWED))
        add_json_bool(static_fields, "account_hedge_allowed", (bool)AccountInfoInteger(ACCOUNT_HEDGE_ALLOWED));
    add_json_string(static_fields, "account_name", AccountInfoString(ACCOUNT_NAME));
    add_json_string(static_fields, "account_server", AccountInfoString(ACCOUNT_SERVER));
    add_json_string(static_fields, "account_currency", AccountInfoString(ACCOUNT_CURRENCY));
    add_json_string(static_fields, "account_company", AccountInfoString(ACCOUNT_COMPANY));

    // Terminal Information (all properties exist in both MQL4 and MQL5 except TERMINAL_X64)
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
    if(TMR_IsTerminalPropertyAvailable(TERMINAL_X64))
        add_json_bool(static_fields, "terminal_x64", (bool)TerminalInfoInteger(TERMINAL_X64));
    add_json_string(static_fields, "terminal_path", TerminalInfoString(TERMINAL_PATH));
    add_json_string(static_fields, "terminal_data_path", TerminalInfoString(TERMINAL_DATA_PATH));
    add_json_string(static_fields, "terminal_commondata_path", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
    add_json_string(static_fields, "terminal_name", TerminalInfoString(TERMINAL_NAME));
    add_json_string(static_fields, "terminal_language", TerminalInfoString(TERMINAL_LANGUAGE));

    // Platform identifier (mt4 or mt5)
    add_json_string(static_fields, "platform", TMR_PLATFORM);

    // MQL Program Information
    add_json_string(static_fields, "mql_program_name", TMR_MQLInfoString(MQL_PROGRAM_NAME));
    add_json_int(static_fields, "mql_program_type", TMR_MQLInfoInteger(MQL_PROGRAM_TYPE));
    add_json_string(static_fields, "mql_program_path", TMR_MQLInfoString(MQL_PROGRAM_PATH));
    add_json_int(static_fields, "mql_trade_allowed", TMR_MQLInfoInteger(MQL_TRADE_ALLOWED));
    add_json_int(static_fields, "mql_optimization", TMR_MQLInfoInteger(MQL_OPTIMIZATION));
    add_json_int(static_fields, "expert_magic", (int)expert_magic_number);

    return static_fields;
}

//+------------------------------------------------------------------+
//| Enum conversion helpers                                           |
//+------------------------------------------------------------------+
string CTMKR_DataCollectorService::get_account_trade_mode_string(int tmkr_mode)
{
    switch(tmkr_mode)
    {
        case ACCOUNT_TRADE_MODE_REAL:    return "REAL";
        case ACCOUNT_TRADE_MODE_DEMO:    return "DEMO";
        case ACCOUNT_TRADE_MODE_CONTEST: return "CONTEST";
        default: return "DEMO";
    }
}

string CTMKR_DataCollectorService::get_account_margin_so_mode_string(int tmkr_mode)
{
    switch(tmkr_mode)
    {
        case ACCOUNT_STOPOUT_MODE_PERCENT: return "PERCENT";
        case ACCOUNT_STOPOUT_MODE_MONEY:   return "MONEY";
        default: return "PERCENT";
    }
}

string CTMKR_DataCollectorService::get_account_margin_mode_string(int tmkr_mode)
{
    switch(tmkr_mode)
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
CArrayObj* CTMKR_DataCollectorService::get_session_symbols()
{
    CArrayObj* symbols_list = new CArrayObj();
    if(symbols_list == NULL) return NULL;

    // STRICT REQUIREMENT: Only collect symbols from the "Market Watch" (watchlist)
    // We use SymbolsTotal(true) and SymbolName(i, true) to ensure this.
    // Do NOT change 'true' to 'false' as that would collect ALL available symbols (thousands),
    // causing massive payload size and timeout issues.
    int total_symbols = SymbolsTotal(true);
    if(SDKShouldLogDebug()) Print("SDK Debug: Found ", total_symbols, " symbols in Market Watch (Watchlist).");
    for(int tmkr_i = 0; tmkr_i < total_symbols; tmkr_i++)
    {
        if(tmkr_i % 100 == 0 && SDKShouldLogDebug()) Print("SDK Debug: Processing watchlist symbol ", tmkr_i, " / ", total_symbols);
        string symbol_name = SymbolName(tmkr_i, true);
        CTMKR_SessionSymbol* tmkr_symbol = new CTMKR_SessionSymbol(symbol_name);
        if(tmkr_symbol != NULL)
        {
            tmkr_symbol.populate_data();
            symbols_list.Add(tmkr_symbol);
        }
    }
    return symbols_list;
}

//+------------------------------------------------------------------+
//| Check if account data is available (terminal connected)           |
//+------------------------------------------------------------------+
bool CTMKR_DataCollectorService::is_account_data_available()
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
CTMKR_JAVal* CTMKR_DataCollectorService::get_dynamic_data()
{
    CTMKR_JAVal* dynamic_data = new CTMKR_JAVal(TMKR_JA_OBJECT);
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
        if(SDKShouldLogDebug()) Print("SDK Debug: Dynamic data - Connected: ", data_available,
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
        if(SDKShouldLogWarning()) Print("SDK Warning: Terminal not connected or account data not available yet. Values may be 0.");
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
void CTMKR_DataCollectorService::add_json_string(CTMKR_JAVal* json, string tmkr_key, string tmkr_value)
{
    CTMKR_JAVal* tmkr_val = new CTMKR_JAVal();
    if(tmkr_val == NULL) return;
    tmkr_val.set_string(tmkr_value);
    json.Add(tmkr_key, tmkr_val);
}

void CTMKR_DataCollectorService::add_json_long(CTMKR_JAVal* json, string tmkr_key, long tmkr_value)
{
    CTMKR_JAVal* tmkr_val = new CTMKR_JAVal();
    if(tmkr_val == NULL) return;
    tmkr_val.set_long(tmkr_value);
    json.Add(tmkr_key, tmkr_val);
}

void CTMKR_DataCollectorService::add_json_int(CTMKR_JAVal* json, string tmkr_key, int tmkr_value)
{
    CTMKR_JAVal* tmkr_val = new CTMKR_JAVal();
    if(tmkr_val == NULL) return;
    tmkr_val.set_long((long)tmkr_value);
    json.Add(tmkr_key, tmkr_val);
}

void CTMKR_DataCollectorService::add_json_bool(CTMKR_JAVal* json, string tmkr_key, bool tmkr_value)
{
    CTMKR_JAVal* tmkr_val = new CTMKR_JAVal();
    if(tmkr_val == NULL) return;
    tmkr_val.set_bool(tmkr_value);
    json.Add(tmkr_key, tmkr_val);
}

void CTMKR_DataCollectorService::add_json_double(CTMKR_JAVal* json, string tmkr_key, double tmkr_value)
{
    CTMKR_JAVal* tmkr_val = new CTMKR_JAVal();
    if(tmkr_val == NULL) return;
    tmkr_val.set_double(tmkr_value);
    json.Add(tmkr_key, tmkr_val);
}

#endif
//+------------------------------------------------------------------+

