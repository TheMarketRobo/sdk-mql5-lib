//+------------------------------------------------------------------+
//|                                          CWinINetHttpService.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
//  WinINet.dll-based HTTP service for use in Custom Indicators where
//  the built-in WebRequest() is blocked (MQL5 error 4014).
//
//  Adapted from WinINet.mqh v1.7 by Geraked (MIT License).
//  https://github.com/geraked/metatrader5/blob/master/Include/WinINet.mqh
//+------------------------------------------------------------------+
#ifndef CWININET_HTTP_SERVICE_MQH
#define CWININET_HTTP_SERVICE_MQH

#define WININET_SDK_TIMEOUT_SECS     10
#define WININET_SDK_BUFF_SIZE        16384

#define WININET_INTERNET_FLAG_RELOAD              0x80000000
#define WININET_INTERNET_FLAG_PRAGMA_NOCACHE      0x00000100
#define WININET_INTERNET_FLAG_SECURE              0x00800000
#define WININET_INTERNET_FLAG_KEEP_CONNECTION     0x00400000
#define WININET_INTERNET_FLAG_NO_AUTO_REDIRECT    0x00200000
#define WININET_INTERNET_FLAG_IGNORE_CERT_CN      0x00001000
#define WININET_INTERNET_FLAG_IGNORE_CERT_DATE    0x00002000

#define WININET_HTTP_ADDREQ_FLAG_REPLACE  0x80000000
#define WININET_HTTP_ADDREQ_FLAG_ADD      0x20000000

#define WININET_INTERNET_OPTION_HTTP_DECODING     65
#define WININET_INTERNET_OPTION_SEND_TIMEOUT      5
#define WININET_INTERNET_OPTION_RECEIVE_TIMEOUT   6
#define WININET_HTTP_QUERY_STATUS_CODE            19
#define WININET_HTTP_QUERY_RAW_HEADERS_CRLF       22

#import "kernel32.dll"
uint GetLastError(void);
#import

#import "wininet.dll"
long InternetOpenW(const ushort &lpszAgent[], int dwAccessType, const ushort &lpszProxyName[], const ushort &lpszProxyBypass[], uint dwFlags);
long InternetConnectW(long hInternet, const ushort &lpszServerName[], int nServerPort, const ushort &lpszUsername[], const ushort &lpszPassword[], int dwService, uint dwFlags, int dwContext);
long HttpOpenRequestW(long hConnect, const ushort &lpszVerb[], const ushort &lpszObjectName[], const ushort &lpszVersion[], const ushort &lpszReferer[], const ushort &lplpszAcceptTypes[][], uint dwFlags, int dwContext);
int  InternetCloseHandle(long hInternet);
int  InternetSetOptionW(long hInternet, int dwOption, long &lpBuffer, int dwBufferLength);
int  HttpAddRequestHeadersW(long hRequest, const ushort &lpszHeaders[], int dwHeadersLength, uint dwModifiers);
int  HttpSendRequestExW(long hRequest, long lpBuffersIn, long lpBuffersOut, uint dwFlags, int dwContext);
int  HttpEndRequestW(long hRequest, long lpBuffersOut, uint dwFlags, int dwContext);
int  HttpQueryInfoW(long hRequest, int dwInfoLevel, uchar &lpvBuffer[], int &lpdwBufferLength, int &lpdwIndex);
int  InternetWriteFile(long hFile, const uchar &lpBuffer[], int dwNumberOfBytesToWrite, int &lpdwNumberOfBytesWritten);
int  InternetReadFile(long hFile, uchar &lpBuffer[], int dwNumberOfBytesToRead, int &lpdwNumberOfBytesRead);
#import

