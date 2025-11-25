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

enum ENUM_CONFIG_FIELD_TYPE
{
    CONFIG_FIELD_INTEGER,
    CONFIG_FIELD_DECIMAL,
    CONFIG_FIELD_BOOLEAN,
    CONFIG_FIELD_RADIO,
    CONFIG_FIELD_MULTIPLE
};

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

class CConfigOption : public CObject
{
public:
    string m_value;
    string m_label;
    double m_numeric_value;
    bool   m_is_numeric;
    
    CConfigOption();
    CConfigOption(string value, string label);
    CConfigOption(double value, string label);
    ~CConfigOption();
    CJAVal* to_json();
};

CConfigOption::CConfigOption() : m_value(""), m_label(""), m_numeric_value(0), m_is_numeric(false) {}
CConfigOption::CConfigOption(string value, string label) : m_value(value), m_label(label), m_numeric_value(0), m_is_numeric(false) {}
CConfigOption::CConfigOption(double value, string label) : m_value(""), m_label(label), m_numeric_value(value), m_is_numeric(true) {}
CConfigOption::~CConfigOption() {}

CJAVal* CConfigOption::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    CJAVal* label_val = new CJAVal(); label_val.set_string(m_label); json.Add("label", label_val);
    if(m_is_numeric) { CJAVal* v = new CJAVal(); v.set_double(m_numeric_value); json.Add("value", v); }
    else { CJAVal* v = new CJAVal(); v.set_string(m_value); json.Add("value", v); }
    return json;
}

class CConfigDependency : public CObject
{
public:
    string m_field;
    ENUM_DEPENDENCY_CONDITION m_condition;
    string m_value_string;
    double m_value_numeric;
    bool   m_value_bool;
    int    m_value_type;
    
    CConfigDependency();
    ~CConfigDependency();
    void set_string_value(string field, ENUM_DEPENDENCY_CONDITION condition, string value);
    void set_numeric_value(string field, ENUM_DEPENDENCY_CONDITION condition, double value);
    void set_bool_value(string field, ENUM_DEPENDENCY_CONDITION condition, bool value);
    CJAVal* to_json();
};

CConfigDependency::CConfigDependency() : m_field(""), m_condition(CONDITION_EQUALS), m_value_string(""), m_value_numeric(0), m_value_bool(false), m_value_type(0) {}
CConfigDependency::~CConfigDependency() {}

void CConfigDependency::set_string_value(string field, ENUM_DEPENDENCY_CONDITION condition, string value) { m_field = field; m_condition = condition; m_value_string = value; m_value_type = 0; }
void CConfigDependency::set_numeric_value(string field, ENUM_DEPENDENCY_CONDITION condition, double value) { m_field = field; m_condition = condition; m_value_numeric = value; m_value_type = 1; }
void CConfigDependency::set_bool_value(string field, ENUM_DEPENDENCY_CONDITION condition, bool value) { m_field = field; m_condition = condition; m_value_bool = value; m_value_type = 2; }

CJAVal* CConfigDependency::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    CJAVal* f = new CJAVal(); f.set_string(m_field); json.Add("field", f);
    string cond = "equals";
    switch(m_condition) { case CONDITION_NOT_EQUALS: cond = "notEquals"; break; case CONDITION_GREATER_THAN: cond = "greaterThan"; break; case CONDITION_LESS_THAN: cond = "lessThan"; break; }
    CJAVal* c = new CJAVal(); c.set_string(cond); json.Add("condition", c);
    CJAVal* v = new CJAVal();
    if(m_value_type == 0) v.set_string(m_value_string); else if(m_value_type == 1) v.set_double(m_value_numeric); else v.set_bool(m_value_bool);
    json.Add("value", v);
    return json;
}

class CConfigField : public CObject
{
public:
    ENUM_CONFIG_FIELD_TYPE m_type;
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
    CConfigDependency* m_depends_on;

    CConfigField();
    ~CConfigField();
    
    static CConfigField* create_integer(string key, string label, bool required, int default_value);
    static CConfigField* create_decimal(string key, string label, bool required, double default_value);
    static CConfigField* create_boolean(string key, string label, bool required, bool default_value);
    static CConfigField* create_radio(string key, string label, bool required, string default_value);
    static CConfigField* create_multiple(string key, string label, bool required);
    
    CConfigField* with_description(string description);
    CConfigField* with_placeholder(string placeholder);
    CConfigField* with_tooltip(string tooltip);
    CConfigField* with_group(string group, int order);
    CConfigField* with_disabled(bool disabled);
    CConfigField* with_hidden(bool hidden);
    CConfigField* with_range(double min_val, double max_val);
    CConfigField* with_step(double step_val);
    CConfigField* with_precision(int precision_val);
    CConfigField* with_option(string value, string label);
    CConfigField* with_option_numeric(double value, string label);
    CConfigField* with_selection_limits(int min_sel, int max_sel);
    CConfigField* with_default_selections(string &selections[]);
    CConfigField* with_depends_on(CConfigDependency* dependency);
    
