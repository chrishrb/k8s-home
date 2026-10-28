# k8s-home

GitOps repo for a home Kubernetes cluster: Talos Linux nodes, with Flux v2 reconciling `kubernetes/` from `main`.

## Ground rules

- **Git is the source of truth.** Change manifests and let Flux apply them. Don't `kubectl apply/edit/delete`, `helm install/upgrade` or `talosctl apply` unless the user asks explicitly. Read-only `kubectl get/describe/logs` and `flux get` are fine.
- **Secrets:**
  - App secrets live in Bitwarden Secrets Manager. They're pulled by an `ExternalSecret` through the `bitwarden-secretsmanager` ClusterSecretStore.
  - `*.sops.yaml` files are age-encrypted. Never edit them directly; the user runs `sops edit <file>`.
  - Never read or print `age.key`, `kubeconfig` or `talosconfig`.
- Tools come from the Nix flake through direnv (`.envrc` sets `KUBECONFIG`, `SOPS_AGE_KEY_FILE`, `TALOSCONFIG`). If a CLI is missing, the shell probably wasn't started with direnv loaded.

## Layout

- `kubernetes/apps/<namespace>/<app>/ks.yaml`: the Flux Kustomization (in `flux-system`, with the `substitution.flux.home.arpa/enabled: "true"` label). It points at `./app`.
- `kubernetes/apps/<namespace>/<app>/app/`: `kustomization.yaml`, `helm-release.yaml`, plus `external-secret.yaml` / `database.yaml` if needed.
- `kubernetes/apps/<namespace>/kustomization.yaml`: lists `namespace.yaml` and each `./<app>/ks.yaml`.
- `kubernetes/tmpl/gatus/external`: reusable component, configured through `postBuild.substitute` (`APP`, `GATUS_SUBDOMAIN`).
- `kubernetes/flux/`: Flux config, Helm/OCI/Git repositories, and cluster vars (`cluster-settings`, encrypted `cluster-secrets` holding e.g. `BASE_PATH`).
- `kubernetes/bootstrap/`: Talos (talhelper) and the initial Flux/helmfile bootstrap.
- `bootstrap/templates/`: makejinja templates from the upstream cluster-template. Not used for day-to-day changes.

## Conventions

- HelmReleases use `helm.toolkit.fluxcd.io/v2`, `interval: 30m`, and remediation `retries: 3`. HelmRepositories live in `flux-system`.
- Generic apps use the bjw-s `app-template` chart.
- Exposure: an `HTTPRoute` (see `kubernetes/apps/observability/grafana/app/httproute.yaml`) attached to its own `https-<app>` listener on the `external` Gateway in `kubernetes/apps/networking/gateway/app/gateway.yaml`, host `<sub>.${BASE_PATH}`. Adding a host means adding a listener there; cert-manager issues its certificate. No Ingress/ingress-nginx.
- Postgres: ext-postgres-operator `Postgres` + `PostgresUser` against the CloudNativePG cluster (`dependsOn: postgres-cluster`).
- Storage: `openebs-hostpath`. Apps own their PVC in `app/pvc.yaml` (with `kustomize.toolkit.fluxcd.io/prune: disabled`). There are no PVC backups at the moment (volsync was removed).
- Commit messages follow Conventional Commits (`feat(app): …`, `fix(helm): …`). Renovate manages version bumps.

## Commands

- `task kubernetes:kubeconform`: validate every manifest (CI runs the same script, `scripts/kubeconform.sh`).
- `task kubernetes:reconcile`: force Flux to pull from git.
- `task kubernetes:resources`: dump common cluster resources.
- `task talos:sync` (`DRY_RUN=true` to preview): upgrade Talos, then Kubernetes, to the versions in `talconfig.yaml`. Changes the node, so only run it when the user asks.
- `task --list`: list all tasks.

## Upgrades

- Renovate bumps `talosVersion` / `kubernetesVersion` in `talconfig.yaml` together with `TALOS_VERSION` / `KUBERNETES_VERSION` in `kubernetes/flux/vars/cluster-settings.yaml` (same PR). Kubernetes minor bumps need approval on the Dependency Dashboard; check the Talos support matrix first.
- Nothing applies Talos/Kubernetes bumps automatically (single node, so no tuppr). After the merge, `TalosVersionDrift` / `KubernetesVersionDrift` fire until someone runs `task talos:sync`.
- Bootstrap-only pins (`kubernetes/bootstrap/helmfile.yaml`, `kubernetes/bootstrap/flux/kustomization.yaml`) are bumped by Renovate together with their Flux counterparts but only matter when rebuilding the cluster.
- `flake.lock` gets a monthly Renovate lock-file-maintenance PR. `bootstrap/templates/` is ignored by Renovate.

## Claude tooling in this repo

- Hooks (`.claude/settings.json`) block edits to secrets and run kustomize + kubeconform on edited manifests.
- `/new-app <ns> <app>`: scaffold an app.
- `/flux-debug [app]`: triage reconcile failures.
- `renovate-reviewer` agent: review dependency PRs for breaking changes.
