```markdown
# Rancher Operations Runbook

## Overview

Rancher Manager provides the Kubernetes management layer for the Barou Platform homelab.

## Endpoint

Hostname:

```text
rancher.lab.barouconsulting.nl

Expected URL:

https://rancher.lab.barouconsulting.nl
Kubernetes Namespace

Rancher runs in:

cattle-system
Cluster Access

Connect to the RKE2 control plane:

ssh moustafa@192.168.178.110
kubectl

RKE2 provides kubectl at:

/var/lib/rancher/rke2/bin/kubectl

The cluster kubeconfig is located at:

/etc/rancher/rke2/rke2.yaml

Example:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get nodes
Rancher Pod Status
sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n cattle-system \
  get pods -o wide
Rancher Service
sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n cattle-system \
  get svc
Rancher Ingress
sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n cattle-system \
  get ingress
Logs

List Rancher pods:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n cattle-system \
  get pods

View Rancher logs:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n cattle-system \
  logs deployment/rancher \
  --tail=200

Follow logs:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n cattle-system \
  logs deployment/rancher \
  -f
Resource Usage
sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  top pods -n cattle-system
Basic Troubleshooting

Describe Rancher deployment:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n cattle-system \
  describe deployment rancher

Check namespace events:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n cattle-system \
  get events \
  --sort-by=.lastTimestamp

Check ingress controller:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n kube-system \
  get pods \
  -l app.kubernetes.io/name=rke2-ingress-nginx

Check DNS:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  -n kube-system \
  get pods \
  -l k8s-app=kube-dns
Important Notes

The current Rancher deployment uses one replica.

This is appropriate for the homelab but is not a highly available production design.

Rancher should remain pinned to an explicitly selected version and should not be upgraded automatically without checking Kubernetes compatibility first.
