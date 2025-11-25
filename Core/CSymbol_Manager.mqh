//+------------------------------------------------------------------+
//|                                           CSymbol_Manager.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSYMBOL_MANAGER_MQH
#define CSYMBOL_MANAGER_MQH

#include <Object.mqh>
#include <Arrays/ArrayObj.mqh>
#include "../Models/Csession_Symbol.mqh"
#include "../Services/Json.mqh"
#include "../Utils/CSDK_Events.mqh"

/**
 * @class CSymbol_Manager
 * @brief Manages the session's symbols, including status updates.
 *
 * ## Feature Toggle Support
 * This manager can be enabled or disabled via set_enabled(). When disabled:
 * - process_change_request() is a no-op
 * - get_pending_results() always returns NULL
 * - Initial symbol setup still works (required for session start)
 *
 * This follows the Open/Closed Principle - the behavior is modified without
 * changing the existing method interfaces.
 */
class CSymbol_Manager : public CObject
{
private:
    CArrayObj* m_session_symbols; // List of Csession_Symbol
    CJAVal* m_pending_change_results;
    bool m_enabled;               // Feature toggle

public:
    CSymbol_Manager();
    ~CSymbol_Manager();
    
    // Feature toggle
    void set_enabled(bool enabled) { m_enabled = enabled; }
    bool is_enabled() const { return m_enabled; }

    void set_initial_symbols(CArrayObj* symbols);
    void process_change_request(const CJAVal &change_request);
    CJAVal* get_pending_results();
    void clear_pending_results();
    
    // Symbol accessors
    int get_symbol_count() const;
    Csession_Symbol* get_symbol(int index);
    Csession_Symbol* find_symbol(string symbol_name);
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CSymbol_Manager::CSymbol_Manager()
{
    m_session_symbols = new CArrayObj();
    m_pending_change_results = NULL;
    m_enabled = true; // Default: enabled
}

CSymbol_Manager::~CSymbol_Manager()
{
    if(CheckPointer(m_session_symbols) == POINTER_DYNAMIC)
    {
        m_session_symbols.FreeMode(true);
        delete m_session_symbols;
    }
    clear_pending_results();
}

/**
 * @brief Sets the initial list of symbols for this session.
 * @param symbols The array of Csession_Symbol objects.
 * @note This always works regardless of enabled state (required for session start).
 */
void CSymbol_Manager::set_initial_symbols(CArrayObj* symbols)
{
    if(CheckPointer(symbols) != POINTER_INVALID)
        m_session_symbols = symbols;
}

/**
 * @brief Gets the number of symbols in this session.
 * @return The symbol count.
 */
int CSymbol_Manager::get_symbol_count() const
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return 0;
    return m_session_symbols.Total();
}

/**
 * @brief Gets a symbol by index.
 * @param index The zero-based index of the symbol.
 * @return The Csession_Symbol pointer, or NULL if invalid index.
 */
Csession_Symbol* CSymbol_Manager::get_symbol(int index)
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return NULL;
    if(index < 0 || index >= m_session_symbols.Total()) return NULL;
    return m_session_symbols.At(index);
}

/**
 * @brief Finds a symbol by name.
 * @param symbol_name The trading symbol name (e.g., "EURUSD").
 * @return The Csession_Symbol pointer, or NULL if not found.
 */
Csession_Symbol* CSymbol_Manager::find_symbol(string symbol_name)
{
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return NULL;
    
    for(int i = 0; i < m_session_symbols.Total(); i++)
    {
        Csession_Symbol* symbol = m_session_symbols.At(i);
        if(symbol != NULL && symbol.get_symbol_name() == symbol_name)
            return symbol;
    }
    return NULL;
}

/**
 * @brief Processes a symbol change request from a heartbeat response.
 * @param change_request The JSON object with requested symbol status changes.
 * @note When disabled (set_enabled(false)), this method is a no-op.
 */