    bool validate_value(string value, string &reason);
    bool validate_value(int value, string &reason);
    bool validate_value(double value, string &reason);
    bool validate_value(bool value, string &reason);
    CJAVal* to_json();
};

CConfigField::CConfigField()
{
    m_type = CONFIG_FIELD_INTEGER; m_key = ""; m_label = ""; m_required = true;
    m_default_int = 0; m_default_double = 0.0; m_default_bool = false; m_default_string = "";
    m_description = ""; m_placeholder = ""; m_tooltip = ""; m_group = ""; m_order = 0;
    m_disabled = false; m_hidden = false;
    m_minimum = 0; m_maximum = 0; m_step = 1; m_precision = 2;
    m_has_minimum = false; m_has_maximum = false;
    m_options = new CArrayObj(); m_min_selections = 0; m_max_selections = 0;
    m_depends_on = NULL;
}

CConfigField::~CConfigField()
{
    if(CheckPointer(m_options) == POINTER_DYNAMIC) { m_options.FreeMode(true); delete m_options; }
    if(CheckPointer(m_depends_on) == POINTER_DYNAMIC) delete m_depends_on;
}

CConfigField* CConfigField::create_integer(string key, string label, bool required, int default_value)
{
    CConfigField* f = new CConfigField(); f.m_type = CONFIG_FIELD_INTEGER; f.m_key = key; f.m_label = label; f.m_required = required; f.m_default_int = default_value; f.m_step = 1; return f;
}

CConfigField* CConfigField::create_decimal(string key, string label, bool required, double default_value)
{
    CConfigField* f = new CConfigField(); f.m_type = CONFIG_FIELD_DECIMAL; f.m_key = key; f.m_label = label; f.m_required = required; f.m_default_double = default_value; f.m_step = 0.01; f.m_precision = 2; return f;
}

CConfigField* CConfigField::create_boolean(string key, string label, bool required, bool default_value)
{
    CConfigField* f = new CConfigField(); f.m_type = CONFIG_FIELD_BOOLEAN; f.m_key = key; f.m_label = label; f.m_required = required; f.m_default_bool = default_value; return f;
}

CConfigField* CConfigField::create_radio(string key, string label, bool required, string default_value)
{
    CConfigField* f = new CConfigField(); f.m_type = CONFIG_FIELD_RADIO; f.m_key = key; f.m_label = label; f.m_required = required; f.m_default_string = default_value; return f;
}

CConfigField* CConfigField::create_multiple(string key, string label, bool required)
{
    CConfigField* f = new CConfigField(); f.m_type = CONFIG_FIELD_MULTIPLE; f.m_key = key; f.m_label = label; f.m_required = required; return f;
}

CConfigField* CConfigField::with_description(string description) { m_description = description; return GetPointer(this); }
CConfigField* CConfigField::with_placeholder(string placeholder) { m_placeholder = placeholder; return GetPointer(this); }
CConfigField* CConfigField::with_tooltip(string tooltip) { m_tooltip = tooltip; return GetPointer(this); }
CConfigField* CConfigField::with_group(string group, int order) { m_group = group; m_order = order; return GetPointer(this); }
CConfigField* CConfigField::with_disabled(bool disabled) { m_disabled = disabled; return GetPointer(this); }
CConfigField* CConfigField::with_hidden(bool hidden) { m_hidden = hidden; return GetPointer(this); }
CConfigField* CConfigField::with_range(double min_val, double max_val) { m_minimum = min_val; m_maximum = max_val; m_has_minimum = true; m_has_maximum = true; return GetPointer(this); }
CConfigField* CConfigField::with_step(double step_val) { m_step = step_val; return GetPointer(this); }
CConfigField* CConfigField::with_precision(int precision_val) { m_precision = precision_val; return GetPointer(this); }
CConfigField* CConfigField::with_option(string value, string label) { m_options.Add(new CConfigOption(value, label)); return GetPointer(this); }
CConfigField* CConfigField::with_option_numeric(double value, string label) { m_options.Add(new CConfigOption(value, label)); return GetPointer(this); }
CConfigField* CConfigField::with_selection_limits(int min_sel, int max_sel) { m_min_selections = min_sel; m_max_selections = max_sel; return GetPointer(this); }
CConfigField* CConfigField::with_default_selections(string &selections[]) { ArrayResize(m_default_array, ArraySize(selections)); for(int i = 0; i < ArraySize(selections); i++) m_default_array[i] = selections[i]; return GetPointer(this); }
CConfigField* CConfigField::with_depends_on(CConfigDependency* dependency) { if(CheckPointer(m_depends_on) == POINTER_DYNAMIC) delete m_depends_on; m_depends_on = dependency; return GetPointer(this); }

bool CConfigField::validate_value(int value, string &reason)
{
    if(m_type != CONFIG_FIELD_INTEGER) { reason = "Field type mismatch"; return false; }
    if(m_has_minimum && value < (int)m_minimum) { reason = StringFormat("Value %d is below minimum %d", value, (int)m_minimum); return false; }
    if(m_has_maximum && value > (int)m_maximum) { reason = StringFormat("Value %d is above maximum %d", value, (int)m_maximum); return false; }
    return true;
}

