```markdown
# Kubernetes Troubleshooting Guide

## Purpose

This document provides a structured troubleshooting workflow for the Barou Platform Kubernetes environment.

The goal is to diagnose failures systematically instead of changing multiple components at the same time.

## Troubleshooting Method

Use the following order:

1. Confirm the symptom
2. Confirm basic connectivity
3. Check service status
4. Check logs
5. Check firewall and ports
6. Check Kubernetes resources
7. Identify the root cause
8. Apply the smallest possible fix
9. Validate recovery
10. Document the incident

## SSH Failure

Symptom:

```text
Connection timed out

Check connectivity:

ping 192.168.178.110

Test SSH:

nc -vz 192.168.178.110 22

Verify VM status in Proxmox:

qm status 110

Check the current VM network configuration:

qm guest cmd 110 network-get-interfaces

For the worker:

qm guest cmd 111 network-get-interfaces
Host Key Verification Failure

Remove an obsolete SSH host key:

ssh-keygen -R 192.168.178.110

Reconnect manually:

ssh moustafa@192.168.178.110

Verify the presented fingerprint before accepting a new host key in production-style environments.

RKE2 Server Not Running

Check status:

sudo systemctl status rke2-server

Check recent logs:

sudo journalctl -u rke2-server -n 100 --no-pager

Check configuration:

sudo cat /etc/rancher/rke2/config.yaml

Validate ports:

sudo ss -lntp | grep -E '6443|9345'
Worker Does Not Join

On the worker:

sudo systemctl status rke2-agent

Check logs:

sudo journalctl -u rke2-agent -n 100 --no-pager

Test the server supervisor port:

nc -vz 192.168.178.110 9345

Test the Kubernetes API:

nc -vz 192.168.178.110 6443

Typical causes include:

incorrect RKE2 token
incorrect server address
firewall blocking port 9345
control-plane service unavailable
invalid RKE2 configuration
DNS or routing problems
Node NotReady

Check nodes:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get nodes -o wide

Describe the affected node:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  describe node k8s-worker-01

Check system pods:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get pods -A -o wide
Pod CrashLoopBackOff

List pods:

kubectl get pods -A

Describe the pod:

kubectl describe pod <pod-name> -n <namespace>

Read logs:

kubectl logs <pod-name> -n <namespace>

Read logs from the previous crashed container:

kubectl logs <pod-name> -n <namespace> --previous
Pending Pod

Describe the pod:

kubectl describe pod <pod-name> -n <namespace>

Check events:

kubectl get events -A --sort-by=.lastTimestamp

Possible causes include:

insufficient CPU
insufficient memory
storage unavailable
node selectors
taints and tolerations
scheduling constraints
Network Failure

Check node connectivity:

ping 192.168.178.110
ping 192.168.178.111

Check relevant ports:

sudo ss -lntp

Check UFW:

sudo ufw status verbose

Later, when Cilium is installed, also inspect:

kubectl -n kube-system get pods -l k8s-app=cilium
DNS Failure

Check CoreDNS pods:

kubectl -n kube-system get pods -l k8s-app=kube-dns

Check logs:

kubectl -n kube-system logs -l k8s-app=kube-dns

Test DNS from a temporary workload after the cluster is operational.

Resource Pressure

Memory:

free -h

CPU:

uptime

Disk:

df -h

Kubernetes node information:

kubectl describe node

Look specifically for:

MemoryPressure
DiskPressure
PIDPressure
Controlled Failure Labs

The homelab will intentionally include break/fix exercises.

Planned examples:

stop the RKE2 agent
block port 9345
configure an incorrect node token
configure an invalid Cilium NetworkPolicy
break internal DNS
configure an incorrect reverse proxy upstream
create a CrashLoopBackOff workload
create an unschedulable workload
create an Argo CD sync failure
simulate disk pressure

Each exercise should include:

Symptom
Impact
Investigation
Root cause
Fix
Validation
Lessons learned
Incident Documentation

After each troubleshooting exercise, document:

what was broken
what the user or platform experienced
commands used during investigation
root cause
remediation
preventive improvement

This turns each failure into a repeatable engineering exercise.

## Incident: RKE2 system components unable to reach the Kubernetes API

### Symptoms

After the initial RKE2 deployment, both Kubernetes nodes reported `Ready`, but several cluster services were unhealthy:

- CoreDNS remained NotReady.
- The CoreDNS service had no Ready endpoints.
- RKE2 Helm installer jobs entered `CrashLoopBackOff`.
- ingress-nginx was not installed successfully.
- metrics-server was unavailable.
- snapshot-controller was unavailable.

### Impact

The Kubernetes control plane itself was operational, but important platform services could not initialize.

This affected:

- Cluster DNS
- Metrics collection
- Ingress
- Snapshot controller
- RKE2 packaged component installation

### Investigation

The investigation was performed from the infrastructure layer toward the workload layer.

The following checks were successful:

- Both Kubernetes nodes were `Ready`.
- The Kubernetes API server was listening on TCP 6443.
- The RKE2 supervisor was listening on TCP 9345.
- Cilium reported healthy controllers.
- Cilium cluster health reported both nodes reachable.
- A pod running on the worker node could reach the Kubernetes Service IP `10.43.0.1`.

However, a pod running on the control-plane node could not reach:

```text
192.168.178.110:6443

The connection timed out.

UFW logging then showed the blocked traffic:

SRC=10.42.0.x DST=192.168.178.110 DPT=6443

This confirmed that Kubernetes pod traffic from the pod CIDR was being blocked when attempting to reach the API server.

Root Cause

The Linux security baseline enabled UFW with a default deny incoming policy.

The original RKE2 firewall rules allowed Kubernetes worker-node traffic to reach the control plane, but did not allow traffic originating from the Kubernetes pod network:

10.42.0.0/16

As a result, pods scheduled on the control-plane node could not communicate with the Kubernetes API server.

CoreDNS could therefore not synchronize with the Kubernetes API, and multiple RKE2 Helm installation jobs also failed when attempting to access:

https://10.43.0.1:443
Remediation

The Ansible rke2_firewall role was updated to explicitly allow:

10.42.0.0/16 -> TCP 6443

on the Kubernetes control-plane node.

Pod access to the kubelet service was also explicitly allowed:

10.42.0.0/16 -> TCP 10250

The change was implemented through Ansible rather than manually modifying the firewall.

Validation

After applying the firewall change:

Pod to API server communication returned HTTP 401 instead of timing out.
Pod to Kubernetes ClusterIP 10.43.0.1 returned HTTP 401.
CoreDNS became Ready.
CoreDNS endpoints were populated on both Kubernetes nodes.
Internal Kubernetes DNS resolution succeeded.
All RKE2 Helm installer jobs completed.
ingress-nginx became healthy.
metrics-server became healthy.
snapshot-controller became healthy.
kubectl top nodes returned CPU and memory metrics.
kubectl top pods -A returned workload metrics.
The complete RKE2 Ansible playbook completed with changed=0 and failed=0.
Lessons Learned

A Kubernetes node being Ready does not guarantee that pod-to-host or pod-to-service communication is functioning correctly.

Host firewall policies must account for:

Node-to-node traffic
Pod CIDRs
Kubernetes API access
kubelet communication
CNI-specific networking requirements

The firewall remains enabled and restrictive. The issue was resolved by adding the minimum required rules instead of disabling host-level security controls.
