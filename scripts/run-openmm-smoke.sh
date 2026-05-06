#!/usr/bin/env bash

set -u

OUT_ROOT="${OUT_ROOT:-reports}"
mkdir -p "$OUT_ROOT"
OUT_ROOT_ABS="$(cd "$OUT_ROOT" && pwd -P)"
IMAGE="${OPENMM_SMOKE_IMAGE:-nvcr.io/nvidia/pytorch:25.11-py3}"
CONTAINER=0
CUDA_EXTRA="none"
PLATFORM="${OPENMM_PLATFORM:-CUDA}"
PARTICLES="${OPENMM_PARTICLES:-256}"
STEPS="${OPENMM_STEPS:-100}"
PRECISION="${OPENMM_PRECISION:-mixed}"

usage() {
  cat <<'EOF'
Usage: run-openmm-smoke.sh [options]

Options:
  --container              Run inside a Docker GPU container.
  --image IMAGE            Container image to use.
  --cuda-extra VALUE       Extra OpenMM CUDA plugin package: none, cuda12, or cuda13.
  --platform NAME          Required OpenMM platform to test. Default: CUDA.
  --particles N            Toy system particle count. Default: 256.
  --steps N                Integrator steps. Default: 100.
  --precision VALUE        CUDA precision property. Default: mixed.
  -h, --help               Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --container)
      CONTAINER=1
      shift
      ;;
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --cuda-extra)
      CUDA_EXTRA="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --particles)
      PARTICLES="$2"
      shift 2
      ;;
    --steps)
      STEPS="$2"
      shift 2
      ;;
    --precision)
      PRECISION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$CUDA_EXTRA" in
  none)
    EXTRA_PACKAGE=""
    ;;
  cuda12)
    EXTRA_PACKAGE="OpenMM-CUDA-12"
    ;;
  cuda13)
    EXTRA_PACKAGE="OpenMM-CUDA-13"
    ;;
  *)
    echo "--cuda-extra must be one of: none, cuda12, cuda13" >&2
    exit 2
    ;;
esac

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_ROOT_ABS}/openmm-smoke-${STAMP}"
mkdir -p "$OUT_DIR"

run_host() {
  {
    echo "$ python3 scripts/openmm-smoke-test.py --platform ${PLATFORM} --particles ${PARTICLES} --steps ${STEPS} --precision ${PRECISION}"
    python3 scripts/openmm-smoke-test.py \
      --platform "$PLATFORM" \
      --particles "$PARTICLES" \
      --steps "$STEPS" \
      --precision "$PRECISION"
    code=$?
    echo
    echo "exit_code=${code}"
    return "$code"
  } > "${OUT_DIR}/openmm-smoke.txt" 2>&1
}

run_container() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required for --container" >&2
    return 2
  fi

  docker run --rm --gpus all --network host \
    -v "$PWD:/workspace/stoneytech-fah-arm64-gpu-lab:ro" \
    -v "$OUT_DIR:/workspace/reports" \
    -e EXTRA_PACKAGE="$EXTRA_PACKAGE" \
    -e PLATFORM="$PLATFORM" \
    -e PARTICLES="$PARTICLES" \
    -e STEPS="$STEPS" \
    -e PRECISION="$PRECISION" \
    "$IMAGE" bash -lc '
set -u

python -m venv /tmp/openmm-smoke-venv
. /tmp/openmm-smoke-venv/bin/activate

{
  echo "$ python -m pip install --upgrade pip"
  python -m pip install --upgrade pip
  echo
  if [ -n "${EXTRA_PACKAGE}" ]; then
    echo "$ python -m pip install openmm ${EXTRA_PACKAGE}"
    python -m pip install openmm "${EXTRA_PACKAGE}"
  else
    echo "$ python -m pip install openmm"
    python -m pip install openmm
  fi
} > /workspace/reports/pip-install.txt 2>&1
pip_code=$?
if [ "$pip_code" -ne 0 ]; then
  echo "pip_install_exit_code=${pip_code}" > /workspace/reports/openmm-smoke.txt
  exit "$pip_code"
fi

{
  echo "$ python /workspace/stoneytech-fah-arm64-gpu-lab/scripts/openmm-smoke-test.py --platform ${PLATFORM} --particles ${PARTICLES} --steps ${STEPS} --precision ${PRECISION}"
  python /workspace/stoneytech-fah-arm64-gpu-lab/scripts/openmm-smoke-test.py \
    --platform "${PLATFORM}" \
    --particles "${PARTICLES}" \
    --steps "${STEPS}" \
    --precision "${PRECISION}"
  code=$?
  echo
  echo "exit_code=${code}"
  nvidia-smi > /workspace/reports/nvidia-smi-after.txt 2>&1 || true
  exit "$code"
} > /workspace/reports/openmm-smoke.txt 2>&1
'
}

if [ "$CONTAINER" -eq 1 ]; then
  run_container
  code=$?
else
  run_host
  code=$?
fi

{
  echo
  echo "# OpenMM Smoke ${STAMP}"
  echo "exit_code=${code}"
  echo
  echo "- Mode: $([ "$CONTAINER" -eq 1 ] && echo container || echo host)"
  echo "- Image: ${IMAGE}"
  echo "- CUDA extra: ${CUDA_EXTRA}"
  echo "- Platform: ${PLATFORM}"
  echo "- Particles: ${PARTICLES}"
  echo "- Steps: ${STEPS}"
  echo "- Precision: ${PRECISION}"
  echo "- Output directory: ${OUT_DIR}"
  echo
  echo "Review and sanitize raw files before publishing."
} > "${OUT_DIR}/SUMMARY.md"

echo "Wrote ${OUT_DIR}"
exit "$code"
