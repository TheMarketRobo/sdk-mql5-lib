//+------------------------------------------------------------------+
//|                                                 CConfigField.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CCONFIG_FIELD_MQH
#define CCONFIG_FIELD_MQH

#include <Object.mqh>
#include <Arrays/ArrayObj.mqh>
#include "../Services/Json.mqh"

enum ENUM_TMKR_CONFIG_FIELD_TYPE
{
    TMKR_CONFIG_FIELD_INTEGER,
    TMKR_CONFIG_FIELD_DECIMAL,
    TMKR_CONFIG_FIELD_BOOLEAN,
    TMKR_CONFIG_FIELD_RADIO,
    TMKR_CONFIG_FIELD_MULTIPLE
};

enum ENUM_TMKR_DEPENDENCY_CONDITION
{
    TMKR_CONDITION_EQUALS,
    CONDITION_NOT_EQUALS,
    CONDITION_GREATER_THAN,
    CONDITION_LESS_THAN,
    CONDITION_GREATER_THAN_OR_EQUAL,
    CONDITION_LESS_THAN_OR_EQUAL,
    CONDITION_CONTAINS,
    CONDITION_NOT_CONTAINS
};

class CTMKR_ConfigOption : public CObject
{
public:
    string m_value;
    string m_label;
    double m_numeric_value;
    bool   m_is_numeric;
    
    CTMKR_ConfigOption();
    CTMKR_ConfigOption(string tmkr_value, string tmkr_label);
    CTMKR_ConfigOption(double tmkr_value, string tmkr_label);
    ~CTMKR_ConfigOption();
    CTMKR_JAVal* to_json();
};

CTMKR_ConfigOption::CConfigOption() : m_value(""), m_label(""), m_numeric_value(0), m_is_numeric(false) {}
CTMKR_ConfigOption::CConfigOption(string tmkr_value, string tmkr_label) : m_value(tmkr_value), m_label(tmkr_label), m_numeric_value(0), m_is_numeric(false) {}
CTMKR_ConfigOption::CConfigOption(double tmkr_value, string tmkr_label) : m_value(""), m_label(tmkr_label), m_numeric_value(tmkr_value), m_is_numeric(true) {}
CTMKR_ConfigOption::~CTMKR_ConfigOption() {}

CTMKR_JAVal* CTMKR_ConfigOption::to_json()
{
    CTMKR_JAVal* json = new CTMKR_JAVal(TMKR_JA_OBJECT);
    if(json == NULL) return NULL;
    CTMKR_JAVal* label_val = new CTMKR_JAVal(); label_val.set_string(m_label); json.Add("label", label_val);
    if(m_is_numeric) { CTMKR_JAVal* tmkr_v = new CTMKR_JAVal(); tmkr_v.set_double(m_numeric_value); json.Add("value", tmkr_v); }
    else { CTMKR_JAVal* tmkr_v = new CTMKR_JAVal(); tmkr_v.set_string(m_value); json.Add("value", tmkr_v); }
    return json;
}

class CTMKR_ConfigDependency : public CObject
{
public:
    string m_field;
    ENUM_TMKR_DEPENDENCY_CONDITION m_condition;
    string m_value_string;
    double m_value_numeric;
    bool   m_value_bool;
    int    m_value_type;
    
    CTMKR_ConfigDependency();
    ~CTMKR_ConfigDependency();
    void set_string_value(string field, ENUM_TMKR_DEPENDENCY_CONDITION condition, string tmkr_value);
    void set_numeric_value(string field, ENUM_TMKR_DEPENDENCY_CONDITION condition, double tmkr_value);
    void set_bool_value(string field, ENUM_TMKR_DEPENDENCY_CONDITION condition, bool tmkr_value);
    CTMKR_JAVal* to_json();
};

CTMKR_ConfigDependency::CConfigDependency() : m_field(""), m_condition(TMKR_CONDITION_EQUALS), m_value_string(""), m_value_numeric(0), m_value_bool(false), m_value_type(0) {}
CTMKR_ConfigDependency::~CTMKR_ConfigDependency() {}

