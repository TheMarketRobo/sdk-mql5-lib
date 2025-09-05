//+------------------------------------------------------------------+
//|                                     Cconfiguration_Manager.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CCONFIGURATION_MANAGER_MQH
#define CCONFIGURATION_MANAGER_MQH

#include <Object.mqh>
#include "../Interfaces/Irobot_Config.mqh"
#include "../Interfaces/Irobot_Callback.mqh"
#include "../Services/Json.mqh"

/**
 * @class Cconfiguration_Manager
 * @brief Manages the robot's configuration, including validation and updates.
 */
class Cconfiguration_Manager : public CObject
{
private:
    Irobot_Config* m_robot_config;
    Irobot_Callback* m_robot_callback;
    CJAVal* m_pending_change_results; // Results to be sent in the next heartbeat

public:
    Cconfiguration_Manager(Irobot_Config* robot_config, Irobot_Callback* robot_callback);
    ~Cconfiguration_Manager();

    bool validate_initial_config(const CJAVal &server_config);
    void process_change_request(const CJAVal &change_request);
    CJAVal* get_pending_results();
    void clear_pending_results();
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
Cconfiguration_Manager::Cconfiguration_Manager(Irobot_Config* robot_config, Irobot_Callback* robot_callback)
{
    m_robot_config = robot_config;
    m_robot_callback = robot_callback;
    m_pending_change_results = NULL;
}

Cconfiguration_Manager::~Cconfiguration_Manager()
{
    clear_pending_results();
}

/**
 * @brief Validates the initial server configuration against the developer's config.
 * @param server_config The configuration object from the /start response.
 * @return true if validation passes, false otherwise.
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
 */
void Cconfiguration_Manager::process_change_request(const CJAVal &change_request)
{
    if(CheckPointer(m_robot_config) == POINTER_INVALID || CheckPointer(m_robot_callback) == POINTER_INVALID) return;

    clear_pending_results();
    m_pending_change_results = new CJAVal(JA_OBJECT);
    if(m_pending_change_results == NULL) return;
    
    // Assuming change_request is a JSON object of key-value pairs
    // A full JSON library would provide a way to iterate keys.
    // This is a conceptual implementation.

    // Example for a single field change:
    string field_to_change = "risk_level"; // This would be dynamic in a real scenario
    CJAVal* new_value_node = change_request[field_to_change];

    if(CheckPointer(new_value_node) != POINTER_INVALID)
    {
        string new_value_str = new_value_node.to_string();
        string reason = "";
        
        // 1. Validate using developer's validation method
        if(m_robot_config.validate_field(field_to_change, new_value_str, reason))
        {
            string old_value_str = ""; // Need a way to get old value from m_robot_config
            
            // 2. Update developer's config object
            m_robot_config.update_field(field_to_change, new_value_str);

            // 3. Notify robot about the change
            m_robot_callback.on_configuration_changed(field_to_change, old_value_str, new_value_str);

            // 4. Add to accepted results
            // m_pending_change_results.Add("accepted_changes", ...);
        }
        else
        {
            // 5. Add to rejected results
            // m_pending_change_results.Add("rejected_changes", ...);
        }
    }
}

/**
 * @brief Gets the results of the last change request to be sent in the next heartbeat.
 * @return A CJAVal object with the results, or NULL if there are none.
 */
CJAVal* Cconfiguration_Manager::get_pending_results()
{
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
