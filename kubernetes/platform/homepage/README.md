# Homepage Platform Dashboard

Homepage provides read-only Kubernetes and Proxmox information and links to platform services. It runs in the RKE2 cluster. Gitea and Jenkins widgets have been removed; GitLab integration is pending deployment of the new platform.

## Deployment Configuration

| Property | Value |
|---|---|
| URL | `https://platform.lab.barouconsulting.nl` |
| Namespace / Deployment | `homepage` / `homepage` |
| Image | `ghcr.io/gethomepage/homepage:v1.13.2` |
| Replicas / strategy | 1 / RollingUpdate |
| Node selector | `kubernetes.io/hostname: k8s-worker-01` |
| Service type / ingress class | `ClusterIP` / `nginx` |
| Container port | `3000/TCP` |
| CPU request / limit | `50m` / `250m` |
| Memory request / limit | `128Mi` / `256Mi` |
| ServiceAccount | `homepage` |

The node selector means the current Deployment cannot move to another node if the worker is unavailable. Homepage is a dashboard, not a replacement for monitoring, alerting or service administration.

## Traffic and Configuration

Internal DNS resolves `platform.lab.barouconsulting.nl` to `192.168.178.106`. Caddy terminates HTTPS and forwards the request to the worker ingress at `192.168.178.111:80`. The Ingress routes the hostname to the Homepage Service and container.

| File | Purpose |
|---|---|
| `namespace.yaml` | Namespace |
| `service-account.yaml` | Workload identity inside Kubernetes |
| `rbac.yaml` | Read-only Kubernetes permissions |
| `configmap.yaml` | Homepage settings, service links and widgets |
| `deployment.yaml` | Pod, image, resources, probes and Secret references |
| `service.yaml` | In-cluster service |
| `ingress.yaml` | Hostname route |

The manifests are applied individually; this directory does not use Helm or Kustomize. Homepage configuration files are mounted under `/app/config/` as ConfigMap `subPath` mounts.

## Integrations and Credentials

Kubernetes information uses the `homepage` ServiceAccount and the permissions in `rbac.yaml`. Cluster and node metrics also depend on the metrics API. Rancher is a service link, not a configured Rancher API widget.

| Proxmox setting | Value |
|---|---|
| API endpoint | `https://192.168.178.10:8006` |
| Browser URL | `https://proxmox.lab.barouconsulting.nl` |
| Account / token ID | `homepage@pve` / `homepage@pve!homepage` |
| Role | `PVEAuditor` on `/` |
| Kubernetes Secret | `homepage-proxmox` |
| Required keys | `token-id`, `token-secret` |

The Proxmox widget displays VM/LXC counts and resource usage. Its token values are injected through `HOMEPAGE_VAR_PROXMOX_TOKEN_ID` and `HOMEPAGE_VAR_PROXMOX_TOKEN_SECRET`. `HOMEPAGE_ALLOWED_HOSTS` is set to `platform.lab.barouconsulting.nl`.

The only remaining external integration Secret is `homepage-proxmox`. The retired `homepage-gitea` and `homepage-jenkins` Secrets and their environment references have been removed. Do not recreate them to repair a new pod; inspect whether an outdated manifest or revision still references them.

Verify the required Secret without decoding values:

```bash
kubectl -n homepage get secret homepage-proxmox
kubectl -n homepage describe secret homepage-proxmox
```

Secret values, exported Secret manifests and API credentials must stay outside Git. Before a fresh deployment, create the namespace and provision this Secret through the approved credential-handling process. Without it, the container cannot start successfully.

## Deployment

Run from the repository root, against the intended cluster. For a fresh installation, create the namespace, provision the Secret described above, then apply the remaining manifests:

```bash
kubectl apply -f kubernetes/platform/homepage/namespace.yaml
```

After confirming `homepage-proxmox` exists:

