#!/usr/bin/env python3
"""Turn raw `agy -p --output-format json` output into a one-line envelope.

Envelope: {"status": completed|skipped|timeout|quota|error, "detail": str, "result": ...}

The agy exit code and its own "status" field are not enough to tell success from
failure: a print timeout and a denied tool call both end with exit 0, status
SUCCESS and an empty response.
"""
import argparse
import json
import re
import sys

QUOTA_RE = re.compile(r"quota|resource[_ ]exhausted|rate.?limit|\b429\b", re.IGNORECASE)


def emit(status, detail="", result=None):
    print(json.dumps({"status": status, "detail": detail, "result": result}, ensure_ascii=False))
    sys.exit(0)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def last_json_object(text):
    # agy can print non-JSON lines (e.g. while waiting for sign-in) before the result line.
    for line in reversed(text.splitlines()):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            data = json.loads(line)
        except ValueError:
            continue
        if isinstance(data, dict):
            return data
    return None


def parse(args):
    raw = read(args.raw)
    stderr = read(args.stderr)
    data = last_json_object(raw)
    if data is None:
        tail = (stderr.strip() or raw.strip())[-300:]
        emit("error", f"agy output is not JSON (exit {args.exit_code}): {tail}")

    error_text = str(data.get("error") or "")
    if args.exit_code != 0 or data.get("status") != "SUCCESS":
        detail = error_text or f"agy exited {args.exit_code} with status {data.get('status')}"
        emit("quota" if QUOTA_RE.search(detail) else "error", detail)

    if "print timeout" in stderr:
        emit("timeout", f"agy print timeout ({args.timeout_label})")

    denied = ", ".join(a.get("display_name") or a.get("action") or "?" for a in data.get("denied_actions") or [])
    if args.schema_mode:
        structured = data.get("structured_output")
        if isinstance(structured, dict):
            emit("completed", "", structured)
        reason = "structured_output missing from agy output"
    else:
        response = data.get("response")
        if isinstance(response, str) and response.strip():
            emit("completed", "", response)
        reason = "agy returned an empty response"
    if denied:
        reason += f" (denied actions: {denied})"
    emit("error", reason)


def normalize_review(args):
    """Recompute result.ok from the issues: the model's own ok flag is unreliable."""
    envelope = json.loads(sys.stdin.read())
    result = envelope.get("result")
    if envelope.get("status") == "completed" and isinstance(result, dict):
        issues = result.get("issues") or []
        result["ok"] = not any(i.get("severity") == "blocking" for i in issues if isinstance(i, dict))
    if args.detail:
        envelope["detail"] = "; ".join(d for d in (envelope.get("detail"), args.detail) if d)
    print(json.dumps(envelope, ensure_ascii=False))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--raw")
    p.add_argument("--stderr")
    p.add_argument("--exit-code", type=int, default=0)
    p.add_argument("--schema-mode", action="store_true")
    p.add_argument("--timeout-label", default="")
    p.add_argument("--emit", choices=["skipped", "error"])
    p.add_argument("--normalize-review", action="store_true")
    p.add_argument("--detail", default="")
    args = p.parse_args()

    if args.emit:
        emit(args.emit, args.detail)
    if args.normalize_review:
        normalize_review(args)
        return
    parse(args)


if __name__ == "__main__":
    main()
