//+------------------------------------------------------------------+
//|                                              TMR_AutoWire.mqh    |
//|                  Copyright 2024, The Market Robo Inc.            |
//|                                  https://themarketrobo.com       |
//+------------------------------------------------------------------+
//
// Boilerplate-elimination macros for SDK integration.
//
// These macros let a vendor's MQL source file declare a fully-wired SDK
// integration in ONE line, instead of duplicating ~80 lines of OnInit /
// OnDeinit / OnTimer / OnTick / OnChartEvent boilerplate that is
// identical across every robot and indicator built on the SDK.
//
// Usage (Robot/EA):
//   #include <themarketrobo/TheMarketRobo_SDK.mqh>
//   input string InpApiKey      = "";
//   input long   InpMagicNumber = 12345;
//   class CMyRobotConfig : public IRobotConfig { ... };
//   class CMyRobot       : public CTheMarketRobo_Base { ... };
//   TMR_DECLARE_ROBOT(CMyRobot, InpApiKey, InpMagicNumber)
//
// Usage (Indicator):
//   #include <themarketrobo/TheMarketRobo_SDK.mqh>
//   input string InpApiKey = "";
//   class CMyIndicator : public CTheMarketRobo_Base { ... };
//   TMR_DECLARE_INDICATOR(CMyIndicator, InpApiKey, 1, "MyIndicator")
//   TMR_FORWARD_ONCALCULATE(g_tmr_indicator_instance)
//
//+------------------------------------------------------------------+
#ifndef TMR_AUTOWIRE_MQH
#define TMR_AUTOWIRE_MQH

#ifndef THEMARKETROBO_SDK_MQH
   #tmkr_error "TMR_AutoWire.mqh requires TheMarketRobo_SDK.mqh — include the SDK first"
#endif

//+------------------------------------------------------------------+
//| TMR_DECLARE_ROBOT(RobotClass, ApiKeyInput, MagicNumberInput)     |
//|                                                                    |
//| Expands to the canonical Robot/EA wiring: a global instance pointer|
//| plus OnInit / OnDeinit / OnTimer / OnTick / OnChartEvent handlers  |
//| with proper CheckPointer guards. RobotClass must derive from       |
//| CTheMarketRobo_Base. ApiKeyInput and MagicNumberInput are the      |
//| names of MQL input parameters; they are referenced (not evaluated) |
//| inside the generated code.                                          |
//+------------------------------------------------------------------+
#define TMR_DECLARE_ROBOT(RobotClass, ApiKeyInput, MagicNumberInput)        \
   RobotClass *g_tmr_robot_instance = NULL;                                  \
   int OnInit()                                                              \
   {                                                                         \
      g_tmr_robot_instance = new RobotClass();                               \
      if(CheckPointer(g_tmr_robot_instance) == POINTER_INVALID)              \
         return INIT_FAILED;                                                 \
      TMKRSetLogLevel(TMKR_LOG_ERROR);                                         \
      return g_tmr_robot_instance.on_init(ApiKeyInput, MagicNumberInput);    \
   }                                                                         \
   void OnDeinit(const int tmkr_reason)                                           \
   {                                                                         \
      if(CheckPointer(g_tmr_robot_instance) != POINTER_INVALID)              \
      {                                                                      \
         g_tmr_robot_instance.on_deinit(tmkr_reason);                             \
         delete g_tmr_robot_instance;                                        \
         g_tmr_robot_instance = NULL;                                        \
      }                                                                      \
   }                                                                         \
   void OnTimer()                                                            \
   {                                                                         \
      if(CheckPointer(g_tmr_robot_instance) != POINTER_INVALID)              \
         g_tmr_robot_instance.on_timer();                                    \
   }                                                                         \
   void OnTick()                                                             \
   {                                                                         \
      if(CheckPointer(g_tmr_robot_instance) != POINTER_INVALID)              \
         g_tmr_robot_instance.on_tick();                                     \
   }                                                                         \
   void OnChartEvent(const int tmkr_id, const long &lparam,                       \
                     const double &dparam, const string &sparam)             \
   {                                                                         \
      if(CheckPointer(g_tmr_robot_instance) != POINTER_INVALID)              \
         g_tmr_robot_instance.on_chart_event(tmkr_id, lparam, dparam, sparam);    \
   }

