//+------------------------------------------------------------------+
//|                                              CConfig_Schema.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CCONFIG_SCHEMA_MQH
#define CCONFIG_SCHEMA_MQH

#include <Object.mqh>
#include <Arrays/ArrayObj.mqh>
#include "CConfig_Field.mqh"

/**
 * @class CConfig_Schema
 * @brief Container for robot configuration schema definition.
 *
 * This class provides a code-based way to define the config schema that matches
 * the robot_config_component_schema/v1.json structure. Since MQL5 cannot use
 * JSON files directly, programmers use this class to define their schema in code.
 *
 * ## Usage Example
 * ```cpp
 * class CMyRobotConfig : public Irobot_Config
 * {
 * private:
 *     CConfig_Schema* m_schema;
 *     
 *     // Actual config values
 *     int    m_max_trades;
 *     double m_stop_loss;
 *     bool   m_use_trailing;
 *     string m_trading_mode;
 *     
 * public:
 *     CMyRobotConfig()
 *     {
 *         m_schema = new CConfig_Schema();
 *         define_schema();
 *         apply_defaults();
 *     }
 *     
 *     void define_schema()
 *     {
 *         // Define integer field with range
 *         m_schema.add_field(
 *             CConfig_Field::create_integer("max_trades", "Maximum Trades", true, 5)
 *                 .with_range(1, 20)
 *                 .with_description("Maximum concurrent trades")
 *                 .with_group("Risk Management", 1)
 *         );
 *         
 *         // Define decimal field
 *         m_schema.add_field(
 *             CConfig_Field::create_decimal("stop_loss", "Stop Loss %", true, 1.5)
 *                 .with_range(0.5, 5.0)
 *                 .with_precision(1)
 *                 .with_group("Risk Management", 2)
 *         );
 *         
 *         // Define boolean field
 *         m_schema.add_field(
 *             CConfig_Field::create_boolean("use_trailing", "Use Trailing Stop", true, false)
 *                 .with_group("Features", 1)
 *         );
 *         
 *         // Define radio field with options
 *         m_schema.add_field(
 *             CConfig_Field::create_radio("trading_mode", "Trading Mode", true, "moderate")
 *                 .with_option("conservative", "Conservative")
 *                 .with_option("moderate", "Moderate")
 *                 .with_option("aggressive", "Aggressive")
 *                 .with_group("Strategy", 1)
 *         );
 *     }
 * };
 * ```
 */
class CConfig_Schema : public CObject
{
private:
    CArrayObj* m_fields;

public:
    CConfig_Schema();
    ~CConfig_Schema();
    
    // Field management
    void add_field(CConfig_Field* field);
    CConfig_Field* get_field(string key);
    CConfig_Field* get_field_by_index(int index);
    int get_field_count();
    void get_field_keys(string &keys[]);
    
    // Validation
    bool validate_field_value(string key, string value, string &reason);
    bool validate_field_value(string key, int value, string &reason);
    bool validate_field_value(string key, double value, string &reason);
    bool validate_field_value(string key, bool value, string &reason);
    
    // Get default values
    int get_default_int(string key);
    double get_default_double(string key);
    bool get_default_bool(string key);
    string get_default_string(string key);
    
