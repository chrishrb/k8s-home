---
name: flux-debug
description: Triage a Flux Kustomization or HelmRelease that is not reconciling, or an app that is failing in the cluster. Use when the user asks why an app is not deploying, is stuck, failing, not ready, or after a Renovate update broke something.
argument-hint: "[app or namespace]"
---

# Flux reconcile triage

Target: `$ARGUMENTS` (if empty, check the whole cluster).

Stick to read-only commands unless the user agrees to something else. The fix goes in git, never in `kubectl edit` or `kubectl apply`. `KUBECONFIG` is set by direnv (`.envrc`). If `kubectl` can't reach the cluster, ask the user to run `direnv allow` / start the session from the repo directory.

## 1. Find what is failing

```bash
flux get sources git -A
flux get ks -A --status-selector ready=false
flux get hr -A --status-selector ready=false
```

Kustomizations form a `dependsOn` chain, so one failure upstream shows up as many "dependency not ready" errors downstream. Find the root: the failing Kustomization whose dependencies are all Ready.

## 2. Dig into the failing object

- **Kustomization:**
  - Run `kubectl -n flux-system describe ks <name>` and `flux events --for Kustomization/<name> -n flux-system`.
  - Typical causes: a kustomize build error, an unresolved `${VAR}` substitution, a missing CRD, a schema error, or `wait: true` timing out because a workload is unhealthy.
- **HelmRelease:**
  - Run `kubectl -n <ns> describe hr <name>`, `flux events --for HelmRelease/<name> -n <ns>` and `helm -n <ns> history <name>`.
  - Typical causes: a chart that won't fetch (version or HelmRepository), values that fail the chart schema, failed upgrade hooks, or exhausted remediation retries. After the fix is merged, a stuck release can be reset with `flux suspend hr` / `flux resume hr` (ask first).
- **Workload:**
  - Run `kubectl -n <ns> get pods,pvc,externalsecret`, `kubectl -n <ns> describe pod <pod>`, `kubectl -n <ns> logs <pod> --previous` and `stern -n <ns> <app>`.
  - An ExternalSecret that isn't `SecretSynced` usually means a wrong Bitwarden UUID or key name.
  - A Pending PVC means openebs or volsync trouble.

## 3. Correlate with observability (if the Grafana MCP tools are available)

- Loki: `{namespace="<ns>"} |= "error"` for the app, and `{namespace="flux-system"}` for controller errors.
- Prometheus: `kube_pod_container_status_restarts_total{namespace="<ns>"}`, plus firing alerts.

## 4. Relate it to a change

Check `git log --oneline -15 -- kubernetes/apps/<ns>/<app>`. Renovate bumps (`fix(helm): update chart …`) are the usual trigger, so compare the chart's release notes for that version range.

## 5. Report

Give:
- the root cause, with the evidence (command output or log lines)
- the fix as a diff to the manifests in git
- what to run after merging: `task kubernetes:reconcile`, or `flux reconcile ks <name> -n flux-system --with-source`
