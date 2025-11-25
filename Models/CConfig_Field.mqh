//+------------------------------------------------------------------+
//|                                               CConfig_Field.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CCONFIG_FIELD_MQH
#define CCONFIG_FIELD_MQH

#include <Object.mqh>
#include <Arrays/ArrayObj.mqh>
#include "../Services/Json.mqh"

//+------------------------------------------------------------------+
//| Field Type Enumeration                                          |
//+------------------------------------------------------------------+
/**
 * @enum ENUM_CONFIG_FIELD_TYPE
 * @brief Configuration field types matching robot_config_component_schema/v1.json
 */
enum ENUM_CONFIG_FIELD_TYPE
{
    CONFIG_FIELD_INTEGER,    // Whole number input
    CONFIG_FIELD_DECIMAL,    // Floating point input
    CONFIG_FIELD_BOOLEAN,    // True/false toggle
    CONFIG_FIELD_RADIO,      // Single choice from options
    CONFIG_FIELD_MULTIPLE    // Multiple choice from options
};

//+------------------------------------------------------------------+
//| Dependency Condition Enumeration                                 |
//+------------------------------------------------------------------+
/**
 * @enum ENUM_DEPENDENCY_CONDITION
 * @brief Conditions for field dependencies (dependsOn)
 */
enum ENUM_DEPENDENCY_CONDITION
{
    CONDITION_EQUALS,
    CONDITION_NOT_EQUALS,
    CONDITION_GREATER_THAN,
    CONDITION_LESS_THAN,
    CONDITION_GREATER_THAN_OR_EQUAL,
    CONDITION_LESS_THAN_OR_EQUAL,
    CONDITION_CONTAINS,
    CONDITION_NOT_CONTAINS
};

//+------------------------------------------------------------------+
//| CConfig_Option Class                                             |
//+------------------------------------------------------------------+
/**
 * @class CConfig_Option
 * @brief Represents an option for radio/multiple fields.
 */
class CConfig_Option : public CObject
{
public:
    string m_value;        // Option value (used in config)
    string m_label;        // Display label for option
    double m_numeric_value; // For numeric option values
    bool   m_is_numeric;   // Whether value is numeric
    
    CConfig_Option();
    CConfig_Option(string value, string label);
    CConfig_Option(double value, string label);
    ~CConfig_Option();
    
    CJAVal* to_json();
};

//+------------------------------------------------------------------+
CConfig_Option::CConfig_Option()
{
    m_value = "";
    m_label = "";
    m_numeric_value = 0;
    m_is_numeric = false;
}

CConfig_Option::CConfig_Option(string value, string label)
{
    m_value = value;
    m_label = label;
    m_numeric_value = 0;
    m_is_numeric = false;
}

CConfig_Option::CConfig_Option(double value, string label)
{
    m_value = "";
    m_label = label;
    m_numeric_value = value;
    m_is_numeric = true;
}

CConfig_Option::~CConfig_Option() {}

CJAVal* CConfig_Option::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    CJAVal* label_val = new CJAVal();
    label_val.set_string(m_label);
    json.Add("label", label_val);
    
    if(m_is_numeric)
    {
        CJAVal* value_val = new CJAVal();
        value_val.set_double(m_numeric_value);
        json.Add("value", value_val);
    }
    else
    {
        CJAVal* value_val = new CJAVal();
        value_val.set_string(m_value);
        json.Add("value", value_val);
    }
    
    return json;
}

//+------------------------------------------------------------------+
//| CConfig_Dependency Class                                         |
//+------------------------------------------------------------------+
/**
 * @class CConfig_Dependency
 * @brief Represents a field dependency (dependsOn).
 */
class CConfig_Dependency : public CObject
{
public:
    string m_field;                        // Key of field this depends on
    ENUM_DEPENDENCY_CONDITION m_condition; // Comparison condition
    string m_value_string;                 // Value to compare (string)
    double m_value_numeric;                // Value to compare (numeric)
    bool   m_value_bool;                   // Value to compare (boolean)
    int    m_value_type;                   // 0=string, 1=numeric, 2=bool
    
    CConfig_Dependency();
    ~CConfig_Dependency();
    
    void set_string_value(string field, ENUM_DEPENDENCY_CONDITION condition, string value);
    void set_numeric_value(string field, ENUM_DEPENDENCY_CONDITION condition, double value);
    void set_bool_value(string field, ENUM_DEPENDENCY_CONDITION condition, bool value);
    
    bool evaluate(string current_value);
    bool evaluate(double current_value);
    bool evaluate(bool current_value);
    
