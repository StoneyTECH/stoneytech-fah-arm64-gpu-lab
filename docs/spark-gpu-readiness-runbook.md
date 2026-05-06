# Spark GPU Readiness Runbook

This runbook collects public-safe evidence for a NVIDIA DGX Spark ARM64 system before asking Folding@home for deeper GPU enablement help.

## Guardrails

- Stay inside the official Folding@home trust model.
- Do not run unsigned or modified FAHCores.
- Do not bypass client core verification, assignment, or signing checks.
- Do not publish passkeys, tokens, private hostnames, private IPs, or unrelated customer/employer context.
- Treat GPU testing as readiness evidence until Folding@home explicitly invites GPU beta validation.

## 1. Update the Lab Repository

```sh
git pull --ff-only origin main
```

## 2. Collect GPU Readiness Inventory

```sh
./scripts/collect-gpu-readiness-inventory.sh
```

This records OS/kernel details, NVIDIA driver state, PCI identity, CUDA-related libraries, Python GPU module visibility, Docker version, and local GPU container images.

## 3. Run CUDA Container Smoke Test

```sh
./scripts/run-cuda-smoke-container.sh
```

Expected success criteria:

- Docker can expose the GPU with `--gpus all`.
- PyTorch reports CUDA available.
- The Spark GPU appears as one CUDA device.
- A small CUDA matmul workload completes without driver reset or SSH instability.

## 4. Run OpenMM Baseline Without CUDA Plugin

```sh
./scripts/run-openmm-smoke.sh --container --cuda-extra none --platform CUDA
```

Expected result on the current Spark image: this may fail because the plain PyPI OpenMM package can expose only `Reference` and `CPU` platforms in this container.

That failure is still useful evidence because it separates OpenMM package/platform availability from general CUDA availability.

## 5. Run OpenMM With CUDA Plugin

```sh
./scripts/run-openmm-smoke.sh --container --cuda-extra cuda13 --platform CUDA
```

Expected success criteria for a fully ready stack:

- OpenMM lists the `CUDA` platform.
- The smoke system creates a CUDA context.
- The integrator steps complete.
- Energy and final-position output are recorded.

Current known Spark result: the CUDA platform can enumerate with the CUDA 13 plugin, but context execution can fail with `CUDA_ERROR_UNSUPPORTED_PTX_VERSION`. Capture the full log if that persists.

## 6. Optional CPU Baseline

```sh
./scripts/run-openmm-smoke.sh --container --cuda-extra none --platform CPU
```

This proves the toy OpenMM system itself is valid even when CUDA is not available.

## 7. What to Send Upstream

Send Folding@home a concise summary plus selected sanitized artifacts:

- CPU GROMACS proof paths and WU/project IDs.
- GPU inventory summary, especially PCI ID and driver/CUDA version.
- CUDA container smoke success.
- OpenMM plain-package platform result.
- OpenMM CUDA-plugin result and exact failure text if still failing.
- Folding@home client GPU detection line showing `GB20B [GB10]` and `supported false`.

## Success Target

Before asking for GPU beta access, StoneyTech should be able to show:

- ARM64 CPU GROMACS FAHCore runs complete assignment/progress cleanly.
- The Spark stays reachable under controlled CPU tests.
- CUDA compute is functional through a standard NVIDIA container.
- OpenMM GPU readiness has been tested in a reproducible way.
- Any remaining blocker is stated as a specific upstream/runtime issue, not a vague "Spark does not work."