void CSymbol_Manager::process_change_request(const CJAVal &change_request)
{
    // Early exit if disabled
    if(!m_enabled)
    {
        Print("SDK Info: Symbol change request received but feature is DISABLED. Ignoring.");
        return;
    }
    
    if(CheckPointer(m_session_symbols) == POINTER_INVALID) return;
    
    clear_pending_results();
    m_pending_change_results = new CJAVal(JA_OBJECT);
    if(m_pending_change_results == NULL) return;
    
    CJAVal* accepted_changes = new CJAVal(JA_ARRAY);
    CJAVal* rejected_changes = new CJAVal(JA_ARRAY);

    // Process the "symbols" array from the change request
    // Expected format: { "symbols": [{ "symbol": "EURUSD", "active_to_trade": true }, ...] }
    CJAVal* symbols_array = change_request["symbols"];
    
    if(CheckPointer(symbols_array) != POINTER_INVALID && symbols_array.get_type() == JA_ARRAY)
    {
        int count = symbols_array.count();
        for(int i = 0; i < count; i++)
        {
            CJAVal* change_item = symbols_array[i];
            if(CheckPointer(change_item) == POINTER_INVALID) continue;
            
            // Get symbol name and new status
            CJAVal* symbol_node = change_item["symbol"];
            CJAVal* status_node = change_item["active_to_trade"];
            
            if(CheckPointer(symbol_node) == POINTER_INVALID) continue;
            
            string symbol_name = symbol_node.get_string();
            bool new_status = (CheckPointer(status_node) != POINTER_INVALID) 
                              ? status_node.get_bool() : true;
            
            // Find the symbol in our list
            Csession_Symbol* symbol = find_symbol(symbol_name);
            
            if(symbol != NULL)
            {
                // Update terminal's market watch
                bool select_result = SymbolSelect(symbol_name, new_status);
                
                if(select_result)
                {
                    // Update our internal state
                    symbol.set_active_to_trade(new_status);
                    
                    // Add to accepted results
                    CJAVal* accepted = new CJAVal(JA_OBJECT);
                    CJAVal* sym_val = new CJAVal(); sym_val.set_string(symbol_name);
                    CJAVal* act_val = new CJAVal(); act_val.set_bool(new_status);
                    accepted.Add("symbol", sym_val);
                    accepted.Add("active_to_trade", act_val);
                    accepted_changes.Add(accepted);
                    
                    Print("SDK Info: Symbol '", symbol_name, "' active_to_trade set to ", new_status);

                    // Fire symbol change event
                    SSymbol_Change_Event event_data;
                    event_data.symbol = symbol_name;
                    event_data.active_to_trade = new_status;
                    Fire_Symbol_Change_Event(0, event_data);
                }
                else
                {
                    // Terminal rejected the symbol selection
                    CJAVal* rejected = new CJAVal(JA_OBJECT);
                    CJAVal* sym_val = new CJAVal(); sym_val.set_string(symbol_name);
                    CJAVal* reason_val = new CJAVal(); reason_val.set_string("Terminal rejected symbol selection");
                    rejected.Add("symbol", sym_val);
                    rejected.Add("reason", reason_val);
                    rejected_changes.Add(rejected);
                    
                    Print("SDK Warning: Symbol '", symbol_name, "' change rejected by terminal.");
                }
            }
            else
            {
                // Symbol not found in session
                CJAVal* rejected = new CJAVal(JA_OBJECT);
                CJAVal* sym_val = new CJAVal(); sym_val.set_string(symbol_name);
                CJAVal* reason_val = new CJAVal(); reason_val.set_string("Symbol not found in session");
                rejected.Add("symbol", sym_val);
                rejected.Add("reason", reason_val);
                rejected_changes.Add(rejected);
                
                Print("SDK Warning: Symbol '", symbol_name, "' not found in session symbols.");
            }
        }
    }
    
    // Store results for the next heartbeat
    if(accepted_changes.count() > 0)
        m_pending_change_results.Add("accepted_changes", accepted_changes);
    else
        delete accepted_changes;

    if(rejected_changes.count() > 0)
        m_pending_change_results.Add("rejected_changes", rejected_changes);
    else
        delete rejected_changes;
}

/**
 * @brief Gets the results of the last change request to be sent in the next heartbeat.
 * @return A CJAVal object with the results, or NULL if disabled or no pending results.
 */
CJAVal* CSymbol_Manager::get_pending_results()
{
    // Return NULL if disabled - don't include in heartbeat
    if(!m_enabled) return NULL;
    return m_pending_change_results;
}

/**
 * @brief Clears the pending results after they have been sent.
 */
void CSymbol_Manager::clear_pending_results()
{
    if(CheckPointer(m_pending_change_results) == POINTER_DYNAMIC)
    {
        delete m_pending_change_results;
        m_pending_change_results = NULL;
    }
}

#endif
//+------------------------------------------------------------------+
