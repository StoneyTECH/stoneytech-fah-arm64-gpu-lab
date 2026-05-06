#!/usr/bin/env bash

set -u

OUT_ROOT="${OUT_ROOT:-reports}"
mkdir -p "$OUT_ROOT"
OUT_ROOT_ABS="$(cd "$OUT_ROOT" && pwd -P)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_ROOT_ABS}/gpu-readiness-inventory-${STAMP}"
mkdir -p "$OUT_DIR"

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

run_cmd date-utc date -u
run_cmd uname uname -a
run_shell os-release 'cat /etc/os-release 2>/dev/null || true'
run_shell nvidia-smi 'nvidia-smi 2>/dev/null || true'
run_shell nvidia-smi-list 'nvidia-smi -L 2>/dev/null || true'
run_shell nvidia-smi-q 'nvidia-smi -q 2>/dev/null || true'
run_shell nvidia-smi-query 'nvidia-smi --query-gpu=index,name,pci.bus_id,pci.device_id,driver_version,compute_cap,power.limit,memory.total --format=csv 2>/dev/null || true'
run_shell lspci-gpu 'lspci -nn 2>/dev/null | grep -Ei "nvidia|3d|vga" || true'
run_shell lspci-gpu-detail 'lspci -nnvv 2>/dev/null | grep -A80 -Ei "nvidia|3d controller|vga compatible" || true'
run_shell cuda-libraries 'ldconfig -p 2>/dev/null | grep -Ei "cuda|nvidia|opencl|cudart|nvrtc|cublas|cufft|cusolver|cusparse" || true'
run_shell nvcc-version 'nvcc --version 2>/dev/null || true'
run_shell python-gpu-modules 'python3 - <<'"'"'PY'"'"'
mods = ["torch", "cupy", "numba", "openmm"]
for mod_name in mods:
    try:
        mod = __import__(mod_name)
        print(mod_name, "OK", getattr(mod, "__version__", ""))
    except Exception as exc:
        print(mod_name, "missing", type(exc).__name__, exc)
PY'
run_shell docker-version 'docker version 2>/dev/null || true'
run_shell docker-gpu-images 'docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" 2>/dev/null | grep -Ei "cuda|pytorch|openmm|nvidia|stoneytech" || true'

{
  echo "# GPU Readiness Inventory ${STAMP}"
  echo
  echo "- Host: $(hostname 2>/dev/null || echo unknown)"
  echo "- Date UTC: $(date -u +%FT%TZ)"
  echo "- Output directory: ${OUT_DIR}"
  echo
  echo "Review and sanitize raw files before publishing."
} > "${OUT_DIR}/SUMMARY.md"

echo "Wrote ${OUT_DIR}"
