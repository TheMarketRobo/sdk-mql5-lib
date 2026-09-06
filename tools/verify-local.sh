#!/usr/bin/env bash
# tools/verify-local.sh — LOCAL MIRROR of this repo's required CI checks.
# (ci-cd-hardening P13; this repo had no CI and no verb before it. Ledger L-7.)
#
# Why tools/ and not the fleet-standard scripts/: consistency with the wrapper repo
# `mql5-sample-lib`, which CANNOT have a lowercase `scripts/` — it tracks the MetaTrader
# data-folder directory `Scripts/`, and on case-insensitive dev machines
# (core.ignorecase=true) `git add scripts/…` case-folds into it and silently stages
# nothing. This repo has no such collision, but the two trees are read together often
# enough that one path is worth more than one saved footnote.
#
# CI source of truth: .github/workflows/ci.yml (workflow "CI").
# The single ruleset-required context is its aggregator job:
#
#   required-checks -> needs: [sdk-tls-flags, secret-defaults, commitlint]
#
# Mapping — one local gate per required job:
#
#   | CI job          | Local gate                                                      |
#   |-----------------|-----------------------------------------------------------------|
#   | sdk-tls-flags   | tools/gate-sdk-tls-flags.sh — THE SAME SCRIPT ci.yml runs.      |
#   | secret-defaults | tools/gate-secret-defaults.sh — same script.                    |
#   | commitlint      | gate_commitlint() — the same packages ci.yml installs           |
#   |                 | (@commitlint/cli@19 + @commitlint/config-conventional@19) in a  |
#   |                 | throwaway dir, config pinned at tools/commitlint.config.cjs      |
#   |                 | (file-form of ci.yml's "-x @commitlint/config-conventional"),    |
#   |                 | linting merge-base(origin/main)..HEAD (the PR range). An EMPTY   |
#   |                 | range reports NOTE, never PASS — see gate 0 below.               |
#
# NOT MIRRORED — local-only, and labelled as such on purpose:
#
#   | gate 0          | the three copied templates are byte-identical to hub's masters. |
#   | commit-msg-hook | red-proves .githooks/commit-msg: a bad subject must be REFUSED   |
#   |                 | and a good one accepted. "The file exists" is a claim every      |
#   |                 | uninstalled hook in this fleet could also make.                 |
#   | workflow-lint   | tools/lint-workflows.sh (actionlint + zizmor vs the committed    |
#   |                 | baseline). Deliberately NOT a CI job: installing zizmor on a     |
#   |                 | runner costs more billed minutes per PR than this repo's entire  |
#   |                 | gate matrix, and ../../../.claude/rules/local-verification.md    |
#   |                 | already makes running it on every workflow edit a standing local |
#   |                 | duty. ⚠️ If it is ever promoted to a CI job it joins             |
#   |                 | required-checks `needs:` and this header in the SAME PR.        |
#
# One Δ no local mirror can close, in the other direction from the wrapper's: the
# wrapper runs the same two source gates over the union of both trees, at the sha its
# gitlink pins. Green here does not mean green there — bump the pointer and let the
# wrapper's own PR say so.
#
# MAINTENANCE CONTRACT: if ci.yml's required-checks `needs:` list changes, or a mirrored
# step's commands change, update this header, .github/required-checks.snapshot
# (`bash ../../../scripts/gen-required-checks-snapshot.sh
#   mql5-sample-lib/Include/themarketrobo .github/workflows/ci.yml`) and CLAUDE.md in
# the SAME PR.
#
# All gates run even when one fails; per-gate PASS/FAIL/NOTE summary at the end;
# exit non-zero if any gate failed.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=tools/lib/verify-local-gate0.sh
. "$ROOT/tools/lib/verify-local-gate0.sh"

# The hub tree, reached from mql5-sample-lib/Include/themarketrobo. Absent in a
# standalone clone of this repo, which gate0_assert_template reports as a NOTICE rather
# than a failure — CI's hub-side guards assert the templates anyway.
HUB="$ROOT/../../.."

