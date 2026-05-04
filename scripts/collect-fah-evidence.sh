#!/usr/bin/env bash

set -u

OUT_ROOT="reports"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_ROOT}/fah-evidence-${STAMP}"
mkdir -p "$OUT_DIR"

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

redact_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  if command -v perl >/dev/null 2>&1; then
    perl -0777 -pi -e 's/([Pp]asskey|[Tt]oken|[Ss]ecret|[Pp]assword|[Aa]pi[_ -]?[Kk]ey)(\s*[=:]\s*)\S+/$1$2[REDACTED]/g; s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[EMAIL_REDACTED]/g' "$file"
  fi
}

run_shell fah-client-version 'fah-client --version 2>/dev/null || FAHClient --version 2>/dev/null || true'
run_shell fah-service-status 'systemctl status --no-pager -l fah-client 2>/dev/null || service fah-client status 2>/dev/null || true'
run_shell fah-journal-tail 'journalctl -u fah-client --no-pager -n 500 2>/dev/null || true'
run_shell fah-log-tail 'for f in /var/log/fah-client/* /var/lib/fah-client/log.txt ./log.txt; do [ -f "$f" ] && { echo "## $f"; tail -n 500 "$f"; }; done'
run_shell gpu-visibility 'nvidia-smi -L 2>/dev/null; nvidia-smi --query-gpu=name,pci.bus_id,driver_version,cuda_version --format=csv,noheader 2>/dev/null; clinfo 2>/dev/null | head -n 120 || true'

find "$OUT_DIR" -type f -name "*.txt" -print | while read -r file; do
  redact_file "$file"
done

cat > "${OUT_DIR}/README.md" <<EOF
# Folding@home Evidence ${STAMP}

Review all files before publishing. Redaction is best-effort.

Use this bundle to fill out \`templates/fah-client-evidence-report.md\`.
EOF

echo "Wrote ${OUT_DIR}"
