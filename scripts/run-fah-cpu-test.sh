#!/usr/bin/env bash

set -u

OUT_ROOT="reports"
RUNTIME_SECONDS=1800
CPUS=""
USER_NAME="${FAH_USER:-Anonymous}"
TEAM="${FAH_TEAM:-0}"
PASSKEY="${FAH_PASSKEY:-}"
CLIENT_BIN="${FAH_CLIENT_BIN:-fah-client}"
RUN_DIR=""

usage() {
  cat <<'USAGE'
Usage: run-fah-cpu-test.sh [options]

Options:
  --client PATH          Path to fah-client binary. Default: $FAH_CLIENT_BIN or fah-client
  --user NAME            Folding@home donor name. Default: $FAH_USER or Anonymous
  --team NUM             Folding@home team number. Default: $FAH_TEAM or 0
  --passkey KEY          Folding@home passkey. Prefer FAH_PASSKEY env var.
  --cpus NUM             CPU count to advertise/use. Default: client default
  --seconds NUM          Test runtime in seconds. Default: 1800
  --output-dir DIR       Write report directory under DIR instead of reports/
  -h, --help             Show this help

This runs fah-client in an isolated working directory with CPU-only config:
GPU APIs disabled, empty GPU set, CPU count configured, and no system service
changes. It captures logs and redacts passkeys before writing the report.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --client)
      shift
      CLIENT_BIN="${1:-$CLIENT_BIN}"
      ;;
    --user)
      shift
      USER_NAME="${1:-$USER_NAME}"
      ;;
    --team)
      shift
      TEAM="${1:-$TEAM}"
      ;;
    --passkey)
      shift
      PASSKEY="${1:-}"
      ;;
    --cpus)
      shift
      CPUS="${1:-}"
      ;;
    --seconds)
      shift
      RUNTIME_SECONDS="${1:-$RUNTIME_SECONDS}"
      ;;
    --output-dir)
      shift
      OUT_ROOT="${1:-$OUT_ROOT}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! command -v "$CLIENT_BIN" >/dev/null 2>&1 && [ ! -x "$CLIENT_BIN" ]; then
  echo "Cannot execute fah-client binary: $CLIENT_BIN" >&2
  exit 2
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_ROOT}/fah-cpu-test-${STAMP}"
RUN_DIR="${OUT_DIR}/work"
mkdir -p "$RUN_DIR"

CONFIG="${RUN_DIR}/config.xml"
LOG="${RUN_DIR}/log.txt"
PID_FILE="${RUN_DIR}/fah-client.pid"

xml_escape() {
  printf '%s' "$1" |
    sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g" \
        -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

redact_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  if [ -n "$PASSKEY" ]; then
    sed -i.bak "s/${PASSKEY}/[REDACTED_PASSKEY]/g" "$file" 2>/dev/null || true
    rm -f "${file}.bak"
  fi
  if command -v perl >/dev/null 2>&1; then
    perl -0777 -pi -e 's/([Pp]asskey|[Tt]oken|[Ss]ecret|[Pp]assword|[Aa]pi[_ -]?[Kk]ey)(\s*[=:]\s*)\S+/$1$2[REDACTED]/g; s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[EMAIL_REDACTED]/g' "$file"
  fi
}

write_config() {
  {
    echo "<config>"
    echo "  <user v=\"$(xml_escape "$USER_NAME")\"/>"
    echo "  <team v=\"$(xml_escape "$TEAM")\"/>"
    if [ -n "$PASSKEY" ]; then
      echo "  <passkey v=\"$(xml_escape "$PASSKEY")\"/>"
    fi
    if [ -n "$CPUS" ]; then
      echo "  <cpus v=\"$(xml_escape "$CPUS")\"/>"
    fi
    echo "  <open-web-control v=\"false\"/>"
    echo "  <cuda v=\"false\"/>"
    echo "  <hip v=\"false\"/>"
    echo "  <gpus v=\"{}\"/>"
    echo "  <paused v=\"false\"/>"
    echo "</config>"
  } > "$CONFIG"
}

run_cmd() {
  local name="$1"
  shift
  {
    echo "$ $*"
    "$@"
    local code=$?
    echo
    echo "exit_code=${code}"
  } > "${OUT_DIR}/${name}.txt" 2>&1
}

run_shell() {
  local name="$1"
  shift
  {
    echo "$ $*"
    sh -c "$*"
    local code=$?
    echo
    echo "exit_code=${code}"
  } > "${OUT_DIR}/${name}.txt" 2>&1
}

