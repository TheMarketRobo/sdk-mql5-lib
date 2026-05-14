//+------------------------------------------------------------------+
//|                                                  CFinalStats.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CFINAL_STATS_MQH
#define CFINAL_STATS_MQH

#include <Object.mqh>
#include "../Services/Json.mqh"

/**
 * @class CFinalStats
 * @brief Represents the final trading statistics for a session.
 *
 * This class encapsulates all performance metrics and session details
 * that are sent to the server when a trading session is terminated via
 * the `/end` endpoint.
 */
class CTMKR_FinalStats : public CObject 
{
private:
    int m_total_trades;
    int m_winning_trades;
    int m_losing_trades;
    double m_total_pnl;
    double m_max_drawdown;
    int m_session_duration_minutes;
    string m_last_error;
    string m_shutdown_reason;

public:
    CTMKR_FinalStats();
    ~CTMKR_FinalStats();

    void set_total_trades(int total_trades);
    void set_winning_trades(int winning_trades);
    void set_losing_trades(int losing_trades);
    void set_total_pnl(double total_pnl);
    void set_max_drawdown(double max_drawdown);
    void set_session_duration_minutes(int duration);
    void set_last_error(string last_error);
    void set_shutdown_reason(string tmkr_reason);

    CTMKR_JAVal* to_json();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_FinalStats::CFinalStats()
{
    m_total_trades = 0;
    m_winning_trades = 0;
    m_losing_trades = 0;
    m_total_pnl = 0.0;
    m_max_drawdown = 0.0;
    m_session_duration_minutes = 0;
    m_last_error = "";
    m_shutdown_reason = "";
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_FinalStats::~CTMKR_FinalStats()
{
}

//+------------------------------------------------------------------+
//| Setters                                                           |
//+------------------------------------------------------------------+
void CTMKR_FinalStats::set_total_trades(int total_trades) { m_total_trades = total_trades; }
void CTMKR_FinalStats::set_winning_trades(int winning_trades) { m_winning_trades = winning_trades; }
void CTMKR_FinalStats::set_losing_trades(int losing_trades) { m_losing_trades = losing_trades; }
void CTMKR_FinalStats::set_total_pnl(double total_pnl) { m_total_pnl = total_pnl; }
void CTMKR_FinalStats::set_max_drawdown(double max_drawdown) { m_max_drawdown = max_drawdown; }
void CTMKR_FinalStats::set_session_duration_minutes(int duration) { m_session_duration_minutes = duration; }
void CTMKR_FinalStats::set_last_error(string last_error) { m_last_error = last_error; }
void CTMKR_FinalStats::set_shutdown_reason(string tmkr_reason) { m_shutdown_reason = tmkr_reason; }

//+------------------------------------------------------------------+
//| Convert to JSON                                                   |
//+------------------------------------------------------------------+
CTMKR_JAVal* CTMKR_FinalStats::to_json()
{
    CTMKR_JAVal* json = new CTMKR_JAVal(TMKR_JA_OBJECT);
    if(json == NULL) return NULL;

    CTMKR_JAVal* total_trades_val = new CTMKR_JAVal();
    total_trades_val.set_long(m_total_trades);
    json.Add("total_trades", total_trades_val);
    
    CTMKR_JAVal* winning_trades_val = new CTMKR_JAVal();
    winning_trades_val.set_long(m_winning_trades);
    json.Add("winning_trades", winning_trades_val);

    CTMKR_JAVal* losing_trades_val = new CTMKR_JAVal();
    losing_trades_val.set_long(m_losing_trades);
    json.Add("losing_trades", losing_trades_val);

    CTMKR_JAVal* total_pnl_val = new CTMKR_JAVal();
    total_pnl_val.set_double(m_total_pnl);
    json.Add("total_pnl", total_pnl_val);

    CTMKR_JAVal* max_drawdown_val = new CTMKR_JAVal();
    max_drawdown_val.set_double(m_max_drawdown);
    json.Add("max_drawdown", max_drawdown_val);

    CTMKR_JAVal* duration_val = new CTMKR_JAVal();
    duration_val.set_long(m_session_duration_minutes);
    json.Add("session_duration_minutes", duration_val);

    CTMKR_JAVal* last_error_val = new CTMKR_JAVal();
    last_error_val.set_string(m_last_error);
    json.Add("last_error", last_error_val);

    CTMKR_JAVal* shutdown_reason_val = new CTMKR_JAVal();
    shutdown_reason_val.set_string(m_shutdown_reason);
    json.Add("shutdown_reason", shutdown_reason_val);

    return json;
}

#endif
//+------------------------------------------------------------------+

