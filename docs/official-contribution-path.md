# Official Contribution Path

StoneyTech's goal is to help Folding@home evaluate ARM64 Linux GPU support without weakening the project's trust model.

## Public Work

- File client issues and pull requests in public FoldingAtHome GitHub repositories.
- Keep client PRs narrowly scoped and independently useful.
- Provide reproducible logs and hardware evidence.

## Controlled Work

FAHCore binaries, work assignment, signing, and science-result validation are controlled by Folding@home. Any ARM64 GPU FAHCore work needs Folding@home approval and distribution.

Official developer access docs list `projectmanager@foldingathome.org` as the path for Assignment Server/project access and source-code/core-development access requests:

https://docs.foldingathome.org/start.html

## Current Ask

StoneyTech can provide:

- NVIDIA DGX Spark ARM64 Linux test hardware.
- Idle GPU capacity between internal workloads.
- OpenMM/GROMACS ARM64 CUDA build evidence.
- Folding@home v8 client build and GPU detection logs.
- Long-running beta validation if official signed ARM64 GPU cores are made available.

## Non-Goals

- Reverse engineering FAHCore binaries.
- Bypassing core signature/hash verification.
- Running unsigned cores on the official network.
- Modifying or fabricating science results.