```bash
kubectl apply -f kubernetes/platform/homepage/service-account.yaml
kubectl apply -f kubernetes/platform/homepage/rbac.yaml
kubectl apply -f kubernetes/platform/homepage/configmap.yaml
kubectl apply -f kubernetes/platform/homepage/deployment.yaml
kubectl apply -f kubernetes/platform/homepage/service.yaml
kubectl apply -f kubernetes/platform/homepage/ingress.yaml
kubectl -n homepage rollout status deployment/homepage --timeout=120s
```

For changes to the existing dashboard, validate and apply only the affected resources. Example:

```bash
kubectl apply --dry-run=server -f kubernetes/platform/homepage/configmap.yaml
kubectl apply --dry-run=server -f kubernetes/platform/homepage/deployment.yaml
kubectl apply -f kubernetes/platform/homepage/configmap.yaml
kubectl apply -f kubernetes/platform/homepage/deployment.yaml
```

ConfigMap updates do not propagate into existing `subPath` mounts. If the pod template changed, the Deployment rolls out new pods. For a ConfigMap-only update, restart the Deployment to load the configuration, then wait for readiness:

```bash
kubectl -n homepage rollout restart deployment/homepage
kubectl -n homepage rollout status deployment/homepage --timeout=120s
```

There is no need for an extra restart when new pods from a template change have already loaded the updated ConfigMap. This behavior is documented in [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/#mounted-configmaps-are-updated-automatically).

The retirement change updated both manifests, completed its rollout, and removed the two obsolete Secrets. GitLab integration remains a future change.

## Operations

```bash
kubectl -n homepage get deployment,pods,service,ingress
kubectl -n homepage get pods -o wide
kubectl -n homepage logs deployment/homepage --tail=100
```

Expect one ready replica, a ready pod on `k8s-worker-01`, stable restart counts and the correct ingress hostname. To follow logs, use `kubectl -n homepage logs deployment/homepage --follow`; stop with `Ctrl+C`.

## Troubleshooting

For a dashboard outage, inspect pods and events first:

```bash
kubectl -n homepage get pods
kubectl -n homepage get events --sort-by=.metadata.creationTimestamp
kubectl -n homepage get endpointslices -l kubernetes.io/service-name=homepage
```

Check DNS separately:

```bash
dig @192.168.178.106 platform.lab.barouconsulting.nl +short
```

The expected DNS result is `.106`. EndpointSlices should identify a ready Homepage backend. Then inspect Caddy and ingress if the pod and Service are healthy.

For a Proxmox widget error, confirm the Secret and its key names, inspect recent Homepage logs, and check API reachability and token permissions. Do not expose decoded credentials in logs or screenshots.

For Kubernetes information errors:

```bash
kubectl -n homepage get serviceaccount homepage
kubectl auth can-i get nodes --as=system:serviceaccount:homepage:homepage
kubectl top nodes
```

The authorization check requires the operator to be allowed to impersonate that ServiceAccount. An impersonation-denied response is not proof that Homepage's own permissions are wrong. Metrics availability and ServiceAccount authorization are separate checks.

## Rollback

Inspect rollout history and the intended revision before changing it:

```bash
kubectl -n homepage rollout history deployment/homepage
```

A Deployment rollback restores its pod template, not prior ConfigMap contents or deleted Secrets. Older revisions can reintroduce references to the retired widget Secrets and fail to start.

Prefer a reviewed Git correction that restores compatible configuration and Deployment manifests. Apply the corrected files, ensure new pods load any ConfigMap changes, and verify the rollout and dashboard. Do not blindly undo the retirement revision.

## Security and Future Work

Use scoped API credentials, Kubernetes RBAC and trusted internal HTTPS. Kubernetes Secrets remain sensitive runtime data. Homepage has visibility permissions rather than infrastructure administration privileges.

Add a GitLab service link or widget only when GitLab exists, its endpoint is verified and any required credentials have a defined scope. Full monitoring, alerting and external secret management remain separate platform work.
