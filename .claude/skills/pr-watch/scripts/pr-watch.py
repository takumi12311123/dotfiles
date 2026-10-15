#!/usr/bin/env python3
"""JSON half of pr-watch-poll.sh: merge gh outputs into one snapshot and keep the
state file of handled comment ids. Only the shell wrapper talks to gh."""
import argparse
import json
import os
import sys
from datetime import datetime, timezone


def die(msg, code=1):
    print(f"pr-watch: {msg}", file=sys.stderr)
    sys.exit(code)


def load_json(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    # `gh api --paginate` concatenates one JSON document per page.
    decoder = json.JSONDecoder()
    docs, pos = [], 0
    while True:
        while pos < len(text) and text[pos].isspace():
            pos += 1
        if pos >= len(text):
            break
        doc, pos = decoder.raw_decode(text, pos)
        docs.append(doc)
    if not docs:
        die(f"empty JSON in {path}")
    return docs


def load_list(path):
    items = []
    for doc in load_json(path):
        if not isinstance(doc, list):
            die(f"expected a JSON array in {path}")
        items.extend(doc)
    return items


def norm_login(login):
    login = (login or "").strip().lower()
    return login[:-5] if login.endswith("[bot]") else login


def load_state(path):
    if not path or not os.path.exists(path):
        return {"pr": None, "handled": {}, "vars": {}}
    try:
        with open(path, encoding="utf-8") as f:
            state = json.load(f)
    except (OSError, ValueError) as e:
        die(f"cannot read state file {path}: {e}")
    if not isinstance(state, dict) or not isinstance(state.get("handled"), dict):
        die(f"state file {path} is not a pr-watch state")
    state.setdefault("vars", {})
    return state


def save_state(path, state):
    state["updated_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)


def check_state_pr(state, pr, path):
    if state.get("pr") not in (None, pr):
        die(f"state file {path} belongs to PR #{state['pr']}, not #{pr}")


FAILED = {"FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE", "STALE"}
SKIPPED = {"SKIPPED", "NEUTRAL"}


def norm_check(item):
    if item.get("__typename") == "StatusContext" or "context" in item:
        raw = (item.get("state") or "").upper()
        if raw == "SUCCESS":
            state = "success"
        elif raw in FAILED:
            state = "failure"
        else:
            state = "pending"
        return {"name": item.get("context", ""), "state": state, "url": item.get("targetUrl")}
    status = (item.get("status") or "").upper()
    conclusion = (item.get("conclusion") or "").upper()
    if status != "COMPLETED":
        state = "pending"
    elif conclusion == "SUCCESS":
        state = "success"
    elif conclusion in SKIPPED:
        state = "skipped"
    else:
        state = "failure"
    return {"name": item.get("name", ""), "state": state, "url": item.get("detailsUrl"),
            "workflow": item.get("workflowName")}


def summarize(checks):
    states = {c["state"] for c in checks}
    if "failure" in states:
        return "failure"
    if "pending" in states:
        return "pending"
    return "success"


def cmd_merge(a):
    pr_view = load_json(a.pr_view)[0]
    threads, viewer = [], None
    for doc in load_json(a.threads):
        data = doc.get("data") or {}
        viewer = viewer or norm_login((data.get("viewer") or {}).get("login"))
        pr_node = (data.get("repository") or {}).get("pullRequest") or {}
        threads.extend(((pr_node.get("reviewThreads") or {}).get("nodes")) or [])
    issues = load_list(a.issues)
    reviews = load_list(a.reviews)
    state = load_state(a.state)
    check_state_pr(state, a.pr, a.state)
    handled = state["handled"]
    ai_logins = {norm_login(x) for x in a.ai_logins.split(",") if x.strip()}

    ai, human = [], []

    def route(entry):
        if str(entry["id"]) in handled or entry["author"] == viewer:
            return
        (ai if entry["author"] in ai_logins else human).append(entry)

    for t in threads:
        if t.get("isResolved"):
            continue
        rounds = 0
        for c in ((t.get("comments") or {}).get("nodes")) or []:
            author = norm_login((c.get("author") or {}).get("login"))
            if author in ai_logins:
                rounds += 1
            route({"id": c.get("databaseId"), "kind": "thread", "thread_id": t.get("id"),
                   "author": author, "body": c.get("body") or "", "path": c.get("path"),
                   "line": c.get("line"), "round": rounds, "created_at": c.get("createdAt"),
                   "url": c.get("url")})
    for r in reviews:
        if not (r.get("body") or "").strip():
            continue
        route({"id": r.get("id"), "kind": "review", "author": norm_login((r.get("user") or {}).get("login")),
               "body": r.get("body"), "review_state": r.get("state"), "created_at": r.get("submitted_at"),
               "url": r.get("html_url")})
    for c in issues:
        route({"id": c.get("id"), "kind": "issue", "author": norm_login((c.get("user") or {}).get("login")),
               "body": c.get("body") or "", "created_at": c.get("created_at"), "url": c.get("html_url")})

    checks = [norm_check(x) for x in (pr_view.get("statusCheckRollup") or [])]
    out = {
        "pr": pr_view.get("number", a.pr),
        "pr_state": pr_view.get("state"),
        "url": pr_view.get("url"),
        "head_sha": pr_view.get("headRefOid"),
        "review_decision": pr_view.get("reviewDecision"),
        "checks": checks,
        "checks_summary": summarize(checks),
        "new_ai_comments": ai,
        "new_human_comments": human,
        "viewer": viewer,
        "ai_logins": sorted(ai_logins),
        "handled_count": len(handled),
        "vars": state.get("vars", {}),
        "pending_resolves": [
            {"id": cid, "thread_id": e.get("thread_id")}
            for cid, e in sorted(handled.items(), key=lambda kv: (not kv[0].isdigit(), int(kv[0]) if kv[0].isdigit() else kv[0]))
            if e.get("kind") == "thread" and e.get("action") == "replied" and e.get("resolved") is False
        ],
    }
    json.dump(out, sys.stdout, ensure_ascii=False)
    print()


def cmd_init(a):
    state = load_state(a.state)
    check_state_pr(state, a.pr, a.state)
    if os.path.exists(a.state):
        return
    state["pr"] = a.pr
    state["created_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    save_state(a.state, state)


def cmd_mark(a):
    state = load_state(a.state)
    check_state_pr(state, a.pr, a.state)
    state["pr"] = a.pr
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    for cid in a.ids:
        entry = state["handled"].setdefault(str(cid), {})
        entry["action"] = a.action
        entry.setdefault("at", now)
        if a.resolved is not None:
            entry["resolved"] = a.resolved
        if a.thread_id:
            entry["thread_id"] = a.thread_id
        if a.kind:
            entry["kind"] = a.kind
    save_state(a.state, state)


def cmd_set(a):
    state = load_state(a.state)
    check_state_pr(state, a.pr, a.state)
    state["pr"] = a.pr
    state["vars"][a.key] = a.value
    save_state(a.state, state)


def cmd_is_handled(a):
    """Exit 0 and print the entry when the id was handled, 3 when it was not.
    A state file that cannot be read or belongs to another PR exits 1 (via die)."""
    state = load_state(a.state)
    check_state_pr(state, a.pr, a.state)
    entry = state["handled"].get(str(a.id))
    if entry is None:
        sys.exit(3)
    json.dump(entry, sys.stdout)
    print()


def cmd_find_marker(a):
    """Exit 0 when any comment body in the file contains the marker (a reply already landed)."""
    for c in load_list(a.file):
        if a.marker in (c.get("body") or ""):
            sys.exit(0)
    sys.exit(1)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("merge")
    m.add_argument("--pr", type=int, required=True)
    m.add_argument("--pr-view", required=True)
    m.add_argument("--threads", required=True)
    m.add_argument("--issues", required=True)
    m.add_argument("--reviews", required=True)
    m.add_argument("--state", default="")
    m.add_argument("--ai-logins", default="")
    m.set_defaults(fn=cmd_merge)
    k = sub.add_parser("mark")
    k.add_argument("--pr", type=int, required=True)
    k.add_argument("--state", required=True)
    k.add_argument("--id", dest="ids", action="append", required=True)
    k.add_argument("--action", choices=["seen", "replied"], required=True)
    k.add_argument("--resolved", type=lambda s: s == "true", default=None)
    k.add_argument("--thread-id", default="")
    k.add_argument("--kind", default="")
    k.set_defaults(fn=cmd_mark)
    i = sub.add_parser("init")
    i.add_argument("--pr", type=int, required=True)
    i.add_argument("--state", required=True)
    i.set_defaults(fn=cmd_init)
    v = sub.add_parser("set")
    v.add_argument("--pr", type=int, required=True)
    v.add_argument("--state", required=True)
    v.add_argument("--key", required=True)
    v.add_argument("--value", required=True)
    v.set_defaults(fn=cmd_set)
    f = sub.add_parser("find-marker")
    f.add_argument("--file", required=True)
    f.add_argument("--marker", required=True)
    f.set_defaults(fn=cmd_find_marker)
    h = sub.add_parser("is-handled")
    h.add_argument("--pr", type=int, required=True)
    h.add_argument("--state", required=True)
    h.add_argument("--id", required=True)
    h.set_defaults(fn=cmd_is_handled)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
