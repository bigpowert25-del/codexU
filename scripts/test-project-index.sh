#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP="$ROOT/build/codexU.app/Contents/MacOS/codexU"

if [ "${CODEXU_SKIP_BUILD:-0}" != "1" ]; then
    make -C "$ROOT" build
fi

if [ ! -x "$APP" ]; then
    echo "project index test failed: app executable missing" >&2
    exit 1
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/godexu-project-index.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

"$APP" --self-test-project-index
"$APP" --self-test-project-index-reader
"$APP" --dump-project-index >"$TMP/index.json" 2>"$TMP/index.stderr" &
DUMP_PID=$!
DUMP_FINISHED=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
do
    if ! kill -0 "$DUMP_PID" 2>/dev/null; then
        wait "$DUMP_PID"
        DUMP_FINISHED=1
        break
    fi
    sleep 0.1
done
if [ "$DUMP_FINISHED" -ne 1 ]; then
    kill "$DUMP_PID" 2>/dev/null || true
    wait "$DUMP_PID" 2>/dev/null || true
    echo "project index test failed: dump command timed out" >&2
    exit 1
fi

if [ -s "$TMP/index.stderr" ]; then
    echo "project index test failed: success stderr is not empty" >&2
    exit 1
fi

SCHEMA="$(
    python3 -c 'import json,sys; print(json.load(sys.stdin)["schema"])' \
        <"$TMP/index.json"
)"
if [ "$SCHEMA" != "godexu-project-index-v1" ]; then
    echo "project index test failed: schema mismatch" >&2
    exit 1
fi

LINES="$(wc -l <"$TMP/index.json" | tr -d ' ')"
if [ "$LINES" -ne 1 ]; then
    echo "project index test failed: expected one JSON line" >&2
    exit 1
fi

if ! python3 - "$TMP/index.json" <<'PY'
import json
import sys

forbidden = {
    "handoffNote",
    "recentReply",
    "summary",
    "rolloutPath",
    "sessionFile",
    "prompt",
    "toolArguments",
}

def keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from keys(child)

document = json.load(open(sys.argv[1], encoding="utf-8"))
hits = sorted(forbidden.intersection(keys(document)))
if hits:
    print("forbidden keys: " + ", ".join(hits), file=sys.stderr)
    raise SystemExit(1)
PY
then
    echo "project index test failed: prohibited public field" >&2
    exit 1
fi

if ! python3 - "$TMP/index.json" <<'PY'
import json
import re
import sys

pattern = re.compile(
    r"/Users/|/Volumes/|/private/|/var/|\$CODEX_HOME|~/\.(?:codex|openclaw)"
)

def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)

document = json.load(open(sys.argv[1], encoding="utf-8"))
if any(pattern.search(value) for value in strings(document)):
    print("local path value detected", file=sys.stderr)
    raise SystemExit(1)
PY
then
    echo "project index test failed: local path leaked" >&2
    exit 1
fi

echo "project index command tests passed"
