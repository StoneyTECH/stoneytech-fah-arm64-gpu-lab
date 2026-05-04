#!/usr/bin/env bash

set -u

OUT_ROOT="reports"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_ROOT}/openmm-smoke-${STAMP}"
mkdir -p "$OUT_DIR"

{
  echo "$ python3 scripts/openmm-smoke-test.py"
  python3 scripts/openmm-smoke-test.py
  code=$?
  echo
  echo "exit_code=${code}"
  exit "$code"
} > "${OUT_DIR}/openmm-smoke.txt" 2>&1
