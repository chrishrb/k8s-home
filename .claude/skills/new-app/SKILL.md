---
name: new-app
description: Scaffold a new Flux app (ks.yaml, HelmRelease, ExternalSecret, optional database/volsync/gatus) under kubernetes/apps/<namespace>/<app> and register it in the namespace kustomization.
argument-hint: <namespace> <app> [chart/repo hint]
disable-model-invocation: true
---

# Scaffold a Flux app

Arguments: `$ARGUMENTS` (namespace, app name, and optionally a chart or Helm repository hint).

## Layout to produce

```
kubernetes/apps/<namespace>/
├── kustomization.yaml          # add `- ./<app>/ks.yaml`
├── namespace.yaml              # create only if the namespace is new
└── <app>/
    ├── ks.yaml                 # Flux Kustomization (namespace flux-system)
    └── app/
        ├── kustomization.yaml
        ├── helm-release.yaml
        ├── external-secret.yaml  # only if the app needs secrets
        └── database.yaml         # only if the app needs Postgres
```

Templates are in `${CLAUDE_SKILL_DIR}/templates/`. Copy them and replace the `<PLACEHOLDERS>`.

## Steps

1. **Check the inputs.** Confirm the namespace directory exists under `kubernetes/apps/`. If it doesn't, create `namespace.yaml` modelled on `kubernetes/apps/home-automation/namespace.yaml` and add the namespace to `kubernetes/apps/kustomization.yaml`.
2. **Find the chart source.** Look in `kubernetes/flux/repositories/helm/` for an existing HelmRepository. If there isn't one, add a new `HelmRepository` file there and list it in that directory's `kustomization.yaml`. Use the latest chart version you can verify upstream; don't guess it.
3. **Write `ks.yaml`.** Keep the `substitution.flux.home.arpa/enabled: "true"` label. Cluster-wide `substituteFrom` is patched in by `kubernetes/flux/apps.yaml`, so only add `postBuild.substitute` for per-app values (`APP`, `GATUS_SUBDOMAIN`, `VOLSYNC_*`). Only list `dependsOn` entries the app really needs (`external-secrets`, `openebs`, `postgres-cluster`, `emqx-cluster`, …). Check the names with `grep -rh "name: &app" kubernetes/apps`.
4. **Write `app/`.**
   - Secrets always come from Bitwarden through the `bitwarden-secretsmanager` ClusterSecretStore. Never put plaintext secrets in git, and never create new `*.sops.yaml` files for app secrets. Leave `<BITWARDEN_SECRET_UUID>` as a placeholder and tell the user to fill it in.
   - Databases use the ext-postgres-operator `Postgres` + `PostgresUser` pair (`database.yaml` template). It creates a secret called `database`.
   - Ingress hosts use `${BASE_PATH}`, `ingressClassName: nginx` and `cert-manager.io/cluster-issuer: "letsencrypt-prod"`.
   - Optional components: `../../../../tmpl/volsync` (PVC + restic backup, needs `VOLSYNC_CAPACITY`) and `../../../../tmpl/gatus/{external,internal}` (uptime check).
5. **Register the app.** Add `- ./<app>/ks.yaml` to `kubernetes/apps/<namespace>/kustomization.yaml`.
6. **Validate.** Run `kustomize build kubernetes/apps/<namespace>/<app>/app --load-restrictor=LoadRestrictionsNone | kubeconform -strict -ignore-missing-schemas -skip Secret,ExternalSecret -schema-location default -schema-location 'https://kubernetes-schemas.pages.dev/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'`. You can also run `task kubernetes:kubeconform` for the whole tree.
7. **Report back.** List the files you created and any placeholders still left (Bitwarden UUID, values to review). Don't commit, push or `kubectl apply`. Flux deploys the app once the user merges.
