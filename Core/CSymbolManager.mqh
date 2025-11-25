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
class CSymbolManager : public CObject
{
private:
    CArrayObj* m_session_symbols;
    CJAVal* m_pending_change_results;
    bool m_enabled;

public:
    CSymbolManager();
    ~CSymbolManager();
    
    void set_enabled(bool enabled);
    bool is_enabled() const;

    void set_initial_symbols(CArrayObj* symbols);
    void process_change_request(const CJAVal &change_request);
    CJAVal* get_pending_results();
    void clear_pending_results();
    
    int get_symbol_count() const;
    CSessionSymbol* get_symbol(int index);
    CSessionSymbol* find_symbol(string symbol_name);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSymbolManager::CSymbolManager()
{
    m_session_symbols = new CArrayObj();
    m_pending_change_results = NULL;
    m_enabled = true;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSymbolManager::~CSymbolManager()
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
void CSymbolManager::set_enabled(bool enabled)
{
    m_enabled = enabled;
}

//+------------------------------------------------------------------+
//| Get enabled state                                                 |
//+------------------------------------------------------------------+
bool CSymbolManager::is_enabled() const
{
    return m_enabled;
}

//+------------------------------------------------------------------+
//| Set initial symbols                                               |
//+------------------------------------------------------------------+
void CSymbolManager::set_initial_symbols(CArrayObj* symbols)
{
    if(CheckPointer(symbols) != POINTER_INVALID)
        m_session_symbols = symbols;
}

//+------------------------------------------------------------------+
//| Get symbol count                                                  |
//+------------------------------------------------------------------+
int CSymbolManager::get_symbol_count() const
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return 0;
    return m_session_symbols.Total();
}

//+------------------------------------------------------------------+
//| Get symbol by index                                               |
//+------------------------------------------------------------------+
CSessionSymbol* CSymbolManager::get_symbol(int index)
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return NULL;
    if(index < 0 || index >= m_session_symbols.Total()) return NULL;
    return m_session_symbols.At(index);
}

//+------------------------------------------------------------------+
//| Find symbol by name                                               |
//+------------------------------------------------------------------+
CSessionSymbol* CSymbolManager::find_symbol(string symbol_name)
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return NULL;
    
    for(int i = 0; i < m_session_symbols.Total(); i++)
    {
        CSessionSymbol* symbol = m_session_symbols.At(i);
        if(symbol != NULL && symbol.get_symbol_name() == symbol_name)
            return symbol;
    }
    return NULL;
}

//+------------------------------------------------------------------+
//| Process symbol change request                                     |
//| Matches SymbolsChangeResults from API contract                    |
//+------------------------------------------------------------------+
void CSymbolManager::process_change_request(const CJAVal &change_request)
{
    if(!m_enabled)
    {
        Print("SDK Info: Symbol change request received but feature is DISABLED. Ignoring.");
        return;
    }
    
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return;
    
    clear_pending_results();
    m_pending_change_results = new CJAVal(JA_OBJECT);
    if(m_pending_change_results == NULL) return;
    
    CJAVal* results_array = new CJAVal(JA_ARRAY);
    int accepted_count = 0;
    int rejected_count = 0;
    int total_count = 0;

    // Process change_request as array of SymbolChangeRequestItem
    // Expected format: [{ "symbol": "EURUSD", "active_to_trade": true }, ...]
    if(change_request.get_type() == JA_ARRAY)
    {
        int count = change_request.count();
        for(int i = 0; i < count; i++)
        {
            CJAVal* item = change_request[i];
            if(CheckPointer(item) == POINTER_INVALID) continue;
            
            CJAVal* symbol_node = item["symbol"];
            CJAVal* active_node = item["active_to_trade"];
            
            if(CheckPointer(symbol_node) == POINTER_INVALID) continue;
            
            string symbol_name = symbol_node.get_string();
            bool requested_active = (CheckPointer(active_node) != POINTER_INVALID) 
                                    ? active_node.get_bool() : true;
            
            total_count++;
            
            CJAVal* result_item = new CJAVal(JA_OBJECT);
            
            // symbol (required)
            CJAVal* sym_val = new CJAVal();
            sym_val.set_string(symbol_name);
            result_item.Add("symbol", sym_val);
            
            // requested_active_to_trade (required)
            CJAVal* rat_val = new CJAVal();
            rat_val.set_bool(requested_active);
            result_item.Add("requested_active_to_trade", rat_val);
            
            CSessionSymbol* symbol = find_symbol(symbol_name);
            
            if(symbol != NULL)
            {
                bool select_result = SymbolSelect(symbol_name, requested_active);
                
                if(select_result)
                {
                    symbol.set_active_to_trade(requested_active);
                    
                    // accepted: true
                    CJAVal* acc_val = new CJAVal();
                    acc_val.set_bool(true);
                    result_item.Add("accepted", acc_val);
                    
                    // applied_active_to_trade
                    CJAVal* aat_val = new CJAVal();
                    aat_val.set_bool(requested_active);
                    result_item.Add("applied_active_to_trade", aat_val);
                    
                    accepted_count++;
                    Print("SDK Info: Symbol '", symbol_name, "' active_to_trade set to ", requested_active);

                    SSymbol_Change_Event event_data;
                    event_data.symbol = symbol_name;
                    event_data.active_to_trade = requested_active;
                    Fire_Symbol_Change_Event(0, event_data);
                }
                else
                {
                    // accepted: false
                    CJAVal* acc_val = new CJAVal();
                    acc_val.set_bool(false);
                    result_item.Add("accepted", acc_val);
                    
                    // error_code
                    CJAVal* ec_val = new CJAVal();
                    ec_val.set_string(SYMBOL_ERROR_UNAVAILABLE);
                    result_item.Add("error_code", ec_val);
                    
                    // error_message
                    CJAVal* em_val = new CJAVal();
                    em_val.set_string("Terminal rejected symbol selection");
                    result_item.Add("error_message", em_val);
                    
                    rejected_count++;
                    Print("SDK Warning: Symbol '", symbol_name, "' change rejected by terminal.");
                }
            }
            else
            {
                // accepted: false
                CJAVal* acc_val = new CJAVal();
                acc_val.set_bool(false);
                result_item.Add("accepted", acc_val);
                
                // error_code
                CJAVal* ec_val = new CJAVal();
                ec_val.set_string(SYMBOL_ERROR_NOT_FOUND);
                result_item.Add("error_code", ec_val);
                
                // error_message
                CJAVal* em_val = new CJAVal();
                em_val.set_string("Symbol not found in session");
                result_item.Add("error_message", em_val);
                
                rejected_count++;
                Print("SDK Warning: Symbol '", symbol_name, "' not found in session symbols.");
            }
            
            results_array.Add(result_item);
        }
    }
    
    // Determine status
    CJAVal* status_val = new CJAVal();
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
CJAVal* CSymbolManager::get_pending_results()
{
    if(!m_enabled) return NULL;
    return m_pending_change_results;
}

//+------------------------------------------------------------------+
//| Clear pending results                                             |
//+------------------------------------------------------------------+
void CSymbolManager::clear_pending_results()
{
    if(CheckPointer(m_pending_change_results) == POINTER_DYNAMIC)
    {
        delete m_pending_change_results;
        m_pending_change_results = NULL;
    }
}

#endif
//+------------------------------------------------------------------+

