//+------------------------------------------------------------------+
//|                                           CSymbol_Manager.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSYMBOL_MANAGER_MQH
#define CSYMBOL_MANAGER_MQH

#include <Object.mqh>
#include <Arrays/ArrayObj.h>
#include "../Interfaces/Irobot_Callback.mqh"
#include "../Models/Csession_Symbol.mqh"
#include "../Services/Json.mqh"

/**
 * @class CSymbol_Manager
 * @brief Manages the session's symbols, including status updates.
 */
class CSymbol_Manager : public CObject
{
private:
    Irobot_Callback* m_robot_callback;
    CArrayObj* m_session_symbols; // List of Csession_Symbol
    CJAVal* m_pending_change_results;

public:
    CSymbol_Manager(Irobot_Callback* robot_callback);
    ~CSymbol_Manager();

    void set_initial_symbols(CArrayObj* symbols);
    void process_change_request(const CJAVal &change_request);
    CJAVal* get_pending_results();
    void clear_pending_results();
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CSymbol_Manager::CSymbol_Manager(Irobot_Callback* robot_callback)
{
    m_robot_callback = robot_callback;
    m_session_symbols = new CArrayObj();
    m_pending_change_results = NULL;
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

void CSymbol_Manager::set_initial_symbols(CArrayObj* symbols)
{
    if(CheckPointer(symbols) != POINTER_INVALID)
        m_session_symbols = symbols;
}

/**
 * @brief Processes a symbol change request from a heartbeat response.
 * @param change_request The JSON object with requested symbol status changes.
 */
void CSymbol_Manager::process_change_request(const CJAVal &change_request)
{
    if(CheckPointer(m_robot_callback) == POINTER_INVALID) return;
    
    // Conceptual implementation. A full JSON library would make iteration easier.
    // Example for a single symbol change:
    string symbol_to_change = "EURUSD";
    CJAVal* new_status_node = change_request["symbols"][symbol_to_change];

    if(CheckPointer(new_status_node) != POINTER_INVALID && new_status_node.get_type() == JA_BOOL)
    {
        bool new_status = new_status_node.get_bool();
        
        // Find the symbol in our list
        for(int i = 0; i < m_session_symbols.Total(); i++)
        {
            Csession_Symbol* symbol = m_session_symbols.At(i);
            if(symbol.get_symbol_name() == symbol_to_change)
            {
                // Update terminal's market watch
                SymbolSelect(symbol_to_change, new_status);
                
                // Update our internal state
                symbol.set_active_to_trade(new_status);

                // Notify the robot
                m_robot_callback.on_symbol_status_changed(symbol_to_change, new_status);
                
                // TODO: Add to pending results for next heartbeat
                break;
            }
        }
    }
}

CJAVal* CSymbol_Manager::get_pending_results()
{
    return m_pending_change_results;
}

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
