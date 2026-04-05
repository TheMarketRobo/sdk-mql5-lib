//+------------------------------------------------------------------+
//|                                                 TMR_Platform.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"
#property strict

#ifndef TMR_PLATFORM_MQH
#define TMR_PLATFORM_MQH

//+------------------------------------------------------------------+
//| Platform Detection                                                |
//|                                                                    |
//| MQL5 compiler defines __MQL5__; MQL4 compiler defines __MQL4__.   |
//| Both support classes, virtual functions, and inheritance           |
//| (MQL4 since build 600+).                                          |
//|                                                                    |
//| Most AccountInfo*, TerminalInfo*, SymbolInfo* functions exist in   |
//| both platforms. The guards below handle ONLY the enum values and   |
//| functions that are exclusive to one platform.                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Platform identifier — sent to backend in session start payload    |
//+------------------------------------------------------------------+
#ifdef __MQL5__
   #define TMR_PLATFORM "mt5"
#else
   #define TMR_PLATFORM "mt4"
#endif

//+------------------------------------------------------------------+
//| MQL5-only Account Enum Values                                     |
//|                                                                    |
//| These properties don't exist in MQL4. We define sentinel values   |
//| so the SDK can compile on MQL4 and gracefully skip these fields.  |
//+------------------------------------------------------------------+
#ifdef __MQL4__
   // Account properties not available in MQL4
   #define ACCOUNT_MARGIN_MODE        (-1)
   #define ACCOUNT_CURRENCY_DIGITS    (-1)
   #define ACCOUNT_FIFO_CLOSE         (-1)
   #define ACCOUNT_HEDGE_ALLOWED      (-1)

   // Account margin mode values (MQL4 is always netting)
   #define ACCOUNT_MARGIN_MODE_RETAIL_NETTING  0
   #define ACCOUNT_MARGIN_MODE_RETAIL_HEDGING  1
   #define ACCOUNT_MARGIN_MODE_EXCHANGE        2

   // MQL4 uses OP_BUY/OP_SELL; MQL5 uses ORDER_TYPE_BUY/ORDER_TYPE_SELL.
   // Alias the MQL5 names so SDK code compiles on both platforms.
   #define ORDER_TYPE_BUY   OP_BUY
   #define ORDER_TYPE_SELL  OP_SELL
#endif

//+------------------------------------------------------------------+
//| MQL5-only Terminal Enum Values                                    |
//|                                                                    |
//| Most TERMINAL_* properties exist in both MQL4 and MQL5.           |
//| Only TERMINAL_X64 is exclusive to MQL5.                           |
//+------------------------------------------------------------------+
#ifdef __MQL4__
   #define TERMINAL_X64                   (-1)
#endif

//+------------------------------------------------------------------+
//| MQL5-only Symbol String Properties                                |
//|                                                                    |
//| Many SYMBOL_* string properties were added in MQL5 and don't      |
//| exist in MQL4. Define sentinel values for MQL4 so the SDK can     |
//| compile; populate_data() will skip them at runtime.                |
//+------------------------------------------------------------------+
#ifdef __MQL4__
   #define SYMBOL_COUNTRY         (-1)
   #define SYMBOL_CATEGORY        (-1)
   #define SYMBOL_BASIS           (-1)
   #define SYMBOL_PAGE            (-1)
   #define SYMBOL_FORMULA         (-1)
   #define SYMBOL_SECTOR_NAME     (-1)
   #define SYMBOL_INDUSTRY_NAME   (-1)
   #define SYMBOL_BANK            (-1)
   #define SYMBOL_EXCHANGE        (-1)
   #define SYMBOL_ISIN            (-1)
#endif

//+------------------------------------------------------------------+
//| MQLInfoString / MQLInfoInteger                                    |
//|                                                                    |
//| Both functions exist in MQL4 (build 600+) and MQL5.               |
//| Thin wrappers ensure a consistent call-site across the SDK.       |
//+------------------------------------------------------------------+
string TMR_MQLInfoString(int property_id) { return MQLInfoString(property_id); }
int TMR_MQLInfoInteger(int property_id)   { return (int)MQLInfoInteger(property_id); }

//+------------------------------------------------------------------+
//| OrderCalcMargin                                                   |
//|                                                                    |
//| MQL5's OrderCalcMargin() calculates required margin for a trade.  |
//| MQL4 has no direct equivalent. We provide a wrapper that returns  |
//| false on MQL4 (margin_required will stay 0, which is safe — the   |
//| backend treats 0 as "not available").                              |
//+------------------------------------------------------------------+
#ifdef __MQL4__
   bool TMR_OrderCalcMargin(int order_type, string symbol, double volume, double price, double &margin)
   {
      // MQL4 has no OrderCalcMargin equivalent.
      // AccountFreeMarginCheck gives partial info but not per-lot margin.
      // Return false so the caller knows margin data is unavailable.
      margin = 0.0;
      return false;
   }
