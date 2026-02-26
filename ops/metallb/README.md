# MetalLB configuration (site-specific)

This folder is applied by the ArgoCD Application `metallb-config`.

It is intentionally empty by default to avoid accidentally advertising the wrong
IP range on your LAN.

## What you need to provide

For L2 mode, add at least:

- `ipaddresspool.yaml` (your safe, non-DHCP range)
- `l2advertisement.yaml`

Then reference them in `ops/metallb/kustomization.yaml`.

## Safety note (no reboots)

This is a dedicated ArgoCD application that only applies MetalLB CRs. It does
**not** touch Kairos `NodeOp` or `NodeOpUpgrade` resources, so syncing it won’t
reboot nodes.