//+------------------------------------------------------------------+
//| TMR_DECLARE_INDICATOR(IndicatorClass, ApiKeyInput, BufferCount,  |
//|                       ShortName)                                  |
//|                                                                    |
//| Indicator variant: emits the canonical indicator wiring with       |
//| deferred self-removal, set_indicator_short_name,                   |
//| set_indicator_buffer_count, and OnInit / OnDeinit / OnTimer /      |
//| OnChartEvent forwarders. OnCalculate is generated separately via   |
//| TMR_FORWARD_ONCALCULATE so vendors can decide whether to forward   |
//| straight through or wrap with custom logic.                         |
//|                                                                    |
//| IndicatorClass must derive from CTheMarketRobo_Base; BufferCount   |
//| matches #property indicator_buffers; ShortName is the literal      |
//| short-name string registered with the chart.                       |
//+------------------------------------------------------------------+
#define TMR_DECLARE_INDICATOR(IndicatorClass, ApiKeyInput, BufferCount, ShortName) \
   IndicatorClass *g_tmr_indicator_instance = NULL;                                  \
   bool   g_pending_removal = false;                                                  \
   string g_indicator_short_name = ShortName;                                         \
   int OnInit()                                                                       \
   {                                                                                  \
      g_indicator_short_name = ShortName;                                             \
      g_pending_removal = false;                                                      \
      /* In tester there is no user to read alerts and no API key needed.   */        \
      /* Let the SDK's init_common() see the empty key and trip its own     */        \
      /* tester gate; the indicator boots offline.                          */        \
      if(ApiKeyInput == "" && !TMR_IsInTester())                                      \
      {                                                                               \
         TMKRUserErrorCoded(TMKR_ERR_1002, "API Key is required. Please set it in the indicator settings.");\
         g_pending_removal = true;                                                    \
         EventSetTimer(1);                                                            \
         return INIT_SUCCEEDED;                                                       \
      }                                                                               \
      g_tmr_indicator_instance = new IndicatorClass();                                \
      if(CheckPointer(g_tmr_indicator_instance) == POINTER_INVALID)                   \
      {                                                                               \
         /* In tester there is no user to alert and OnTimer doesn't fire for */       \
         /* MQL4 indicators; setting g_pending_removal would only cause      */       \
         /* per-bar TMKRRemoveIndicatorFromChart spam. Fail silently.         */       \
         if(!TMR_IsInTester())                                                        \
         {                                                                            \
            TMKRUserErrorCoded(TMKR_ERR_9010, "Failed to start. Please try removing and re-adding.");\
            g_pending_removal = true;                                                 \
            EventSetTimer(1);                                                         \
         }                                                                            \
         return INIT_SUCCEEDED;                                                       \
      }                                                                               \
      g_tmr_indicator_instance.set_indicator_short_name(g_indicator_short_name);      \
      g_tmr_indicator_instance.set_indicator_buffer_count(BufferCount);               \
      TMKRSetLogLevel(TMKR_LOG_ERROR);                                                  \
      int _tmr_init_result = g_tmr_indicator_instance.on_init(ApiKeyInput);           \
      if(_tmr_init_result != INIT_SUCCEEDED)                                          \
      {                                                                               \
         /* Same rationale as above — tester path skips the removal flow. */          \
         if(!TMR_IsInTester())                                                        \
         {                                                                            \
            g_pending_removal = g_tmr_indicator_instance.is_pending_removal();        \
            if(!g_pending_removal)                                                    \
            {                                                                         \
               TMKRUserErrorCoded(TMKR_ERR_3020, "Could not connect to TheMarketRobo service.");\
               g_pending_removal = true;                                              \
            }                                                                         \
            EventSetTimer(1);                                                         \
         }                                                                            \
         delete g_tmr_indicator_instance;                                             \
         g_tmr_indicator_instance = NULL;                                             \
      }                                                                               \
      return INIT_SUCCEEDED;                                                          \
   }                                                                                  \
   void OnDeinit(const int tmkr_reason)                                                    \
   {                                                                                  \
      if(CheckPointer(g_tmr_indicator_instance) != POINTER_INVALID)                   \
      {                                                                               \
         g_tmr_indicator_instance.on_deinit(tmkr_reason);                                  \
         delete g_tmr_indicator_instance;                                             \
         g_tmr_indicator_instance = NULL;                                             \
      }                                                                               \
   }                                                                                  \
   void OnTimer()                                                                     \
   {                                                                                  \
      if(g_pending_removal)                                                           \
      {                                                                               \
         EventKillTimer();                                                            \
         TMKRRemoveIndicatorFromChart(g_indicator_short_name);                         \
         return;                                                                      \
      }                                                                               \
      if(CheckPointer(g_tmr_indicator_instance) != POINTER_INVALID)                   \
         g_tmr_indicator_instance.on_timer();                                         \
   }                                                                                  \
   void OnChartEvent(const int tmkr_id, const long &lparam,                                \
                     const double &dparam, const string &sparam)                      \
   {                                                                                  \
      if(CheckPointer(g_tmr_indicator_instance) != POINTER_INVALID)                   \
         g_tmr_indicator_instance.on_chart_event(tmkr_id, lparam, dparam, sparam);         \
   }

