# MetalLB configuration (site-specific)

MetalLB *installation* is handled separately (via the ArgoCD Helm Application).
This folder contains the site/cluster-specific MetalLB CRs (like `IPAddressPool`).

## Kustomize layout

- `ops/metallb/base/` defines the common objects.
- `ops/metallb/overlays/<cluster>/` patches only what differs per cluster.

For example, the `devbox` overlay patches only `spec.addresses`.

## Add a new cluster

1. Copy the overlay folder:

- `ops/metallb/overlays/devbox/` → `ops/metallb/overlays/<newcluster>/`

2. Update `ipaddresspool-addresses.yaml` with your LAN range.
3. Add a new element in the `metallb-config` ApplicationSet generator.

## Safety note (no reboots)

This is a dedicated ArgoCD application that only applies MetalLB CRs. It does
**not** touch Kairos `NodeOp` or `NodeOpUpgrade` resources, so syncing it won’t
reboot nodes.

