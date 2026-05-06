# Spark Readiness Evidence - 2026-05-06

This report summarizes the evidence collected for StoneyTech's NVIDIA DGX Spark ARM64 Folding@home contribution effort. It is written to be public-safe and omits personal passkeys, private network details, and unrelated organization context.

## System Under Test

- Host label: `stoneytech-spark`
- System class: NVIDIA DGX Spark
- Architecture: Linux `aarch64`
- GPU observed by NVIDIA tooling: `NVIDIA GB10`
- PCI device observed by Linux/Folding@home logs: NVIDIA `10de:2e12`

## Folding@home CPU Proof

### 8-core ARM64 CPU run

- Artifact path on Spark: `/home/stoneytech/stoneytech-lab/artifacts/runs/fah-cpu-clean-proof-20260506T020243Z`
- Requested CPU threads: 8
- Runtime window: 900 seconds
- Work unit observed: `P16959 R30 C226 G696`
- Core observed: `fahcore-a8-lin-64bit-aarch64-0.0.12`
- Science engine: GROMACS
- SIMD reported: `arm_neon_asimd`
- CUDA reported by the FAHCore: `OFF`
- Core launch included: `-np 8`
- Progress observed during window: 7%
- Stability result: host remained reachable after cleanup

### 16-core ARM64 CPU run

- Artifact path on Spark: `/home/stoneytech/stoneytech-lab/artifacts/runs/fah-cpu-16core-proof-20260506T022051Z`
- Requested CPU threads: 16
- Runtime window: 1800 seconds
- Work unit observed: `P16969 R16 C108 G348`
- Core observed: `fahcore-a8-lin-64bit-aarch64-0.0.12`
- Science engine: GROMACS
- SIMD reported: `arm_neon_asimd`
- CUDA reported by the FAHCore: `OFF`
- Core launch included: `-np 16`
- Progress observed during window: 3%
- Stability result: host remained reachable after cleanup

These two runs show the ARM64 CPU GROMACS path is functional at both 8 and 16 requested CPU threads. They should not be interpreted as a direct 8-core versus 16-core performance comparison because they received different work units.

## GPU Inventory

- Artifact path on Spark: `/home/stoneytech/stoneytech-lab/artifacts/runs/gpu-readiness-inventory-20260506T031435Z`
- `nvidia-smi -L` observed: `GPU 0: NVIDIA GB10`
- NVIDIA driver observed: `580.142`
- CUDA version reported by `nvidia-smi`: `13.0`
- Host `nvcc`: not installed in PATH during inventory
- CUDA runtime libraries observed under `/usr/local/cuda/targets/sbsa-linux/lib/`
- Local NVIDIA PyTorch container image available: `nvcr.io/nvidia/pytorch:25.11-py3`

## CUDA Container Smoke

- Artifact path on Spark: `/home/stoneytech/stoneytech-lab/artifacts/runs/cuda-smoke-20260506T031508Z`
- Container image: `nvcr.io/nvidia/pytorch:25.11-py3`
- PyTorch version observed: `2.10.0a0+b558c986e8.nv25.11`
- CUDA availability: true
- CUDA version reported by PyTorch: `13.0`
- CUDA device count: 1
- Device observed: `NVIDIA GB10`
- Compute capability observed: `12.1`
- Reported device memory: `130663821312` bytes
- Smoke workload: repeated FP16 matrix multiplication
- Result: completed successfully

This proves the Spark can run CUDA compute from a standard NVIDIA container.

## OpenMM Smoke

### Plain OpenMM package

- Artifact path on Spark: `/home/stoneytech/stoneytech-lab/artifacts/runs/openmm-smoke-20260506T031545Z`
- OpenMM package: `openmm-8.5.1`
- Platforms observed: `Reference`, `CPU`
- CUDA platform observed: no
- Result: expected failure for CUDA testing because no CUDA platform was exposed

### OpenMM CUDA 13 plugin

- Artifact path on Spark: `/home/stoneytech/stoneytech-lab/artifacts/runs/openmm-cuda13-smoke-20260506T031623Z`
- OpenMM package: `openmm-8.5.1`
- Extra package: `OpenMM-CUDA-13-8.5.1`
- Platforms observed: `Reference`, `CPU`, `CUDA`
- CUDA platform observed: yes
- Context execution result: failed
- Failure observed: `CUDA_ERROR_UNSUPPORTED_PTX_VERSION`

This shows the OpenMM CUDA platform can enumerate when the CUDA 13 plugin is installed, but kernel execution is not yet clean on the current Spark driver/runtime/container combination.

## Folding@home GPU Detection

Folding@home client evidence from the CPU test run showed the Spark GPU detected as:

- Type: NVIDIA
- Description: `GB20B [GB10]`
- Supported flag: `false`

The client source indicates the supported flag depends on the GPU resource metadata/species mapping. The Spark's NVIDIA PCI device ID is therefore likely missing or not species-enabled in the current Folding@home GPU resource list. This is a metadata/readiness blocker separate from the OpenMM CUDA execution blocker above.

## Current Conclusion

StoneyTech has proven:

- ARM64 CPU Folding@home GROMACS work can run on the Spark.
- The host remains reachable after controlled 8-core and 16-core CPU proof runs.
- NVIDIA CUDA compute works in a standard GPU container.
- OpenMM CUDA readiness has a concrete, reproducible failure mode rather than an unknown failure.
- Folding@home detects the GB10/GB20B GPU but currently marks it unsupported.

## Prepared Upstream Ask

The next upstream request should be narrow:

- Confirm whether Folding@home wants Spark/GB10 PCI metadata evidence for the GPU resources list.
- Ask whether they prefer StoneyTech to test OpenMM CUDA runtime compatibility first, or wait for their guidance on ARM64 GPU FAHCore packaging.
- Offer the sanitized artifact bundle and repeatable scripts in this repository.
- Make clear that StoneyTech will not bypass FAHCore signing or run unofficial science paths.
