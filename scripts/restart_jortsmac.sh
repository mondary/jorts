#!/usr/bin/env zsh
set -euo pipefail

ROOT="/Users/clm/Documents/GitHub/TESTS/JORTS_macos"
BIN="$ROOT/.build/arm64-apple-macosx/debug/JortsMac"
PIDFILE="/tmp/jortsmac.pid"
LOGFILE="/tmp/jortsmac_run.log"

cd "$ROOT"
swift build

# Kill previous managed instance (pidfile first)
if [[ -f "$PIDFILE" ]]; then
  old_pid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [[ -n "${old_pid:-}" ]] && kill -0 "$old_pid" 2>/dev/null; then
    kill "$old_pid" 2>/dev/null || true
    sleep 0.5
    kill -9 "$old_pid" 2>/dev/null || true
  fi
fi

# Fallback: kill only processes whose executable path matches BIN
for pid in $(pgrep -x JortsMac || true); do
  exe=$(ps -p "$pid" -o command= 2>/dev/null || true)
  if [[ "$exe" == "$BIN"* ]]; then
    kill "$pid" 2>/dev/null || true
  fi
done
sleep 0.7

nohup "$BIN" >"$LOGFILE" 2>&1 &
new_pid=$!
echo "$new_pid" > "$PIDFILE"

sleep 1
if kill -0 "$new_pid" 2>/dev/null; then
  echo "RUNNING $new_pid"
else
  echo "FAILED"
  tail -n 80 "$LOGFILE" || true
  exit 1
fi
