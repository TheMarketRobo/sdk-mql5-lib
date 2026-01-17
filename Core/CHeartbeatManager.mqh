//+------------------------------------------------------------------+
//|                                             CHeartbeatManager.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CHEARTBEAT_MANAGER_MQH
#define CHEARTBEAT_MANAGER_MQH

#include <Object.mqh>
#include "../Services/Json.mqh"

class CSDKContext;

/**
 * @class CHeartbeatManager
 * @brief Manages the periodic heartbeat communication with the server.
 *
 * ## Heartbeat Payload (matches RobotHeartbeatRequest)
 * - sequence: Monotonically increasing sequence number
 * - timestamp: ISO 8601 formatted timestamp in UTC
 * - dynamic_data: Real-time account data and performance metrics
 * - config_change_results: Results of configuration change requests (optional)
 * - symbols_change_results: Results of symbol change requests (optional)
 */
class CHeartbeatManager : public CObject
{
private:
    ulong m_session_id;
    uint m_sequence;
    uint m_heartbeat_interval_seconds;
    uint m_max_heartbeat_interval;
    datetime m_last_heartbeat_time;
    CSDKContext* m_context;
    CJAVal* m_pending_heartbeat_data;
    bool m_waiting_for_confirmation;
    
    string get_iso_timestamp();

public:
    CHeartbeatManager(CSDKContext* context);
    ~CHeartbeatManager();

    void set_session_id(ulong session_id);
    void set_interval(uint interval);
    bool is_time_to_send();
    CJAVal* build_heartbeat_payload();
    void process_heartbeat_response(const CJAVal &response);
};

