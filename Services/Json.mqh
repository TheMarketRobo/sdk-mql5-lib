//+------------------------------------------------------------------+
//|                                                         Json.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"
#property strict

#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayString.mqh>

//+------------------------------------------------------------------+
//| JSON value types                                                 |
//+------------------------------------------------------------------+
enum ENUM_JA_TYPE
{
    JA_NULL,
    JA_OBJECT,
    JA_ARRAY,
    JA_STRING,
    JA_NUMBER,
    JA_BOOL
};

class CJAVal;

//+------------------------------------------------------------------+
//| Class for JSON object key-value pair                             |
//+------------------------------------------------------------------+
class CJAObj : public CObject
{
public:
    string      m_key;
    CJAVal     *m_val;

                CJAObj(string key, CJAVal *val);
               ~CJAObj();
};

//+------------------------------------------------------------------+
CJAObj::CJAObj(string key, CJAVal *val) : m_key(key), m_val(val) {}

//+------------------------------------------------------------------+
CJAObj::~CJAObj()
{
    if(CheckPointer(m_val) == POINTER_DYNAMIC)
        delete m_val;
}

//+------------------------------------------------------------------+
//| Class for a JSON value                                           |
//+------------------------------------------------------------------+
class CJAVal : public CObject
{
private:
    ENUM_JA_TYPE m_type;
    string      m_string;
    double      m_number;
    bool        m_bool;
    CArrayObj  *m_obj;
    CArrayObj  *m_arr;

public:
                CJAVal(ENUM_JA_TYPE type = JA_NULL);
               ~CJAVal();

    bool        parse(string &json_string);
    string      to_string();

    ENUM_JA_TYPE get_type() const;
    string      get_string() const;
    double      get_double() const;
    long        get_long() const;
    bool        get_bool() const;
    int         count() const;

    void        set_string(const string value);
    void        set_double(const double value);
    void        set_long(const long value);
    void        set_bool(const bool value);

    bool        Add(const string key, CJAVal *value);
    CJAVal     *operator[](const string key);
    CJAVal     *operator[](const string key) const;
    bool        has_key(const string key) const;

    bool        Add(CJAVal *value);
    CJAVal     *operator[](const int index);
    CJAVal     *operator[](const int index) const;
    
