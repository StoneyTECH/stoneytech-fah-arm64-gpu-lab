#!/usr/bin/env bash

set -euo pipefail

WORK_ROOT="${WORK_ROOT:-$HOME/stoneytech-fah-pr442}"
CBANG_REPO="${CBANG_REPO:-https://github.com/cauldrondevelopmentllc/cbang.git}"
FAH_REPO="${FAH_REPO:-https://github.com/stoney-arch/fah-client-bastet.git}"
FAH_BRANCH="${FAH_BRANCH:-arm64-gpu-client-fixes}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
INSTALL_DEPS=0

usage() {
  cat <<'USAGE'
Usage: bootstrap-pr442-client.sh [options]

Options:
  --work-root DIR       Checkout/build directory. Default: ~/stoneytech-fah-pr442
  --install-deps        Install Debian/Ubuntu build dependencies with sudo apt
  --jobs N              Parallel build jobs. Default: CPU count
  -h, --help            Show this help

Builds cbang and fah-client-bastet PR #442 on ARM64 Linux.

Outputs:
  $WORK_ROOT/fah-client-bastet/fah-client

Environment overrides:
  CBANG_REPO, FAH_REPO, FAH_BRANCH, JOBS, WORK_ROOT
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --work-root)
      shift
      WORK_ROOT="${1:-$WORK_ROOT}"
      ;;
    --install-deps)
      INSTALL_DEPS=1
      ;;
    --jobs)
      shift
      JOBS="${1:-$JOBS}"
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

if [ "$INSTALL_DEPS" -eq 1 ]; then
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "--install-deps currently supports Debian/Ubuntu apt-get only" >&2
    exit 2
  fi

  sudo apt-get update
  sudo apt-get install -y \
    build-essential \
    ca-certificates \
    fakeroot \
    git \
    libbz2-dev \
    liblz4-dev \
    libssl-dev \
    libsystemd-dev \
    npm \
    python3 \
    python3-pip \
    scons \
    zlib1g-dev
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 2
fi

if ! command -v scons >/dev/null 2>&1; then
  echo "scons is required. Run with --install-deps on Debian/Ubuntu or install scons manually." >&2
  exit 2
fi

mkdir -p "$WORK_ROOT"
cd "$WORK_ROOT"

if [ ! -d cbang/.git ]; then
  git clone "$CBANG_REPO" cbang
else
  git -C cbang fetch --all --tags --prune
fi

if [ ! -d fah-client-bastet/.git ]; then
  git clone "$FAH_REPO" fah-client-bastet
else
  git -C fah-client-bastet fetch --all --tags --prune
fi

git -C fah-client-bastet checkout "$FAH_BRANCH"
git -C fah-client-bastet pull --ff-only origin "$FAH_BRANCH"

export CBANG_HOME="$WORK_ROOT/cbang"

scons -C cbang -j "$JOBS"
scons -C fah-client-bastet -j "$JOBS"

echo
echo "Built client:"
echo "$WORK_ROOT/fah-client-bastet/fah-client"
"$WORK_ROOT/fah-client-bastet/fah-client" --version || true
