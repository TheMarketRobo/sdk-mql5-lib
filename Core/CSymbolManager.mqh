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
#include "../Interfaces/ITMKR_SymbolGate.mqh"
#include "../Services/Json.mqh"
#include "../Utils/CSDK_Events.mqh"
#include "../Utils/CSDKLogger.mqh"

// Error codes matching API contract
#define SYMBOL_ERROR_NOT_FOUND       "SYMBOL_NOT_FOUND"
#define SYMBOL_ERROR_UNAVAILABLE     "SYMBOL_UNAVAILABLE"
#define SYMBOL_ERROR_TRADING_DISABLED "TRADING_DISABLED"
#define SYMBOL_ERROR_NOT_TRADED      "SYMBOL_NOT_TRADED"

/**
 * @class CSymbolManager
 * @brief Manages the session's symbols, including status updates.
 *
 * ## API Contract Compliance
 * Results structure matches SymbolsChangeResults from session-global.yaml:
 * - status: enum [all_accepted, all_rejected, partially_accepted]
 * - results: array of SymbolChangeResultItem
 *
 * ## active_to_trade is a TRADING GATE, not a Market Watch subscription (v1.3.0)
 * Until v1.3.0 this class implemented `active_to_trade` as SymbolSelect(symbol, active).
 * That is a category error with two proven production consequences:
 *   1. SymbolSelect(sym, false) REMOVES a symbol from Market Watch — a data subscription —
 *      which is not what "stop opening new trades on this symbol" means. MQL refuses it
 *      outright while the symbol is in use, and an EA's own chart symbol ALWAYS is. So a
 *      single-symbol robot could never be told to stop trading: the primary use case
 *      returned SYMBOL_UNAVAILABLE every time.
 *   2. The ACK was decided from SymbolSelect's return, and the only route to the strategy
 *      (Fire_Symbol_Change_Event → on_symbol_changed) is EventChartCustom(): asynchronous
 *      and void. It fired AFTER accepted_count++ and after the result JSON was built, so
 *      the strategy could not veto. The SDK ACKed accepted:true for changes the expert
 *      never applied.
 * The verdict now comes from ITMKR_SymbolGate (synchronous, like ITMKR_RobotConfig::
 * update_field), SymbolSelect survives only on the ACTIVATE path (where ensuring the
 * terminal has the symbol's data is genuinely useful), and the event fires afterwards for
 * observability only.
 */
class CTMKR_SymbolManager : public CObject
{
private:
    CArrayObj* m_session_symbols;
    CTMKR_JAVal* m_pending_change_results;
    bool m_enabled;
    ITMKR_SymbolGate* m_symbol_gate;   // NOT owned — the consumer owns its gate's lifetime

public:
    CTMKR_SymbolManager();
    ~CTMKR_SymbolManager();

    void set_enabled(bool enabled);
    bool is_enabled() const;

    void set_symbol_gate(ITMKR_SymbolGate* tmkr_gate);

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
CTMKR_SymbolManager::CTMKR_SymbolManager()
{
    m_session_symbols = new CArrayObj();
    m_pending_change_results = NULL;
    m_enabled = true;
    m_symbol_gate = NULL;
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
//| Set the strategy's symbol gate (optional)                         |
//|                                                                   |
//| NOT owned: the consumer constructs the gate and outlives the SDK  |
//| call into it. A NULL gate (the default) accepts every change,     |
//| which is the v1.2.x behaviour minus the SymbolSelect miscarriage. |
//+------------------------------------------------------------------+
void CTMKR_SymbolManager::set_symbol_gate(ITMKR_SymbolGate* tmkr_gate)
{
    m_symbol_gate = tmkr_gate;
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
                // ── 1. Ask the strategy FIRST. Its verdict — not the terminal's Market
                //       Watch state — decides the ACK. This is the whole point of v1.3.0:
                //       `accepted` means "accepted AND APPLIED by the robot" per the API
                //       contract, and only the strategy knows whether it applied anything.
                bool tmkr_strategy_accepts = true;
                if(CheckPointer(m_symbol_gate) != POINTER_INVALID)
                    tmkr_strategy_accepts = m_symbol_gate.can_apply_symbol_change(symbol_name, requested_active);

                // ── 2. On ACTIVATE only, make sure the terminal actually carries the
                //       symbol's data. NEVER SymbolSelect(sym, false) to deactivate: that
                //       drops a Market Watch subscription (not a trading gate) and MQL
                //       refuses it while the symbol is in use — the chart symbol always is.
                bool tmkr_data_available = true;
                if(tmkr_strategy_accepts && requested_active)
                    tmkr_data_available = SymbolSelect(symbol_name, true);

                if(tmkr_strategy_accepts && tmkr_data_available)
                {
                    tmkr_symbol.set_active_to_trade(requested_active);

                    // accepted: true
                    CTMKR_JAVal* acc_val = new CTMKR_JAVal();
                    acc_val.set_bool(true);
                    result_item.Add("accepted", acc_val);

                    // applied_active_to_trade — the value the strategy actually applied
                    CTMKR_JAVal* aat_val = new CTMKR_JAVal();
                    aat_val.set_bool(requested_active);
                    result_item.Add("applied_active_to_trade", aat_val);

                    accepted_count++;
                    if(SDKShouldLogInfo()) Print("SDK Info: Symbol '", symbol_name, "' active_to_trade set to ", requested_active);

                    // ── 3. Observability only. The strategy has already had its say, so
                    //       this event can no longer influence the verdict — it just tells
                    //       the vendor hook what landed. Fired only on a real change.
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

                    // applied_active_to_trade — report the UNCHANGED value, so the platform
                    // can see that nothing moved rather than inferring it from `accepted`.
                    CTMKR_JAVal* aat_val = new CTMKR_JAVal();
                    aat_val.set_bool(tmkr_symbol.is_active_to_trade());
                    result_item.Add("applied_active_to_trade", aat_val);

                    // error_code / error_message — distinguish "the robot won't" from
                    // "the terminal can't"; they need different fixes from the customer.
                    CTMKR_JAVal* ec_val = new CTMKR_JAVal();
                    CTMKR_JAVal* em_val = new CTMKR_JAVal();
                    if(!tmkr_strategy_accepts)
                    {
                        ec_val.set_string(SYMBOL_ERROR_NOT_TRADED);
                        em_val.set_string("Symbol is not in this robot's trading set");
                        if(SDKShouldLogWarning()) Print("SDK Warning: Symbol '", symbol_name, "' change refused by the strategy (not in its trading set).");
                    }
                    else
                    {
                        ec_val.set_string(SYMBOL_ERROR_UNAVAILABLE);
                        em_val.set_string("Terminal rejected symbol selection");
                        if(SDKShouldLogWarning()) Print("SDK Warning: Symbol '", symbol_name, "' change rejected by terminal.");
                    }
                    result_item.Add("error_code", ec_val);
                    result_item.Add("error_message", em_val);

                    rejected_count++;
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

