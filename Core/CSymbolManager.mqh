//+------------------------------------------------------------------+
//|                                               CSymbolManager.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSYMBOL_MANAGER_MQH
#define CSYMBOL_MANAGER_MQH

#include <Object.mqh>
#include <Arrays/ArrayObj.mqh>
#include "../Models/CSessionSymbol.mqh"
#include "../Services/Json.mqh"
#include "../Utils/CSDK_Events.mqh"
#include "../Utils/CSDKLogger.mqh"

// Error codes matching API contract
#define SYMBOL_ERROR_NOT_FOUND       "SYMBOL_NOT_FOUND"
#define SYMBOL_ERROR_UNAVAILABLE     "SYMBOL_UNAVAILABLE"
#define SYMBOL_ERROR_TRADING_DISABLED "TRADING_DISABLED"

/**
 * @class CSymbolManager
 * @brief Manages the session's symbols, including status updates.
 *
 * ## API Contract Compliance
 * Results structure matches SymbolsChangeResults from session-global.yaml:
 * - status: enum [all_accepted, all_rejected, partially_accepted]
 * - results: array of SymbolChangeResultItem
 */
class CTMKR_SymbolManager : public CObject
{
private:
    CArrayObj* m_session_symbols;
    CTMKR_JAVal* m_pending_change_results;
    bool m_enabled;

public:
    CTMKR_SymbolManager();
    ~CTMKR_SymbolManager();
    
    void set_enabled(bool enabled);
    bool is_enabled() const;

    void set_initial_symbols(CArrayObj* symbols);
    void process_change_request(const CTMKR_JAVal &change_request);
    CTMKR_JAVal* get_pending_results();
    void clear_pending_results();
    
    int get_symbol_count() const;
    CTMKR_SessionSymbol* get_symbol(int tmkr_idx);
    CTMKR_SessionSymbol* find_symbol(string symbol_name);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_SymbolManager::CSymbolManager()
{
    m_session_symbols = new CArrayObj();
    m_pending_change_results = NULL;
    m_enabled = true;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_SymbolManager::~CTMKR_SymbolManager()
{
    if(CheckPointer(m_session_symbols) == POINTER_DYNAMIC)
    {
        m_session_symbols.FreeMode(true);
        delete m_session_symbols;
    }
    clear_pending_results();
}

//+------------------------------------------------------------------+
//| Set enabled state                                                 |
//+------------------------------------------------------------------+
void CTMKR_SymbolManager::set_enabled(bool enabled)
{
    m_enabled = enabled;
}

//+------------------------------------------------------------------+
//| Get enabled state                                                 |
//+------------------------------------------------------------------+
bool CTMKR_SymbolManager::is_enabled() const
{
    return m_enabled;
}

//+------------------------------------------------------------------+
//| Set initial symbols                                               |
//+------------------------------------------------------------------+
void CTMKR_SymbolManager::set_initial_symbols(CArrayObj* symbols)
{
    if(CheckPointer(symbols) != POINTER_INVALID)
    {
        // Delete the old array if it exists and is different from the new one
        if(CheckPointer(m_session_symbols) == POINTER_DYNAMIC && m_session_symbols != symbols)
        {
            m_session_symbols.FreeMode(true);
            delete m_session_symbols;
        }
        m_session_symbols = symbols;
    }
}

//+------------------------------------------------------------------+
//| Get symbol count                                                  |
//+------------------------------------------------------------------+
int CTMKR_SymbolManager::get_symbol_count() const
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return 0;
    return m_session_symbols.Total();
}

//+------------------------------------------------------------------+
//| Get symbol by index                                               |
//+------------------------------------------------------------------+
// Param renamed from `index` to `idx` — see notes in Services/Json.mqh.
CTMKR_SessionSymbol* CTMKR_SymbolManager::get_symbol(int tmkr_idx)
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return NULL;
    if(tmkr_idx < 0 || tmkr_idx >= m_session_symbols.Total()) return NULL;
    return m_session_symbols.At(tmkr_idx);
}

