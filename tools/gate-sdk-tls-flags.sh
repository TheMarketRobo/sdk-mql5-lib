#!/usr/bin/env bash
# tools/gate-sdk-tls-flags.sh — TLS validation stays on (audit state-path SDK-1 / MQL-1, HIGH).
#
# ONE implementation, called by BOTH .github/workflows/ci.yml (job `sdk-tls-flags`)
# and tools/verify-local.sh.
#
# ── WHY THIS REPO NEEDS ITS OWN COPY ─────────────────────────────────────────────────
# The wrapper repo `mql5-sample-lib` runs the same gate over the union of its own tree
# and this one, reached through the `Include/themarketrobo` gitlink. That check is real,
# but it only fires on a *wrapper* PR — and it tests the sha the wrapper PINS, which is
# whatever the pointer last recorded. A change landing HERE reached `main` with nothing
# looking at it, sometimes for weeks, until someone bumped the pointer.
#
# This repo is PUBLIC and is the actual home of the transport, so the gate belongs here
# too (ci-cd-hardening P13, ledger L-7 / N-17). The wrapper's copy stays: two checks over
# the same code from opposite sides of the gitlink is the point, not duplication.
#
# ── WHAT IT DEFENDS ──────────────────────────────────────────────────────────────────
# CWinINetHttpService is the indicator transport (indicators cannot call WebRequest —
# MQL error 4014 — so it drives wininet.dll directly). It used to build its request
# flags with INTERNET_FLAG_IGNORE_CERT_CN_INVALID | _DATE_INVALID set UNCONDITIONALLY,
# which told WinINet to accept any CA-issued certificate for any hostname, expired or
# not, on every request — each carrying the vendor API key and the session token. Since
# SDK v1.3.2 both flags compile in only under an explicit TMKR_INSECURE_TLS_DEBUG opt-in.
#
# Two assertions, and the second is the one that matters:
#   A. TMKR_INSECURE_TLS_DEBUG is #defined nowhere in the tree — an opt-in that the
#      shipped tree opts into is not an opt-in.
#   B. Every mention of IGNORE_CERT in MQL source sits either inside a
#      `#ifdef TMKR_INSECURE_TLS_DEBUG` region or in a comment. A bare one is the
#      original defect returning.
#
# Portability: parsing is python3, never shell regex (`git grep -E '\s'` matches
# nothing under macOS BSD userland and everything under Linux).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

# This repo IS the SDK — there is no submodule to descend into, which is the only
# difference from the wrapper's copy of this gate.
git ls-files -z -- '*.mqh' '*.mq4' '*.mq5' | python3 -c '
import re, sys

GUARD = "TMKR_INSECURE_TLS_DEBUG"
paths = [p for p in sys.stdin.buffer.read().split(b"\0") if p]

define_of_guard = []   # assertion A violations
bare_ignore     = []   # assertion B violations
guarded_count   = 0
scanned         = 0

re_def    = re.compile(r"^\s*#\s*define\s+" + GUARD + r"\b")
re_ifdef  = re.compile(r"^\s*#\s*if(def)?\b.*\b" + GUARD + r"\b")
re_ifany  = re.compile(r"^\s*#\s*if(n?def)?\b")
re_endif  = re.compile(r"^\s*#\s*endif\b")
re_else   = re.compile(r"^\s*#\s*else\b")

for raw in paths:
    p = raw.decode("utf-8", "surrogateescape")
    try:
        with open(p, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError:
        continue
    scanned += 1

    # Track nested #if regions and whether any enclosing one is the guard.
    stack = []          # list of bool: "this region is the TMKR_INSECURE_TLS_DEBUG guard"
    in_block_comment = False

    for n, line in enumerate(lines, 1):
        if re_def.match(line):
            define_of_guard.append(f"{p}:{n}: {line.strip()}")

        if re_ifany.match(line):
            stack.append(bool(re_ifdef.match(line)))
        elif re_else.match(line) and stack:
            # #else of the guard region is the NOT-guarded half.
            stack[-1] = False
        elif re_endif.match(line) and stack:
            stack.pop()

        # Strip comments before deciding whether IGNORE_CERT is live code.
        code = line
        if in_block_comment:
            end = code.find("*/")
            if end == -1:
                continue
            code = code[end + 2:]
            in_block_comment = False
        start = code.find("/*")
        while start != -1:
            end = code.find("*/", start + 2)
            if end == -1:
                code = code[:start]
                in_block_comment = True
                break
            code = code[:start] + code[end + 2:]
            start = code.find("/*")
        slash = code.find("//")
        if slash != -1:
            code = code[:slash]

        if "IGNORE_CERT" not in code:
            continue
        if any(stack):
            guarded_count += 1
        else:
            bare_ignore.append(f"{p}:{n}: {line.strip()}")

print(f"  scanned {scanned} tracked MQL source files")
print(f"  IGNORE_CERT mentions inside a #ifdef {GUARD} region: {guarded_count}")

# A scan that found no files is not a pass. This repo has ~29 tracked .mqh sources; a
# zero here means the enumeration broke (wrong cwd, empty checkout), and reporting
# "no violations" from it would be the vacuous-green shape this fleet keeps paying for.
if scanned == 0:
    print("\nERROR: no tracked MQL sources were scanned. That is a broken gate, not a clean")
    print("       tree — check the working directory and that this is a full checkout.")
    sys.exit(1)

fail = False
if define_of_guard:
    fail = True
    print(f"\nERROR: {GUARD} is #defined in the tree. It is an opt-in for a developer")
    print("       building locally; a shipped tree that defines it ships the vulnerability.")
    for h in define_of_guard:
        print(f"       {h}")
if bare_ignore:
    fail = True
    print("\nERROR: IGNORE_CERT appears in live code outside a")
    print(f"       `#ifdef {GUARD}` region. Those flags disable TLS hostname and expiry")
    print("       validation on a transport that carries the vendor API key and the session")
    print("       token (audit state-path SDK-1 / MQL-1, HIGH). Guard them or remove them.")
    for h in bare_ignore:
        print(f"       {h}")

if fail:
    sys.exit(1)
print("\nTLS certificate validation is enforced: no unguarded IGNORE_CERT, guard never defined.")
'
