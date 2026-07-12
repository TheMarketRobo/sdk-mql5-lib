//+------------------------------------------------------------------+
//|                                              ITMKR_SymbolGate.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef ITMKR_SYMBOL_GATE_MQH
#define ITMKR_SYMBOL_GATE_MQH

#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"
#property strict

/**
 * @class ITMKR_SymbolGate
 * @brief The strategy's veto on a symbol change, asked BEFORE the ACK is built.
 *
 * The platform contract (session-global.yaml) defines `accepted` as "accepted AND
 * APPLIED by the robot", and `applied_active_to_trade` as "the ACTUAL value that was
 * applied". Until SDK v1.3.0 the symbol rail could not honour that: the only route to
 * the strategy was Fire_Symbol_Change_Event(), which is EventChartCustom() — asynchronous
 * and void — so it fired AFTER the verdict was decided and could never influence it. The
 * SDK therefore ACKed changes the strategy never made.
 *
 * This is the symbol-side counterpart of ITMKR_RobotConfig::update_field() — a SYNCHRONOUS
 * call whose return value decides the ACK. Register an implementation with
 * CTMKR_RobotBase::set_symbol_gate(); a robot with no gate accepts every change (the
 * v1.2.x default), so vendor EAs that don't implement one keep working unchanged.
 */
class ITMKR_SymbolGate
{
public:
    virtual ~ITMKR_SymbolGate() {}

    /**
     * @brief May this symbol's active_to_trade flag move to `tmkr_active_to_trade`?
     *
     * Called once per requested symbol, before the SDK builds the result item. Return
     * false and the SDK reports accepted:false / SYMBOL_NOT_TRADED rather than claiming
     * a change the strategy did not make.
     *
     * Implementations must be cheap and side-effect-free with respect to the request:
     * the SDK applies the flag itself on a true return, and fires on_symbol_changed()
     * afterwards for observability.
     */
    virtual bool can_apply_symbol_change(const string tmkr_symbol,
                                         const bool tmkr_active_to_trade) = 0;
};

#endif // ITMKR_SYMBOL_GATE_MQH
