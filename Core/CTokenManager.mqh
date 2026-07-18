//+------------------------------------------------------------------+
//|                                                CTokenManager.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CTOKEN_MANAGER_MQH
#define CTOKEN_MANAGER_MQH

#include <Object.mqh>
#include "CSDKConstants.mqh"
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
 * - Default refresh threshold: 60 seconds (TMKR_DEFAULT_TOKEN_REFRESH_THRESHOLD)
 * - Token is refreshed when: current_time >= (expiration_time - effective_threshold)
 * - This ensures the robot always has a valid token for API calls
 *
 * ## Loop safety (v1.3.1)
 * The EFFECTIVE threshold is clamped to half the token's real lifetime (exp - iat,
 * falling back to the server's expires_in). A configured threshold >= the token
 * lifetime (e.g. threshold 300 s against 300 s tokens) previously made the refresh
 * predicate true from the moment each token was issued — the 1-second SDK timer
 * then produced ~1 POST /robot/refresh per second, forever. With the clamp, a
 * 300 s token refreshes once at ~T+150 s regardless of the configured value.
 * Additionally, refresh signals carry a TMKR_TOKEN_REFRESH_RETRY_SECONDS cooldown
 * so a FAILING refresh near expiry retries at that cadence instead of every tick;
 * a successfully stored fresh token resets the cooldown.
 */
class CTMKR_TokenManager : public CObject
{
private:
    string m_jwt;
    long   m_expiration_timestamp;
    long   m_issued_at_timestamp;
    int    m_refresh_threshold_seconds;
    int    m_expires_in;
    long   m_last_refresh_signal;   // TimeGMT() of the last should_refresh_token()==true (retry cooldown)

public:
    CTMKR_TokenManager();
    ~CTMKR_TokenManager();

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
    int    get_effective_refresh_threshold_seconds() const;

private:
    long   get_token_lifetime_seconds() const;
    void   warn_if_threshold_clamped() const;
    bool   decode_token_payload(string jwt);
    string base64_url_decode(const string &encoded_string);
    int    base64_char_to_value(uchar tmkr_c);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_TokenManager::CTMKR_TokenManager()
{
    m_jwt = "";
    m_expiration_timestamp = 0;
    m_issued_at_timestamp = 0;
    m_expires_in = 0;
    m_last_refresh_signal = 0;
    // Default to 60 seconds; the effective threshold is additionally clamped to
    // half the token's real lifetime at decision time (see should_refresh_token).
    m_refresh_threshold_seconds = TMKR_DEFAULT_TOKEN_REFRESH_THRESHOLD;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_TokenManager::~CTMKR_TokenManager()
{
}

//+------------------------------------------------------------------+
//| Sets a new JWT and decodes its payload                           |
//+------------------------------------------------------------------+
void CTMKR_TokenManager::set_token(string jwt)
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
        // Fresh token: clear the refresh-retry cooldown so the next refresh
        // is scheduled purely from this token's own lifetime.
        m_last_refresh_signal = 0;
        warn_if_threshold_clamped();
        if(SDKShouldLogInfo())
            Print("SDK Info: Token set successfully. Expires at: ",
                  TimeToString(m_expiration_timestamp, TIME_DATE|TIME_SECONDS));
    }
}

//+------------------------------------------------------------------+
//| Restore token from saved state (no decode log noise)              |
//+------------------------------------------------------------------+
void CTMKR_TokenManager::restore_token(string jwt, int expires_in)
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
        m_last_refresh_signal = 0;
        warn_if_threshold_clamped();
        if(SDKShouldLogInfo())
            Print("SDK Info: Token restored. Expires at: ",
                  TimeToString(m_expiration_timestamp, TIME_DATE|TIME_SECONDS));
    }
}

//+------------------------------------------------------------------+
//| Sets the expires_in value from server response                    |
//+------------------------------------------------------------------+
void CTMKR_TokenManager::set_expires_in(int expires_in)
{
    m_expires_in = expires_in;
}

//+------------------------------------------------------------------+
//| Returns the expires_in value                                      |
//+------------------------------------------------------------------+
int CTMKR_TokenManager::get_expires_in() const
{
    return m_expires_in;
}

//+------------------------------------------------------------------+
//| Returns the expiration timestamp                                   |
//+------------------------------------------------------------------+
long CTMKR_TokenManager::get_expiration_timestamp() const
{
    return m_expiration_timestamp;
}

//+------------------------------------------------------------------+
//| Returns the current JWT token                                     |
//+------------------------------------------------------------------+
string CTMKR_TokenManager::get_token() const
{
    return m_jwt;
}

