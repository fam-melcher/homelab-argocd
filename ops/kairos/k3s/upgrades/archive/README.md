# Upgrade Archive

This directory stores historical NodeOpUpgrade manifests that have already been applied.

## Usage

- **Active upgrades** live in `../active/`. Only one upgrade manifest should be present there at a time.
- When a new upgrade is released, move the current file from `active/` to this directory and add the new manifest to `active/`.

## Why immutable upgrades?

NodeOpUpgrade resources are one-shot operations. Mutating them in-place while ArgoCD continuously reconciles causes unintended re-runs. By using dated, immutable filenames and archiving completed upgrades, we ensure:

- Each upgrade run corresponds to a distinct manifest in git history.
- Completed upgrades are preserved for audit and rollback reference.
- The ops ArgoCD Application (manual-sync) only applies what is explicitly in `active/`.
