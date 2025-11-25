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

// Error codes matching API contract
#define CONFIG_ERROR_INVALID_VALUE    "INVALID_VALUE"
#define CONFIG_ERROR_OUT_OF_RANGE     "OUT_OF_RANGE"
#define CONFIG_ERROR_FIELD_NOT_FOUND  "FIELD_NOT_FOUND"
#define CONFIG_ERROR_READ_ONLY_FIELD  "READ_ONLY_FIELD"

/**
 * @class CConfigurationManager
 * @brief Manages the robot's configuration, including validation and updates.
 *
 * ## API Contract Compliance
 * Results structure matches ConfigChangeResults from session-global.yaml:
 * - status: enum [all_accepted, all_rejected, partially_accepted]
 * - results: array of ConfigChangeResultItem
 */
class CConfigurationManager : public CObject
{
private:
    IRobotConfig* m_robot_config;
    CJAVal* m_pending_change_results;
    bool m_enabled;

public:
    CConfigurationManager(IRobotConfig* robot_config);
    ~CConfigurationManager();

    void set_enabled(bool enabled);
    bool is_enabled() const;

    bool validate_initial_config(const CJAVal &server_config);
    void process_change_request(const CJAVal &change_request);
    CJAVal* get_pending_results();
    void clear_pending_results();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CConfigurationManager::CConfigurationManager(IRobotConfig* robot_config)
{
    m_robot_config = robot_config;
    m_pending_change_results = NULL;
    m_enabled = true;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CConfigurationManager::~CConfigurationManager()
{
    clear_pending_results();
}

//+------------------------------------------------------------------+
//| Set enabled state                                                 |
//+------------------------------------------------------------------+
void CConfigurationManager::set_enabled(bool enabled)
{
    m_enabled = enabled;
}

//+------------------------------------------------------------------+
//| Get enabled state                                                 |
//+------------------------------------------------------------------+
bool CConfigurationManager::is_enabled() const
{
    return m_enabled;
}

//+------------------------------------------------------------------+
//| Validate initial configuration from server                        |
//+------------------------------------------------------------------+
bool CConfigurationManager::validate_initial_config(const CJAVal &server_config)
{
    if(CheckPointer(m_robot_config) == POINTER_INVALID) return false;
    return m_robot_config.update_from_json(server_config);
}

//+------------------------------------------------------------------+
//| Process configuration change request                              |
//| Matches ConfigChangeResults from API contract                     |
//+------------------------------------------------------------------+
void CConfigurationManager::process_change_request(const CJAVal &change_request)
{
    if(!m_enabled)
    {
        Print("SDK Info: Config change request received but feature is DISABLED. Ignoring.");
        return;
    }
    
    if(CheckPointer(m_robot_config) == POINTER_INVALID) return;

    clear_pending_results();
    m_pending_change_results = new CJAVal(JA_OBJECT);
    if(m_pending_change_results == NULL) return;

    CJAVal* results_array = new CJAVal(JA_ARRAY);
    int accepted_count = 0;
    int rejected_count = 0;
    int total_count = 0;

    // Process change_request as array of ConfigChangeRequestItem
    // Expected format: [{ "field_name": "xxx", "new_value": yyy }, ...]
    if(change_request.get_type() == JA_ARRAY)
    {
        int count = change_request.count();
        for(int i = 0; i < count; i++)
        {
            CJAVal* item = change_request[i];
            if(CheckPointer(item) == POINTER_INVALID) continue;
            
            CJAVal* field_node = item["field_name"];
            CJAVal* value_node = item["new_value"];
            
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
            
            CJAVal* result_item = new CJAVal(JA_OBJECT);
            
            // field_name (required)
            CJAVal* fn_val = new CJAVal();
            fn_val.set_string(field_name);
            result_item.Add("field_name", fn_val);
            
            // requested_value (required)
            CJAVal* rv_val = new CJAVal();
            rv_val.set_string(new_value_str);
            result_item.Add("requested_value", rv_val);
            
            string reason = "";
            if(m_robot_config.validate_field(field_name, new_value_str, reason))
            {
                m_robot_config.update_field(field_name, new_value_str);
                
                // accepted: true
                CJAVal* acc_val = new CJAVal();
                acc_val.set_bool(true);
                result_item.Add("accepted", acc_val);
                
                // applied_value (optional but included on success)
                CJAVal* av_val = new CJAVal();
                av_val.set_string(new_value_str);
                result_item.Add("applied_value", av_val);
                
                accepted_count++;
                Print("SDK Info: Config field '", field_name, "' updated to '", new_value_str, "'");
            }
            else
            {
                // accepted: false
                CJAVal* acc_val = new CJAVal();
                acc_val.set_bool(false);
                result_item.Add("accepted", acc_val);
                
                // error_code
                CJAVal* ec_val = new CJAVal();
                ec_val.set_string(CONFIG_ERROR_INVALID_VALUE);
                result_item.Add("error_code", ec_val);
                
                // error_message
                CJAVal* em_val = new CJAVal();
                em_val.set_string(reason);
                result_item.Add("error_message", em_val);
                
                rejected_count++;
                Print("SDK Warning: Config field '", field_name, "' rejected. Reason: ", reason);
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
CJAVal* CConfigurationManager::get_pending_results()
{
    if(!m_enabled) return NULL;
    return m_pending_change_results;
}

//+------------------------------------------------------------------+
//| Clear pending results                                             |
//+------------------------------------------------------------------+
void CConfigurationManager::clear_pending_results()
{
    if(CheckPointer(m_pending_change_results) == POINTER_DYNAMIC)
    {
        delete m_pending_change_results;
        m_pending_change_results = NULL;
    }
}

#endif
//+------------------------------------------------------------------+

