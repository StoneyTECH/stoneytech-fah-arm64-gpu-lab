# Spark CPU-Only Folding@home Runbook

This is the next execution step after Joseph Coffland's request to test ARM64 CPU folding with the existing GROMACS core.

## Goal

On `stoneytech-spark`, run Folding@home CPU-only with a client containing PR #442 and capture enough evidence to answer:

- Does ARM64 Linux platform detection work?
- Does CPU-only assignment succeed?
- Does the official ARM64 CPU GROMACS core download?
- Does the core start and make WU progress?
- Can one WU complete and upload?

## Do Not Publish Raw Output

The scripts write raw-ish output under `reports/`. Review before publishing.

Commit only:

- summarized markdown reports;
- short, redacted log excerpts;
- no passkeys;
- no account tokens;
- no private host/network details unless intentionally included.

## Step 1: Clone The Lab Repo On Spark

```sh
git clone https://github.com/StoneyTECH/stoneytech-fah-arm64-gpu-lab.git
cd stoneytech-fah-arm64-gpu-lab
```

## Step 2: Build PR #442 Client

Preferred on Spark: build and run inside the containerized harness:

```sh
FAH_USER=Stoney_DeVille \
FAH_TEAM=0 \
FAH_PASSKEY='your-passkey' \
./scripts/run-fah-cpu-test-container.sh \
  --cpus 8 \
  --seconds 1800
```

This keeps the Folding@home client, build cache, core downloads, and logs inside
container-mounted lab directories. It does not install or modify a host
Folding@home service.

Host fallback:

On Debian/Ubuntu, install dependencies and build:

```sh
./scripts/bootstrap-pr442-client.sh --install-deps --jobs 8
```

If dependencies are already installed:

```sh
./scripts/bootstrap-pr442-client.sh --jobs 8
```

Expected client path:

```text
~/stoneytech-fah-pr442/fah-client-bastet/fah-client
```

## Step 3: Capture Hardware Profile

```sh
./scripts/collect-hardware-profile.sh
```

Review the generated `reports/hardware-profile-*` directory before publishing anything.

## Step 4: Run CPU-Only Folding Test

If you used the containerized command in step 2, this step is already done.

For the host fallback, start with a modest CPU count so the machine stays responsive:

```sh
FAH_USER=Stoney_DeVille \
FAH_TEAM=0 \
FAH_PASSKEY='your-passkey' \
./scripts/run-fah-cpu-test.sh \
  --client "$HOME/stoneytech-fah-pr442/fah-client-bastet/fah-client" \
  --cpus 8 \
  --seconds 1800
```

Notes:

- Use the real team number if you want the WU credited to a team.
- Prefer `FAH_PASSKEY` in the environment over `--passkey`.
- The runner redacts the passkey from generated files.
- The runner uses an isolated working directory and does not modify the system service.

## Step 5: Look For Success Signals

In `reports/fah-cpu-test-*/log.txt`, look for:

- CPU platform reported as `arm64`;
- assignment response received;
- core metadata/package URL;
- `Core signature valid`;
- GROMACS/CPU core info;
- WU enters run state;
- progress log lines;
- upload result if the run is long enough to complete.

## Step 6: Create The Public Report

Use:

```text
templates/fah-arm64-cpu-gromacs-report.md
```

Save reviewed report as:

```text
docs/reports/arm64-cpu-gromacs-stoneytech-spark-YYYY-MM-DD.md
```

Commit only reviewed markdown and small sanitized excerpts.

## Step 7: Reply To Folding@home

Reply only after the report is reviewed:

- If it works, share the report link and summary.
- If it fails, share the exact failure point and sanitized evidence.