#include "CSDKContext.mqh"

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CHeartbeatManager::CHeartbeatManager(CSDKContext* context)
{
    m_session_id = 0;
    m_sequence = 0;
    m_heartbeat_interval_seconds = 60;
    m_max_heartbeat_interval = 300;
    m_last_heartbeat_time = 0;
    m_context = context;
    m_pending_heartbeat_data = NULL;
    m_waiting_for_confirmation = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CHeartbeatManager::~CHeartbeatManager()
{
    if(CheckPointer(m_pending_heartbeat_data) == POINTER_DYNAMIC)
        delete m_pending_heartbeat_data;
}

//+------------------------------------------------------------------+
//| Set session ID                                                    |
//+------------------------------------------------------------------+
void CHeartbeatManager::set_session_id(ulong session_id)
{
    m_session_id = session_id;
    Print("SDK Debug: HeartbeatManager - Session ID set to: ", m_session_id);
}

//+------------------------------------------------------------------+
//| Set heartbeat interval                                            |
//+------------------------------------------------------------------+
void CHeartbeatManager::set_interval(uint interval)
{
    uint old_interval = m_heartbeat_interval_seconds;
    m_heartbeat_interval_seconds = MathMin(interval, m_max_heartbeat_interval);
    if(old_interval != m_heartbeat_interval_seconds)
    {
        Print("SDK Debug: HeartbeatManager - Interval changed from ", old_interval, 
              " to ", m_heartbeat_interval_seconds, " seconds");
    }
}

//+------------------------------------------------------------------+
//| Check if it's time to send heartbeat                              |
//+------------------------------------------------------------------+
bool CHeartbeatManager::is_time_to_send()
{
    datetime current_time = TimeCurrent();
    datetime next_heartbeat_time = m_last_heartbeat_time + m_heartbeat_interval_seconds;
    bool should_send = (current_time >= next_heartbeat_time);
    
    // Debug logging only when we're about to send
    if(should_send)
    {
        Print("SDK Debug: HeartbeatManager - Time to send heartbeat. ",
              "Last sent: ", (m_last_heartbeat_time == 0 ? "never" : TimeToString(m_last_heartbeat_time, TIME_DATE|TIME_SECONDS)),
              ", Interval: ", m_heartbeat_interval_seconds, "s",
              ", Sequence: ", m_sequence);
    }
    
    return should_send;
}

//+------------------------------------------------------------------+
//| Generate ISO 8601 timestamp                                       |
//+------------------------------------------------------------------+
string CHeartbeatManager::get_iso_timestamp()
{
    datetime current = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current, dt);
    
    return StringFormat("%04d-%02d-%02dT%02d:%02d:%02d.000Z",
                        dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
//| Build heartbeat payload                                           |
//+------------------------------------------------------------------+
CJAVal* CHeartbeatManager::build_heartbeat_payload()
{
    if(m_waiting_for_confirmation && CheckPointer(m_pending_heartbeat_data) != POINTER_INVALID)
    {
        Print("SDK Debug: HeartbeatManager - Reusing pending heartbeat data (waiting for confirmation)");
        return m_pending_heartbeat_data;
    }

    Print("SDK Debug: HeartbeatManager - Building new heartbeat payload for sequence ", m_sequence + 1);
    
    CJAVal* payload = new CJAVal(JA_OBJECT);
    if(payload == NULL)
    {
        Print("SDK Error: HeartbeatManager - Failed to create payload object");
        return NULL;
    }

    CJAVal* sequence_val = new CJAVal();
    sequence_val.set_long(m_sequence + 1);
    payload.Add("sequence", sequence_val);
    
    CJAVal* timestamp_val = new CJAVal();
    timestamp_val.set_string(get_iso_timestamp());
    payload.Add("timestamp", timestamp_val);
    
    CJAVal* dynamic_data = m_context.data_collector.get_dynamic_data();
    if(CheckPointer(dynamic_data) == POINTER_INVALID)
    {
        Print("SDK Warning: HeartbeatManager - Failed to get dynamic data");
    }
    payload.Add("dynamic_data", dynamic_data);
    
    CJAVal* config_results = m_context.config_manager.get_pending_results();
    if(CheckPointer(config_results) != POINTER_INVALID)
    {
        Print("SDK Debug: HeartbeatManager - Including config change results");
        payload.Add("config_change_results", config_results);
    }

    CJAVal* symbol_results = m_context.symbol_manager.get_pending_results();
    if(CheckPointer(symbol_results) != POINTER_INVALID)
    {
        Print("SDK Debug: HeartbeatManager - Including symbol change results");
        payload.Add("symbols_change_results", symbol_results);
    }
        
    m_pending_heartbeat_data = payload;
    m_waiting_for_confirmation = true;

    Print("SDK Debug: HeartbeatManager - Payload built successfully");
    return payload;
}

//+------------------------------------------------------------------+
//| Process heartbeat response                                        |
//+------------------------------------------------------------------+
void CHeartbeatManager::process_heartbeat_response(const CJAVal &response)
{
    Print("SDK Debug: HeartbeatManager - Processing heartbeat response");
    
    m_sequence++;
    m_last_heartbeat_time = TimeCurrent();
    m_waiting_for_confirmation = false;
    
    Print("SDK Debug: HeartbeatManager - Sequence updated to ", m_sequence, 
          ", last heartbeat time: ", TimeToString(m_last_heartbeat_time, TIME_DATE|TIME_SECONDS));
    
    if(m_context.config_manager.is_enabled())
        m_context.config_manager.clear_pending_results();
    
    if(m_context.symbol_manager.is_enabled())
        m_context.symbol_manager.clear_pending_results();
    
    if(CheckPointer(m_pending_heartbeat_data) == POINTER_DYNAMIC)
    {
        delete m_pending_heartbeat_data;
        m_pending_heartbeat_data = NULL;
    }

    CJAVal* interval_node = response["heartbeat_interval_seconds"];
    if(CheckPointer(interval_node) != POINTER_INVALID && interval_node.get_type() == JA_NUMBER)
    {
        uint new_interval = (uint)interval_node.get_long();
        Print("SDK Debug: HeartbeatManager - Server requested interval: ", new_interval, " seconds");
        set_interval(new_interval);
    }
    
    CJAVal* config_change_node = response["robot_config_change_request"];
    if(CheckPointer(config_change_node) != POINTER_INVALID)
    {
        Print("SDK Debug: HeartbeatManager - Processing config change request from server");
        m_context.config_manager.process_change_request(config_change_node);
    }
    
    CJAVal* symbol_change_node = response["session_symbols_change_request"];
    if(CheckPointer(symbol_change_node) != POINTER_INVALID)
    {
        Print("SDK Debug: HeartbeatManager - Processing symbol change request from server");
        m_context.symbol_manager.process_change_request(symbol_change_node);
    }
    
    Print("SDK Debug: HeartbeatManager - Response processed successfully");
}

#endif
//+------------------------------------------------------------------+

