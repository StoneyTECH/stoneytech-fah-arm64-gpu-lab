# ARM64 CPU GROMACS Test

Joseph Coffland asked whether `stoneytech-spark` can run the client configured for CPU on ARM64. Folding@home already has ARM64 CPU GROMACS cores for Linux and macOS, so this is the first useful validation step before GPU/OpenMM work.

## Goal

Show whether an ARM64 Linux client containing PR #442 can:

- request CPU-only work;
- download the official ARM64 CPU GROMACS core;
- start a work unit;
- advance progress;
- optionally complete and upload one WU.

## Safe Runner

Use the isolated runner:

```sh
FAH_USER=Stoney_DeVille FAH_TEAM=0 FAH_PASSKEY='your-passkey' \
  ./scripts/run-fah-cpu-test.sh --client /path/to/fah-client --cpus 8 --seconds 1800
```

The runner:

- writes to `reports/fah-cpu-test-*`;
- creates an isolated `config.xml`;
- disables CUDA/HIP/GPU slots in the test config;
- does not modify the system service;
- redacts passkeys before writing output.

## Review Before Publishing

Do not commit raw output directly. Review generated logs and use:

```text
templates/fah-arm64-cpu-gromacs-report.md
```

Commit only a reviewed markdown report and small, redacted excerpts.
