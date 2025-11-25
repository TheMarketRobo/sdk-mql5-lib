//+------------------------------------------------------------------+
//|                                               CToken_Manager.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CTOKEN_MANAGER_MQH
#define CTOKEN_MANAGER_MQH

#include <Object.mqh>
#include "../Services/Json.mqh"

/**
 * @class CToken_Manager
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
class CToken_Manager : public CObject
{
private:
    string m_jwt;
    long   m_expiration_timestamp;        // 'exp' claim from JWT payload (Unix timestamp)
    long   m_issued_at_timestamp;         // 'iat' claim from JWT payload (Unix timestamp)
    int    m_refresh_threshold_seconds;   // Seconds before expiration to trigger refresh
    int    m_expires_in;                  // Token validity duration in seconds (from server)

public:
    CToken_Manager();
    ~CToken_Manager();

    // Token Management
    void   set_token(string jwt);
    void   set_expires_in(int expires_in) { m_expires_in = expires_in; }
    string get_token() const { return m_jwt; }
    bool   is_token_set() const { return m_jwt != ""; }
    
    // Proactive Refresh Logic
    bool   should_refresh_token();
    int    get_seconds_until_expiration() const;
    int    get_seconds_until_refresh() const;
    
    // Refresh Threshold Configuration
    int    get_refresh_threshold_seconds() const { return m_refresh_threshold_seconds; }
    void   set_refresh_threshold_seconds(int seconds);

private:
    bool   decode_token_payload(string jwt);
    string base64_url_decode(string encoded_string);
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CToken_Manager::CToken_Manager()
{
    m_jwt = "";
    m_expiration_timestamp = 0;
    m_issued_at_timestamp = 0;
    m_expires_in = 0;
    m_refresh_threshold_seconds = 300; // Default: Refresh 5 minutes (300 seconds) before expiration
}

CToken_Manager::~CToken_Manager()
{
}

/**
 * @brief Sets a new JWT and decodes its payload to extract the expiration time.
 * @param jwt The new JWT string received from the server.
 */
void CToken_Manager::set_token(string jwt)
{
    m_jwt = jwt;
    if(!decode_token_payload(jwt))
    {
        // If decoding fails, invalidate the token to prevent issues.
        m_expiration_timestamp = 0;
        m_issued_at_timestamp = 0;
        m_jwt = "";
        Print("Error: Failed to decode JWT payload. Token has been invalidated.");
    }
    else
    {
        Print("SDK Info: Token set successfully. Expires at: ", TimeToString(m_expiration_timestamp, TIME_DATE|TIME_SECONDS));
        Print("SDK Info: Token will be refreshed ", m_refresh_threshold_seconds, " seconds before expiration.");
    }
}

/**
 * @brief Sets the refresh threshold in seconds.
 * @param seconds Number of seconds before expiration to trigger refresh.
 * @note Minimum value is 60 seconds. Maximum is 3600 seconds (1 hour).
 */
void CToken_Manager::set_refresh_threshold_seconds(int seconds)
{
    // Enforce reasonable bounds
    if(seconds < 60)
    {
        Print("SDK Warning: Refresh threshold too low. Setting to minimum 60 seconds.");
        seconds = 60;
    }
    else if(seconds > 3600)
    {
        Print("SDK Warning: Refresh threshold too high. Setting to maximum 3600 seconds.");
        seconds = 3600;
    }
    
    m_refresh_threshold_seconds = seconds;
    Print("SDK Info: Token refresh threshold set to ", m_refresh_threshold_seconds, " seconds before expiration.");
}

/**
 * @brief Checks if the current token should be refreshed proactively.
 * @return true if the token is set and current time has passed the refresh threshold.
 * @note This implements PROACTIVE refresh - the token is refreshed BEFORE it expires,
 *       not after. This ensures uninterrupted API access.
 */
bool CToken_Manager::should_refresh_token()
{
    if(m_expiration_timestamp == 0 || m_jwt == "") return false;

    long current_time = TimeCurrent();
    long refresh_time = m_expiration_timestamp - m_refresh_threshold_seconds;
    
    // Proactive refresh: trigger when current time >= (expiration - threshold)
    return (current_time >= refresh_time);
}

/**
 * @brief Gets the number of seconds until the token expires.
 * @return Seconds until expiration (negative if already expired).
 */
int CToken_Manager::get_seconds_until_expiration() const
{
    if(m_expiration_timestamp == 0) return 0;
    return (int)(m_expiration_timestamp - TimeCurrent());
}

/**
 * @brief Gets the number of seconds until the token should be refreshed.
 * @return Seconds until refresh threshold (negative if should refresh now).
 */
int CToken_Manager::get_seconds_until_refresh() const
{
    if(m_expiration_timestamp == 0) return 0;
    long refresh_time = m_expiration_timestamp - m_refresh_threshold_seconds;
    return (int)(refresh_time - TimeCurrent());
}

/**
 * @brief Decodes the Base64Url encoded payload of a JWT to read its claims.
 * @param jwt The JWT string.
 * @return true if the payload was successfully decoded and the 'exp' claim was found.
 */
bool CToken_Manager::decode_token_payload(string jwt)
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
        Print("JWT Error: Base64 decoding of payload failed.");
        return false;
    }

    CJAVal json_payload;
    if(!json_payload.parse(decoded_payload))
    {
        Print("JWT Error: Failed to parse JSON payload. Content: ", decoded_payload);
        return false;
    }

    // Extract 'exp' claim (required)
    CJAVal* exp_node = json_payload["exp"];
    if(CheckPointer(exp_node) == POINTER_INVALID || exp_node.get_type() != JA_NUMBER)
    {
        Print("JWT Error: 'exp' claim not found or is not a number.");
        return false;
    }
    m_expiration_timestamp = exp_node.get_long();

    // Extract 'iat' claim (optional)
    CJAVal* iat_node = json_payload["iat"];
    if(CheckPointer(iat_node) != POINTER_INVALID && iat_node.get_type() == JA_NUMBER)
    {
        m_issued_at_timestamp = iat_node.get_long();
    }

    return true;
}

/**
 * @brief Placeholder for Base64Url decoding.
 * @param encoded_string The Base64Url encoded string.
 * @return The decoded string.
 * @note MQL5 lacks a native Base64 decoder. This function is a critical dependency
 *       that would need to be implemented using a third-party library, a DLL call,
 *       or a pure MQL5 implementation. For this design, it returns a dummy valid
 *       JSON payload to allow the rest of the SDK to function.
 */
string CToken_Manager::base64_url_decode(string encoded_string)
{
    // THIS IS A PLACEHOLDER. A REAL BASE64URL DECODE IMPLEMENTATION IS REQUIRED.
    // For testing purposes, assume token expires based on configured threshold + buffer
    long current_time = TimeCurrent();
    long expiration = current_time + m_refresh_threshold_seconds + 60; // Expire after threshold + 1 minute
    long issued_at = current_time;
    return "{\"exp\":" + (string)expiration + ",\"iat\":" + (string)issued_at + "}";
}

#endif
//+------------------------------------------------------------------+