bool CConfigField::validate_value(double value, string &reason)
{
    if(m_type != CONFIG_FIELD_DECIMAL) { reason = "Field type mismatch"; return false; }
    if(m_has_minimum && value < m_minimum) { reason = StringFormat("Value %.2f is below minimum %.2f", value, m_minimum); return false; }
    if(m_has_maximum && value > m_maximum) { reason = StringFormat("Value %.2f is above maximum %.2f", value, m_maximum); return false; }
    return true;
}

bool CConfigField::validate_value(bool value, string &reason) { if(m_type != CONFIG_FIELD_BOOLEAN) { reason = "Field type mismatch"; return false; } return true; }

bool CConfigField::validate_value(string value, string &reason)
{
    if(m_type == CONFIG_FIELD_RADIO)
    {
        for(int i = 0; i < m_options.Total(); i++) { CConfigOption* o = m_options.At(i); if(o.m_value == value) return true; }
        reason = StringFormat("Value '%s' is not a valid option", value); return false;
    }
    return true;
}

CJAVal* CConfigField::to_json()
{
    CJAVal* j = new CJAVal(JA_OBJECT); if(j == NULL) return NULL;
    string ts = ""; switch(m_type) { case CONFIG_FIELD_INTEGER: ts = "integer"; break; case CONFIG_FIELD_DECIMAL: ts = "decimal"; break; case CONFIG_FIELD_BOOLEAN: ts = "boolean"; break; case CONFIG_FIELD_RADIO: ts = "radio"; break; case CONFIG_FIELD_MULTIPLE: ts = "multiple"; break; }
    CJAVal* tv = new CJAVal(); tv.set_string(ts); j.Add("type", tv);
    CJAVal* kv = new CJAVal(); kv.set_string(m_key); j.Add("key", kv);
    CJAVal* lv = new CJAVal(); lv.set_string(m_label); j.Add("label", lv);
    CJAVal* rv = new CJAVal(); rv.set_bool(m_required); j.Add("required", rv);
    CJAVal* dv = new CJAVal();
    switch(m_type) { case CONFIG_FIELD_INTEGER: dv.set_long(m_default_int); break; case CONFIG_FIELD_DECIMAL: dv.set_double(m_default_double); break; case CONFIG_FIELD_BOOLEAN: dv.set_bool(m_default_bool); break; case CONFIG_FIELD_RADIO: dv.set_string(m_default_string); break; case CONFIG_FIELD_MULTIPLE: delete dv; dv = new CJAVal(JA_ARRAY); for(int i = 0; i < ArraySize(m_default_array); i++) { CJAVal* it = new CJAVal(); it.set_string(m_default_array[i]); dv.Add(it); } break; }
    j.Add("default", dv);
    if(m_description != "") { CJAVal* dsc = new CJAVal(); dsc.set_string(m_description); j.Add("description", dsc); }
    if(m_group != "") { CJAVal* gv = new CJAVal(); gv.set_string(m_group); j.Add("group", gv); CJAVal* ov = new CJAVal(); ov.set_long(m_order); j.Add("order", ov); }
    if(m_type == CONFIG_FIELD_INTEGER || m_type == CONFIG_FIELD_DECIMAL)
    {
        if(m_has_minimum) { CJAVal* mv = new CJAVal(); if(m_type == CONFIG_FIELD_INTEGER) mv.set_long((int)m_minimum); else mv.set_double(m_minimum); j.Add("minimum", mv); }
        if(m_has_maximum) { CJAVal* mv = new CJAVal(); if(m_type == CONFIG_FIELD_INTEGER) mv.set_long((int)m_maximum); else mv.set_double(m_maximum); j.Add("maximum", mv); }
        CJAVal* sv = new CJAVal(); if(m_type == CONFIG_FIELD_INTEGER) sv.set_long((int)m_step); else sv.set_double(m_step); j.Add("step", sv);
        if(m_type == CONFIG_FIELD_DECIMAL) { CJAVal* pv = new CJAVal(); pv.set_long(m_precision); j.Add("precision", pv); }
    }
    if(m_type == CONFIG_FIELD_RADIO || m_type == CONFIG_FIELD_MULTIPLE)
    {
        CJAVal* oa = new CJAVal(JA_ARRAY); for(int i = 0; i < m_options.Total(); i++) { CConfigOption* o = m_options.At(i); oa.Add(o.to_json()); } j.Add("options", oa);
        if(m_type == CONFIG_FIELD_MULTIPLE) { if(m_min_selections > 0) { CJAVal* ms = new CJAVal(); ms.set_long(m_min_selections); j.Add("minSelections", ms); } if(m_max_selections > 0) { CJAVal* ms = new CJAVal(); ms.set_long(m_max_selections); j.Add("maxSelections", ms); } }
    }
    if(CheckPointer(m_depends_on) != POINTER_INVALID) j.Add("dependsOn", m_depends_on.to_json());
    return j;
}

#endif
//+------------------------------------------------------------------+