//+------------------------------------------------------------------+
//| Checks if a token has been set                                    |
//+------------------------------------------------------------------+
bool CTMKR_TokenManager::is_token_set() const
{
    return m_jwt != "";
}

//+------------------------------------------------------------------+
//| Sets the refresh threshold in seconds                             |
//+------------------------------------------------------------------+
void CTMKR_TokenManager::set_refresh_threshold_seconds(int seconds)
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
int CTMKR_TokenManager::get_refresh_threshold_seconds() const
{
    return m_refresh_threshold_seconds;
}

//+------------------------------------------------------------------+
//| Token lifetime in seconds (exp - iat, fallback expires_in)        |
//+------------------------------------------------------------------+
long CTMKR_TokenManager::get_token_lifetime_seconds() const
{
    if(m_expiration_timestamp > 0 && m_issued_at_timestamp > 0 &&
       m_expiration_timestamp > m_issued_at_timestamp)
        return m_expiration_timestamp - m_issued_at_timestamp;
    if(m_expires_in > 0)
        return m_expires_in;
    return 0; // unknown — no clamp possible
}

//+------------------------------------------------------------------+
//| Effective refresh threshold: configured value clamped to half     |
//| the token's real lifetime. A threshold >= the lifetime would make |
//| the refresh predicate true from the moment the token is issued    |
//| (the ~1 refresh/second self-DoS observed in production).          |
//+------------------------------------------------------------------+
int CTMKR_TokenManager::get_effective_refresh_threshold_seconds() const
{
    long effective_threshold = m_refresh_threshold_seconds;
    long lifetime_seconds = get_token_lifetime_seconds();
    if(lifetime_seconds > 0)
    {
        long half_life = lifetime_seconds / 2;
        if(effective_threshold > half_life)
            effective_threshold = half_life;
    }
    return (int)effective_threshold;
}

//+------------------------------------------------------------------+
//| One warning per received token when the clamp is engaged          |
//+------------------------------------------------------------------+
void CTMKR_TokenManager::warn_if_threshold_clamped() const
{
    int effective_threshold = get_effective_refresh_threshold_seconds();
    if(effective_threshold < m_refresh_threshold_seconds && SDKShouldLogWarning())
        Print("SDK Warning: Token refresh threshold (", m_refresh_threshold_seconds,
              "s) is at least half the token lifetime (", get_token_lifetime_seconds(),
              "s). Using effective threshold ", effective_threshold,
              "s to avoid an immediate-refresh loop.");
}

//+------------------------------------------------------------------+
//| Checks if the token should be refreshed proactively               |
//+------------------------------------------------------------------+
bool CTMKR_TokenManager::should_refresh_token()
{
    if(m_expiration_timestamp == 0 || m_jwt == "")
        return false;

    // Use TimeGMT() instead of TimeCurrent() for two reasons:
    // 1. TimeCurrent() doesn't advance when market is closed (weekends/holidays)
    // 2. JWT exp claim is a Unix UTC timestamp, so we should compare with UTC time
    long current_time = TimeGMT();
    long refresh_time = m_expiration_timestamp - get_effective_refresh_threshold_seconds();

    if(current_time < refresh_time)
        return false;

    // Retry cooldown: this predicate is polled every timer tick (1 s). Without a
    // cooldown, a refresh that FAILS while the token is inside the refresh window
    // is retried once per second. Signal at most once per cooldown period; a
    // successfully stored fresh token resets it (set_token/restore_token).
    if(m_last_refresh_signal != 0 &&
       (current_time - m_last_refresh_signal) < TMKR_TOKEN_REFRESH_RETRY_SECONDS)
        return false;

    m_last_refresh_signal = current_time;
    return true;
}

//+------------------------------------------------------------------+
//| Gets the seconds until token expiration                           |
//+------------------------------------------------------------------+
int CTMKR_TokenManager::get_seconds_until_expiration() const
{
    if(m_expiration_timestamp == 0) 
        return 0;
    // Use TimeGMT() for accurate comparison with JWT exp (Unix UTC timestamp)
    return (int)(m_expiration_timestamp - TimeGMT());
}

//+------------------------------------------------------------------+
//| Gets the seconds until refresh threshold                          |
//+------------------------------------------------------------------+
int CTMKR_TokenManager::get_seconds_until_refresh() const
{
    if(m_expiration_timestamp == 0)
        return 0;
    long refresh_time = m_expiration_timestamp - get_effective_refresh_threshold_seconds();
    // Use TimeGMT() for accurate comparison with JWT exp (Unix UTC timestamp)
    return (int)(refresh_time - TimeGMT());
}

