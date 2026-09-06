#!/usr/bin/env bash
# lint-workflows.sh — actionlint + zizmor over a repo's .github/workflows, against a
# COMMITTED baseline. (ci-cd-hardening P2, eng review D9. Template: hub owns the master
# copy at scripts/templates/lint-workflows.sh and every repo phase copies it VERBATIM.)
#
# ── WHY A TEMPLATE AND NOT ELEVEN SCRIPTS ────────────────────────────────────────────
# Eleven repos need the same workflow lint. Eleven hand-written copies drift, and the
# drift is invisible: each repo's CI stays green while the guards diverge. So this file
# is copied byte-for-byte and each consumer asserts it (`cmp` against hub's copy in that
# repo's verify:local — see scripts/lib/verify-local-gate0.sh::gate0_assert_template).
# ⚠️ Fix a bug HERE, in hub, then re-copy. A local edit is drift by definition.
#
# ── WHY A BASELINE ───────────────────────────────────────────────────────────────────
# `zizmor --pedantic` on a real repo returns dozens of findings on day one, most of them
# accepted risk (a checkout that must persist credentials because it pushes; a
# `${{ needs.x.result }}` whose value is a four-word closed enum). "Fix them all before
# you may turn the gate on" means the gate never turns on. So: every finding that exists
# TODAY is recorded, with a reason, in a committed baseline; anything NEW fails.
#
# The baseline is a RATCHET, in both directions:
#   • a finding not in the baseline → FAIL (that is the gate)
#   • a baseline row that no longer fires → FAIL, telling you to drop the row
# The second half is what makes it shrink. Without it, a baseline is a list of things
# somebody once decided not to look at, and it only ever grows.
# 🚫 Never add a row to silence a NEW finding. Fix the workflow, or — if the risk really
#    is accepted — say so in the row's reason, in the PR that adds it, on purpose.
#
# ── FINGERPRINTS ARE STRUCTURAL, NOT POSITIONAL ──────────────────────────────────────
# A row is `<tool>|<rule>|<file>|<route>`, where route is zizmor's own symbolic path
# (`jobs.commitlint.steps[3]`). Line numbers are deliberately NOT part of it: adding a
# comment above a job would otherwise invalidate every row below it and turn the ratchet
# into noise. Moving a step DOES change its route, and that re-triage is intended.
#
# Usage:
#   bash scripts/templates/lint-workflows.sh                 # the gate
#   bash scripts/templates/lint-workflows.sh --update-baseline
#   bash scripts/templates/lint-workflows.sh --baseline <path> --workflows <dir>
# Exit: 0 = clean · 1 = a new finding, or a stale baseline row · 2 = cannot run honestly
#
# NOTE ON HONESTY: a missing `actionlint` or `zizmor` is exit 2, never a skip. A lint
# that did not run has not passed — the same rule the rest of this fleet's gates follow.

set -uo pipefail

REPO_ROOT="${LINT_WORKFLOWS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT" || exit 2

BASELINE=".github/zizmor-baseline.txt"
WORKFLOWS=".github/workflows"
UPDATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --baseline)  [ $# -ge 2 ] || { echo "--baseline needs a path" >&2; exit 2; }; BASELINE="$2"; shift 2 ;;
    --workflows) [ $# -ge 2 ] || { echo "--workflows needs a path" >&2; exit 2; }; WORKFLOWS="$2"; shift 2 ;;
    --update-baseline) UPDATE=1; shift ;;
    -h|--help) sed -n '2,45p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

[ -d "$WORKFLOWS" ] || { echo "lint-workflows: no $WORKFLOWS in $REPO_ROOT" >&2; exit 2; }

for tool in actionlint zizmor python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "lint-workflows: $tool is required and is NOT installed." >&2
    echo "  install: brew install actionlint zizmor      (verified: actionlint 1.7.12, zizmor 1.30.0)" >&2
    echo "  Refusing to exit 0 — a lint that cannot run has not passed." >&2
    exit 2
  }
done

RC=0

# ---------------------------------------------------------------------------
# 1. actionlint — schema, expression and shellcheck errors in the workflow files
# ---------------------------------------------------------------------------
bold "1. actionlint"
# Bare invocation from the repo root auto-discovers .github/workflows and honours a
# repo-local .github/actionlint.yaml (which is where self-hosted runner LABELS belong —
# never "fix" a runs-on line to please the linter).
if actionlint; then
  green "   actionlint: clean"
else
  red   "   actionlint: findings above. Fix the workflow — actionlint has no baseline here"
  red   "   on purpose: everything it reports is a defect in the file, not accepted risk."
  RC=1
fi

# ---------------------------------------------------------------------------
# 2. zizmor --pedantic, diffed against the committed baseline
# ---------------------------------------------------------------------------
bold "2. zizmor --pedantic (baseline: $BASELINE)"

