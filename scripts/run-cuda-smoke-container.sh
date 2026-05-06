#!/usr/bin/env bash

set -u

IMAGE="${CUDA_SMOKE_IMAGE:-nvcr.io/nvidia/pytorch:25.11-py3}"
OUT_ROOT="${OUT_ROOT:-reports}"
mkdir -p "$OUT_ROOT"
OUT_ROOT_ABS="$(cd "$OUT_ROOT" && pwd -P)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_ROOT_ABS}/cuda-smoke-${STAMP}"
mkdir -p "$OUT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 2
fi

docker run --rm --gpus all --network host -v "$PWD:/workspace/stoneytech-fah-arm64-gpu-lab:ro" -v "$OUT_DIR:/workspace/reports" "$IMAGE" bash -lc '
set -u

python - <<'"'"'PY'"'"' > /workspace/reports/torch-cuda-smoke.txt 2>&1
import time
import torch

print("torch", torch.__version__)
print("cuda_available", torch.cuda.is_available())
print("cuda_version", torch.version.cuda)
print("device_count", torch.cuda.device_count())

for index in range(torch.cuda.device_count()):
    props = torch.cuda.get_device_properties(index)
    print(
        "device",
        index,
        props.name,
        "cc",
        f"{props.major}.{props.minor}",
        "total_memory",
        props.total_memory,
    )

if not torch.cuda.is_available():
    raise SystemExit(2)

device = torch.device("cuda:0")
torch.cuda.synchronize()
a = torch.randn((4096, 4096), device=device, dtype=torch.float16)
b = torch.randn((4096, 4096), device=device, dtype=torch.float16)
torch.cuda.synchronize()

start = time.time()
for _ in range(20):
    c = a @ b
torch.cuda.synchronize()

print("matmul_elapsed_seconds", round(time.time() - start, 4))
print("result_checksum", float(c.float().mean().cpu()))
PY
code=$?
nvidia-smi > /workspace/reports/nvidia-smi-after.txt 2>&1 || true
exit "$code"
'
code=$?

{
  echo "# CUDA Smoke ${STAMP}"
  echo
  echo "- Image: ${IMAGE}"
  echo "- Exit code: ${code}"
  echo "- Output directory: ${OUT_DIR}"
  echo
  echo "Review and sanitize raw files before publishing."
} > "${OUT_DIR}/SUMMARY.md"

echo "Wrote ${OUT_DIR}"
exit "$code"