//+------------------------------------------------------------------+
//| TMR_FORWARD_ONCALCULATE(InstanceName)                            |
//|                                                                    |
//| Generates the standard OnCalculate forwarder. Vendors who want to  |
//| keep their own OnCalculate (e.g. to do extra work outside the SDK  |
//| wrapper class) can skip this macro and call                         |
//| InstanceName.on_calculate(...) themselves.                          |
//+------------------------------------------------------------------+
#define TMR_FORWARD_ONCALCULATE(InstanceName)                                         \
   int OnCalculate(const int rates_total, const int prev_calculated,                  \
                   const datetime &tmkr_time[], const double &open[],                      \
                   const double &high[], const double &low[],                         \
                   const double &close[], const long &tick_volume[],                  \
                   const long &tmkr_volume[], const int &tmkr_spread[])                         \
   {                                                                                  \
      if(CheckPointer(InstanceName) != POINTER_INVALID && InstanceName.is_killed())   \
         return rates_total;                                                          \
      if(g_pending_removal)                                                           \
      {                                                                               \
         TMKRRemoveIndicatorFromChart(g_indicator_short_name);                         \
         return rates_total;                                                          \
      }                                                                               \
      if(CheckPointer(InstanceName) != POINTER_INVALID)                               \
         return InstanceName.on_calculate(rates_total, prev_calculated,               \
                                          tmkr_time, open, high, low, close,               \
                                          tick_volume, tmkr_volume, tmkr_spread);               \
      return rates_total;                                                             \
   }

//+------------------------------------------------------------------+
//| Fine-grained forwarders                                          |
//|                                                                    |
//| Useful when a vendor wants to keep their own OnInit (e.g. for      |
//| custom indicator buffer setup that must run before SDK init) but   |
//| still wants the standard handlers without retyping them.           |
//+------------------------------------------------------------------+
#define TMR_FORWARD_ONDEINIT(InstanceName)                                            \
   void OnDeinit(const int tmkr_reason)                                                    \
   {                                                                                  \
      if(CheckPointer(InstanceName) != POINTER_INVALID)                               \
      {                                                                               \
         InstanceName.on_deinit(tmkr_reason);                                              \
         delete InstanceName;                                                         \
         InstanceName = NULL;                                                         \
      }                                                                               \
   }

#define TMR_FORWARD_ONTIMER(InstanceName)                                             \
   void OnTimer()                                                                     \
   {                                                                                  \
      if(CheckPointer(InstanceName) != POINTER_INVALID)                               \
         InstanceName.on_timer();                                                     \
   }

#define TMR_FORWARD_ONTICK(InstanceName)                                              \
   void OnTick()                                                                      \
   {                                                                                  \
      if(CheckPointer(InstanceName) != POINTER_INVALID)                               \
         InstanceName.on_tick();                                                      \
   }

#define TMR_FORWARD_ONCHARTEVENT(InstanceName)                                        \
   void OnChartEvent(const int tmkr_id, const long &lparam,                                \
                     const double &dparam, const string &sparam)                      \
   {                                                                                  \
      if(CheckPointer(InstanceName) != POINTER_INVALID)                               \
         InstanceName.on_chart_event(tmkr_id, lparam, dparam, sparam);                     \
   }

#endif // TMR_AUTOWIRE_MQH
//+------------------------------------------------------------------+
