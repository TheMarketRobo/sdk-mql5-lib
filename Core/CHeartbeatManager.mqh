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
}

//+------------------------------------------------------------------+
//| Set heartbeat interval                                            |
//+------------------------------------------------------------------+
void CHeartbeatManager::set_interval(uint interval)
{
    m_heartbeat_interval_seconds = MathMin(interval, m_max_heartbeat_interval);
}

//+------------------------------------------------------------------+
//| Check if it's time to send heartbeat                              |
//+------------------------------------------------------------------+
bool CHeartbeatManager::is_time_to_send()
{
    return (TimeCurrent() >= (m_last_heartbeat_time + m_heartbeat_interval_seconds));
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
        return m_pending_heartbeat_data;
    }

    CJAVal* payload = new CJAVal(JA_OBJECT);
    if(payload == NULL) return NULL;

    CJAVal* sequence_val = new CJAVal();
    sequence_val.set_long(m_sequence + 1);
    payload.Add("sequence", sequence_val);
    
    CJAVal* timestamp_val = new CJAVal();
    timestamp_val.set_string(get_iso_timestamp());
    payload.Add("timestamp", timestamp_val);
    
    payload.Add("dynamic_data", m_context.data_collector.get_dynamic_data());
    
    CJAVal* config_results = m_context.config_manager.get_pending_results();
    if(CheckPointer(config_results) != POINTER_INVALID)
        payload.Add("config_change_results", config_results);

    CJAVal* symbol_results = m_context.symbol_manager.get_pending_results();
    if(CheckPointer(symbol_results) != POINTER_INVALID)
        payload.Add("symbols_change_results", symbol_results);
        
    m_pending_heartbeat_data = payload;
    m_waiting_for_confirmation = true;

    return payload;
}

//+------------------------------------------------------------------+
//| Process heartbeat response                                        |
//+------------------------------------------------------------------+
void CHeartbeatManager::process_heartbeat_response(const CJAVal &response)
{
    m_sequence++;
    m_last_heartbeat_time = TimeCurrent();
    m_waiting_for_confirmation = false;
    
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
        set_interval((uint)interval_node.get_long());
    }
    
    CJAVal* config_change_node = response["robot_config_change_request"];
    if(CheckPointer(config_change_node) != POINTER_INVALID)
    {
        m_context.config_manager.process_change_request(config_change_node);
    }
    
    CJAVal* symbol_change_node = response["session_symbols_change_request"];
    if(CheckPointer(symbol_change_node) != POINTER_INVALID)
    {
        m_context.symbol_manager.process_change_request(symbol_change_node);
    }
}

#endif
//+------------------------------------------------------------------+