# ---------------------------------------------------------------------------
# Gate 0 — template integrity. No lockfile check: this repo has no package manifest
# (the commitlint packages are installed by version into a throwaway dir).
# ---------------------------------------------------------------------------
gate_gate0() {
  local rc=0
  gate0_assert_template tools/lint-workflows.sh         "$HUB/scripts/templates/lint-workflows.sh" || rc=1
  gate0_assert_template tools/commit-msg.sh             "$HUB/scripts/templates/commit-msg.sh"     || rc=1
  gate0_assert_template tools/lib/verify-local-gate0.sh "$HUB/scripts/lib/verify-local-gate0.sh"   || rc=1
  return $rc
}

# ---------------------------------------------------------------------------
# Gates 1-2 — mirror of ci.yml jobs sdk-tls-flags and secret-defaults. Each is THE SAME
# SCRIPT the workflow runs, so this mirror cannot drift from CI by transcription.
# ---------------------------------------------------------------------------
gate_sdk_tls_flags()   { bash "$ROOT/tools/gate-sdk-tls-flags.sh"; }
gate_secret_defaults() { bash "$ROOT/tools/gate-secret-defaults.sh"; }

# ---------------------------------------------------------------------------
# Gate 3 — mirror of ci.yml job: commitlint
# ---------------------------------------------------------------------------
gate_commitlint() {
  # nvm is not sourced in non-interactive shells (hub-wide trap) — extend PATH with the
  # pinned node before declaring npm missing.
  command -v npm >/dev/null 2>&1 || PATH="$HOME/.nvm/versions/node/v24.13.1/bin:$PATH"
  if ! command -v npm >/dev/null 2>&1; then
    echo "ERROR: npm not found on PATH (commitlint needs Node — CI uses Node 24)."
    return 1
  fi

  # An EMPTY range is a NOTICE, never a PASS: `commitlint --from X --to X` exits 0
  # because there is nothing to lint, and reporting PASS from that claims a gate ran
  # when nothing did. rc 3 propagates to the runner as NOTE.
  gate0_commitlint_range origin/main
  local range_rc=$?
  [ "$range_rc" -eq 0 ] || return "$range_rc"

  local base tmp rc
  base="$(git merge-base origin/main HEAD)" || return 1
  tmp="$(mktemp -d)" || return 1
  echo "linting range: ${base}..HEAD"
  echo "installing @commitlint/cli@19 + @commitlint/config-conventional@19 (throwaway: $tmp)"
  if ! (cd "$tmp" && npm install --no-save --no-audit --no-fund --loglevel=error \
        @commitlint/cli@19 @commitlint/config-conventional@19); then
    rm -rf "$tmp"
    echo "ERROR: npm install of commitlint failed."
    return 1
  fi
  # The pinned config is copied NEXT TO the throwaway node_modules so its `extends`
  # resolves against the packages installed there.
  cp "$ROOT/tools/commitlint.config.cjs" "$tmp/commitlint.config.cjs" || { rm -rf "$tmp"; return 1; }
  "$tmp/node_modules/.bin/commitlint" --config "$tmp/commitlint.config.cjs" \
    --from "$base" --to HEAD --verbose
  rc=$?
  rm -rf "$tmp"
  return $rc
}