//+------------------------------------------------------------------+
//| Find symbol by name                                               |
//+------------------------------------------------------------------+
CTMKR_SessionSymbol* CTMKR_SymbolManager::find_symbol(string symbol_name)
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return NULL;
    
    for(int tmkr_i = 0; tmkr_i < m_session_symbols.Total(); tmkr_i++)
    {
        CTMKR_SessionSymbol* tmkr_symbol = m_session_symbols.At(tmkr_i);
        if(tmkr_symbol != NULL && tmkr_symbol.get_symbol_name() == symbol_name)
            return tmkr_symbol;
    }
    return NULL;
}

//+------------------------------------------------------------------+
//| Process symbol change request                                     |
//| Matches SymbolsChangeResults from API contract                    |
//| Expected input format:                                            |
//| {                                                                  |
//|   "id": "123",                                                     |
//|   "request": [{ "symbol": "EURUSD", "active_to_trade": true }, ...],|
//|   "created_at": "2026-01-17T00:00:00.000Z"                        |
//| }                                                                  |
//+------------------------------------------------------------------+
void CTMKR_SymbolManager::process_change_request(const CTMKR_JAVal &change_request)
{
    if(!m_enabled)
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Symbol change request received but feature is DISABLED. Ignoring.");
        return;
    }
    
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return;
    
    clear_pending_results();
    m_pending_change_results = new CTMKR_JAVal(TMKR_JA_OBJECT);
    if(m_pending_change_results == NULL) return;
    
    // Extract request_id from the change request wrapper
    CTMKR_JAVal* id_node = change_request["id"];
    if(CheckPointer(id_node) != POINTER_INVALID)
    {
        string request_id = id_node.get_string();
        CTMKR_JAVal* request_id_val = new CTMKR_JAVal();
        request_id_val.set_string(request_id);
        m_pending_change_results.Add("request_id", request_id_val);
        if(SDKShouldLogDebug()) Print("SDK Debug: Symbol change request ID: ", request_id);
    }
    else
    {
        if(SDKShouldLogWarning()) Print("SDK Warning: Symbol change request missing 'id' field");
    }
    
    CTMKR_JAVal* results_array = new CTMKR_JAVal(TMKR_JA_ARRAY);
    int accepted_count = 0;
    int rejected_count = 0;
    int total_count = 0;

    // Get the actual request array from the "request" field
    CTMKR_JAVal* request_array = change_request["request"];
    bool use_direct = false;
    
    if(CheckPointer(request_array) == POINTER_INVALID)
    {
        // Fallback: maybe the change_request itself is the array (old format)
        use_direct = true;
    }

    // Process request as array of SymbolChangeRequestItem
    // Expected format: [{ "symbol": "EURUSD", "active_to_trade": true }, ...]
    int count = use_direct ? change_request.count() : request_array.count();
    bool is_array = use_direct ? (change_request.get_type() == TMKR_JA_ARRAY) : (request_array.get_type() == TMKR_JA_ARRAY);
    
    if(is_array)
    {
        for(int tmkr_i = 0; tmkr_i < count; tmkr_i++)
        {
            CTMKR_JAVal* tmkr_item = use_direct ? change_request[tmkr_i] : request_array[tmkr_i];
            if(CheckPointer(tmkr_item) == POINTER_INVALID) continue;
            
            CTMKR_JAVal* symbol_node = tmkr_item["symbol"];
            CTMKR_JAVal* active_node = tmkr_item["active_to_trade"];
            
            if(CheckPointer(symbol_node) == POINTER_INVALID) continue;
            
            string symbol_name = symbol_node.get_string();
            bool requested_active = (CheckPointer(active_node) != POINTER_INVALID) 
                                    ? active_node.get_bool() : true;
            
            total_count++;
            
            CTMKR_JAVal* result_item = new CTMKR_JAVal(TMKR_JA_OBJECT);
            
            // symbol (required)
            CTMKR_JAVal* sym_val = new CTMKR_JAVal();
            sym_val.set_string(symbol_name);
            result_item.Add("symbol", sym_val);
            
            // requested_active_to_trade (required)
            CTMKR_JAVal* rat_val = new CTMKR_JAVal();
            rat_val.set_bool(requested_active);
            result_item.Add("requested_active_to_trade", rat_val);
            
            CTMKR_SessionSymbol* tmkr_symbol = find_symbol(symbol_name);
            
            if(tmkr_symbol != NULL)
            {
                bool select_result = SymbolSelect(symbol_name, requested_active);
                
                if(select_result)
                {
                    tmkr_symbol.set_active_to_trade(requested_active);
                    
                    // accepted: true
                    CTMKR_JAVal* acc_val = new CTMKR_JAVal();
                    acc_val.set_bool(true);
                    result_item.Add("accepted", acc_val);
                    
                    // applied_active_to_trade
                    CTMKR_JAVal* aat_val = new CTMKR_JAVal();
                    aat_val.set_bool(requested_active);
                    result_item.Add("applied_active_to_trade", aat_val);
                    
                    accepted_count++;
                    if(SDKShouldLogInfo()) Print("SDK Info: Symbol '", symbol_name, "' active_to_trade set to ", requested_active);

                    STMKR_SymbolChangeEvent event_data;
                    event_data.symbol = symbol_name;
                    event_data.active_to_trade = requested_active;
                    Fire_Symbol_Change_Event(0, event_data);
                }
                else
                {
                    // accepted: false
                    CTMKR_JAVal* acc_val = new CTMKR_JAVal();
                    acc_val.set_bool(false);
                    result_item.Add("accepted", acc_val);
                    
                    // error_code
                    CTMKR_JAVal* ec_val = new CTMKR_JAVal();
                    ec_val.set_string(SYMBOL_ERROR_UNAVAILABLE);
                    result_item.Add("error_code", ec_val);
                    
                    // error_message
                    CTMKR_JAVal* em_val = new CTMKR_JAVal();
                    em_val.set_string("Terminal rejected symbol selection");
                    result_item.Add("error_message", em_val);
                    
                    rejected_count++;
                    if(SDKShouldLogWarning()) Print("SDK Warning: Symbol '", symbol_name, "' change rejected by terminal.");
                }
            }
            else
            {
                // accepted: false
                CTMKR_JAVal* acc_val = new CTMKR_JAVal();
                acc_val.set_bool(false);
                result_item.Add("accepted", acc_val);
                
                // error_code
                CTMKR_JAVal* ec_val = new CTMKR_JAVal();
                ec_val.set_string(SYMBOL_ERROR_NOT_FOUND);
                result_item.Add("error_code", ec_val);
                
                // error_message
                CTMKR_JAVal* em_val = new CTMKR_JAVal();
                em_val.set_string("Symbol not found in session");
                result_item.Add("error_message", em_val);
                
                rejected_count++;
                if(SDKShouldLogWarning()) Print("SDK Warning: Symbol '", symbol_name, "' not found in session symbols.");
            }
            
            results_array.Add(result_item);
        }
    }
    
    // Determine status
    CTMKR_JAVal* status_val = new CTMKR_JAVal();
    if(total_count == 0 || rejected_count == 0)
        status_val.set_string("all_accepted");
    else if(accepted_count == 0)
        status_val.set_string("all_rejected");
    else
        status_val.set_string("partially_accepted");
    
    m_pending_change_results.Add("status", status_val);
    m_pending_change_results.Add("results", results_array);
}

//+------------------------------------------------------------------+
//| Get pending results                                               |
//+------------------------------------------------------------------+
CTMKR_JAVal* CTMKR_SymbolManager::get_pending_results()
{
    if(!m_enabled) return NULL;
    return m_pending_change_results;
}

//+------------------------------------------------------------------+
//| Clear pending results                                             |
//+------------------------------------------------------------------+
void CTMKR_SymbolManager::clear_pending_results()
{
    if(CheckPointer(m_pending_change_results) == POINTER_DYNAMIC)
    {
        delete m_pending_change_results;
        m_pending_change_results = NULL;
    }
}

#endif
//+------------------------------------------------------------------+

