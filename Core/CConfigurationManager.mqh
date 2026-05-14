//+------------------------------------------------------------------+
//|                                        CConfigurationManager.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CCONFIGURATION_MANAGER_MQH
#define CCONFIGURATION_MANAGER_MQH

#include <Object.mqh>
#include "../Interfaces/IRobotConfig.mqh"
#include "../Services/Json.mqh"
#include "../Utils/CSDK_Events.mqh"
#include "../Utils/CSDKLogger.mqh"

// Error codes matching API contract
#define TMKR_CONFIG_ERROR_INVALID_VALUE    "INVALID_VALUE"
#define TMKR_CONFIG_ERROR_OUT_OF_RANGE     "OUT_OF_RANGE"
#define TMKR_CONFIG_ERROR_FIELD_NOT_FOUND  "FIELD_NOT_FOUND"
#define TMKR_CONFIG_ERROR_READ_ONLY_FIELD  "READ_ONLY_FIELD"

/**
 * @class CConfigurationManager
 * @brief Manages the robot's configuration, including validation and updates.
 *
 * ## API Contract Compliance
 * Results structure matches ConfigChangeResults from session-global.yaml:
 * - status: enum [all_accepted, all_rejected, partially_accepted]
 * - results: array of ConfigChangeResultItem
 */
class CTMKR_ConfigurationManager : public CObject
{
private:
    ITMKR_RobotConfig* m_robot_config;
    CTMKR_JAVal* m_pending_change_results;
    bool m_enabled;

public:
    CTMKR_ConfigurationManager(ITMKR_RobotConfig* robot_config);
    ~CTMKR_ConfigurationManager();

    void set_enabled(bool enabled);
    bool is_enabled() const;