    CJAVal* to_json();
};

//+------------------------------------------------------------------+
CConfig_Dependency::CConfig_Dependency()
{
    m_field = "";
    m_condition = CONDITION_EQUALS;
    m_value_string = "";
    m_value_numeric = 0;
    m_value_bool = false;
    m_value_type = 0;
}

CConfig_Dependency::~CConfig_Dependency() {}

void CConfig_Dependency::set_string_value(string field, ENUM_DEPENDENCY_CONDITION condition, string value)
{
    m_field = field;
    m_condition = condition;
    m_value_string = value;
    m_value_type = 0;
}

void CConfig_Dependency::set_numeric_value(string field, ENUM_DEPENDENCY_CONDITION condition, double value)
{
    m_field = field;
    m_condition = condition;
    m_value_numeric = value;
    m_value_type = 1;
}

void CConfig_Dependency::set_bool_value(string field, ENUM_DEPENDENCY_CONDITION condition, bool value)
{
    m_field = field;
    m_condition = condition;
    m_value_bool = value;
    m_value_type = 2;
}

bool CConfig_Dependency::evaluate(string current_value)
{
    switch(m_condition)
    {
        case CONDITION_EQUALS:     return current_value == m_value_string;
        case CONDITION_NOT_EQUALS: return current_value != m_value_string;
        default: return false;
    }
}

bool CConfig_Dependency::evaluate(double current_value)
{
    switch(m_condition)
    {
        case CONDITION_EQUALS:               return current_value == m_value_numeric;
        case CONDITION_NOT_EQUALS:           return current_value != m_value_numeric;
        case CONDITION_GREATER_THAN:         return current_value > m_value_numeric;
        case CONDITION_LESS_THAN:            return current_value < m_value_numeric;
        case CONDITION_GREATER_THAN_OR_EQUAL: return current_value >= m_value_numeric;
        case CONDITION_LESS_THAN_OR_EQUAL:   return current_value <= m_value_numeric;
        default: return false;
    }
}

bool CConfig_Dependency::evaluate(bool current_value)
{
    switch(m_condition)
    {
        case CONDITION_EQUALS:     return current_value == m_value_bool;
        case CONDITION_NOT_EQUALS: return current_value != m_value_bool;
        default: return false;
    }
}

CJAVal* CConfig_Dependency::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    CJAVal* field_val = new CJAVal();
    field_val.set_string(m_field);
    json.Add("field", field_val);
    
    CJAVal* condition_val = new CJAVal();
    string condition_str = "";
    switch(m_condition)
    {
        case CONDITION_EQUALS:               condition_str = "equals"; break;
        case CONDITION_NOT_EQUALS:           condition_str = "notEquals"; break;
        case CONDITION_GREATER_THAN:         condition_str = "greaterThan"; break;
        case CONDITION_LESS_THAN:            condition_str = "lessThan"; break;
        case CONDITION_GREATER_THAN_OR_EQUAL: condition_str = "greaterThanOrEqual"; break;
        case CONDITION_LESS_THAN_OR_EQUAL:   condition_str = "lessThanOrEqual"; break;
        case CONDITION_CONTAINS:             condition_str = "contains"; break;
        case CONDITION_NOT_CONTAINS:         condition_str = "notContains"; break;
    }
    condition_val.set_string(condition_str);
    json.Add("condition", condition_val);
    
    CJAVal* value_val = new CJAVal();
    switch(m_value_type)
    {
        case 0: value_val.set_string(m_value_string); break;
        case 1: value_val.set_double(m_value_numeric); break;
        case 2: value_val.set_bool(m_value_bool); break;
    }
    json.Add("value", value_val);
    
    return json;
}

//+------------------------------------------------------------------+
//| CConfig_Field Class                                              |
//+------------------------------------------------------------------+
/**
 * @class CConfig_Field
 * @brief Represents a configuration field definition.
 *
 * This class mirrors the field structure in robot_config_component_schema/v1.json.
 * Programmers use this to define their robot's configurable parameters.
 */
class CConfig_Field : public CObject
{
public:
    // Required properties
    ENUM_CONFIG_FIELD_TYPE m_type;
    string m_key;
    string m_label;
    bool   m_required;
    
    // Default values (type-specific)
    int    m_default_int;
    double m_default_double;
    bool   m_default_bool;
    string m_default_string;
    string m_default_array[];  // For multiple type
    