void CTMKR_ConfigDependency::set_string_value(string field, ENUM_TMKR_DEPENDENCY_CONDITION condition, string tmkr_value) { m_field = field; m_condition = condition; m_value_string = tmkr_value; m_value_type = 0; }
void CTMKR_ConfigDependency::set_numeric_value(string field, ENUM_TMKR_DEPENDENCY_CONDITION condition, double tmkr_value) { m_field = field; m_condition = condition; m_value_numeric = tmkr_value; m_value_type = 1; }
void CTMKR_ConfigDependency::set_bool_value(string field, ENUM_TMKR_DEPENDENCY_CONDITION condition, bool tmkr_value) { m_field = field; m_condition = condition; m_value_bool = tmkr_value; m_value_type = 2; }

CTMKR_JAVal* CTMKR_ConfigDependency::to_json()
{
    CTMKR_JAVal* json = new CTMKR_JAVal(TMKR_JA_OBJECT);
    if(json == NULL) return NULL;
    CTMKR_JAVal* tmkr_f = new CTMKR_JAVal(); tmkr_f.set_string(m_field); json.Add("field", tmkr_f);
    string cond = "equals";
    switch(m_condition) { case CONDITION_NOT_EQUALS: cond = "notEquals"; break; case CONDITION_GREATER_THAN: cond = "greaterThan"; break; case CONDITION_LESS_THAN: cond = "lessThan"; break; }
    CTMKR_JAVal* tmkr_c = new CTMKR_JAVal(); tmkr_c.set_string(cond); json.Add("condition", tmkr_c);
    CTMKR_JAVal* tmkr_v = new CTMKR_JAVal();
    if(m_value_type == 0) tmkr_v.set_string(m_value_string); else if(m_value_type == 1) tmkr_v.set_double(m_value_numeric); else tmkr_v.set_bool(m_value_bool);
    json.Add("value", tmkr_v);
    return json;
}

class CTMKR_ConfigField : public CObject
{
public:
    ENUM_TMKR_CONFIG_FIELD_TYPE m_type;
    string m_key;
    string m_label;
    bool   m_required;
    int    m_default_int;
    double m_default_double;
    bool   m_default_bool;
    string m_default_string;
    string m_default_array[];
    string m_description;
    string m_placeholder;
    string m_tooltip;
    string m_group;
    int    m_order;
    bool   m_disabled;
    bool   m_hidden;
    double m_minimum;
    double m_maximum;
    double m_step;
    int    m_precision;
    bool   m_has_minimum;
    bool   m_has_maximum;
    CArrayObj* m_options;
    int    m_min_selections;
    int    m_max_selections;
    CTMKR_ConfigDependency* m_depends_on;

    CTMKR_ConfigField();
    ~CTMKR_ConfigField();
    
    static CTMKR_ConfigField* create_integer(string tmkr_key, string tmkr_label, bool required, int default_value);
    static CTMKR_ConfigField* create_decimal(string tmkr_key, string tmkr_label, bool required, double default_value);
    static CTMKR_ConfigField* create_boolean(string tmkr_key, string tmkr_label, bool required, bool default_value);
    static CTMKR_ConfigField* create_radio(string tmkr_key, string tmkr_label, bool required, string default_value);
    static CTMKR_ConfigField* create_multiple(string tmkr_key, string tmkr_label, bool required);
    
    CTMKR_ConfigField* with_description(string description);
    CTMKR_ConfigField* with_placeholder(string placeholder);
    CTMKR_ConfigField* with_tooltip(string tooltip);
    CTMKR_ConfigField* with_group(string group, int tmkr_order);
    CTMKR_ConfigField* with_disabled(bool disabled);
    CTMKR_ConfigField* with_hidden(bool hidden);
    CTMKR_ConfigField* with_range(double min_val, double max_val);
    CTMKR_ConfigField* with_step(double step_val);
    CTMKR_ConfigField* with_precision(int precision_val);
    CTMKR_ConfigField* with_option(string tmkr_value, string tmkr_label);
    CTMKR_ConfigField* with_option_numeric(double tmkr_value, string tmkr_label);
    CTMKR_ConfigField* with_selection_limits(int min_sel, int max_sel);
    CTMKR_ConfigField* with_default_selections(string &selections[]);
    CTMKR_ConfigField* with_depends_on(CTMKR_ConfigDependency* dependency);
    