    bool validate_initial_config(const CTMKR_JAVal &server_config);
    void process_change_request(const CTMKR_JAVal &change_request);
    CTMKR_JAVal* get_pending_results();
    void clear_pending_results();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_ConfigurationManager::CConfigurationManager(ITMKR_RobotConfig* robot_config)
{
    m_robot_config = robot_config;
    m_pending_change_results = NULL;
    m_enabled = true;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_ConfigurationManager::~CTMKR_ConfigurationManager()
{
    clear_pending_results();
}

//+------------------------------------------------------------------+
//| Set enabled state                                                 |
//+------------------------------------------------------------------+
void CTMKR_ConfigurationManager::set_enabled(bool enabled)
{
    m_enabled = enabled;
}

//+------------------------------------------------------------------+
//| Get enabled state                                                 |
//+------------------------------------------------------------------+
bool CTMKR_ConfigurationManager::is_enabled() const
{
    return m_enabled;
}

//+------------------------------------------------------------------+
//| Validate initial configuration from server                        |
//+------------------------------------------------------------------+
bool CTMKR_ConfigurationManager::validate_initial_config(const CTMKR_JAVal &server_config)
{
    if(CheckPointer(m_robot_config) == POINTER_INVALID) return false;
    return m_robot_config.update_from_json(server_config);
}

//+------------------------------------------------------------------+
//| Process configuration change request                              |
//| Matches ConfigChangeResults from API contract                     |
//| Expected input format:                                            |
//| {                                                                  |
//|   "id": "123",                                                     |
//|   "request": [{ "field_name": "xxx", "new_value": yyy }, ...],    |
//|   "created_at": "2026-01-17T00:00:00.000Z"                        |
//| }                                                                  |
//+------------------------------------------------------------------+
void CTMKR_ConfigurationManager::process_change_request(const CTMKR_JAVal &change_request)
{
    if(!m_enabled)
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Config change request received but feature is DISABLED. Ignoring.");
        return;
    }
    
    if(CheckPointer(m_robot_config) == POINTER_INVALID) return;

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
        if(SDKShouldLogDebug()) Print("SDK Debug: Config change request ID: ", request_id);
    }
    else
    {
        if(SDKShouldLogWarning()) Print("SDK Warning: Config change request missing 'id' field");
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

    // Process request as array of ConfigChangeRequestItem
    // Expected format: [{ "field_name": "xxx", "new_value": yyy }, ...]
    int count = use_direct ? change_request.count() : request_array.count();
    bool is_array = use_direct ? (change_request.get_type() == TMKR_JA_ARRAY) : (request_array.get_type() == TMKR_JA_ARRAY);
    
    if(is_array)
    {
        for(int tmkr_i = 0; tmkr_i < count; tmkr_i++)
        {
            CTMKR_JAVal* tmkr_item = use_direct ? change_request[tmkr_i] : request_array[tmkr_i];
            if(CheckPointer(tmkr_item) == POINTER_INVALID) continue;
            
            CTMKR_JAVal* field_node = tmkr_item["field_name"];
            CTMKR_JAVal* value_node = tmkr_item["new_value"];
            
            if(CheckPointer(field_node) == POINTER_INVALID) continue;
            
            string field_name = field_node.get_string();
            string new_value_str = (CheckPointer(value_node) != POINTER_INVALID) 
                                   ? value_node.to_string() : "";
            
            // Remove quotes from string values
            if(StringLen(new_value_str) >= 2 && 
               StringGetCharacter(new_value_str, 0) == '"')
            {
                new_value_str = StringSubstr(new_value_str, 1, StringLen(new_value_str) - 2);
            }
            
            total_count++;
            
            CTMKR_JAVal* result_item = new CTMKR_JAVal(TMKR_JA_OBJECT);
            
            // field_name (required)
            CTMKR_JAVal* fn_val = new CTMKR_JAVal();
            fn_val.set_string(field_name);
            result_item.Add("field_name", fn_val);
            
            // requested_value (required)
            CTMKR_JAVal* rv_val = new CTMKR_JAVal();
            rv_val.set_string(new_value_str);
            result_item.Add("requested_value", rv_val);
            
            string tmkr_reason = "";
            if(m_robot_config.validate_field(field_name, new_value_str, tmkr_reason))
            {
                m_robot_config.update_field(field_name, new_value_str);
                
                // accepted: true
                CTMKR_JAVal* acc_val = new CTMKR_JAVal();
                acc_val.set_bool(true);
                result_item.Add("accepted", acc_val);
                
                // applied_value (optional but included on success)
                CTMKR_JAVal* av_val = new CTMKR_JAVal();
                av_val.set_string(new_value_str);
                result_item.Add("applied_value", av_val);
                
                accepted_count++;
                if(SDKShouldLogInfo()) Print("SDK Info: Config field '", field_name, "' updated to '", new_value_str, "'");
            }
            else
            {
                // accepted: false
                CTMKR_JAVal* acc_val = new CTMKR_JAVal();
                acc_val.set_bool(false);
                result_item.Add("accepted", acc_val);
                
                // error_code
                CTMKR_JAVal* ec_val = new CTMKR_JAVal();
                ec_val.set_string(TMKR_CONFIG_ERROR_INVALID_VALUE);
                result_item.Add("error_code", ec_val);
                
                // error_message
                CTMKR_JAVal* em_val = new CTMKR_JAVal();
                em_val.set_string(tmkr_reason);
                result_item.Add("error_message", em_val);
                
                rejected_count++;
                if(SDKShouldLogWarning()) Print("SDK Warning: Config field '", field_name, "' rejected. Reason: ", tmkr_reason);
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
CTMKR_JAVal* CTMKR_ConfigurationManager::get_pending_results()
{
    if(!m_enabled) return NULL;
    return m_pending_change_results;
}

//+------------------------------------------------------------------+
//| Clear pending results                                             |
//+------------------------------------------------------------------+
void CTMKR_ConfigurationManager::clear_pending_results()
{
    if(CheckPointer(m_pending_change_results) == POINTER_DYNAMIC)
    {
        delete m_pending_change_results;
        m_pending_change_results = NULL;
    }
}

#endif
//+------------------------------------------------------------------+

