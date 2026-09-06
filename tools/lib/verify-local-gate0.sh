#!/usr/bin/env bash
# verify-local-gate0.sh — the checks EVERY repo's `verify:local` runs first.
# (ci-cd-hardening P2, eng review D9/D12. SOURCED, never executed.)
#
#   . scripts/lib/verify-local-gate0.sh      # hub
#   . ../scripts/lib/verify-local-gate0.sh   # a submodule, via the hub copy it cmp's
#
# ── WHY "GATE 0" ─────────────────────────────────────────────────────────────────────
# Tier 3 is the expensive tier: it boots containers, initialises submodules, talks to
# GitHub. Three failure classes make ALL of that wasted, and all three are decidable in
# under a second:
#
#   1. A LOCKFILE that does not match its manifest. CI installs with `npm ci` /
#      `--frozen-lockfile` / `--immutable`, which REFUSE on drift; a laptop's plain
#      `npm install` silently rewrites the lockfile instead. So the laptop is green, CI
#      fails at the install step, and the verb that promised to mirror CI never ran a
#      single gate. Catching it first turns a 12-minute red into a 2-second one.
#   2. A COMMITLINT RANGE THAT IS EMPTY. `commitlint --from X --to Y` over zero commits
#      exits 0 — correctly, there is nothing to lint — and a verb that reports "commitlint
#      PASS" from it is telling you a gate ran when nothing did. This is the vacuous-green
#      shape in miniature, inside the very tool meant to prevent it.
#   3. A PINNED CONFIG THAT HAS DRIFTED from the copy CI generates. Two files claiming to
#      be the same config, one of which nothing compares.
#
# Every function here is CHEAP and prints what it decided. None of them talk to a network.

# ---------------------------------------------------------------------------
# gate0_lockfile — the package manager's own frozen-install check, no install.
#
# Each of these resolves the dependency graph and compares it to the lockfile WITHOUT
# writing node_modules/.venv. Use the one that matches the repo; a repo with two
# manifests calls it twice.
# ---------------------------------------------------------------------------
gate0_lockfile() {  # gate0_lockfile <npm|pnpm|yarn|uv> [dir]
  local pm="${1:-}" dir="${2:-.}" rc=0
  ( cd "$dir" 2>/dev/null || exit 2
    case "$pm" in
      npm)
        [ -f package-lock.json ] || { echo "gate0: no package-lock.json in $dir — CI's \`npm ci\` cannot run"; exit 1; }
        npm ci --dry-run --ignore-scripts >/dev/null 2>&1 ;;
      pnpm)
        [ -f pnpm-lock.yaml ] || { echo "gate0: no pnpm-lock.yaml in $dir"; exit 1; }
        pnpm install --frozen-lockfile --lockfile-only >/dev/null 2>&1 ;;
      yarn)
        [ -f yarn.lock ] || { echo "gate0: no yarn.lock in $dir"; exit 1; }
        yarn install --immutable --mode=skip-build >/dev/null 2>&1 ;;
      uv)
        [ -f uv.lock ] || { echo "gate0: no uv.lock in $dir"; exit 1; }
        uv lock --check >/dev/null 2>&1 ;;
      *) echo "gate0_lockfile: unknown package manager '$pm'" >&2; exit 2 ;;
    esac
  ) || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "gate0: $pm lockfile matches its manifest ($dir)"
    return 0
  fi
  if [ "$rc" -eq 2 ]; then return 2; fi
  cat >&2 <<EOF
gate0: $pm LOCKFILE DRIFT in $dir.
  CI installs with a frozen/immutable install and will REFUSE this tree; a plain local
  install would instead rewrite the lockfile and hide the drift. Re-resolve deliberately
  and COMMIT the lockfile in this PR. Running the rest of verify:local now would only
  tell you about a tree CI is never going to reach.
EOF
  return 1
}

# ---------------------------------------------------------------------------
# gate0_commitlint_range — refuse to report PASS on an EMPTY range.
#
# Returns 0 when there is something to lint (the caller then runs commitlint), 3 when the
# range is empty (the caller must print a NOTICE, not a PASS), 1 on a bad base.
# ---------------------------------------------------------------------------
gate0_commitlint_range() {  # gate0_commitlint_range [base-ref]
  local base="${1:-origin/main}" mb n
  if ! git rev-parse --verify --quiet "$base" >/dev/null; then
    echo "gate0: base ref '$base' does not exist here — fetch it before trusting a commitlint result" >&2
    return 1
  fi
  mb="$(git merge-base "$base" HEAD 2>/dev/null)" || return 1
  n="$(git rev-list --count "$mb..HEAD" 2>/dev/null || echo 0)"
  if [ "$n" -eq 0 ]; then
    cat <<EOF
gate0: NOTICE — commitlint range $base..HEAD is EMPTY (0 commits).
  commitlint exits 0 on an empty range, so reporting PASS here would claim a gate ran
  when nothing was linted. This is a NOTICE, not a pass and not a failure: commit
  something, or lint a different range. On a PR, CI lints base..head and will have
  commits to look at.
EOF
    return 3
  fi
  echo "gate0: commitlint range $base..HEAD has $n commit(s) to lint"
  return 0
}

# ---------------------------------------------------------------------------
# gate0_assert_pin — two files that claim to be the same config must be identical.
# ---------------------------------------------------------------------------
gate0_assert_pin() {  # gate0_assert_pin <generated-copy> <committed-pin> [label]
  local gen="$1" pin="$2" label="${3:-pinned config}"
  if diff -u "$gen" "$pin"; then
    echo "gate0: $label matches its pin"
    return 0
  fi
  echo "gate0: $label DRIFT — $pin differs from the copy CI generates. Fix BOTH in one PR." >&2
  return 1
}

# ---------------------------------------------------------------------------
# gate0_assert_template — a copied template must stay byte-identical to hub's master.
#
# The templates (scripts/templates/*.sh) are copied into eleven repos on purpose: one
# implementation, eleven runners. A local edit is drift by definition and is invisible
# — the repo's own CI stays green while its guard diverges from everyone else's. So each
# consumer asserts the copy. ⚠️ Fix a template bug in HUB and re-copy; never in place.
# ---------------------------------------------------------------------------
gate0_assert_template() {  # gate0_assert_template <local-copy> <hub-master>
  local local_copy="$1" master="$2"
  if [ ! -f "$master" ]; then
    echo "gate0: NOTICE — hub master $master not reachable from here; template not asserted." >&2
    echo "  (A standalone clone of a submodule has no hub tree. CI's hub-ci asserts it.)" >&2
    return 0
  fi
  if cmp -s "$local_copy" "$master"; then
    echo "gate0: $(basename "$local_copy") is byte-identical to hub's master"
    return 0
  fi
  echo "gate0: TEMPLATE DRIFT — $local_copy != $master" >&2
  echo "  The templates are copied, not forked. Fix the bug in hub's copy and re-copy here." >&2
  return 1
}