# ---------------------------------------------------------------------------
# commit-msg hook — RED-PROVED, not merely present (ledger L-13).
#
# Wiring is reported separately and does NOT fail: a fresh clone has not run
# `bash tools/install-hooks.sh` yet, and reporting that as a broken gate would train
# people to ignore this line.
# ---------------------------------------------------------------------------
gate_commit_msg_hook() {
  local hook="$ROOT/.githooks/commit-msg" tmp rc=0
  [ -f "$hook" ] || { echo "ERROR: $hook is missing."; return 1; }

  tmp="$(mktemp -d)" || return 1

  printf 'Bump thing from 1 to 2\n' > "$tmp/bad-subject"
  if bash "$hook" "$tmp/bad-subject" >/dev/null 2>&1; then
    echo "ERROR: the hook ACCEPTED a non-conventional subject ('Bump thing from 1 to 2')."
    echo "       That is the Dependabot default subject, which commitlint rejects — the"
    echo "       hook is not doing the one job it exists for."
    rc=1
  else
    echo "  refused a non-conventional subject                    ok"
  fi

  { printf 'fix: a legitimate subject\n\n'
    printf 'This body line is deliberately longer than one hundred columns so that the hook has something real to refuse.\n'
  } > "$tmp/long-body"
  if bash "$hook" "$tmp/long-body" >/dev/null 2>&1; then
    echo "ERROR: the hook ACCEPTED a body line over 100 columns — the rule whose failure"
    echo "       presents fleet-wide as 'CI was green and nothing shipped'."
    rc=1
  else
    echo "  refused a body line over 100 columns                  ok"
  fi

  printf 'fix(ci): a subject this repo should accept\n' > "$tmp/good"
  if bash "$hook" "$tmp/good" >/dev/null 2>&1; then
    echo "  accepted a well-formed conventional subject           ok"
  else
    echo "ERROR: the hook REFUSED a well-formed subject. A hook that refuses everything is"
    echo "       worse than none: the next commit is made with --no-verify and stays that way."
    bash "$hook" "$tmp/good"
    rc=1
  fi

  rm -rf "$tmp"

  local hp
  hp="$(git config core.hooksPath 2>/dev/null || true)"
  if [ "$hp" = ".githooks" ]; then
    echo "  wiring: core.hooksPath=.githooks                      installed"
  else
    echo "  wiring: NOTICE — core.hooksPath='${hp:-unset}' in THIS checkout, so git will not"
    echo "          run the hook here. The hook itself is proven above. Install with:"
    echo "          bash tools/install-hooks.sh"
  fi
  return $rc
}

# ---------------------------------------------------------------------------
# workflow-lint — actionlint + zizmor against the committed baseline. LOCAL-ONLY.
# ---------------------------------------------------------------------------
gate_workflow_lint() { bash "$ROOT/tools/lint-workflows.sh"; }

# ---------------------------------------------------------------------------
# Runner — run ALL gates, summarize, exit non-zero on any failure
# ---------------------------------------------------------------------------
OVERALL=0
SUMMARY=""

run_gate() { # <display-name> <function>
  local name="$1" fn="$2" t0 rc dt verdict
  printf '\n=== gate: %s ===\n' "$name"
  t0=$SECONDS
  "$fn"
  rc=$?
  dt=$(( SECONDS - t0 ))
  # rc 3 is gate 0's NOTICE: the gate could not lint anything, which is neither a pass
  # nor a failure. Printing it as its own verdict is the point — a summary that says
  # PASS for a gate that examined nothing is the defect this whole file guards against.
  case "$rc" in
    0) verdict="PASS" ;;
    3) verdict="NOTE" ;;
    *) verdict="FAIL"; OVERALL=1 ;;
  esac
  SUMMARY="${SUMMARY}$(printf '  %-26s %-4s %3ss' "$name" "$verdict" "$dt")
"
}

run_gate "gate0"            gate_gate0
run_gate "sdk-tls-flags"    gate_sdk_tls_flags
run_gate "secret-defaults"  gate_secret_defaults
run_gate "commitlint"       gate_commitlint
run_gate "commit-msg-hook"  gate_commit_msg_hook
run_gate "workflow-lint"    gate_workflow_lint

printf '\n=== verify-local summary (required-checks mirror + local-only gates) ===\n%s' "$SUMMARY"
printf '  NOTE = the gate ran but had nothing to examine (never counted as a pass).\n'
if [ "$OVERALL" -ne 0 ]; then
  echo "RESULT: FAIL — at least one required gate did not pass."
  exit 1
fi
echo "RESULT: PASS — all required gates green."
exit 0
