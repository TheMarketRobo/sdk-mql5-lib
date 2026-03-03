# Robot Config Component Schema — Validation Rules

This document summarizes the validation rules applied when your robot configuration schema is submitted on the Vendor Portal. Your config **must** pass these checks before submission is allowed.

## 1. Structure

- Root object must have a `fields` array.
- `fields` must contain at least one field.
- Each field must have: `type`, `key`, `label`, `required`, `default`.

## 2. Field Keys

- **Pattern:** `^[a-z][a-z0-9_]*$` — start with a lowercase letter; only lowercase letters, numbers, and underscores.
- **Unique:** No duplicate keys across fields.
- **Length:** 1–50 characters.

Valid: `max_trades`, `stop_loss_pips`, `use_trailing_stop`.  
Invalid: `MaxTrades`, `stop-loss`, `1st_trade`.

## 3. Type-Specific Rules

### Integer

- `default` must be an integer.
- If `minimum`/`maximum` are set, default must be in range; and `maximum >= minimum`.
- `step` must be an integer ≥ 1.

### Decimal

- `default` must be a number in range if min/max set.
- `step` ≥ 0.0001; `precision` 0–10.

### Boolean

- `default` must be `true` or `false` (boolean, not string).

### Radio

- `options` is required; at least 2 options.
- Each option: `value` (string or number) and `label` (string).
- Option values must be unique.
- `default` must equal one of the option `value`s.

### Multiple

- Same `options` rules as radio.
- `default` must be an array; each element must be an option value.
- Array length must be between `minSelections` and `maxSelections` (if set).
- `maxSelections` cannot exceed the number of options.

## 4. dependsOn

- `field` must reference an existing field key.
- `condition` must be one of: `equals`, `notEquals`, `greaterThan`, `lessThan`, `greaterThanOrEqual`, `lessThanOrEqual`, `contains`, `notContains`.
- `value` must match the type of the referenced field (e.g. boolean for a boolean field, number for numeric).
- No circular dependencies.

## 5. default_config

When you provide default values (e.g. in the Vendor Portal):

- Every required field must have a key in `default_config`.
- Every key in `default_config` must match a field `key`.
- Each value must match the field type and constraints (min/max, options, min/max selections).

## Errors at Submission

If validation fails, the portal returns errors with codes such as:

- `MISSING_FIELDS_ARRAY`, `EMPTY_FIELDS_ARRAY`
- `MISSING_REQUIRED_PROPERTY`, `INVALID_KEY_PATTERN`, `DUPLICATE_FIELD_KEY`
- `INVALID_DEFAULT_TYPE`, `DEFAULT_OUT_OF_RANGE`, `DEFAULT_NOT_IN_OPTIONS`
- `INSUFFICIENT_OPTIONS`, `INVALID_DEPENDENCY_FIELD`, `CIRCULAR_DEPENDENCY`

Fix the reported fields and resubmit. See [README](./README.md) and [examples](./examples/) for valid shapes.
