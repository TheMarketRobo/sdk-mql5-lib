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
 * @brief Manages the JWT token for the session, including storage and expiration checking.
 */
class CToken_Manager : public CObject
{
private:
    string m_jwt;
    long m_expiration_timestamp; // 'exp' claim from JWT payload
    long m_refresh_buffer;       // Seconds before expiration to trigger a refresh

public:
    CToken_Manager();
    ~CToken_Manager();

    void set_token(string jwt);
    string get_token() const { return m_jwt; }
    bool is_token_set() const { return m_jwt != ""; }
    bool should_refresh_token();

private:
    bool decode_token_payload(string jwt);
    string base64_url_decode(string encoded_string);
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CToken_Manager::CToken_Manager()
{
    m_jwt = "";
    m_expiration_timestamp = 0;
    m_refresh_buffer = 120; // Refresh 2 minutes before expiration
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
        m_jwt = "";
        Print("Error: Failed to decode JWT payload. Token has been invalidated.");
    }
}

/**
 * @brief Checks if the current token is within the refresh buffer and should be renewed.
 * @return true if the token is set and its expiration is within the refresh buffer period.
 */
bool CToken_Manager::should_refresh_token()
{
    if(m_expiration_timestamp == 0 || m_jwt == "") return false;

    long current_time = TimeCurrent();
    return (m_expiration_timestamp <= (current_time + m_refresh_buffer));
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

    CJAVal* exp_node = json_payload["exp"];
    if(CheckPointer(exp_node) == POINTER_INVALID || exp_node.get_type() != JA_NUMBER)
    {
        Print("JWT Error: 'exp' claim not found or is not a number.");
        return false;
    }

    m_expiration_timestamp = exp_node.get_long();
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
    long expiration = TimeCurrent() + 300; // Assume token expires in 5 minutes
    return "{\"exp\":" + (string)expiration + "}";
}

#endif
//+------------------------------------------------------------------+