    bool validate_value(string tmkr_value, string &tmkr_reason);
    bool validate_value(int tmkr_value, string &tmkr_reason);
    bool validate_value(double tmkr_value, string &tmkr_reason);
    bool validate_value(bool tmkr_value, string &tmkr_reason);
    CTMKR_JAVal* to_json();
};

CTMKR_ConfigField::CConfigField()
{
    m_type = TMKR_CONFIG_FIELD_INTEGER; m_key = ""; m_label = ""; m_required = true;
    m_default_int = 0; m_default_double = 0.0; m_default_bool = false; m_default_string = "";
    m_description = ""; m_placeholder = ""; m_tooltip = ""; m_group = ""; m_order = 0;
    m_disabled = false; m_hidden = false;
    m_minimum = 0; m_maximum = 0; m_step = 1; m_precision = 2;
    m_has_minimum = false; m_has_maximum = false;
    m_options = new CArrayObj(); m_min_selections = 0; m_max_selections = 0;
    m_depends_on = NULL;
}

CTMKR_ConfigField::~CTMKR_ConfigField()
{
    if(CheckPointer(m_options) == POINTER_DYNAMIC) { m_options.FreeMode(true); delete m_options; }
    if(CheckPointer(m_depends_on) == POINTER_DYNAMIC) delete m_depends_on;
}

CTMKR_ConfigField* CTMKR_ConfigField::create_integer(string tmkr_key, string tmkr_label, bool required, int default_value)
{
    CTMKR_ConfigField* tmkr_f = new CTMKR_ConfigField(); tmkr_f.m_type = TMKR_CONFIG_FIELD_INTEGER; tmkr_f.m_key = tmkr_key; tmkr_f.m_label = tmkr_label; tmkr_f.m_required = required; tmkr_f.m_default_int = default_value; tmkr_f.m_step = 1; return tmkr_f;
}

CTMKR_ConfigField* CTMKR_ConfigField::create_decimal(string tmkr_key, string tmkr_label, bool required, double default_value)
{
    CTMKR_ConfigField* tmkr_f = new CTMKR_ConfigField(); tmkr_f.m_type = TMKR_CONFIG_FIELD_DECIMAL; tmkr_f.m_key = tmkr_key; tmkr_f.m_label = tmkr_label; tmkr_f.m_required = required; tmkr_f.m_default_double = default_value; tmkr_f.m_step = 0.01; tmkr_f.m_precision = 2; return tmkr_f;
}

CTMKR_ConfigField* CTMKR_ConfigField::create_boolean(string tmkr_key, string tmkr_label, bool required, bool default_value)
{
    CTMKR_ConfigField* tmkr_f = new CTMKR_ConfigField(); tmkr_f.m_type = TMKR_CONFIG_FIELD_BOOLEAN; tmkr_f.m_key = tmkr_key; tmkr_f.m_label = tmkr_label; tmkr_f.m_required = required; tmkr_f.m_default_bool = default_value; return tmkr_f;
}

CTMKR_ConfigField* CTMKR_ConfigField::create_radio(string tmkr_key, string tmkr_label, bool required, string default_value)
{
    CTMKR_ConfigField* tmkr_f = new CTMKR_ConfigField(); tmkr_f.m_type = TMKR_CONFIG_FIELD_RADIO; tmkr_f.m_key = tmkr_key; tmkr_f.m_label = tmkr_label; tmkr_f.m_required = required; tmkr_f.m_default_string = default_value; return tmkr_f;
}

CTMKR_ConfigField* CTMKR_ConfigField::create_multiple(string tmkr_key, string tmkr_label, bool required)
{
    CTMKR_ConfigField* tmkr_f = new CTMKR_ConfigField(); tmkr_f.m_type = TMKR_CONFIG_FIELD_MULTIPLE; tmkr_f.m_key = tmkr_key; tmkr_f.m_label = tmkr_label; tmkr_f.m_required = required; return tmkr_f;
}

