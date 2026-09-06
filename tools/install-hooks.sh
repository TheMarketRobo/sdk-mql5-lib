#!/usr/bin/env bash
# tools/install-hooks.sh — wire this checkout's git hooks to .githooks/.
# (ci-cd-hardening P13, ledger L-13. Byte-identical to the wrapper repo's copy at
# mql5-sample-lib/tools/install-hooks.sh — the submodule hazard below is the reason it
# exists, and it applies to BOTH repos: mql5-sample-lib is a submodule of hub, and this
# repo is a submodule of mql5-sample-lib.)
#
# Usage: bash tools/install-hooks.sh [--check]
#   --check   report whether hooks are wired here; exit 1 if not. Mutates nothing.
#
# ── WHY THIS IS NOT ONE `git config` LINE ────────────────────────────────────────────
# `git config core.hooksPath .githooks` writes to `.git/config`, which in a LINKED
# WORKTREE is the SHARED config of the main repository. This repo is worked in linked
# worktrees constantly — every Phase Console run builds one, and several plans are live
# at once. Git's answer to exactly that is `git config --worktree`, gated behind
# `extensions.worktreeConfig`.
#
# ── 🚨 AND WHY THAT ANSWER IS FORBIDDEN HERE ─────────────────────────────────────────
# THIS REPO IS A SUBMODULE, and a submodule's shared config carries
# `core.worktree = ../../../../Include/themarketrobo` (or the wrapper's equivalent) — that line is the only thing connecting
# the modules dir under its parent's .git to the checkout. Enabling `extensions.worktreeConfig`
# REVOKES the special case that makes `core.worktree` readable from the shared config
# (git-worktree(1): "the exception for core.bare and core.worktree is gone — if they
# exist in $GIT_DIR/config you must move them to the config.worktree of the main working
# tree"). The instant the extension is on, git stops finding the work tree, resolves
# the toplevel to the git dir, and `git status` reports EVERY TRACKED FILE AS DELETED —
# in every worktree of this submodule at once, including other sessions'.
#
# Measured 2026-09-06 (ci-cd-hardening P13): hub's own scripts/install-hooks.sh does the
# `--worktree` dance and is correct FOR HUB, which is not a submodule. Copying it here
# broke this checkout on the first run. Recovery is one line —
# `git config --unset extensions.worktreeConfig` — but only if you know that is what
# happened, and "all my files vanished" does not point at it.
#
# So: when the shared config carries `core.worktree` (i.e. we are a submodule), this
# script writes `--local` and says so. `core.hooksPath` is then shared by this
# submodule's worktrees, which is benign: the value is RELATIVE, git looks for
# `.githooks/commit-msg` under whichever worktree is running the command, and a branch
# that does not carry the file simply has no hook — git skips a missing hook silently.
#
# ⚠️ This repo installs ONE hook, `commit-msg`, and deliberately no pre-commit/pre-push.
# The reason is written out in .githooks/commit-msg.

set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

GITDIR="$(git rev-parse --git-dir)"
COMMON="$(git rev-parse --git-common-dir)"
LINKED=0
[ "$GITDIR" != "$COMMON" ] && LINKED=1

# The submodule tell: core.worktree present in the SHARED config file. Read the file
# directly — `git config --get core.worktree` would also answer from a worktree-scoped
# override, and it is specifically the shared-config copy that the extension breaks.
SHARED_WORKTREE="$(git config --file "$COMMON/config" --get core.worktree 2>/dev/null || true)"

current="$(git config core.hooksPath 2>/dev/null || true)"

if [ "$CHECK" -eq 1 ]; then
  if [ -n "$current" ] && [ -d "$current" ]; then
    echo "hooks wired: core.hooksPath=$current"
    exit 0
  fi
  echo "hooks NOT wired here (core.hooksPath='${current:-unset}')." >&2
  echo "  run: bash tools/install-hooks.sh" >&2
  exit 1
fi

[ -d .githooks ] || { echo "no .githooks/ in $(pwd)" >&2; exit 1; }
chmod +x .githooks/* 2>/dev/null || true

if [ -n "$SHARED_WORKTREE" ]; then
  # Submodule. --worktree is unavailable here at any price: see the 🚨 block above.
  echo "submodule checkout detected (shared core.worktree='$SHARED_WORKTREE')."
  echo "  writing --local: extensions.worktreeConfig would revoke that setting and"
  echo "  detach every worktree of this submodule from its files. Never enable it here."
  git config --local core.hooksPath .githooks
elif [ "$LINKED" -eq 1 ]; then
  echo "linked worktree detected — scoping core.hooksPath to THIS worktree only."
  if [ "$(git config extensions.worktreeConfig 2>/dev/null || echo false)" != "true" ]; then
    echo "  enabling extensions.worktreeConfig in the shared config (inert for worktrees"
    echo "  that have no config.worktree of their own)."
    git config extensions.worktreeConfig true
  fi
  git config --worktree core.hooksPath .githooks
else
  git config --local core.hooksPath .githooks
fi

echo "hooks installed → $(git config core.hooksPath)"
echo "red-prove them: bash tools/verify-local.sh   (gate: commit-msg-hook)"