#else
   bool TMR_OrderCalcMargin(int order_type, string symbol, double volume, double price, double &margin)
   {
      return OrderCalcMargin((ENUM_ORDER_TYPE)order_type, symbol, volume, price, margin);
   }
#endif

//+------------------------------------------------------------------+
//| Indicator Removal from Chart                                      |
//|                                                                    |
//| MQL5 has ChartIndicatorDelete(), ChartIndicatorsTotal(), and      |
//| ChartIndicatorName() for programmatic indicator removal.           |
//| MQL4 also has these functions, but restricts all chart operations  |
//| to Expert Advisors and scripts only (docs.mql4.com/chart_ops).    |
//| Since the SDK calls these from indicator context, the stubs below |
//| return safe no-op values and alert the user to remove manually.   |
//+------------------------------------------------------------------+
#ifdef __MQL4__
   bool TMR_ChartIndicatorDelete(long chart_id, int sub_window, string indicator_name)
   {
      // MQL4 restricts chart operations to EAs/scripts, but forum evidence shows
      // ChartIndicatorDelete works for self-deletion on many MT4 builds because
      // the command is asynchronous (queued, executes after current handler returns).
      // Try the real function first; if it fails, caller falls through to functional death.
      bool result = ChartIndicatorDelete(chart_id, sub_window, indicator_name);
      if(result)
      {
         ChartRedraw(chart_id);
         return true;
      }
      Print("SDK Info: ChartIndicatorDelete returned false on MQL4. ",
            "Disabling indicator output. Please remove '", indicator_name, "' from the chart.");
      return false;
   }

   int TMR_ChartIndicatorsTotal(long chart_id, int sub_window)
   {
      // Try the real function — needed for the fallback scan in SDKRemoveIndicatorFromChart.
      // May return 0 if restricted in indicator context.
      return ChartIndicatorsTotal(chart_id, sub_window);
   }

   string TMR_ChartIndicatorName(long chart_id, int sub_window, int index)
   {
      // Try the real function — needed for the fallback scan in SDKRemoveIndicatorFromChart.
      return ChartIndicatorName(chart_id, sub_window, index);
   }
#else
   bool TMR_ChartIndicatorDelete(long chart_id, int sub_window, string indicator_name)
   {
      return ChartIndicatorDelete(chart_id, sub_window, indicator_name);
   }

   int TMR_ChartIndicatorsTotal(long chart_id, int sub_window)
   {
      return ChartIndicatorsTotal(chart_id, sub_window);
   }

   string TMR_ChartIndicatorName(long chart_id, int sub_window, int index)
   {
      return ChartIndicatorName(chart_id, sub_window, index);
   }
#endif

//+------------------------------------------------------------------+
//| ChartWindowFind and ChartGetInteger                               |
//|                                                                    |
//| ChartWindowFind() exists in both MQL4 and MQL5. MQL4 has a       |
//| parameterless variant for indicators, but the parameterised       |
//| variant used here is restricted to EAs/scripts on MQL4.           |
//| ChartGetInteger with CHART_WINDOWS_TOTAL works on both platforms. |
//+------------------------------------------------------------------+
#ifdef __MQL4__
   int TMR_ChartWindowFind(long chart_id, string indicator_name)
   {
      // MQL4's parameterised ChartWindowFind(chart_id, name) is restricted
      // to EAs/scripts. Return -1 so the caller falls through to the
      // scan loop (also a no-op on MQL4 via TMR_ChartIndicatorsTotal).
      return -1;
   }

   long TMR_ChartGetInteger(long chart_id, int prop_id)
   {
      // CHART_WINDOWS_TOTAL is available in MQL4 via ChartGetInteger
      return ChartGetInteger(chart_id, prop_id);
   }
#else
   int TMR_ChartWindowFind(long chart_id, string indicator_name)
   {
      return ChartWindowFind(chart_id, indicator_name);
   }

   long TMR_ChartGetInteger(long chart_id, int prop_id)
   {
      return ChartGetInteger(chart_id, prop_id);
   }
#endif

//+------------------------------------------------------------------+
//| Helper: Check if a TerminalInfoInteger property is available      |
//|                                                                    |
//| Only TERMINAL_X64 is MQL5-exclusive (sentinel = -1 on MQL4).     |
//| All other TERMINAL_* properties exist on both platforms.           |
//+------------------------------------------------------------------+
bool TMR_IsTerminalPropertyAvailable(int property_id)
{
   return (property_id >= 0);
}

//+------------------------------------------------------------------+
//| Helper: Check if an Account property is available                 |
//+------------------------------------------------------------------+
bool TMR_IsAccountPropertyAvailable(int property_id)
{
   return (property_id >= 0);
}

//+------------------------------------------------------------------+
//| Helper: Check if a Symbol string property is available            |
//+------------------------------------------------------------------+
bool TMR_IsSymbolStringPropertyAvailable(int property_id)
{
   return (property_id >= 0);
}

#endif // TMR_PLATFORM_MQH
//+------------------------------------------------------------------+
