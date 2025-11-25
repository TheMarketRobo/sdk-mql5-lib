//+------------------------------------------------------------------+
//|                                     Cconfiguration_Manager.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CCONFIGURATION_MANAGER_MQH
#define CCONFIGURATION_MANAGER_MQH

#include <Object.mqh>
#include "../Interfaces/Irobot_Config.mqh"
#include "../Services/Json.mqh"
#include "../Utils/CSDK_Events.mqh"

/**
 * @class Cconfiguration_Manager
 * @brief Manages the robot's configuration, including validation and updates.
 *
 * ## Feature Toggle Support
 * This manager can be enabled or disabled via set_enabled(). When disabled:
 * - process_change_request() is a no-op
 * - get_pending_results() always returns NULL
 * - Initial config validation still works (required for session start)
 *
 * This follows the Open/Closed Principle - the behavior is modified without
 * changing the existing method interfaces.
 */
class Cconfiguration_Manager : public CObject
{
private:
    Irobot_Config* m_robot_config;
    CJAVal* m_pending_change_results; // Results to be sent in the next heartbeat
    bool m_enabled;                    // Feature toggle

public:
    Cconfiguration_Manager(Irobot_Config* robot_config);
    ~Cconfiguration_Manager();

    // Feature toggle
    void set_enabled(bool enabled) { m_enabled = enabled; }
    bool is_enabled() const { return m_enabled; }

    bool validate_initial_config(const CJAVal &server_config);
    void process_change_request(const CJAVal &change_request);
    CJAVal* get_pending_results();
    void clear_pending_results();
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
Cconfiguration_Manager::Cconfiguration_Manager(Irobot_Config* robot_config)
{
    m_robot_config = robot_config;
    m_pending_change_results = NULL;
    m_enabled = true; // Default: enabled
}

Cconfiguration_Manager::~Cconfiguration_Manager()
{
    clear_pending_results();
}

/**
 * @brief Validates the initial server configuration against the developer's config.
 * @param server_config The configuration object from the /start response.
 * @return true if validation passes, false otherwise.
 * @note This always works regardless of enabled state (required for session start).
 */
bool Cconfiguration_Manager::validate_initial_config(const CJAVal &server_config)
{
    if(CheckPointer(m_robot_config) == POINTER_INVALID) return false;
    // For now, we assume the developer's `update_from_json` handles validation.
    // A more robust implementation would check for missing fields here.
    return m_robot_config.update_from_json(server_config);
}

/**
 * @brief Processes a configuration change request from a heartbeat response.
 * @param change_request The JSON object with requested changes.
 * @note When disabled (set_enabled(false)), this method is a no-op.
 */
void Cconfiguration_Manager::process_change_request(const CJAVal &change_request)
{
    // Early exit if disabled
    if(!m_enabled)
    {
        Print("SDK Info: Config change request received but feature is DISABLED. Ignoring.");
        return;
    }
    
    if(CheckPointer(m_robot_config) == POINTER_INVALID) return;

    clear_pending_results();
    m_pending_change_results = new CJAVal(JA_OBJECT);
    if(m_pending_change_results == NULL) return;

    // Get the list of field names from the developer's config
    string field_names[];
    m_robot_config.get_field_names(field_names);

    CJAVal* accepted_changes = new CJAVal(JA_ARRAY);
    CJAVal* rejected_changes = new CJAVal(JA_ARRAY);

    // Iterate through the developer's fields and check for changes
    for(int i = 0; i < ArraySize(field_names); i++)
    {
        string field_name = field_names[i];
        CJAVal* new_value_node = change_request[field_name];

        if(CheckPointer(new_value_node) != POINTER_INVALID)
        {
            string new_value_str = new_value_node.to_string();
            string reason = "";

            string old_value_str = m_robot_config.get_field_as_string(field_name);

            if(m_robot_config.validate_field(field_name, new_value_str, reason))
            {
                m_robot_config.update_field(field_name, new_value_str);

                // Add to accepted results
                CJAVal* change = new CJAVal(JA_OBJECT);
                CJAVal* field_val = new CJAVal(); field_val.set_string(field_name);
                CJAVal* new_val = new CJAVal(); new_val.set_string(new_value_str);
                change.Add("field_name", field_val);
                change.Add("value", new_val);
                accepted_changes.Add(change);
                
                Print("SDK Info: Config field '", field_name, "' updated to '", new_value_str, "'");
            }
            else
            {
                // Add to rejected results
                CJAVal* rejection = new CJAVal(JA_OBJECT);
                CJAVal* field_val = new CJAVal(); field_val.set_string(field_name);
                CJAVal* reason_val = new CJAVal(); reason_val.set_string(reason);
                rejection.Add("field_name", field_val);
                rejection.Add("reason", reason_val);
                rejected_changes.Add(rejection);
                
                Print("SDK Warning: Config field '", field_name, "' rejected. Reason: ", reason);
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
CJAVal* Cconfiguration_Manager::get_pending_results()
{
    // Return NULL if disabled - don't include in heartbeat
    if(!m_enabled) return NULL;
    return m_pending_change_results;
}

/**
 * @brief Clears the pending results after they have been sent.
 */
void Cconfiguration_Manager::clear_pending_results()
{
    if(CheckPointer(m_pending_change_results) == POINTER_DYNAMIC)
    {
        delete m_pending_change_results;
        m_pending_change_results = NULL;
    }
}

#endif
//+------------------------------------------------------------------+