    // Serialization
    CJAVal* to_json();
    string to_json_string();
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CConfig_Schema::CConfig_Schema()
{
    m_fields = new CArrayObj();
    m_fields.FreeMode(true);
}

CConfig_Schema::~CConfig_Schema()
{
    if(CheckPointer(m_fields) == POINTER_DYNAMIC)
        delete m_fields;
}

/**
 * @brief Adds a field to the schema.
 * @param field The field definition to add.
 */
void CConfig_Schema::add_field(CConfig_Field* field)
{
    if(CheckPointer(field) != POINTER_INVALID)
        m_fields.Add(field);
}

/**
 * @brief Gets a field by its key.
 * @param key The field key.
 * @return The field or NULL if not found.
 */
CConfig_Field* CConfig_Schema::get_field(string key)
{
    for(int i = 0; i < m_fields.Total(); i++)
    {
        CConfig_Field* field = m_fields.At(i);
        if(field != NULL && field.m_key == key)
            return field;
    }
    return NULL;
}

/**
 * @brief Gets a field by its index.
 * @param index The field index.
 * @return The field or NULL if invalid index.
 */
CConfig_Field* CConfig_Schema::get_field_by_index(int index)
{
    if(index < 0 || index >= m_fields.Total())
        return NULL;
    return m_fields.At(index);
}

/**
 * @brief Gets the number of fields in the schema.
 * @return Field count.
 */
int CConfig_Schema::get_field_count()
{
    return m_fields.Total();
}

/**
 * @brief Gets all field keys.
 * @param keys Array to fill with keys.
 */
void CConfig_Schema::get_field_keys(string &keys[])
{
    ArrayResize(keys, m_fields.Total());
    for(int i = 0; i < m_fields.Total(); i++)
    {
        CConfig_Field* field = m_fields.At(i);
        if(field != NULL)
            keys[i] = field.m_key;
    }
}

/**
 * @brief Validates a string value against a field.
 */
bool CConfig_Schema::validate_field_value(string key, string value, string &reason)
{
    CConfig_Field* field = get_field(key);
    if(field == NULL)
    {
        reason = "Field not found: " + key;
        return false;
    }
    return field.validate_value(value, reason);
}

/**
 * @brief Validates an integer value against a field.
 */
bool CConfig_Schema::validate_field_value(string key, int value, string &reason)
{
    CConfig_Field* field = get_field(key);
    if(field == NULL)
    {
        reason = "Field not found: " + key;
        return false;
    }
    return field.validate_value(value, reason);
}

/**
 * @brief Validates a double value against a field.
 */
bool CConfig_Schema::validate_field_value(string key, double value, string &reason)
{
    CConfig_Field* field = get_field(key);
    if(field == NULL)
    {
        reason = "Field not found: " + key;
        return false;
    }
    return field.validate_value(value, reason);
}

/**
 * @brief Validates a boolean value against a field.
 */
bool CConfig_Schema::validate_field_value(string key, bool value, string &reason)
{
    CConfig_Field* field = get_field(key);
    if(field == NULL)
    {
        reason = "Field not found: " + key;
        return false;
    }
    return field.validate_value(value, reason);
}

/**
 * @brief Gets the default integer value for a field.
 */
int CConfig_Schema::get_default_int(string key)
{
    CConfig_Field* field = get_field(key);
    if(field != NULL)
        return field.m_default_int;
    return 0;
}

/**
 * @brief Gets the default double value for a field.
 */
double CConfig_Schema::get_default_double(string key)
{
    CConfig_Field* field = get_field(key);
    if(field != NULL)
        return field.m_default_double;
    return 0.0;
}

/**
 * @brief Gets the default boolean value for a field.
 */
bool CConfig_Schema::get_default_bool(string key)
{
    CConfig_Field* field = get_field(key);
    if(field != NULL)
        return field.m_default_bool;
    return false;
}

/**
 * @brief Gets the default string value for a field.
 */
string CConfig_Schema::get_default_string(string key)
{
    CConfig_Field* field = get_field(key);
    if(field != NULL)
        return field.m_default_string;
    return "";
}

/**
 * @brief Converts the schema to JSON.
 * @return JSON object matching robot_config_component_schema structure.
 */
CJAVal* CConfig_Schema::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    CJAVal* fields_arr = new CJAVal(JA_ARRAY);
    for(int i = 0; i < m_fields.Total(); i++)
    {
        CConfig_Field* field = m_fields.At(i);
        if(field != NULL)
            fields_arr.Add(field.to_json());
    }
    json.Add("fields", fields_arr);
    
    return json;
}

/**
 * @brief Converts the schema to a JSON string.
 * @return JSON string representation.
 */
string CConfig_Schema::to_json_string()
{
    CJAVal* json = to_json();
    if(json == NULL) return "";
    
    string result = json.to_string();
    delete json;
    return result;
}

#endif
//+------------------------------------------------------------------+

