# k8s-home

## Core Components

- [cert-manager](https://github.com/cert-manager/cert-manager): Creates SSL certificates for services in my cluster.
- [cilium](https://github.com/cilium/cilium): Internal Kubernetes container networking interface, and the [Gateway API](https://gateway-api.sigs.k8s.io/) implementation that exposes services.
- [external-secrets](https://github.com/external-secrets/external-secrets): Managed Kubernetes secrets using [bitwarden secrets manager](https://external-secrets.io/latest/provider/bitwarden-secrets-manager/).
- [sops](https://github.com/getsops/sops): Managed secrets for Kubernetes and Terraform which are commited to Git.
- [spegel](https://github.com/spegel-org/spegel): Stateless cluster local OCI registry mirror.

## GitOps

[Flux](https://github.com/fluxcd/flux2) watches the clusters in my [kubernetes](./kubernetes/) folder (see Directories below) and makes the changes to my clusters based on the state of my Git repository.

The way Flux works for me here is it will recursively search the `kubernetes/${cluster}/apps` folder until it finds the most top level `kustomization.yaml` per directory and then apply all the resources listed in it. That aforementioned `kustomization.yaml` will generally only have a namespace resource and one or many Flux kustomizations (`ks.yaml`). Under the control of those Flux kustomizations there will be a `HelmRelease` or other resources related to the application which will be applied.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates, when they are found a PR is automatically created. When some PRs are merged Flux applies the changes to my cluster.

Talos and Kubernetes versions live in `kubernetes/bootstrap/talos/talconfig.yaml`. Renovate bumps them, but they aren't applied automatically. Once the PR is merged, the `TalosVersionDrift` / `KubernetesVersionDrift` alerts fire until `task talos:sync` (`DRY_RUN=true` to preview) upgrades the node.

## Directories

This Git repository contains the following directories under [Kubernetes](./kubernetes/).

```sh
📁 kubernetes
├── 📁 apps            # applications
├── 📁 bootstrap       # bootstrap procedures
├── 📁 flux            # core flux configuration
├── 📁 tmpl            # re-useable components
```

## Backup / recovery

PVC backups are currently disabled (volsync was removed).
