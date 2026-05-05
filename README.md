# StoneyTech Folding@home ARM64 GPU Lab

This repository collects reproducible evidence for helping Folding@home evaluate ARM64 Linux systems with NVIDIA GPU acceleration.

Primary test target: `stoneytech-spark`, a NVIDIA DGX Spark running ARM64 Linux.

## Purpose

StoneyTech wants to contribute to Folding@home through the official path:

- public client improvements through GitHub pull requests;
- reproducible hardware, driver, and runtime evidence;
- OpenMM and GROMACS ARM64 CUDA validation;
- beta testing of official signed ARM64 GPU FAHCores if Folding@home provides them.

This repository does not contain FAHCore binaries, reverse engineering notes, bypasses for core signing, or modified science-result paths.

## Current Folding@home Context

- Upstream ARM64 GPU issue: https://github.com/FoldingAtHome/fah-client-bastet/issues/139
- StoneyTech client-side draft PR: https://github.com/FoldingAtHome/fah-client-bastet/pull/442
- Known blocker: no official ARM64 GPU FAHCore binaries are currently available through the normal assignment/core distribution path.

## Quick Start

Collect a public-safe hardware profile:

```sh
./scripts/collect-hardware-profile.sh
```

Collect hardware profile plus redacted Folding@home logs:

```sh
./scripts/collect-hardware-profile.sh --include-fah-logs
```

Run an OpenMM platform smoke test if OpenMM is installed:

```sh
./scripts/run-openmm-smoke.sh
```

Run the maintainer-requested ARM64 CPU GROMACS test:

```sh
FAH_USER=Stoney_DeVille FAH_TEAM=0 FAH_PASSKEY='your-passkey' \
  ./scripts/run-fah-cpu-test.sh --client /path/to/fah-client --cpus 8 --seconds 1800
```

Prefer the containerized path on Spark:

```sh
FAH_USER=Stoney_DeVille FAH_TEAM=0 FAH_PASSKEY='your-passkey' \
  ./scripts/run-fah-cpu-test-container.sh --cpus 8 --seconds 1800
```

Build the PR #442 test client on Spark:

```sh
./scripts/bootstrap-pr442-client.sh --install-deps --jobs 8
```

See `docs/spark-cpu-test-runbook.md` for the full runbook.

Reports are written under `reports/`.

## Evidence We Want

- ARM64 Linux OS/kernel details.
- NVIDIA GPU model, driver, CUDA runtime, and PCI identity.
- OpenCL platform/device visibility when present.
- Folding@home client version and GPU detection logs.
- ARM64 CPU GROMACS core assignment and progress logs.
- Assignment failure logs showing the missing ARM64 GPU core path.
- OpenMM CUDA platform availability.
- Optional GROMACS CUDA build and benchmark logs.
- Long-run utilization, thermals, power, and error counters.

## Trust Boundary

The official Folding@home client verifies downloaded FAHCore packages using hash and certificate/signature checks before running them. This lab stays inside that trust model.

Do not add:

- closed FAHCore binaries;
- decompiled code;
- patches that bypass core verification;
- passkeys, tokens, private keys, or account secrets;
- unredacted logs containing credentials.

## Repository Layout

```text
scripts/
  bootstrap-pr442-client.sh
  collect-hardware-profile.sh
  collect-fah-evidence.sh
  run-fah-cpu-test.sh
  run-fah-cpu-test-container.sh
  openmm-smoke-test.py
  run-openmm-smoke.sh
containers/
  fah-cpu-test/Dockerfile
templates/
  hardware-profile-report.md
  fah-client-evidence-report.md
  fah-arm64-cpu-gromacs-report.md
  openmm-validation-report.md
  gromacs-validation-report.md
  beta-validation-checklist.md
docs/
  official-contribution-path.md
reports/
  generated evidence output, ignored by git except .gitkeep
```

## License

MIT. See `LICENSE`.