    string      serialize();  // Alias for to_string

private:
    string      Escape(const string s);
    string      Unescape(const string s);
    bool        ParseValue(string &json, int &pos);
    bool        ParseObject(string &json, int &pos);
    bool        ParseArray(string &json, int &pos);
    bool        ParseString(string &json, int &pos);
    bool        ParseNumber(string &json, int &pos);
    bool        ParseLiteral(string &json, int &pos);
    void        SkipWhitespace(string &json, int &pos);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CJAVal::CJAVal(ENUM_JA_TYPE type) : m_type(type), m_number(0), m_bool(false)
{
    m_string = "";
    if(type == JA_OBJECT)
        m_obj = new CArrayObj();
    else
        m_obj = NULL;

    if(type == JA_ARRAY)
        m_arr = new CArrayObj();
    else
        m_arr = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CJAVal::~CJAVal()
{
    if(CheckPointer(m_obj) == POINTER_DYNAMIC)
        delete m_obj;
    if(CheckPointer(m_arr) == POINTER_DYNAMIC)
        delete m_arr;
}

//+------------------------------------------------------------------+
//| Parse JSON string                                                 |
//+------------------------------------------------------------------+
bool CJAVal::parse(string &json_string)
{
    int pos = 0;
    return ParseValue(json_string, pos);
}

//+------------------------------------------------------------------+
//| Convert to JSON string                                            |
//+------------------------------------------------------------------+
string CJAVal::to_string()
{
    switch(m_type)
    {
        case JA_NULL: 
            return "null";
        case JA_STRING: 
            return "\"" + Escape(m_string) + "\"";
        case JA_NUMBER:
        {
            if(m_number == MathFloor(m_number) && MathAbs(m_number) < 1e15)
                return IntegerToString((long)m_number);
            return DoubleToString(m_number, 8);
        }
        case JA_BOOL: 
            return m_bool ? "true" : "false";
        case JA_OBJECT:
        {
            string s = "{";
            int total = m_obj.Total();
            for(int i = 0; i < total; i++)
            {
                CJAObj *pair = m_obj.At(i);
                s += "\"" + Escape(pair.m_key) + "\":" + pair.m_val.to_string();
                if(i < total - 1)
                    s += ",";
            }
            s += "}";
            return s;
        }
        case JA_ARRAY:
        {
            string s = "[";
            int total = m_arr.Total();
            for(int i = 0; i < total; i++)
            {
                CJAVal *val = m_arr.At(i);
                s += val.to_string();
                if(i < total - 1)
                    s += ",";
            }
            s += "]";
            return s;
        }
    }
    return "";
}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
ENUM_JA_TYPE CJAVal::get_type() const { return m_type; }
string CJAVal::get_string() const { return m_string; }
double CJAVal::get_double() const { return m_number; }
long CJAVal::get_long() const { return (long)m_number; }
bool CJAVal::get_bool() const { return m_bool; }

int CJAVal::count() const
{
    if(m_type == JA_OBJECT && m_obj != NULL) return m_obj.Total();
    if(m_type == JA_ARRAY && m_arr != NULL) return m_arr.Total();
    return 0;
}

//+------------------------------------------------------------------+
//| Setters                                                           |
//+------------------------------------------------------------------+
void CJAVal::set_string(const string value)
{
    m_type = JA_STRING;
    m_string = value;
}

void CJAVal::set_double(const double value)
{
    m_type = JA_NUMBER;
    m_number = value;
}

void CJAVal::set_long(const long value)
{
    m_type = JA_NUMBER;
    m_number = (double)value;
}

void CJAVal::set_bool(const bool value)
{
    m_type = JA_BOOL;
    m_bool = value;
}

//+------------------------------------------------------------------+
//| Object methods                                                    |
//+------------------------------------------------------------------+
bool CJAVal::Add(const string key, CJAVal* value)
{
    if(m_type != JA_OBJECT) return false;
    if(m_obj == NULL) m_obj = new CArrayObj();
    return m_obj.Add(new CJAObj(key, value));
}

CJAVal* CJAVal::operator[](const string key)
{
    if(m_type != JA_OBJECT || m_obj == NULL) return NULL;
    for(int i = 0; i < m_obj.Total(); i++)
    {
        CJAObj* pair = m_obj.At(i);
        if(pair.m_key == key) return pair.m_val;
    }
    return NULL;
}

CJAVal* CJAVal::operator[](const string key) const
{
    if(m_type != JA_OBJECT || m_obj == NULL) return NULL;
    for(int i = 0; i < m_obj.Total(); i++)
    {
        CJAObj* pair = m_obj.At(i);
        if(pair.m_key == key) return pair.m_val;
    }
    return NULL;
}

//+------------------------------------------------------------------+
//| Array methods                                                     |
//+------------------------------------------------------------------+
bool CJAVal::Add(CJAVal* value)
{
    if(m_type != JA_ARRAY) return false;
    if(m_arr == NULL) m_arr = new CArrayObj();
    return m_arr.Add(value);
}

CJAVal* CJAVal::operator[](const int index)
{
    if(m_type != JA_ARRAY || m_arr == NULL) return NULL;
    return m_arr.At(index);
}

CJAVal* CJAVal::operator[](const int index) const
{
    if(m_type != JA_ARRAY || m_arr == NULL) return NULL;
    return m_arr.At(index);
}

//+------------------------------------------------------------------+
//| Check if object has a key                                         |
//+------------------------------------------------------------------+
bool CJAVal::has_key(const string key) const
{
    if(m_type != JA_OBJECT || m_obj == NULL) return false;
    for(int i = 0; i < m_obj.Total(); i++)
    {
        CJAObj* pair = m_obj.At(i);
        if(pair.m_key == key) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Serialize to JSON string (alias for to_string)                    |
//+------------------------------------------------------------------+
string CJAVal::serialize()
{
    return to_string();
}

//+------------------------------------------------------------------+
//| Skip whitespace characters                                        |
//+------------------------------------------------------------------+
void CJAVal::SkipWhitespace(string &json, int &pos)
{
    int len = StringLen(json);
    while(pos < len)
    {
        ushort c = StringGetCharacter(json, pos);
        if(c == ' ' || c == '\t' || c == '\n' || c == '\r')
            pos++;
        else
            break;
    }
}

//+------------------------------------------------------------------+
//| Parse any JSON value                                              |
//+------------------------------------------------------------------+
bool CJAVal::ParseValue(string &json, int &pos)
{
    SkipWhitespace(json, pos);
    
    if(pos >= StringLen(json))
        return false;
    
    ushort c = StringGetCharacter(json, pos);
    
    if(c == '{')
        return ParseObject(json, pos);
    if(c == '[')
        return ParseArray(json, pos);
    if(c == '"')
        return ParseString(json, pos);
    if(c == '-' || (c >= '0' && c <= '9'))
        return ParseNumber(json, pos);
    if(c == 't' || c == 'f' || c == 'n')
        return ParseLiteral(json, pos);
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON object                                                 |
//+------------------------------------------------------------------+
bool CJAVal::ParseObject(string &json, int &pos)
{
    if(StringGetCharacter(json, pos) != '{')
        return false;
    
    m_type = JA_OBJECT;
    if(m_obj == NULL)
        m_obj = new CArrayObj();
    
    pos++;
    SkipWhitespace(json, pos);
    
    if(pos < StringLen(json) && StringGetCharacter(json, pos) == '}')
    {
        pos++;
        return true;
    }
    
    while(pos < StringLen(json))
    {
        SkipWhitespace(json, pos);
        
        if(StringGetCharacter(json, pos) != '"')
            return false;
        
        CJAVal* keyVal = new CJAVal();
        if(!keyVal.ParseString(json, pos))
        {
            delete keyVal;
            return false;
        }
        string key = keyVal.get_string();
        delete keyVal;
        
        SkipWhitespace(json, pos);
        
        if(pos >= StringLen(json) || StringGetCharacter(json, pos) != ':')
            return false;
        pos++;
        
        SkipWhitespace(json, pos);
        
        CJAVal* value = new CJAVal();
        if(!value.ParseValue(json, pos))
        {
            delete value;
            return false;
        }
        
        m_obj.Add(new CJAObj(key, value));
        
        SkipWhitespace(json, pos);
        
        if(pos >= StringLen(json))
            return false;
        
        ushort c = StringGetCharacter(json, pos);
        if(c == '}')
        {
            pos++;
            return true;
        }
        if(c == ',')
        {
            pos++;
            continue;
        }
        
        return false;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON array                                                  |
//+------------------------------------------------------------------+
bool CJAVal::ParseArray(string &json, int &pos)
{
    if(StringGetCharacter(json, pos) != '[')
        return false;
    
    m_type = JA_ARRAY;
    if(m_arr == NULL)
        m_arr = new CArrayObj();
    
    pos++;
    SkipWhitespace(json, pos);
    
    if(pos < StringLen(json) && StringGetCharacter(json, pos) == ']')
    {
        pos++;
        return true;
    }
    
    while(pos < StringLen(json))
    {
        SkipWhitespace(json, pos);
        
        CJAVal* value = new CJAVal();
        if(!value.ParseValue(json, pos))
        {
            delete value;
            return false;
        }
        
        m_arr.Add(value);
        
        SkipWhitespace(json, pos);
        
        if(pos >= StringLen(json))
            return false;
        
        ushort c = StringGetCharacter(json, pos);
        if(c == ']')
        {
            pos++;
            return true;
        }
        if(c == ',')
        {
            pos++;
            continue;
        }
        
        return false;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON string                                                 |
//+------------------------------------------------------------------+
bool CJAVal::ParseString(string &json, int &pos)
{
    if(StringGetCharacter(json, pos) != '"')
        return false;
    
    pos++;
    string result = "";
    int len = StringLen(json);
    
    while(pos < len)
    {
        ushort c = StringGetCharacter(json, pos);
        
        if(c == '"')
        {
            pos++;
            m_type = JA_STRING;
            m_string = result;
            return true;
        }
        
        if(c == '\\')
        {
            pos++;
            if(pos >= len)
                return false;
            
            ushort escaped = StringGetCharacter(json, pos);
            switch(escaped)
            {
                case '"':  result += "\""; break;
                case '\\': result += "\\"; break;
                case '/':  result += "/"; break;
                case 'b':  result += ShortToString(8); break;  // backspace
                case 'f':  result += ShortToString(12); break; // form feed
                case 'n':  result += "\n"; break;
                case 'r':  result += "\r"; break;
                case 't':  result += "\t"; break;
                case 'u':
                {
                    if(pos + 4 >= len)
                        return false;
                    string hex = StringSubstr(json, pos + 1, 4);
                    int code = 0;
                    for(int i = 0; i < 4; i++)
                    {
                        ushort h = StringGetCharacter(hex, i);
                        int val = 0;
                        if(h >= '0' && h <= '9') val = h - '0';
                        else if(h >= 'a' && h <= 'f') val = h - 'a' + 10;
                        else if(h >= 'A' && h <= 'F') val = h - 'A' + 10;
                        else return false;
                        code = code * 16 + val;
                    }
                    result += ShortToString((ushort)code);
                    pos += 4;
                    break;
                }
                default:
                    return false;
            }
            pos++;
        }
        else
        {
            result += ShortToString(c);
            pos++;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON number                                                 |
//+------------------------------------------------------------------+
bool CJAVal::ParseNumber(string &json, int &pos)
{
    int start = pos;
    int len = StringLen(json);
    
    if(pos < len && StringGetCharacter(json, pos) == '-')
        pos++;
    
    if(pos >= len)
        return false;
    
    ushort c = StringGetCharacter(json, pos);
    if(c == '0')
    {
        pos++;
    }
    else if(c >= '1' && c <= '9')
    {
        pos++;
        while(pos < len)
        {
            c = StringGetCharacter(json, pos);
            if(c >= '0' && c <= '9')
                pos++;
            else
                break;
        }
    }
    else
    {
        return false;
    }
    
    if(pos < len && StringGetCharacter(json, pos) == '.')
    {
        pos++;
        if(pos >= len)
            return false;
        
        c = StringGetCharacter(json, pos);
        if(c < '0' || c > '9')
            return false;
        
        while(pos < len)
        {
            c = StringGetCharacter(json, pos);
            if(c >= '0' && c <= '9')
                pos++;
            else
                break;
        }
    }
    
    if(pos < len)
    {
        c = StringGetCharacter(json, pos);
        if(c == 'e' || c == 'E')
        {
            pos++;
            if(pos >= len)
                return false;
            
            c = StringGetCharacter(json, pos);
            if(c == '+' || c == '-')
                pos++;
            
            if(pos >= len)
                return false;
            
            c = StringGetCharacter(json, pos);
            if(c < '0' || c > '9')
                return false;
            
            while(pos < len)
            {
                c = StringGetCharacter(json, pos);
                if(c >= '0' && c <= '9')
                    pos++;
                else
                    break;
            }
        }
    }
    
    string numStr = StringSubstr(json, start, pos - start);
    m_type = JA_NUMBER;
    m_number = StringToDouble(numStr);
    
    return true;
}

//+------------------------------------------------------------------+
//| Parse JSON literal (true, false, null)                            |
//+------------------------------------------------------------------+
bool CJAVal::ParseLiteral(string &json, int &pos)
{
    int len = StringLen(json);
    
    if(pos + 4 <= len && StringSubstr(json, pos, 4) == "true")
    {
        m_type = JA_BOOL;
        m_bool = true;
        pos += 4;
        return true;
    }
    
    if(pos + 5 <= len && StringSubstr(json, pos, 5) == "false")
    {
        m_type = JA_BOOL;
        m_bool = false;
        pos += 5;
        return true;
    }
    
    if(pos + 4 <= len && StringSubstr(json, pos, 4) == "null")
    {
        m_type = JA_NULL;
        pos += 4;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Escape special characters in string                               |
//+------------------------------------------------------------------+
string CJAVal::Escape(const string s)
{
    string result = "";
    int len = StringLen(s);
    
    for(int i = 0; i < len; i++)
    {
        ushort c = StringGetCharacter(s, i);
        switch(c)
        {
            case '"':  result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case 8:    result += "\\b"; break;  // backspace (0x08)
            case 12:   result += "\\f"; break;  // form feed (0x0C)
            case '\n': result += "\\n"; break;
            case '\r': result += "\\r"; break;
            case '\t': result += "\\t"; break;
            default:
                if(c < 32)
                {
                    result += "\\u";
                    string hex = "";
                    for(int j = 3; j >= 0; j--)
                    {
                        int nibble = (c >> (j * 4)) & 0xF;
                        if(nibble < 10)
                            hex += ShortToString((ushort)('0' + nibble));
                        else
                            hex += ShortToString((ushort)('a' + nibble - 10));
                    }
                    result += hex;
                }
                else
                {
                    result += ShortToString(c);
                }
                break;
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Unescape special characters in string                             |
//+------------------------------------------------------------------+
string CJAVal::Unescape(const string s)
{
    string result = "";
    int len = StringLen(s);
    int i = 0;
    
    while(i < len)
    {
        ushort c = StringGetCharacter(s, i);
        
        if(c == '\\' && i + 1 < len)
        {
            ushort next = StringGetCharacter(s, i + 1);
            switch(next)
            {
                case '"':  result += "\""; i += 2; break;
                case '\\': result += "\\"; i += 2; break;
                case '/':  result += "/"; i += 2; break;
                case 'b':  result += ShortToString(8); i += 2; break;  // backspace
                case 'f':  result += ShortToString(12); i += 2; break; // form feed
                case 'n':  result += "\n"; i += 2; break;
                case 'r':  result += "\r"; i += 2; break;
                case 't':  result += "\t"; i += 2; break;
                case 'u':
                {
                    if(i + 5 < len)
                    {
                        string hex = StringSubstr(s, i + 2, 4);
                        int code = 0;
                        for(int j = 0; j < 4; j++)
                        {
                            ushort h = StringGetCharacter(hex, j);
                            int val = 0;
                            if(h >= '0' && h <= '9') val = h - '0';
                            else if(h >= 'a' && h <= 'f') val = h - 'a' + 10;
                            else if(h >= 'A' && h <= 'F') val = h - 'A' + 10;
                            code = code * 16 + val;
                        }
                        result += ShortToString((ushort)code);
                        i += 6;
                    }
                    else
                    {
                        result += ShortToString(c);
                        i++;
                    }
                    break;
                }
                default:
                    result += ShortToString(c);
                    i++;
                    break;
            }
        }
        else
        {
            result += ShortToString(c);
            i++;
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