    // Optional common properties
    string m_description;
    string m_placeholder;
    string m_tooltip;
    string m_group;
    int    m_order;
    bool   m_disabled;
    bool   m_hidden;
    
    // Integer/Decimal specific
    double m_minimum;
    double m_maximum;
    double m_step;
    int    m_precision;  // Decimal only
    bool   m_has_minimum;
    bool   m_has_maximum;
    
    // Radio/Multiple specific
    CArrayObj* m_options;
    int    m_min_selections;  // Multiple only
    int    m_max_selections;  // Multiple only
    
    // Dependency
    CConfig_Dependency* m_depends_on;

public:
    CConfig_Field();
    ~CConfig_Field();
    
    // Factory methods for creating fields
    static CConfig_Field* create_integer(string key, string label, bool required, int default_value);
    static CConfig_Field* create_decimal(string key, string label, bool required, double default_value);
    static CConfig_Field* create_boolean(string key, string label, bool required, bool default_value);
    static CConfig_Field* create_radio(string key, string label, bool required, string default_value);
    static CConfig_Field* create_multiple(string key, string label, bool required);
    
    // Fluent setters for optional properties
    CConfig_Field* with_description(string description);
    CConfig_Field* with_placeholder(string placeholder);
    CConfig_Field* with_tooltip(string tooltip);
    CConfig_Field* with_group(string group, int order);
    CConfig_Field* with_disabled(bool disabled);
    CConfig_Field* with_hidden(bool hidden);
    CConfig_Field* with_range(double min_val, double max_val);
    CConfig_Field* with_step(double step_val);
    CConfig_Field* with_precision(int precision_val);
    CConfig_Field* with_option(string value, string label);
    CConfig_Field* with_option_numeric(double value, string label);
    CConfig_Field* with_selection_limits(int min_sel, int max_sel);
    CConfig_Field* with_default_selections(string &selections[]);
    CConfig_Field* with_depends_on(CConfig_Dependency* dependency);
    
    // Validation
    bool validate_value(string value, string &reason);
    bool validate_value(int value, string &reason);
    bool validate_value(double value, string &reason);
    bool validate_value(bool value, string &reason);
    
