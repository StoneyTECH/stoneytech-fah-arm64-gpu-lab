#!/usr/bin/env bash
set -euo pipefail

IMAGE="${FAH_CPU_TEST_IMAGE:-stoneytech/fah-arm64-cpu-test:local}"
WORK_ROOT="${WORK_ROOT:-$HOME/stoneytech-fah-pr442-container}"
REPORT_ROOT="${REPORT_ROOT:-reports}"
CPUS="${FAH_CPUS:-8}"
RUNTIME_SECONDS="${FAH_RUNTIME_SECONDS:-1800}"
BUILD_JOBS="${FAH_BUILD_JOBS:-8}"
USER_NAME="${FAH_USER:-Stoney_DeVille}"
TEAM="${FAH_TEAM:-0}"
BUILD_IMAGE=1
INSTALL_DEPS=0

usage() {
  cat <<'USAGE'
Usage: run-fah-cpu-test-container.sh [options]

Options:
  --image NAME          Container image name. Default: stoneytech/fah-arm64-cpu-test:local
  --no-build-image      Use an existing image instead of building locally
  --work-root DIR       Host build/cache directory. Default: ~/stoneytech-fah-pr442-container
  --report-root DIR     Host report directory. Default: reports
  --cpus NUM            CPU count for Folding@home. Default: 8
  --seconds NUM         Test runtime seconds. Default: 1800
  --build-jobs NUM      SCons parallel jobs. Default: 8
  --install-deps        Accepted for parity; dependencies are already in the image
  -h, --help            Show this help

Environment:
  FAH_USER, FAH_TEAM, FAH_PASSKEY, FAH_REPO, FAH_BRANCH, CBANG_REPO

The passkey is passed as a container environment variable and redacted from
generated evidence. It is not written to the image or command line.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image)
      shift
      IMAGE="${1:-$IMAGE}"
      ;;
    --no-build-image)
      BUILD_IMAGE=0
      ;;
    --work-root)
      shift
      WORK_ROOT="${1:-$WORK_ROOT}"
      ;;
    --report-root|--output-dir)
      shift
      REPORT_ROOT="${1:-$REPORT_ROOT}"
      ;;
    --cpus)
      shift
      CPUS="${1:-$CPUS}"
      ;;
    --seconds)
      shift
      RUNTIME_SECONDS="${1:-$RUNTIME_SECONDS}"
      ;;
    --build-jobs|--jobs)
      shift
      BUILD_JOBS="${1:-$BUILD_JOBS}"
      ;;
    --install-deps)
      INSTALL_DEPS=1
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

case "$CPUS:$RUNTIME_SECONDS:$BUILD_JOBS" in
  *[!0-9:]*)
    echo "cpus, seconds, and build-jobs must be integers" >&2
    exit 2
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$WORK_ROOT" "$REPORT_ROOT"

if [ "$INSTALL_DEPS" -eq 1 ]; then
  echo "--install-deps is a no-op in container mode; dependencies are baked into the image."
fi

if [ "$BUILD_IMAGE" -eq 1 ]; then
  docker build --network host -t "$IMAGE" -f "$repo_root/containers/fah-cpu-test/Dockerfile" "$repo_root"
fi

docker_args=(--rm)
if [ -t 0 ] && [ -t 1 ]; then
  docker_args+=(-it)
fi

exec docker run "${docker_args[@]}" \
  --network host \
  --cpus "$CPUS" \
  -v "$repo_root:/workspace/stoneytech-fah-arm64-gpu-lab:ro" \
  -v "$WORK_ROOT:/workspace/fah-build" \
  -v "$REPORT_ROOT:/workspace/reports" \
  -e "WORK_ROOT=/workspace/fah-build" \
  -e "CBANG_REPO=${CBANG_REPO:-https://github.com/cauldrondevelopmentllc/cbang.git}" \
  -e "FAH_REPO=${FAH_REPO:-https://github.com/stoney-arch/fah-client-bastet.git}" \
  -e "FAH_BRANCH=${FAH_BRANCH:-arm64-gpu-client-fixes}" \
  -e "JOBS=$BUILD_JOBS" \
  -e "FAH_USER=$USER_NAME" \
  -e "FAH_TEAM=$TEAM" \
  -e "FAH_PASSKEY=${FAH_PASSKEY:-}" \
  "$IMAGE" \
  bash -lc '
    set -euo pipefail
    cd /workspace/stoneytech-fah-arm64-gpu-lab
    ./scripts/bootstrap-pr442-client.sh --work-root "$WORK_ROOT" --jobs "$JOBS"
    ./scripts/collect-hardware-profile.sh --output-dir /workspace/reports
    ./scripts/run-fah-cpu-test.sh \
      --client "$WORK_ROOT/fah-client-bastet/fah-client" \
      --user "$FAH_USER" \
      --team "$FAH_TEAM" \
      --cpus "'"$CPUS"'" \
      --seconds "'"$RUNTIME_SECONDS"'" \
      --output-dir /workspace/reports
  '
