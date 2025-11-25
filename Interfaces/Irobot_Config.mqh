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
#include "../Models/CConfig_Schema.mqh"

/**
 * @class Irobot_Config
 * @brief Abstract base class for a robot's configuration with schema support.
 *
 * Developers must inherit from this class to define their robot's specific
 * configuration parameters. The class provides two key features:
 *
 * ## 1. Configuration Schema Definition
 * Define the schema (field types, constraints, UI hints) that matches
 * robot_config_component_schema/v1.json using the CConfig_Schema class.
 *
 * ## 2. Configuration Value Management
 * Store and manage the actual configuration values, with validation
 * based on the schema.
 *
 * ## Usage Example
 * ```cpp
 * class CMyRobotConfig : public Irobot_Config
 * {
 * private:
 *     // Actual config values
 *     int    m_max_trades;
 *     double m_stop_loss_percent;
 *     bool   m_use_trailing_stop;
 *     string m_trading_mode;
 *     
 * public:
 *     CMyRobotConfig()
 *     {
 *         // Define the schema
 *         define_schema();
 *         
 *         // Apply default values from schema
 *         apply_defaults();
 *     }
 *     
 * protected:
 *     virtual void define_schema() override
 *     {
 *         // Integer field with range
 *         m_schema.add_field(
 *             CConfig_Field::create_integer("max_trades", "Maximum Trades", true, 5)
 *                 .with_range(1, 20)
 *                 .with_description("Maximum concurrent trades")
 *                 .with_group("Risk Management", 1)
 *         );
 *         
 *         // Decimal field
 *         m_schema.add_field(
 *             CConfig_Field::create_decimal("stop_loss_percent", "Stop Loss %", true, 1.5)
 *                 .with_range(0.5, 5.0)
 *                 .with_precision(1)
 *                 .with_group("Risk Management", 2)
 *         );
 *         
 *         // Boolean field
 *         m_schema.add_field(
 *             CConfig_Field::create_boolean("use_trailing_stop", "Use Trailing Stop", true, false)
 *                 .with_group("Features", 1)
 *         );
 *         
 *         // Radio field with options
 *         m_schema.add_field(
 *             CConfig_Field::create_radio("trading_mode", "Trading Mode", true, "moderate")
 *                 .with_option("conservative", "Conservative")
 *                 .with_option("moderate", "Moderate")
 *                 .with_option("aggressive", "Aggressive")
 *                 .with_group("Strategy", 1)
 *         );
 *     }
 *     
 *     virtual void apply_defaults() override
 *     {
 *         m_max_trades = m_schema.get_default_int("max_trades");
 *         m_stop_loss_percent = m_schema.get_default_double("stop_loss_percent");
 *         m_use_trailing_stop = m_schema.get_default_bool("use_trailing_stop");
 *         m_trading_mode = m_schema.get_default_string("trading_mode");
 *     }
 * };
 * ```
 */
class Irobot_Config
{
protected:
    CConfig_Schema* m_schema;  // Configuration schema

public:
    Irobot_Config();
    virtual ~Irobot_Config();
    
    //==========================================================================
    // SCHEMA DEFINITION (Programmer must implement)
    //==========================================================================
    
    /**
     * @brief Defines the configuration schema.
     * Override this method to define your robot's configuration fields
     * using m_schema.add_field() with CConfig_Field factory methods.
     */
    virtual void define_schema() = 0;
    
    /**
     * @brief Applies default values from the schema to member variables.
     * Override this method to set your member variables to their default values
     * using m_schema.get_default_*() methods.
     */
    virtual void apply_defaults() = 0;
    
    //==========================================================================
    // CONFIGURATION VALIDATION (SDK uses these)
    //==========================================================================
    
    /**
     * @brief Validates a new value for a specific configuration field.
     *
     * The SDK calls this method when it receives a configuration change request
     * from the server. Uses the schema for validation by default.
     *
     * @param field_name The name of the field to validate.
     * @param new_value The proposed new value for the field.
     * @param[out] reason A descriptive reason if the validation fails.
     * @return true if the value is valid, otherwise false.
     */
    virtual bool validate_field(string field_name, string new_value, string &reason);