//+------------------------------------------------------------------+
//| Parse an HTTPS URL into host and path components.                |
//| Input:  "https://api.staging.themarketrobo.com"                  |
//| Output: host = "api.staging.themarketrobo.com", path = "/"       |
//+------------------------------------------------------------------+
bool WinINetParseUrl(const string url, string &host, string &path, int &port)
{
    string work = url;

    if(StringFind(work, "https://") == 0)
    {
        work = StringSubstr(work, 8);
        port = 443;
    }
    else if(StringFind(work, "http://") == 0)
    {
        work = StringSubstr(work, 7);
        port = 80;
    }
    else
    {
        port = 443;
    }

    // Remove trailing slash
    if(StringLen(work) > 0 && StringGetCharacter(work, StringLen(work) - 1) == '/')
        work = StringSubstr(work, 0, StringLen(work) - 1);

    int slash_pos = StringFind(work, "/");
    if(slash_pos < 0)
    {
        host = work;
        path = "/";
    }
    else
    {
        host = StringSubstr(work, 0, slash_pos);
        path = StringSubstr(work, slash_pos);
    }

    // Check for explicit port in host (e.g. "host:8443")
    int colon_pos = StringFind(host, ":");
    if(colon_pos > 0)
    {
        string port_str = StringSubstr(host, colon_pos + 1);
        host = StringSubstr(host, 0, colon_pos);
        port = (int)StringToInteger(port_str);
    }

    return (StringLen(host) > 0);
}

//+------------------------------------------------------------------+
//| Internal: log WinINet error and clean up handles.                |
//+------------------------------------------------------------------+
int _sdkWinINetErr(string title, long session = 0, long connection = 0, long request = 0)
{
    uint err = kernel32::GetLastError();
    PrintFormat("SDK WinINet Error (%s): kernel32 error #%d", title, err);
    if(request > 0)    InternetCloseHandle(request);
    if(connection > 0) InternetCloseHandle(connection);
    if(session > 0)    InternetCloseHandle(session);
    return -1;
}

