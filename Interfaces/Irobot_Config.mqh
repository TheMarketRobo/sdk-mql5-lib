//+------------------------------------------------------------------+
//|                                              Irobot_Config.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"
#property strict

#include "../Services/Json.mqh"

/**
 * @class Irobot_Config
 * @brief Abstract base class for a robot's configuration.
 *
 * Developers must inherit from this class to define their robot's specific
 * configuration parameters. It enforces the implementation of methods for
 * validation, JSON serialization, and updating the configuration from a
 * server response, which are essential for the SDK to manage the configuration
 * lifecycle.
 */
class Irobot_Config
{
public:
    /**
     * @brief Validates a new value for a specific configuration field.
     *
     * The SDK calls this method when it receives a configuration change request
     * from the server. The developer must implement the logic to check if the
     * new value is acceptable for the given field.
     *
     * @param field_name The name of the field to validate.
     * @param new_value The proposed new value for the field.
     * @param[out] reason A descriptive reason if the validation fails.
     * @return true if the value is valid, otherwise false.
     */
    virtual bool validate_field(string field_name, string new_value, string &reason) = 0;

    /**
     * @brief Serializes the entire configuration object to a JSON string.
     *
     * The SDK calls this method during the initial `/start` request to send the
     * robot's default configuration to the server.
     *
     * @return A string containing the JSON representation of the configuration.
     */
    virtual string to_json() = 0;

    /**
     * @brief Updates the configuration object from a JSON object.
     *
     * The SDK calls this method to apply the initial configuration received
     * from the server in the `/start` response. The developer must parse the
     * JSON and update the corresponding member variables.
     *
     * @param config_json A CJAVal object representing the server's configuration.
     * @return true if the update was successful, otherwise false.
     */
    virtual bool update_from_json(const CJAVal &config_json) = 0;
    
    /**
     * @brief Updates a single field in the configuration object.
     *
     * The SDK calls this method after a new value has been validated to apply
     * the change to the developer's configuration object.
     *
     * @param field_name The name of the field to update.
     * @param new_value The new value to apply.
     * @return true if the update was successful, otherwise false.
     */
    virtual bool update_field(string field_name, string new_value) = 0;
};
//+------------------------------------------------------------------+