    /**
     * @brief Serializes the entire configuration object to a JSON string.
     *
     * The SDK calls this method during the initial `/start` request to send the
     * robot's current configuration to the server.
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

    /**
     * @brief Retrieves the current value of a field, converted to a string.
     *
     * The SDK calls this method to get the `old_value` for a configuration
     * change notification before the value is updated.
     *
     * @param field_name The name of the field to retrieve.
     * @return A string representation of the field's current value.
     */
    virtual string get_field_as_string(string field_name) = 0;

    /**
     * @brief Provides the SDK with a list of all developer-defined configuration field names.
     *
     * Default implementation uses the schema to get field names.
     *
     * @param[out] field_names The string array to be filled with the names of the configuration fields.
     */
    virtual void get_field_names(string &field_names[]);
    
    //==========================================================================
    // SCHEMA ACCESS
    //==========================================================================
    
    /**
     * @brief Gets the configuration schema.
     * @return Pointer to the CConfig_Schema object.
     */
    CConfig_Schema* get_schema() { return m_schema; }
    
    /**
     * @brief Gets the schema as a JSON string.
     * @return JSON string matching robot_config_component_schema structure.
     */
    string get_schema_json();
    
    /**
     * @brief Gets a specific field definition from the schema.
     * @param key The field key.
     * @return Pointer to the CConfig_Field or NULL if not found.
     */
    CConfig_Field* get_field_definition(string key);
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
Irobot_Config::Irobot_Config()
{
    m_schema = new CConfig_Schema();
}

Irobot_Config::~Irobot_Config()
{
    if(CheckPointer(m_schema) == POINTER_DYNAMIC)
        delete m_schema;
}

/**
 * @brief Default implementation uses schema for validation.
 */
bool Irobot_Config::validate_field(string field_name, string new_value, string &reason)
{
    if(CheckPointer(m_schema) == POINTER_INVALID)
    {
        reason = "Schema not initialized";
        return false;
    }
    
    CConfig_Field* field = m_schema.get_field(field_name);
    if(field == NULL)
    {
        reason = "Field not found: " + field_name;
        return false;
    }
    
    // Validate based on field type
    switch(field.m_type)
    {
        case CONFIG_FIELD_INTEGER:
        {
            int value = (int)StringToInteger(new_value);
            return field.validate_value(value, reason);
        }
        case CONFIG_FIELD_DECIMAL:
        {
            double value = StringToDouble(new_value);
            return field.validate_value(value, reason);
        }
        case CONFIG_FIELD_BOOLEAN:
        {
            bool value = (new_value == "true" || new_value == "1");
            return field.validate_value(value, reason);
        }
        case CONFIG_FIELD_RADIO:
        {
            return field.validate_value(new_value, reason);
        }
        case CONFIG_FIELD_MULTIPLE:
        {
            // Multiple field validation would need array parsing
            return true;
        }
    }
    
    return true;
}

/**
 * @brief Gets field names from the schema.
 */
void Irobot_Config::get_field_names(string &field_names[])
{
    if(CheckPointer(m_schema) != POINTER_INVALID)
    {
        m_schema.get_field_keys(field_names);
    }
}

/**
 * @brief Gets the schema as JSON string.
 */
string Irobot_Config::get_schema_json()
{
    if(CheckPointer(m_schema) != POINTER_INVALID)
    {
        return m_schema.to_json_string();
    }
    return "{}";
}

/**
 * @brief Gets a field definition from the schema.
 */
CConfig_Field* Irobot_Config::get_field_definition(string key)
{
    if(CheckPointer(m_schema) != POINTER_INVALID)
    {
        return m_schema.get_field(key);
    }
    return NULL;
}

#endif
//+------------------------------------------------------------------+