//+------------------------------------------------------------------+
//| Send an HTTPS POST request via WinINet.dll.                      |
//| Returns HTTP status code (200, 403, etc.) or -1 on failure.      |
//+------------------------------------------------------------------+
int WinINetPost(const string host,
                const string url_path,
                int          port,
                const string headers_str,
                const string body,
                string       &response_body)
{
    ushort buff[WININET_SDK_BUFF_SIZE / 2];
    ushort buff2[WININET_SDK_BUFF_SIZE / 2];
    uchar  cbuff[WININET_SDK_BUFF_SIZE];
    ushort nill[2]     = {0, 0};
    ushort nill2[2][2] = {{0, 0}, {0, 0}};
    long   lval;
    int    bLen, bLen2, bIdx;

    // --- Open session ---
    string agent = StringFormat("TheMarketRoboSDK/%s (%s)",
                                "1.0",
                                TerminalInfoString(TERMINAL_NAME));
    StringToShortArray(agent, buff);
    long session = InternetOpenW(buff, 0, nill, nill, 0);
    if(session <= 0)
        return _sdkWinINetErr("InternetOpen");

    // Enable gzip/deflate decoding
    lval = 1;
    if(!InternetSetOptionW(session, WININET_INTERNET_OPTION_HTTP_DECODING, lval, sizeof(int)))
        return _sdkWinINetErr("InternetSetOption DECODING", session);

    // Set timeouts
    lval = WININET_SDK_TIMEOUT_SECS * 1000;
    InternetSetOptionW(session, WININET_INTERNET_OPTION_SEND_TIMEOUT, lval, sizeof(int));
    lval = WININET_SDK_TIMEOUT_SECS * 1000;
    InternetSetOptionW(session, WININET_INTERNET_OPTION_RECEIVE_TIMEOUT, lval, sizeof(int));

    // --- Connect ---
    StringToShortArray(host, buff);
    long connection = InternetConnectW(session, buff, port, nill, nill, 3, 0, 0);
    if(connection <= 0)
        return _sdkWinINetErr("InternetConnect", session);

    // --- Open request ---
    StringToShortArray("POST", buff);
    StringToShortArray(url_path, buff2);
    uint flags = WININET_INTERNET_FLAG_RELOAD
               | WININET_INTERNET_FLAG_PRAGMA_NOCACHE
               | WININET_INTERNET_FLAG_KEEP_CONNECTION
               | WININET_INTERNET_FLAG_NO_AUTO_REDIRECT
               | WININET_INTERNET_FLAG_IGNORE_CERT_CN
               | WININET_INTERNET_FLAG_IGNORE_CERT_DATE;
    if(port == 443)
        flags |= WININET_INTERNET_FLAG_SECURE;

    long request = HttpOpenRequestW(connection, buff, buff2, nill, nill, nill2, flags, 0);
    if(request <= 0)
        return _sdkWinINetErr("HttpOpenRequest", session, connection);

    // --- Prepare body bytes ---
    uchar body_data[];
    int body_len = StringToCharArray(body, body_data, 0, WHOLE_ARRAY, CP_UTF8);
    if(body_len > 0 && body_data[body_len - 1] == 0)
        body_len--;

    // --- Add headers ---
    string all_headers = StringFormat("Accept-Encoding: gzip, deflate\r\nContent-Length: %d\r\n%s",
                                      body_len, headers_str);
    bLen = StringToShortArray(all_headers, buff);
    if(bLen > 0 && buff[bLen - 1] == 0) bLen--;
    if(!HttpAddRequestHeadersW(request, buff, bLen, WININET_HTTP_ADDREQ_FLAG_ADD | WININET_HTTP_ADDREQ_FLAG_REPLACE))
        return _sdkWinINetErr("HttpAddRequestHeaders", session, connection, request);

    // --- Send request ---
    int attempts = 0;
    while(!HttpSendRequestExW(request, 0, 0, 0, 0))
    {
        attempts++;
        if(attempts >= 3)
            return _sdkWinINetErr("HttpSendRequestEx", session, connection, request);
        Sleep(500);
    }

    // --- Write body ---
    bIdx = 0;
    while(bIdx < body_len)
    {
        bLen = MathMin(WININET_SDK_BUFF_SIZE, body_len - bIdx);
        ArrayCopy(cbuff, body_data, 0, bIdx, bLen);
        bLen2 = 0;
        if(!InternetWriteFile(request, cbuff, bLen, bLen2))
            return _sdkWinINetErr("InternetWriteFile", session, connection, request);
        bIdx += bLen2;
    }

    if(!HttpEndRequestW(request, 0, 0, 0))
        return _sdkWinINetErr("HttpEndRequest", session, connection, request);

    // --- Read status code ---
    bLen = WININET_SDK_BUFF_SIZE;
    bIdx = 0;
    if(!HttpQueryInfoW(request, WININET_HTTP_QUERY_STATUS_CODE, cbuff, bLen, bIdx))
        return _sdkWinINetErr("HttpQueryInfo STATUS_CODE", session, connection, request);

    // Convert wide-char status code bytes to string
    ushort status_arr[];
    int status_chars = bLen / 2;
    ArrayResize(status_arr, status_chars);
    for(int i = 0; i < status_chars; i++)
        status_arr[i] = (ushort)(cbuff[i * 2] | (cbuff[i * 2 + 1] << 8));
    int status_code = (int)StringToInteger(ShortArrayToString(status_arr, 0, status_chars));

    // --- Read response body ---
    uchar result[];
    bLen = 0;
    while(true)
    {
        if(!InternetReadFile(request, cbuff, WININET_SDK_BUFF_SIZE, bLen))
            return _sdkWinINetErr("InternetReadFile", session, connection, request);
        if(bLen <= 0)
            break;
        ArrayCopy(result, cbuff, ArraySize(result), 0, bLen);
    }

    response_body = CharArrayToString(result, 0, -1, CP_UTF8);

    // --- Cleanup ---
    InternetCloseHandle(request);
    InternetCloseHandle(connection);
    InternetCloseHandle(session);

    return status_code;
}

#endif
//+------------------------------------------------------------------+