CTMKR_ConfigField* CTMKR_ConfigField::with_description(string description) { m_description = description; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_placeholder(string placeholder) { m_placeholder = placeholder; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_tooltip(string tooltip) { m_tooltip = tooltip; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_group(string group, int tmkr_order) { m_group = group; m_order = tmkr_order; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_disabled(bool disabled) { m_disabled = disabled; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_hidden(bool hidden) { m_hidden = hidden; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_range(double min_val, double max_val) { m_minimum = min_val; m_maximum = max_val; m_has_minimum = true; m_has_maximum = true; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_step(double step_val) { m_step = step_val; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_precision(int precision_val) { m_precision = precision_val; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_option(string tmkr_value, string tmkr_label) { m_options.Add(new CTMKR_ConfigOption(tmkr_value, tmkr_label)); return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_option_numeric(double tmkr_value, string tmkr_label) { m_options.Add(new CTMKR_ConfigOption(tmkr_value, tmkr_label)); return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_selection_limits(int min_sel, int max_sel) { m_min_selections = min_sel; m_max_selections = max_sel; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_default_selections(string &selections[]) { ArrayResize(m_default_array, ArraySize(selections)); for(int tmkr_i = 0; tmkr_i < ArraySize(selections); tmkr_i++) m_default_array[tmkr_i] = selections[tmkr_i]; return GetPointer(this); }
CTMKR_ConfigField* CTMKR_ConfigField::with_depends_on(CTMKR_ConfigDependency* dependency) { if(CheckPointer(m_depends_on) == POINTER_DYNAMIC) delete m_depends_on; m_depends_on = dependency; return GetPointer(this); }

bool CTMKR_ConfigField::validate_value(int tmkr_value, string &tmkr_reason)
{
    if(m_type != TMKR_CONFIG_FIELD_INTEGER) { tmkr_reason = "Field type mismatch"; return false; }
    if(m_has_minimum && tmkr_value < (int)m_minimum) { tmkr_reason = StringFormat("Value %d is below minimum %d", tmkr_value, (int)m_minimum); return false; }
    if(m_has_maximum && tmkr_value > (int)m_maximum) { tmkr_reason = StringFormat("Value %d is above maximum %d", tmkr_value, (int)m_maximum); return false; }
    return true;
}

bool CTMKR_ConfigField::validate_value(double tmkr_value, string &tmkr_reason)
{
    if(m_type != TMKR_CONFIG_FIELD_DECIMAL) { tmkr_reason = "Field type mismatch"; return false; }
    if(m_has_minimum && tmkr_value < m_minimum) { tmkr_reason = StringFormat("Value %.2f is below minimum %.2f", tmkr_value, m_minimum); return false; }
    if(m_has_maximum && tmkr_value > m_maximum) { tmkr_reason = StringFormat("Value %.2f is above maximum %.2f", tmkr_value, m_maximum); return false; }
    return true;
}

bool CTMKR_ConfigField::validate_value(bool tmkr_value, string &tmkr_reason) { if(m_type != TMKR_CONFIG_FIELD_BOOLEAN) { tmkr_reason = "Field type mismatch"; return false; } return true; }

bool CTMKR_ConfigField::validate_value(string tmkr_value, string &tmkr_reason)
{
    if(m_type == TMKR_CONFIG_FIELD_RADIO)
    {
        for(int tmkr_i = 0; tmkr_i < m_options.Total(); tmkr_i++) { CTMKR_ConfigOption* tmkr_o = m_options.At(tmkr_i); if(tmkr_o.m_value == tmkr_value) return true; }
        tmkr_reason = StringFormat("Value '%s' is not a valid option", tmkr_value); return false;
    }
    return true;
}

CTMKR_JAVal* CTMKR_ConfigField::to_json()
{
    CTMKR_JAVal* tmkr_j = new CTMKR_JAVal(TMKR_JA_OBJECT); if(tmkr_j == NULL) return NULL;
    string tmkr_ts = ""; switch(m_type) { case TMKR_CONFIG_FIELD_INTEGER: tmkr_ts = "integer"; break; case TMKR_CONFIG_FIELD_DECIMAL: tmkr_ts = "decimal"; break; case TMKR_CONFIG_FIELD_BOOLEAN: tmkr_ts = "boolean"; break; case TMKR_CONFIG_FIELD_RADIO: tmkr_ts = "radio"; break; case TMKR_CONFIG_FIELD_MULTIPLE: tmkr_ts = "multiple"; break; }
    CTMKR_JAVal* tv = new CTMKR_JAVal(); tv.set_string(tmkr_ts); tmkr_j.Add("type", tv);
    CTMKR_JAVal* kv = new CTMKR_JAVal(); kv.set_string(m_key); tmkr_j.Add("key", kv);
    CTMKR_JAVal* lv = new CTMKR_JAVal(); lv.set_string(m_label); tmkr_j.Add("label", lv);
    CTMKR_JAVal* rv = new CTMKR_JAVal(); rv.set_bool(m_required); tmkr_j.Add("required", rv);
    CTMKR_JAVal* dv = new CTMKR_JAVal();
    switch(m_type) { case TMKR_CONFIG_FIELD_INTEGER: dv.set_long(m_default_int); break; case TMKR_CONFIG_FIELD_DECIMAL: dv.set_double(m_default_double); break; case TMKR_CONFIG_FIELD_BOOLEAN: dv.set_bool(m_default_bool); break; case TMKR_CONFIG_FIELD_RADIO: dv.set_string(m_default_string); break; case TMKR_CONFIG_FIELD_MULTIPLE: delete dv; dv = new CTMKR_JAVal(TMKR_JA_ARRAY); for(int tmkr_i = 0; tmkr_i < ArraySize(m_default_array); tmkr_i++) { CTMKR_JAVal* it = new CTMKR_JAVal(); it.set_string(m_default_array[tmkr_i]); dv.Add(it); } break; }
    tmkr_j.Add("default", dv);
    if(m_description != "") { CTMKR_JAVal* dsc = new CTMKR_JAVal(); dsc.set_string(m_description); tmkr_j.Add("description", dsc); }
    if(m_group != "") { CTMKR_JAVal* gv = new CTMKR_JAVal(); gv.set_string(m_group); tmkr_j.Add("group", gv); CTMKR_JAVal* ov = new CTMKR_JAVal(); ov.set_long(m_order); tmkr_j.Add("order", ov); }
    if(m_type == TMKR_CONFIG_FIELD_INTEGER || m_type == TMKR_CONFIG_FIELD_DECIMAL)
    {
        if(m_has_minimum) { CTMKR_JAVal* mv = new CTMKR_JAVal(); if(m_type == TMKR_CONFIG_FIELD_INTEGER) mv.set_long((int)m_minimum); else mv.set_double(m_minimum); tmkr_j.Add("minimum", mv); }
        if(m_has_maximum) { CTMKR_JAVal* mv = new CTMKR_JAVal(); if(m_type == TMKR_CONFIG_FIELD_INTEGER) mv.set_long((int)m_maximum); else mv.set_double(m_maximum); tmkr_j.Add("maximum", mv); }
        CTMKR_JAVal* sv = new CTMKR_JAVal(); if(m_type == TMKR_CONFIG_FIELD_INTEGER) sv.set_long((int)m_step); else sv.set_double(m_step); tmkr_j.Add("step", sv);
        if(m_type == TMKR_CONFIG_FIELD_DECIMAL) { CTMKR_JAVal* pv = new CTMKR_JAVal(); pv.set_long(m_precision); tmkr_j.Add("precision", pv); }
    }
    if(m_type == TMKR_CONFIG_FIELD_RADIO || m_type == TMKR_CONFIG_FIELD_MULTIPLE)
    {
        CTMKR_JAVal* oa = new CTMKR_JAVal(TMKR_JA_ARRAY); for(int tmkr_i = 0; tmkr_i < m_options.Total(); tmkr_i++) { CTMKR_ConfigOption* tmkr_o = m_options.At(tmkr_i); oa.Add(tmkr_o.to_json()); } tmkr_j.Add("options", oa);
        if(m_type == TMKR_CONFIG_FIELD_MULTIPLE) { if(m_min_selections > 0) { CTMKR_JAVal* ms = new CTMKR_JAVal(); ms.set_long(m_min_selections); tmkr_j.Add("minSelections", ms); } if(m_max_selections > 0) { CTMKR_JAVal* ms = new CTMKR_JAVal(); ms.set_long(m_max_selections); tmkr_j.Add("maxSelections", ms); } }
    }
    if(CheckPointer(m_depends_on) != POINTER_INVALID) tmkr_j.Add("dependsOn", m_depends_on.to_json());
    return tmkr_j;
}

#endif
//+------------------------------------------------------------------+

