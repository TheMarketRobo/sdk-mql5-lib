//+------------------------------------------------------------------+
//|                                                  TMKR_Compat.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
/**
 * @file TMKR_Compat.mqh
 * @brief Backwards-compatibility aliases for the pre-2026 (pre-TMKR-rename)
 *        public SDK identifiers.
 *
 * The 2026 TMKR-namespace rename (SDK commit 3a87e84, applied by
 * `scripts/sdk-type-rename.js` from the map in
 * `aws/src/endpoints/common/sdk-integrator/src/lib/sdk-symbols.ts`)
 * renamed every public identifier in place but did not ship the
 * compatibility aliases that the SDK docs and samples promise
 * ("existing robots require NO code changes"). This header restores the
 * PUBLIC legacy surface as preprocessor aliases so vendor code written
 * against the pre-rename API compiles unchanged.
 *
 * Scope: only the vendor-facing names documented in QUICK_START /
 * API_REFERENCE and used by the sample EA/indicator. SDK-internal names
 * (manager classes, event structs, TMKR_ERR_* codes) are NOT aliased —
 * they were never part of the vendor contract.
 *
 * Notes:
 *  - These are plain token aliases; a vendor file that declares its OWN
 *    type with one of these legacy names will collide. Rename the vendor
 *    type or #undef the alias after the SDK include in that file.
 *  - Some legacy spellings survived the rename and are still the REAL
 *    definitions (no alias needed): SDKShouldLogDebug/Info/Warning(),
 *    the SDK_SESSION_* / SDK_HEARTBEAT_* enum values, and the
 *    CONDITION_NOT_EQUALS..CONDITION_NOT_CONTAINS dependency enumerators
 *    (only CONDITION_EQUALS was renamed).
 *  - Included last from TheMarketRobo_SDK.mqh, after all real
 *    definitions. Available in both SDK-enabled and TMR_SDK_DISABLED
 *    builds (every alias target exists in both modes).
 */
#ifndef TMKR_COMPAT_MQH
#define TMKR_COMPAT_MQH

// ── Base classes ────────────────────────────────────────────────────
#define CTheMarketRobo_Base      CTMKR_RobotBase
#define CTheMarketRobo_Bot_Base  CTMKR_RobotBase

// ── Interfaces ──────────────────────────────────────────────────────
#define IRobotConfig             ITMKR_RobotConfig

// ── JSON ────────────────────────────────────────────────────────────
#define CJAVal                   CTMKR_JAVal
#define CJAObj                   CTMKR_JAObj
#define ENUM_JA_TYPE             ENUM_TMKR_JA_TYPE
#define JA_NULL                  TMKR_JA_NULL
#define JA_OBJECT                TMKR_JA_OBJECT
#define JA_ARRAY                 TMKR_JA_ARRAY
#define JA_STRING                TMKR_JA_STRING
#define JA_NUMBER                TMKR_JA_NUMBER
#define JA_BOOL                  TMKR_JA_BOOL

// ── Config schema builder ───────────────────────────────────────────
#define CConfigField             CTMKR_ConfigField
#define CConfigSchema            CTMKR_ConfigSchema
#define CConfigOption            CTMKR_ConfigOption
#define CConfigDependency        CTMKR_ConfigDependency
#define ENUM_CONFIG_FIELD_TYPE   ENUM_TMKR_CONFIG_FIELD_TYPE
#define CONFIG_FIELD_INTEGER     TMKR_CONFIG_FIELD_INTEGER
#define CONFIG_FIELD_DECIMAL     TMKR_CONFIG_FIELD_DECIMAL
#define CONFIG_FIELD_BOOLEAN     TMKR_CONFIG_FIELD_BOOLEAN
#define CONFIG_FIELD_RADIO       TMKR_CONFIG_FIELD_RADIO
#define CONFIG_FIELD_MULTIPLE    TMKR_CONFIG_FIELD_MULTIPLE
#define ENUM_DEPENDENCY_CONDITION ENUM_TMKR_DEPENDENCY_CONDITION
#define CONDITION_EQUALS         TMKR_CONDITION_EQUALS

// ── Logging ─────────────────────────────────────────────────────────
#define ENUM_SDK_LOG_LEVEL       ENUM_TMKR_LOG_LEVEL
#define SDK_LOG_ALL              TMKR_LOG_ALL
#define SDK_LOG_INFO             TMKR_LOG_INFO
#define SDK_LOG_WARNING          TMKR_LOG_WARNING
#define SDK_LOG_ERROR            TMKR_LOG_ERROR
#define SDKSetLogLevel           TMKRSetLogLevel
#define SDKGetLogLevel           TMKRGetLogLevel

// ── Public free functions ───────────────────────────────────────────
#define SDKRemoveIndicatorFromChart TMKRRemoveIndicatorFromChart
#define SDKUserError                TMKRUserError
#define SDKUserErrorWithDetails     TMKRUserErrorWithDetails

#endif // TMKR_COMPAT_MQH
//+------------------------------------------------------------------+
