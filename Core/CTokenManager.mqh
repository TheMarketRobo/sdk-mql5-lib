//+------------------------------------------------------------------+
//|                                                CTokenManager.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CTOKEN_MANAGER_MQH
#define CTOKEN_MANAGER_MQH

#include <Object.mqh>
#include "../Services/Json.mqh"
#include "../Utils/CSDKLogger.mqh"

/**
 * @class CTokenManager
 * @brief Manages the JWT token for the session, including storage and proactive refresh.
 *
 * ## Token Refresh Strategy
 * The manager implements proactive token refresh to ensure uninterrupted session continuity.
 * Tokens are refreshed BEFORE expiration, not after. The refresh threshold is configurable.
 *
 * ## Default Behavior
 * - Default refresh threshold: 300 seconds (5 minutes) before expiration
 * - Token is refreshed when: current_time >= (expiration_time - refresh_threshold)
 * - This ensures the robot always has a valid token for API calls
 */
class CTokenManager : public CObject
{
private:
    string m_jwt;
    long   m_expiration_timestamp;
    long   m_issued_at_timestamp;
    int    m_refresh_threshold_seconds;
    int    m_expires_in;

public:
    CTokenManager();
    ~CTokenManager();

    void   set_token(string jwt);
    void   restore_token(string jwt, int expires_in);
    void   set_expires_in(int expires_in);
    string get_token() const;
    int    get_expires_in() const;
    long   get_expiration_timestamp() const;
    bool   is_token_set() const;
    
    bool   should_refresh_token();
    int    get_seconds_until_expiration() const;
    int    get_seconds_until_refresh() const;
    
