#!/usr/bin/env bash
# tools/test-final-stats.sh — T-55b: how a session ends, read from the source.
# (trade-feature-wave-1 Phase 18, FC-55: F-17.)
#
# POST /robot/end's contract (aws contracts/api/robot/components/robot-end.yaml) is
# {reason, final_stats}: `reason` one of six values, `final_stats` eight keys counted from
# the session's own closed deals. SDK <= 1.4.4 sent `session_id` (never read), free text in
# `reason` ("EA Shutdown: reason 1") and a CTMKR_FinalStats nothing ever filled in, so every
# end reported zero trades.
#
# No MQL compiler or terminal runs on a laptop or a CI runner, so this test reads the
# headers. It asserts the structure the contract needs:
#   1. end_session() sends `reason` through TMKREndReasonName() and no `session_id`;
#   2. TMKREndReasonName() can return exactly the contract's six values (checked against
#      the aws contract too, when an aws checkout sits beside this repo);
#   3. every internal terminate() call names an ENUM_TMKR_END_REASON, so `reason` is never
#      free text again;
#   4. final_stats.total_trades is the closed-deal count: terminate() fills the stats with
#      the data collector's collect_session_stats() before end_session(), and that method
#      counts, per dialect, the session's exit deals (MQL5) or closed market orders (MQL4)
#      carrying the robot's magic number, into the one variable set_total_trades() reads;
#   5. both ways a session begins (start_session, resume_session) record its start time.
#
# Local-only: tools/verify-local.sh runs it and labels it so. Exit 0 = pass, 1 = fail.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found on PATH (this test parses the headers with it)."
  exit 1
fi

exec python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
contract = root.parent.parent.parent / "aws/contracts/api/robot/components/robot-end.yaml"
CONTRACT_REASONS = {
    "normal_shutdown", "error_shutdown", "maintenance_shutdown",
    "user_request", "license_expired", "system_error",
}
failures = []


def check(ok, what):
    print(f"  {'ok  ' if ok else 'FAIL'} {what}")
    if not ok:
        failures.append(what)


def code(path):
    """The file without comments, so prose naming a call is never counted as one."""
    text = (root / path).read_text(encoding="utf-8", errors="replace")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return "\n".join(line.split("//", 1)[0] for line in text.splitlines())


def body(text, signature):
    """The body of the first definition whose header matches ``signature`` (a regex)."""
    m = re.search(signature + r"[^;{]*\{", text)
    if not m:
        return None
    depth, i = 1, m.end()
    while depth and i < len(text):
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return text[m.end():i - 1]


def region(text, macro):
    """Every `#ifdef <macro>` region of ``text``, joined (no nested #ifdef inside)."""
    return "\n".join(re.findall(r"#ifdef\s+" + macro + r"\b(.*?)#(?:else|endif)", text, flags=re.S))


session = code("Core/CSessionManager.mqh")
context = code("Core/CSDKContext.mqh")
stats = code("Models/CFinalStats.mqh")
collector = code("Services/CDataCollectorService.mqh")
everything = "\n".join(
    code(p.relative_to(root)) for p in sorted(root.rglob("*.mqh")) if "tools" not in p.parts
)

print("1. the end payload")
end = body(session, r"bool\s+CTMKR_SessionManager::end_session\s*\(")
check(end is not None, "CTMKR_SessionManager::end_session is defined")
end = end or ""
check('"session_id"' not in end, "end_session sends no session_id (the token names the session)")
check(re.search(r'Add\(\s*"reason"', end) is not None and "TMKREndReasonName(" in end,
      "end_session sends `reason` through TMKREndReasonName()")
check(re.search(r'Add\(\s*"final_stats"', end) is not None, "end_session sends final_stats")

print("2. the reason vocabulary")
names = body(stats, r"string\s+TMKREndReasonName\s*\(")
returned = set(re.findall(r'return\s+"([a-z_]+)"', names or ""))
check(returned == CONTRACT_REASONS,
      f"TMKREndReasonName returns exactly the contract's six values (got {sorted(returned)})")
if contract.is_file():
    block = re.search(r"\n        reason:\n(.*?)\n        final_stats:", contract.read_text(), re.S)
    listed = set(re.findall(r"^\s+- ([a-z_]+)$", block.group(1), re.M)) if block else set()
    check(listed == CONTRACT_REASONS, f"the aws contract's reason enum is the same six ({contract})")
else:
    print("  NOTE no aws checkout beside this repo: the six values are checked as embedded here")

print("3. every terminate() names an end reason")
calls = re.findall(r"\bterminate\(\s*([^,)]*)", everything)
calls = [c for c in calls if not re.match(r"(string|ENUM_TMKR_END_REASON)\s", c)]
free_text = [c for c in calls if not re.match(r"TMKR_END_[A-Z_]+$|TMKREndReasonForDeinit\(", c.strip())]
check(len(calls) >= 4, f"the four ways a session ends call terminate() ({len(calls)} found)")
check(free_text == [], f"no terminate() call passes free text as the reason ({free_text})")

print("4. final_stats.total_trades is the closed-deal count")
term = body(context, r"void\s+CTMKR_Context::terminate\s*\(\s*ENUM_TMKR_END_REASON")
check(term is not None, "CTMKR_Context::terminate(ENUM_TMKR_END_REASON, ...) is defined")
term = term or ""
fill = term.find("collect_session_stats(")
send = term.find("end_session(")
check(0 <= fill < send, "terminate() fills the stats before end_session() sends them")
collect = body(collector, r"void\s+CTMKR_DataCollectorService::collect_session_stats\s*\(") or ""
check(collect != "", "CTMKR_DataCollectorService::collect_session_stats is defined")
counted = re.findall(r"set_total_trades\(\s*(\w+)\s*\)", collect)
check(len(counted) == 1, f"one set_total_trades() call, from a counter ({counted})")
counter = counted[0] if counted else "\x00"
mql5, mql4 = region(collect, "__MQL5__"), region(collect, "__MQL4__")
check(all(t in mql5 for t in ("HistorySelect(", "HistoryDealsTotal()", "HistoryDealGetTicket(",
                              "DEAL_MAGIC", "DEAL_ENTRY_OUT", "DEAL_ENTRY_INOUT", "DEAL_ENTRY_OUT_BY")),
      "MQL5 reads the session's deals by magic number and keeps the exit deals")
check(all(t in mql4 for t in ("OrdersHistoryTotal()", "MODE_HISTORY", "OrderMagicNumber()",
                              "OrderCloseTime()", "OP_BUY", "OP_SELL")),
      "MQL4 reads the closed market orders by magic number and close time")
check(re.search(rf"\b{counter}\+\+", mql5) is not None and re.search(rf"\b{counter}\+\+", mql4) is not None,
      f"both dialects count each closed trade into `{counter}`, the value set_total_trades() sends")

print("5. the session start is recorded")
for fn in ("start_session", "resume_session"):
    b = body(session, rf"bool\s+CTMKR_SessionManager::{fn}\s*\(") or ""
    check(re.search(r"m_session_started_at\s*=\s*TimeCurrent\(\)", b) is not None,
          f"{fn} records the session's start (server time)")

if failures:
    print(f"T-55b: FAIL — {len(failures)} check(s) failed")
    sys.exit(1)
print("T-55b: PASS")
PY
