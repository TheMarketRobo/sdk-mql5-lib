//+------------------------------------------------------------------+
//|                                           IRobot_Callback.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"
#property strict

/**
 * @class Irobot_Callback
 * @brief Interface for the trading robot to receive notifications and events from the SDK.
 *
 * The developer's main Expert Advisor class must implement this interface to handle
 * real-time events such as configuration changes, symbol status updates, and session
 * termination notifications.
 */
class Irobot_Callback
{
public:
    /**
     * @brief Called when a configuration parameter is changed by the server.
     * @param field_name The name of the configuration field that changed.
     * @param old_value The previous value of the field.
     * @param new_value The new value for the field.
     */
    virtual void on_configuration_changed(string field_name, string old_value, string new_value) = 0;

    /**
     * @brief Called when the trading status of a symbol is changed by the server.
     * @param symbol The symbol whose status has changed (e.g., "EURUSD").
     * @param active_to_trade The new trading status for the symbol.
     */
    virtual void on_symbol_status_changed(string symbol, bool active_to_trade) = 0;

    /**
     * @brief Optional: Called when the session termination process has started.
     * The robot can perform its own pre-shutdown cleanup operations here.
     * @param reason The reason for the termination.
     */
    virtual void on_termination_started(string reason) {}

    /**
     * @brief Optional: Called when the SDK has successfully terminated the session.
     * This is the final notification. The robot should complete its cleanup.
     * @param success True if the session was terminated successfully on the server.
     * @param message A descriptive message about the termination result.
     */
    virtual void on_termination_completed(bool success, string message) {}

    /**
     * @brief Optional: Called if an error occurs during the termination process.
     * The SDK will still attempt to perform local cleanup.
     * @param error_message A message describing the error.
     */
    virtual void on_termination_error(string error_message) {}

    /**
     * @brief Optional: Called when a token refresh operation succeeds.
     * Useful for monitoring the connection state.
     */
    virtual void on_token_refresh_success() {}
    
    /**
     * @brief Optional: Called when a token refresh operation fails.
     * @param error_message The error message from the server.
     * @param action_required The action the robot should take (e.g., "restart_required").
     */
    virtual void on_token_refresh_failure(string error_message, string action_required) {}
};
//+------------------------------------------------------------------+