# --offline ALWAYS, deliberately. Online mode adds API-backed audits and needs a token,
# so the finding set would differ between a laptop with `gh` logged in, CI with
# GITHUB_TOKEN, and a laptop without either — three different answers, one baseline,
# permanent churn. Determinism is worth more here than the extra audits.
ZJSON="$(mktemp)"
trap 'rm -f "$ZJSON"' EXIT
zizmor --pedantic --offline --no-progress --format json "$WORKFLOWS" >"$ZJSON" 2>/dev/null
zrc=$?
# zizmor exits non-zero when it HAS findings; that is expected here (the baseline
# decides). Only a hard tool failure (no JSON at all) is fatal.
if [ ! -s "$ZJSON" ]; then
  red "   zizmor produced no output (exit $zrc) — treating as a tool failure, not a pass."
  exit 2
fi

python3 - "$ZJSON" "$BASELINE" "$UPDATE" <<'PYEOF'
import json, os, sys

zjson, baseline_path, update = sys.argv[1], sys.argv[2], sys.argv[3] == "1"

with open(zjson) as fh:
    findings = json.load(fh)


def route_of(sym):
    parts = []
    for seg in sym["route"]["route"]:
        if "Key" in seg:
            parts.append(str(seg["Key"]))
        elif "Index" in seg:
            parts.append("[%d]" % seg["Index"])
        else:  # a shape this zizmor version added; keep it visible rather than silent
            parts.append(str(seg))
    out = ""
    for p in parts:
        if p.startswith("["):
            out += p
        else:
            out += ("." if out else "") + p
    return out or "<root>"


counts = {}
hints = {}
for f in findings:
    loc = f["locations"][0]
    sym = loc["symbolic"]
    path = sym["key"].get("Local", {}).get("verbatim_path", "?")
    stem = "zizmor|%s|%s|%s" % (f["ident"], path, route_of(sym))
    counts[stem] = counts.get(stem, 0) + 1
    # keep the first annotation as a human hint for a new baseline row
    hints.setdefault(stem, sym.get("annotation") or f["desc"])

# The occurrence COUNT is part of the fingerprint. Several findings of one rule can share
# a route — a `run:` block with eight `${{ }}` expressions in it reports eight
# template-injections at `jobs.required-checks.steps[0]`. Without the count, adding a
# NINTH would land on an existing row and pass silently, which is exactly the hole a
# baseline is supposed to close.
live = {"%s|x%d" % (stem, n): hints[stem] for stem, n in counts.items()}

# The baseline file: `<fingerprint>  # <reason>`; blank lines and full-line `#` are notes.
baselined = {}
if os.path.exists(baseline_path):
    with open(baseline_path) as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            fp, _, reason = line.partition("  #")
            baselined[fp.strip()] = reason.strip()

new = sorted(k for k in live if k not in baselined)
stale = sorted(k for k in baselined if k not in live)

if update:
    with open(baseline_path, "w") as fh:
        fh.write("# zizmor --pedantic --offline baseline (scripts/templates/lint-workflows.sh)\n")
        fh.write("# ONE LINE PER ACCEPTED FINDING: <tool>|<rule>|<file>|<route>  # why it is accepted\n")
        fh.write("# Regenerate with: bash scripts/templates/lint-workflows.sh --update-baseline\n")
        fh.write("# then WRITE A REASON on every new row by hand. A row with no reason is a\n")
        fh.write("# finding nobody triaged, which is the thing this file exists to prevent.\n")
        fh.write("#\n")
        fh.write("# SHRINK-ONLY: a row that no longer fires FAILS the gate until it is removed.\n")
        fh.write("# Never add a row to silence a NEW finding.\n")
        for k in sorted(live):
            reason = baselined.get(k) or "TODO: triage — %s" % live[k]
            fh.write("%s  # %s\n" % (k, reason))
    print("   baseline rewritten: %d row(s) -> %s" % (len(live), baseline_path))
    print("   review the diff and write a reason on every new row before committing.")
    sys.exit(0)

# Untriaged = the generated placeholder OR no reason at all. QA round 1: the first
# version only matched the literal "TODO: triage", so hand-deleting the reason text
# produced a row that passed the gate while saying nothing — the exact state the
# untriaged check exists to refuse.
untriaged = sorted(k for k, r in baselined.items() if not r.strip() or r.startswith("TODO: triage"))

if new:
    print("   NEW zizmor finding(s) — not in the baseline:")
    for k in new:
        print("     + %s" % k)
        print("       %s" % live[k])
    print()
    print("   Fix the workflow. If the risk is genuinely accepted, add the row WITH A")
    print("   REASON in this same PR (--update-baseline writes the rows; you write the why).")
if stale:
    print("   STALE baseline row(s) — these no longer fire, so the baseline is lying:")
    for k in stale:
        print("     - %s" % k)
    print()
    print("   Drop them: bash scripts/templates/lint-workflows.sh --update-baseline")
    print("   (The baseline is shrink-only; a row nobody removes is a finding nobody re-reads.)")
if untriaged:
    print("   UNTRIAGED baseline row(s) — placeholder reason, or no reason at all:")
    for k in untriaged:
        print("     ? %s" % k)

if new or stale or untriaged:
    sys.exit(1)

print("   zizmor: %d finding(s) over %d baselined row(s), each with a reason"
      % (len(findings), len(live)))
sys.exit(0)
PYEOF
prc=$?
[ "$prc" -eq 0 ] || RC="$prc"

printf '\n'
if [ "$RC" -eq 0 ]; then
  green "lint-workflows: OK"
else
  red "lint-workflows: FAILED (see above)"
fi
exit "$RC"