    int    get_refresh_threshold_seconds() const;
    void   set_refresh_threshold_seconds(int seconds);

private:
    bool   decode_token_payload(string jwt);
    string base64_url_decode(const string &encoded_string);
    int    base64_char_to_value(uchar c);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTokenManager::CTokenManager()
{
    m_jwt = "";
    m_expiration_timestamp = 0;
    m_issued_at_timestamp = 0;
    m_expires_in = 0;
    // Default to 60 seconds - must be less than JWT expiration (default 300s)
    m_refresh_threshold_seconds = 60;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTokenManager::~CTokenManager()
{
}

//+------------------------------------------------------------------+
//| Sets a new JWT and decodes its payload                           |
//+------------------------------------------------------------------+
void CTokenManager::set_token(string jwt)
{
    m_jwt = jwt;
    if(!decode_token_payload(jwt))
    {
        m_expiration_timestamp = 0;
        m_issued_at_timestamp = 0;
        m_jwt = "";
        Print("SDK Error: Failed to decode JWT payload. Token has been invalidated.");
    }
    else
    {
        if(SDKShouldLogInfo())
            Print("SDK Info: Token set successfully. Expires at: ", 
                  TimeToString(m_expiration_timestamp, TIME_DATE|TIME_SECONDS));
    }
}

//+------------------------------------------------------------------+
//| Restore token from saved state (no decode log noise)              |
//+------------------------------------------------------------------+
void CTokenManager::restore_token(string jwt, int expires_in)
{
    m_jwt = jwt;
    m_expires_in = expires_in;
    if(!decode_token_payload(jwt))
    {
        m_expiration_timestamp = 0;
        m_issued_at_timestamp = 0;
        m_jwt = "";
    }
    else
    {
        if(SDKShouldLogInfo())
            Print("SDK Info: Token restored. Expires at: ",
                  TimeToString(m_expiration_timestamp, TIME_DATE|TIME_SECONDS));
    }
}

//+------------------------------------------------------------------+
//| Sets the expires_in value from server response                    |
//+------------------------------------------------------------------+
void CTokenManager::set_expires_in(int expires_in)
{
    m_expires_in = expires_in;
}

//+------------------------------------------------------------------+
//| Returns the expires_in value                                      |
//+------------------------------------------------------------------+
int CTokenManager::get_expires_in() const
{
    return m_expires_in;
}

//+------------------------------------------------------------------+
//| Returns the expiration timestamp                                   |
//+------------------------------------------------------------------+
long CTokenManager::get_expiration_timestamp() const
{
    return m_expiration_timestamp;
}

//+------------------------------------------------------------------+
//| Returns the current JWT token                                     |
//+------------------------------------------------------------------+
string CTokenManager::get_token() const
{
    return m_jwt;
}

//+------------------------------------------------------------------+
//| Checks if a token has been set                                    |
//+------------------------------------------------------------------+
bool CTokenManager::is_token_set() const
{
    return m_jwt != "";
}

//+------------------------------------------------------------------+
//| Sets the refresh threshold in seconds                             |
//+------------------------------------------------------------------+
void CTokenManager::set_refresh_threshold_seconds(int seconds)
{
    if(seconds < 60)
    {
        if(SDKShouldLogWarning())
            Print("SDK Warning: Refresh threshold too low. Setting to minimum 60 seconds.");
        seconds = 60;
    }
    else if(seconds > 3600)
    {
        if(SDKShouldLogWarning())
            Print("SDK Warning: Refresh threshold too high. Setting to maximum 3600 seconds.");
        seconds = 3600;
    }
    m_refresh_threshold_seconds = seconds;
}

//+------------------------------------------------------------------+
//| Returns the refresh threshold in seconds                          |
//+------------------------------------------------------------------+
int CTokenManager::get_refresh_threshold_seconds() const
{
    return m_refresh_threshold_seconds;
}

//+------------------------------------------------------------------+
//| Checks if the token should be refreshed proactively               |
//+------------------------------------------------------------------+
bool CTokenManager::should_refresh_token()
{
    if(m_expiration_timestamp == 0 || m_jwt == "") 
        return false;

    // Use TimeGMT() instead of TimeCurrent() for two reasons:
    // 1. TimeCurrent() doesn't advance when market is closed (weekends/holidays)
    // 2. JWT exp claim is a Unix UTC timestamp, so we should compare with UTC time
    long current_time = TimeGMT();
    long refresh_time = m_expiration_timestamp - m_refresh_threshold_seconds;
    
    return (current_time >= refresh_time);
}

//+------------------------------------------------------------------+
//| Gets the seconds until token expiration                           |
//+------------------------------------------------------------------+
int CTokenManager::get_seconds_until_expiration() const
{
    if(m_expiration_timestamp == 0) 
        return 0;
    // Use TimeGMT() for accurate comparison with JWT exp (Unix UTC timestamp)
    return (int)(m_expiration_timestamp - TimeGMT());
}

//+------------------------------------------------------------------+
//| Gets the seconds until refresh threshold                          |
//+------------------------------------------------------------------+
int CTokenManager::get_seconds_until_refresh() const
{
    if(m_expiration_timestamp == 0) 
        return 0;
    long refresh_time = m_expiration_timestamp - m_refresh_threshold_seconds;
    // Use TimeGMT() for accurate comparison with JWT exp (Unix UTC timestamp)
    return (int)(refresh_time - TimeGMT());
}

//+------------------------------------------------------------------+
//| Decodes the JWT payload to extract claims                         |
//+------------------------------------------------------------------+
bool CTokenManager::decode_token_payload(string jwt)
{
    string parts[];
    if(StringSplit(jwt, '.', parts) != 3)
    {
        Print("JWT Error: Invalid token structure.");
        return false;
    }

    string payload_base64url = parts[1];
    string decoded_payload = base64_url_decode(payload_base64url);

    if(decoded_payload == "") 
    {
        Print("JWT Error: Base64URL decoding of payload failed.");
        return false;
    }

    CJAVal json_payload;
    if(!json_payload.parse(decoded_payload))
    {
        Print("JWT Error: Failed to parse JSON payload.");
        return false;
    }

    CJAVal* exp_node = json_payload["exp"];
    if(CheckPointer(exp_node) == POINTER_INVALID || exp_node.get_type() != JA_NUMBER)
    {
        Print("JWT Error: 'exp' claim not found or is not a number.");
        return false;
    }
    m_expiration_timestamp = exp_node.get_long();

    CJAVal* iat_node = json_payload["iat"];
    if(CheckPointer(iat_node) != POINTER_INVALID && iat_node.get_type() == JA_NUMBER)
    {
        m_issued_at_timestamp = iat_node.get_long();
    }

    return true;
}

//+------------------------------------------------------------------+
//| Converts a Base64/Base64URL character to its 6-bit value          |
//+------------------------------------------------------------------+
int CTokenManager::base64_char_to_value(uchar c)
{
    if(c >= 'A' && c <= 'Z') return c - 'A';
    if(c >= 'a' && c <= 'z') return c - 'a' + 26;
    if(c >= '0' && c <= '9') return c - '0' + 52;
    if(c == '+' || c == '-') return 62;
    if(c == '/' || c == '_') return 63;
    return -1;
}

//+------------------------------------------------------------------+
//| Decodes a Base64URL encoded string                                |
//+------------------------------------------------------------------+
string CTokenManager::base64_url_decode(const string &encoded_string)
{
    if(encoded_string == "")
        return "";
    
    string str_input = encoded_string;
    
    StringReplace(str_input, "-", "+");
    StringReplace(str_input, "_", "/");
    
    int padding = 4 - (StringLen(str_input) % 4);
    if(padding != 4)
    {
        for(int p = 0; p < padding; p++)
            str_input += "=";
    }
    
    int input_len = StringLen(str_input);
    
    int pad_count = 0;
    if(input_len >= 1 && StringGetCharacter(str_input, input_len - 1) == '=') pad_count++;
    if(input_len >= 2 && StringGetCharacter(str_input, input_len - 2) == '=') pad_count++;
    
    int output_len = (input_len / 4) * 3 - pad_count;
    if(output_len <= 0)
        return "";
    
    uchar output_bytes[];
    ArrayResize(output_bytes, output_len);
    
    int output_index = 0;
    
    for(int i = 0; i < input_len; i += 4)
    {
        uchar c0 = (uchar)StringGetCharacter(str_input, i);
        uchar c1 = (uchar)StringGetCharacter(str_input, i + 1);
        uchar c2 = (i + 2 < input_len) ? (uchar)StringGetCharacter(str_input, i + 2) : '=';
        uchar c3 = (i + 3 < input_len) ? (uchar)StringGetCharacter(str_input, i + 3) : '=';
        
        int v0 = base64_char_to_value(c0);
        int v1 = base64_char_to_value(c1);
        int v2 = (c2 == '=') ? 0 : base64_char_to_value(c2);
        int v3 = (c3 == '=') ? 0 : base64_char_to_value(c3);
        
        if(v0 < 0 || v1 < 0 || (c2 != '=' && v2 < 0) || (c3 != '=' && v3 < 0))
        {
            Print("JWT Error: Invalid Base64 character in input.");
            return "";
        }
        
        uint combined = ((uint)v0 << 18) | ((uint)v1 << 12) | ((uint)v2 << 6) | (uint)v3;
        
        if(output_index < output_len)
            output_bytes[output_index++] = (uchar)((combined >> 16) & 0xFF);
        if(output_index < output_len && c2 != '=')
            output_bytes[output_index++] = (uchar)((combined >> 8) & 0xFF);
        if(output_index < output_len && c3 != '=')
            output_bytes[output_index++] = (uchar)(combined & 0xFF);
    }
    
    string result = CharArrayToString(output_bytes, 0, output_index, CP_UTF8);
    return result;
}

#endif
//+------------------------------------------------------------------+
