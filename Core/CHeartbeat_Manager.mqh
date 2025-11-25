//+------------------------------------------------------------------+
//|                                        CHeartbeat_Manager.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CHEARTBEAT_MANAGER_MQH
#define CHEARTBEAT_MANAGER_MQH

#include <Object.mqh>
#include "../Services/Json.mqh"

// Forward declaration to break circular dependency
class CSDK_Context;

/**
 * @class CHeartbeat_Manager
 * @brief Manages the periodic heartbeat communication with the server.
 *
 * ## Heartbeat Payload (matches RobotHeartbeatRequest)
 * - sequence: Monotonically increasing sequence number
 * - timestamp: ISO 8601 formatted timestamp in UTC
 * - dynamic_data: Real-time account data and performance metrics
 * - config_change_results: Results of configuration change requests (optional)
 * - symbols_change_results: Results of symbol change requests (optional)
 */
class CHeartbeat_Manager : public CObject
{
private:
    ulong m_session_id;
    uint m_sequence;
    uint m_heartbeat_interval_seconds;
    uint m_max_heartbeat_interval;
    datetime m_last_heartbeat_time;
    
    // SDK Context
    CSDK_Context* m_context;
    
    // Data persistence for retries
    CJAVal* m_pending_heartbeat_data;
    bool m_waiting_for_confirmation;
    
    // Helper methods
    string get_iso_timestamp();

public:
    CHeartbeat_Manager(CSDK_Context* context);
    ~CHeartbeat_Manager();

    void set_session_id(ulong session_id) { m_session_id = session_id; }
    void set_interval(uint interval);
    bool is_time_to_send();
    CJAVal* build_heartbeat_payload();
    void process_heartbeat_response(const CJAVal &response);
};

#include "CSDK_Context.mqh" // Full include for implementation

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CHeartbeat_Manager::CHeartbeat_Manager(CSDK_Context* context)
{
    m_session_id = 0;
    m_sequence = 0;
    m_heartbeat_interval_seconds = 60; // Default interval
    m_max_heartbeat_interval = 300;    // 5 minutes
    m_last_heartbeat_time = 0;
    
    m_context = context;
    
    m_pending_heartbeat_data = NULL;
    m_waiting_for_confirmation = false;
}

CHeartbeat_Manager::~CHeartbeat_Manager()
{
    if(CheckPointer(m_pending_heartbeat_data) == POINTER_DYNAMIC)
        delete m_pending_heartbeat_data;
}

void CHeartbeat_Manager::set_interval(uint interval)
{
    m_heartbeat_interval_seconds = MathMin(interval, m_max_heartbeat_interval);
}

bool CHeartbeat_Manager::is_time_to_send()
{
    return (TimeCurrent() >= (m_last_heartbeat_time + m_heartbeat_interval_seconds));
}

/**
 * @brief Generates an ISO 8601 formatted timestamp string.
 * @return String in format "2024-01-15T10:30:00.000Z"
 */
string CHeartbeat_Manager::get_iso_timestamp()
{
    datetime current = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current, dt);
    
    return StringFormat("%04d-%02d-%02dT%02d:%02d:%02d.000Z",
                        dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

/**
 * @brief Builds the JSON payload for a heartbeat request.
 * @return A CJAVal object representing the payload.
 * @note Payload matches RobotHeartbeatRequest schema from API contract.
 */
CJAVal* CHeartbeat_Manager::build_heartbeat_payload()
{
    if(m_waiting_for_confirmation && CheckPointer(m_pending_heartbeat_data) != POINTER_INVALID)
    {
        // Resend pending data if we haven't received confirmation
        return m_pending_heartbeat_data;
    }

    CJAVal* payload = new CJAVal(JA_OBJECT);
    if(payload == NULL) return NULL;

    // ===========================================================================
    // REQUIRED FIELDS (from RobotHeartbeatRequest)
    // ===========================================================================

    // sequence: integer - Monotonically increasing sequence number
    CJAVal* sequence_val = new CJAVal();
    sequence_val.set_long(m_sequence + 1); // Increment sequence for this attempt
    payload.Add("sequence", sequence_val);
    
    // timestamp: string - ISO 8601 formatted timestamp in UTC
    CJAVal* timestamp_val = new CJAVal();
    timestamp_val.set_string(get_iso_timestamp());
    payload.Add("timestamp", timestamp_val);
    
    // dynamic_data: object - Real-time account data and performance metrics
    payload.Add("dynamic_data", m_context.data_collector.get_dynamic_data());
    
    // ===========================================================================
    // OPTIONAL FIELDS (change results from previous requests)
    // ===========================================================================
    
    // config_change_results: object - Results of configuration change requests
    CJAVal* config_results = m_context.config_manager.get_pending_results();
    if(CheckPointer(config_results) != POINTER_INVALID)
        payload.Add("config_change_results", config_results);

    // symbols_change_results: object - Results of symbol change requests
    CJAVal* symbol_results = m_context.symbol_manager.get_pending_results();
    if(CheckPointer(symbol_results) != POINTER_INVALID)
        payload.Add("symbols_change_results", symbol_results);
        
    // Cache this payload in case a retry is needed
    // Note: A proper deep copy of the object would be needed here.
    m_pending_heartbeat_data = payload;
    m_waiting_for_confirmation = true;

    return payload;
}

/**
 * @brief Processes the response from a heartbeat request.
 * @param response The JSON response from the server.
 * @note Change requests are only processed if the respective feature is enabled.
 *       When features are disabled, the SDK gracefully ignores those fields.
 */
void CHeartbeat_Manager::process_heartbeat_response(const CJAVal &response)
{
    // On successful confirmation, update state
    m_sequence++;
    m_last_heartbeat_time = TimeCurrent();
    m_waiting_for_confirmation = false;
    
    // Clear the pending results that were successfully sent (if feature is enabled)
    if(m_context.config_manager.is_enabled())
        m_context.config_manager.clear_pending_results();
    
    if(m_context.symbol_manager.is_enabled())
        m_context.symbol_manager.clear_pending_results();
    
    if(CheckPointer(m_pending_heartbeat_data) == POINTER_DYNAMIC)
    {
        delete m_pending_heartbeat_data;
        m_pending_heartbeat_data = NULL;
    }

    // Update heartbeat interval (always processed)
    CJAVal* interval_node = response["heartbeat_interval_seconds"];
    if(CheckPointer(interval_node) != POINTER_INVALID && interval_node.get_type() == JA_NUMBER)
    {
        set_interval((uint)interval_node.get_long());
    }
    
    // Process new change requests (only if feature is enabled)
    // The managers will also check their enabled state, this is an additional guard
    CJAVal* config_change_node = response["robot_config_change_request"];
    if(CheckPointer(config_change_node) != POINTER_INVALID)
    {
        // Manager will check its enabled state and log if disabled
        m_context.config_manager.process_change_request(config_change_node);
    }
    
    CJAVal* symbol_change_node = response["session_symbols_change_request"];
    if(CheckPointer(symbol_change_node) != POINTER_INVALID)
    {
        // Manager will check its enabled state and log if disabled
        m_context.symbol_manager.process_change_request(symbol_change_node);
    }
}

#endif
//+------------------------------------------------------------------+
