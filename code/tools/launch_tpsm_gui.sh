#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PYTHON_BIN="${PROJECT_ROOT}/.venv/bin/python"
HOST="127.0.0.1"
PORT="8787"
URL="http://${HOST}:${PORT}"
OUTPUT_ROOT="${PROJECT_ROOT}/outputs/active/gui_runs"
RUNTIME_DIR="${PROJECT_ROOT}/.runtime/tpsm_gui"
PID_FILE="${RUNTIME_DIR}/gui.pid"
LOG_FILE="${RUNTIME_DIR}/gui.log"

mkdir -p "${RUNTIME_DIR}" "${OUTPUT_ROOT}"

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "Python virtualenv not found: ${PYTHON_BIN}" >&2
  exit 1
fi

is_pid_alive() {
  local pid="${1:-}"
  [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

is_gui_reachable() {
  "${PYTHON_BIN}" - <<PY >/dev/null 2>&1
import sys, urllib.request
try:
    with urllib.request.urlopen("${URL}/api/runs", timeout=1.5) as resp:
        sys.exit(0 if resp.status == 200 else 1)
except Exception:
    sys.exit(1)
PY
}

kill_pid_if_alive() {
  local pid="${1:-}"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
    for _ in $(seq 1 20); do
      if ! kill -0 "${pid}" 2>/dev/null; then
        return 0
      fi
      sleep 0.25
    done
    kill -9 "${pid}" 2>/dev/null || true
  fi
}

kill_matching_gui_processes() {
  local pids
  pids="$(pgrep -f "${PYTHON_BIN} -m code.python.tpsm.gui --host ${HOST} --port ${PORT}" || true)"
  if [[ -n "${pids}" ]]; then
    while IFS= read -r pid; do
      [[ -n "${pid}" ]] && kill_pid_if_alive "${pid}"
    done <<< "${pids}"
  fi
}

start_gui() {
  (
    cd "${PROJECT_ROOT}"
    nohup "${PYTHON_BIN}" -m code.python.tpsm.gui --host "${HOST}" --port "${PORT}" --output-root "${OUTPUT_ROOT}" \
      >>"${LOG_FILE}" 2>&1 &
    echo $! > "${PID_FILE}"
  )
}

if [[ -f "${PID_FILE}" ]]; then
  EXISTING_PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
else
  EXISTING_PID=""
fi

# Always restart cleanly.
kill_pid_if_alive "${EXISTING_PID}"
kill_matching_gui_processes
rm -f "${PID_FILE}"

if is_gui_reachable; then
  echo "Port ${PORT} is still occupied by another process. Refusing to start a second GUI." >&2
  echo "Free ${URL} manually, then relaunch." >&2
  exit 1
fi

start_gui

for _ in $(seq 1 40); do
  if is_gui_reachable; then
    xdg-open "${URL}" >/dev/null 2>&1 || true
    exit 0
  fi
  sleep 0.5
done

echo "TPSM GUI did not become reachable at ${URL}" >&2
echo "Check log: ${LOG_FILE}" >&2
exit 1