send_fold_state() {
  python3 - <<'PY'
import base64
import json
import os
import socket
import struct
import time


def recv_until(sock, marker):
    data = b""
    while marker not in data:
        chunk = sock.recv(4096)
        if not chunk:
            break
        data += chunk
    return data


def send_ws_message(sock, payload):
    data = payload.encode("utf-8")
    mask = os.urandom(4)

    if len(data) < 126:
        header = struct.pack("!BB", 0x81, 0x80 | len(data))
    elif len(data) < 65536:
        header = struct.pack("!BBH", 0x81, 0x80 | 126, len(data))
    else:
        header = struct.pack("!BBQ", 0x81, 0x80 | 127, len(data))

    masked = bytes(byte ^ mask[i % 4] for i, byte in enumerate(data))
    sock.sendall(header + mask + masked)


deadline = time.time() + 15
last_error = None
while time.time() < deadline:
    try:
        with socket.create_connection(("127.0.0.1", 7396), timeout=2) as sock:
            key = base64.b64encode(os.urandom(16)).decode("ascii")
            request = (
                "GET /api/websocket HTTP/1.1\r\n"
                "Host: 127.0.0.1:7396\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key}\r\n"
                "Sec-WebSocket-Version: 13\r\n"
                "Origin: http://localhost:7396\r\n"
                "\r\n"
            )
            sock.sendall(request.encode("ascii"))
            response = recv_until(sock, b"\r\n\r\n")
            if b" 101 " not in response.split(b"\r\n", 1)[0]:
                raise RuntimeError(response.decode("utf-8", "replace"))

            send_ws_message(sock, json.dumps({"cmd": "state", "state": "fold"}))
            print("sent fold state over websocket")
            raise SystemExit(0)
    except Exception as exc:
        last_error = exc
        time.sleep(0.5)

raise SystemExit(f"failed to send fold state: {last_error}")
PY
}

cleanup_client() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 5
      kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    fi
  fi
}

trap cleanup_client EXIT INT TERM

write_config
run_cmd date-utc date -u
run_cmd uname uname -a
run_shell os-release 'cat /etc/os-release 2>/dev/null || true'
run_shell client-version "\"${CLIENT_BIN}\" --version 2>/dev/null || true"

(
  cd "$RUN_DIR" || exit 1
  "$CLIENT_BIN" --config="$CONFIG" --log="$LOG" --verbosity=5 > stdout.txt 2> stderr.txt &
  echo "$!" > "../$(basename "$PID_FILE")"
)

send_fold_state > "${OUT_DIR}/fold-state.txt" 2>&1 || true
sleep "$RUNTIME_SECONDS"
cleanup_client
trap - EXIT INT TERM

run_shell process-tree 'ps -ef | grep -i "[f]ah-client" || true'
run_shell nvidia-smi-after 'nvidia-smi --query-gpu=name,utilization.gpu,power.draw,temperature.gpu --format=csv 2>/dev/null || true'

cp "$CONFIG" "${OUT_DIR}/config.xml"
if [ -f "$LOG" ]; then cp "$LOG" "${OUT_DIR}/log.txt"; fi
if [ -f "${RUN_DIR}/stdout.txt" ]; then cp "${RUN_DIR}/stdout.txt" "${OUT_DIR}/stdout.txt"; fi
if [ -f "${RUN_DIR}/stderr.txt" ]; then cp "${RUN_DIR}/stderr.txt" "${OUT_DIR}/stderr.txt"; fi

find "$OUT_DIR" -type f \( -name "*.txt" -o -name "*.xml" \) -print | while read -r file; do
  redact_file "$file"
done

cat > "${OUT_DIR}/SUMMARY.md" <<EOF
# Folding@home ARM64 CPU Test ${STAMP}

- Client: ${CLIENT_BIN}
- Runtime seconds: ${RUNTIME_SECONDS}
- User: ${USER_NAME}
- Team: ${TEAM}
- CPUS: ${CPUS:-client default}
- GPU disabled: true

## What To Check

- Assignment succeeds.
- Core package downloads.
- Log mentions ARM64 CPU/GROMACS core.
- WU enters RUN state.
- Progress advances.
- No GPU/OpenMM core is requested.

## Files

- config.xml
- log.txt
- stdout.txt
- stderr.txt
- client-version.txt
- uname.txt
- os-release.txt
EOF

echo "Wrote ${OUT_DIR}"