//+------------------------------------------------------------------+
//| Decodes the JWT payload to extract claims                         |
//+------------------------------------------------------------------+
bool CTMKR_TokenManager::decode_token_payload(string jwt)
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

    CTMKR_JAVal json_payload;
    if(!json_payload.parse(decoded_payload))
    {
        Print("JWT Error: Failed to parse JSON payload.");
        return false;
    }

    CTMKR_JAVal* exp_node = json_payload["exp"];
    if(CheckPointer(exp_node) == POINTER_INVALID || exp_node.get_type() != TMKR_JA_NUMBER)
    {
        Print("JWT Error: 'exp' claim not found or is not a number.");
        return false;
    }
    m_expiration_timestamp = exp_node.get_long();

    CTMKR_JAVal* iat_node = json_payload["iat"];
    if(CheckPointer(iat_node) != POINTER_INVALID && iat_node.get_type() == TMKR_JA_NUMBER)
    {
        m_issued_at_timestamp = iat_node.get_long();
    }

    return true;
}

//+------------------------------------------------------------------+
//| Converts a Base64/Base64URL character to its 6-bit value          |
//+------------------------------------------------------------------+
int CTMKR_TokenManager::base64_char_to_value(uchar tmkr_c)
{
    if(tmkr_c >= 'A' && tmkr_c <= 'Z') return tmkr_c - 'A';
    if(tmkr_c >= 'a' && tmkr_c <= 'z') return tmkr_c - 'a' + 26;
    if(tmkr_c >= '0' && tmkr_c <= '9') return tmkr_c - '0' + 52;
    if(tmkr_c == '+' || tmkr_c == '-') return 62;
    if(tmkr_c == '/' || tmkr_c == '_') return 63;
    return -1;
}

//+------------------------------------------------------------------+
//| Decodes a Base64URL encoded string                                |
//+------------------------------------------------------------------+
string CTMKR_TokenManager::base64_url_decode(const string &encoded_string)
{
    if(encoded_string == "")
        return "";
    
    string str_input = encoded_string;
    
    StringReplace(str_input, "-", "+");
    StringReplace(str_input, "_", "/");
    
    int padding = 4 - (StringLen(str_input) % 4);
    if(padding != 4)
    {
        for(int tmkr_p = 0; tmkr_p < padding; tmkr_p++)
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
    
    for(int tmkr_i = 0; tmkr_i < input_len; tmkr_i += 4)
    {
        // tmkr_-prefixed to avoid colliding with vendor globals named c0..c3
        // (some vendors declare these at file scope; MQL's strict compiler
        // emits "declaration of 'c1' hides global variable" for the shadow).
        uchar tmkr_c0 = (uchar)StringGetCharacter(str_input, tmkr_i);
        uchar tmkr_c1 = (uchar)StringGetCharacter(str_input, tmkr_i + 1);
        uchar tmkr_c2 = (tmkr_i + 2 < input_len) ? (uchar)StringGetCharacter(str_input, tmkr_i + 2) : '=';
        uchar tmkr_c3 = (tmkr_i + 3 < input_len) ? (uchar)StringGetCharacter(str_input, tmkr_i + 3) : '=';

        int v0 = base64_char_to_value(tmkr_c0);
        int v1 = base64_char_to_value(tmkr_c1);
        int v2 = (tmkr_c2 == '=') ? 0 : base64_char_to_value(tmkr_c2);
        int v3 = (tmkr_c3 == '=') ? 0 : base64_char_to_value(tmkr_c3);

        if(v0 < 0 || v1 < 0 || (tmkr_c2 != '=' && v2 < 0) || (tmkr_c3 != '=' && v3 < 0))
        {
            Print("JWT Error: Invalid Base64 character in input.");
            return "";
        }

        uint combined = ((uint)v0 << 18) | ((uint)v1 << 12) | ((uint)v2 << 6) | (uint)v3;

        if(output_index < output_len)
            output_bytes[output_index++] = (uchar)((combined >> 16) & 0xFF);
        if(output_index < output_len && tmkr_c2 != '=')
            output_bytes[output_index++] = (uchar)((combined >> 8) & 0xFF);
        if(output_index < output_len && tmkr_c3 != '=')
            output_bytes[output_index++] = (uchar)(combined & 0xFF);
    }
    
    string tmkr_result = CharArrayToString(output_bytes, 0, output_index, CP_UTF8);
    return tmkr_result;
}

#endif
//+------------------------------------------------------------------+