    // Serialization
    CJAVal* to_json();
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CConfig_Field::CConfig_Field()
{
    m_type = CONFIG_FIELD_INTEGER;
    m_key = "";
    m_label = "";
    m_required = true;
    
    m_default_int = 0;
    m_default_double = 0.0;
    m_default_bool = false;
    m_default_string = "";
    
    m_description = "";
    m_placeholder = "";
    m_tooltip = "";
    m_group = "";
    m_order = 0;
    m_disabled = false;
    m_hidden = false;
    
    m_minimum = 0;
    m_maximum = 0;
    m_step = 1;
    m_precision = 2;
    m_has_minimum = false;
    m_has_maximum = false;
    
    m_options = new CArrayObj();
    m_min_selections = 0;
    m_max_selections = 0;
    
    m_depends_on = NULL;
}

CConfig_Field::~CConfig_Field()
{
    if(CheckPointer(m_options) == POINTER_DYNAMIC)
    {
        m_options.FreeMode(true);
        delete m_options;
    }
    if(CheckPointer(m_depends_on) == POINTER_DYNAMIC)
        delete m_depends_on;
}

//+------------------------------------------------------------------+
//| Factory Methods                                                  |
//+------------------------------------------------------------------+
CConfig_Field* CConfig_Field::create_integer(string key, string label, bool required, int default_value)
{
    CConfig_Field* field = new CConfig_Field();
    field.m_type = CONFIG_FIELD_INTEGER;
    field.m_key = key;
    field.m_label = label;
    field.m_required = required;
    field.m_default_int = default_value;
    field.m_step = 1;
    return field;
}

CConfig_Field* CConfig_Field::create_decimal(string key, string label, bool required, double default_value)
{
    CConfig_Field* field = new CConfig_Field();
    field.m_type = CONFIG_FIELD_DECIMAL;
    field.m_key = key;
    field.m_label = label;
    field.m_required = required;
    field.m_default_double = default_value;
    field.m_step = 0.01;
    field.m_precision = 2;
    return field;
}

CConfig_Field* CConfig_Field::create_boolean(string key, string label, bool required, bool default_value)
{
    CConfig_Field* field = new CConfig_Field();
    field.m_type = CONFIG_FIELD_BOOLEAN;
    field.m_key = key;
    field.m_label = label;
    field.m_required = required;
    field.m_default_bool = default_value;
    return field;
}

CConfig_Field* CConfig_Field::create_radio(string key, string label, bool required, string default_value)
{
    CConfig_Field* field = new CConfig_Field();
    field.m_type = CONFIG_FIELD_RADIO;
    field.m_key = key;
    field.m_label = label;
    field.m_required = required;
    field.m_default_string = default_value;
    return field;
}

CConfig_Field* CConfig_Field::create_multiple(string key, string label, bool required)
{
    CConfig_Field* field = new CConfig_Field();
    field.m_type = CONFIG_FIELD_MULTIPLE;
    field.m_key = key;
    field.m_label = label;
    field.m_required = required;
    return field;
}

//+------------------------------------------------------------------+
//| Fluent Setters                                                   |
//+------------------------------------------------------------------+
CConfig_Field* CConfig_Field::with_description(string description)
{
    m_description = description;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_placeholder(string placeholder)
{
    m_placeholder = placeholder;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_tooltip(string tooltip)
{
    m_tooltip = tooltip;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_group(string group, int order)
{
    m_group = group;
    m_order = order;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_disabled(bool disabled)
{
    m_disabled = disabled;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_hidden(bool hidden)
{
    m_hidden = hidden;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_range(double min_val, double max_val)
{
    m_minimum = min_val;
    m_maximum = max_val;
    m_has_minimum = true;
    m_has_maximum = true;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_step(double step_val)
{
    m_step = step_val;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_precision(int precision_val)
{
    m_precision = precision_val;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_option(string value, string label)
{
    CConfig_Option* option = new CConfig_Option(value, label);
    m_options.Add(option);
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_option_numeric(double value, string label)
{
    CConfig_Option* option = new CConfig_Option(value, label);
    m_options.Add(option);
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_selection_limits(int min_sel, int max_sel)
{
    m_min_selections = min_sel;
    m_max_selections = max_sel;
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_default_selections(string &selections[])
{
    ArrayResize(m_default_array, ArraySize(selections));
    for(int i = 0; i < ArraySize(selections); i++)
        m_default_array[i] = selections[i];
    return GetPointer(this);
}

CConfig_Field* CConfig_Field::with_depends_on(CConfig_Dependency* dependency)
{
    if(CheckPointer(m_depends_on) == POINTER_DYNAMIC)
        delete m_depends_on;
    m_depends_on = dependency;
    return GetPointer(this);
}

//+------------------------------------------------------------------+
//| Validation                                                       |
//+------------------------------------------------------------------+
bool CConfig_Field::validate_value(int value, string &reason)
{
    if(m_type != CONFIG_FIELD_INTEGER)
    {
        reason = "Field type mismatch: expected integer";
        return false;
    }
    
    if(m_has_minimum && value < (int)m_minimum)
    {
        reason = StringFormat("Value %d is below minimum %d", value, (int)m_minimum);
        return false;
    }
    
    if(m_has_maximum && value > (int)m_maximum)
    {
        reason = StringFormat("Value %d is above maximum %d", value, (int)m_maximum);
        return false;
    }
    
    return true;
}

bool CConfig_Field::validate_value(double value, string &reason)
{
    if(m_type != CONFIG_FIELD_DECIMAL)
    {
        reason = "Field type mismatch: expected decimal";
        return false;
    }
    
    if(m_has_minimum && value < m_minimum)
    {
        reason = StringFormat("Value %.2f is below minimum %.2f", value, m_minimum);
        return false;
    }
    
    if(m_has_maximum && value > m_maximum)
    {
        reason = StringFormat("Value %.2f is above maximum %.2f", value, m_maximum);
        return false;
    }
    
    return true;
}

bool CConfig_Field::validate_value(bool value, string &reason)
{
    if(m_type != CONFIG_FIELD_BOOLEAN)
    {
        reason = "Field type mismatch: expected boolean";
        return false;
    }
    return true;
}

bool CConfig_Field::validate_value(string value, string &reason)
{
    if(m_type == CONFIG_FIELD_RADIO)
    {
        // Check if value is in options
        for(int i = 0; i < m_options.Total(); i++)
        {
            CConfig_Option* opt = m_options.At(i);
            if(opt.m_value == value)
                return true;
        }
        reason = StringFormat("Value '%s' is not a valid option", value);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Serialization                                                    |
//+------------------------------------------------------------------+
CJAVal* CConfig_Field::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    // Type
    CJAVal* type_val = new CJAVal();
    string type_str = "";
    switch(m_type)
    {
        case CONFIG_FIELD_INTEGER:  type_str = "integer"; break;
        case CONFIG_FIELD_DECIMAL:  type_str = "decimal"; break;
        case CONFIG_FIELD_BOOLEAN:  type_str = "boolean"; break;
        case CONFIG_FIELD_RADIO:    type_str = "radio"; break;
        case CONFIG_FIELD_MULTIPLE: type_str = "multiple"; break;
    }
    type_val.set_string(type_str);
    json.Add("type", type_val);
    
    // Key
    CJAVal* key_val = new CJAVal();
    key_val.set_string(m_key);
    json.Add("key", key_val);
    
    // Label
    CJAVal* label_val = new CJAVal();
    label_val.set_string(m_label);
    json.Add("label", label_val);
    
    // Required
    CJAVal* req_val = new CJAVal();
    req_val.set_bool(m_required);
    json.Add("required", req_val);
    
    // Default value
    CJAVal* default_val = new CJAVal();
    switch(m_type)
    {
        case CONFIG_FIELD_INTEGER:
            default_val.set_long(m_default_int);
            break;
        case CONFIG_FIELD_DECIMAL:
            default_val.set_double(m_default_double);
            break;
        case CONFIG_FIELD_BOOLEAN:
            default_val.set_bool(m_default_bool);
            break;
        case CONFIG_FIELD_RADIO:
            default_val.set_string(m_default_string);
            break;
        case CONFIG_FIELD_MULTIPLE:
            // Array of strings
            delete default_val;
            default_val = new CJAVal(JA_ARRAY);
            for(int i = 0; i < ArraySize(m_default_array); i++)
            {
                CJAVal* item = new CJAVal();
                item.set_string(m_default_array[i]);
                default_val.Add(item);
            }
            break;
    }
    json.Add("default", default_val);
    
    // Optional properties
    if(m_description != "")
    {
        CJAVal* desc_val = new CJAVal();
        desc_val.set_string(m_description);
        json.Add("description", desc_val);
    }
    
    if(m_group != "")
    {
        CJAVal* group_val = new CJAVal();
        group_val.set_string(m_group);
        json.Add("group", group_val);
        
        CJAVal* order_val = new CJAVal();
        order_val.set_long(m_order);
        json.Add("order", order_val);
    }
    
    // Type-specific properties
    if(m_type == CONFIG_FIELD_INTEGER || m_type == CONFIG_FIELD_DECIMAL)
    {
        if(m_has_minimum)
        {
            CJAVal* min_val = new CJAVal();
            if(m_type == CONFIG_FIELD_INTEGER)
                min_val.set_long((int)m_minimum);
            else
                min_val.set_double(m_minimum);
            json.Add("minimum", min_val);
        }
        
        if(m_has_maximum)
        {
            CJAVal* max_val = new CJAVal();
            if(m_type == CONFIG_FIELD_INTEGER)
                max_val.set_long((int)m_maximum);
            else
                max_val.set_double(m_maximum);
            json.Add("maximum", max_val);
        }
        
        CJAVal* step_val = new CJAVal();
        if(m_type == CONFIG_FIELD_INTEGER)
            step_val.set_long((int)m_step);
        else
            step_val.set_double(m_step);
        json.Add("step", step_val);
        
        if(m_type == CONFIG_FIELD_DECIMAL)
        {
            CJAVal* prec_val = new CJAVal();
            prec_val.set_long(m_precision);
            json.Add("precision", prec_val);
        }
    }
    
    // Options for radio/multiple
    if(m_type == CONFIG_FIELD_RADIO || m_type == CONFIG_FIELD_MULTIPLE)
    {
        CJAVal* options_arr = new CJAVal(JA_ARRAY);
        for(int i = 0; i < m_options.Total(); i++)
        {
            CConfig_Option* opt = m_options.At(i);
            options_arr.Add(opt.to_json());
        }
        json.Add("options", options_arr);
        
        if(m_type == CONFIG_FIELD_MULTIPLE)
        {
            if(m_min_selections > 0)
            {
                CJAVal* min_sel = new CJAVal();
                min_sel.set_long(m_min_selections);
                json.Add("minSelections", min_sel);
            }
            if(m_max_selections > 0)
            {
                CJAVal* max_sel = new CJAVal();
                max_sel.set_long(m_max_selections);
                json.Add("maxSelections", max_sel);
            }
        }
    }
    
    // Dependency
    if(CheckPointer(m_depends_on) != POINTER_INVALID)
    {
        json.Add("dependsOn", m_depends_on.to_json());
    }
    
    return json;
}

#endif
//+------------------------------------------------------------------+

