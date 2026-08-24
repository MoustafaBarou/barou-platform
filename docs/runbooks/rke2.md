```markdown
# RKE2 Operations Runbook

## Purpose

This runbook provides operational commands for accessing, validating and troubleshooting the RKE2 Kubernetes cluster.

The document is intended for day-to-day administration and troubleshooting.

## Nodes

### Control Plane

Hostname:

```text
k8s-cp-01

IP address:

192.168.178.110

Role:

RKE2 Server / Kubernetes Control Plane

SSH:

ssh moustafa@192.168.178.110
Worker

Hostname:

k8s-worker-01

IP address:

192.168.178.111

Role:

RKE2 Agent / Kubernetes Worker

SSH:

ssh moustafa@192.168.178.111
Important Ports
Port	Protocol	Purpose
22	TCP	SSH
6443	TCP	Kubernetes API
9345	TCP	RKE2 supervisor
RKE2 Server Service

Check service status:

sudo systemctl status rke2-server

Check whether the service is active:

sudo systemctl is-active rke2-server

Start the service:

sudo systemctl start rke2-server

Restart the service:

sudo systemctl restart rke2-server

Stop the service:

sudo systemctl stop rke2-server

Enable the service at boot:

sudo systemctl enable rke2-server
RKE2 Agent Service

Check service status:

sudo systemctl status rke2-agent

Check whether the service is active:

sudo systemctl is-active rke2-agent

Restart the service:

sudo systemctl restart rke2-agent
Logs

Follow RKE2 server logs:

sudo journalctl -u rke2-server -f

View the last 100 server log lines:

sudo journalctl -u rke2-server -n 100 --no-pager

Follow worker logs:

sudo journalctl -u rke2-agent -f

View the last 100 worker log lines:

sudo journalctl -u rke2-agent -n 100 --no-pager
RKE2 Configuration

Main configuration:

/etc/rancher/rke2/config.yaml

Read configuration:

sudo cat /etc/rancher/rke2/config.yaml

RKE2 data directory:

/var/lib/rancher/rke2
Kubernetes Kubeconfig

RKE2 kubeconfig:

/etc/rancher/rke2/rke2.yaml

Read kubeconfig:

sudo cat /etc/rancher/rke2/rke2.yaml

The kubeconfig contains authentication information and must not be committed to Git.

kubectl

RKE2 kubectl binary:

/var/lib/rancher/rke2/bin/kubectl

Check nodes:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get nodes -o wide

Check all pods:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get pods -A -o wide

Check services:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get svc -A

Check recent events:

sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get events -A --sort-by=.lastTimestamp
Networking

Show listening TCP ports:

sudo ss -lntp

Check Kubernetes API and RKE2 supervisor:

sudo ss -lntp | grep -E '6443|9345'

Test control-plane API connectivity from the worker:

nc -vz 192.168.178.110 6443

Test RKE2 supervisor connectivity:

nc -vz 192.168.178.110 9345
Node Health

Check CPU and memory:

free -h
uptime
top

Check disk usage:

df -h

Check failed systemd services:

systemctl --failed
Firewall

Check UFW status:

sudo ufw status verbose
Ansible

Test connectivity to the complete Kubernetes cluster:

cd ~/terraform/barou-platform/configuration/ansible
ansible k8s_cluster -i inventories/homelab/hosts.yml -m ping

Run the Kubernetes baseline:

ansible-playbook \
  -i inventories/homelab/hosts.yml \
  playbooks/k8s-baseline.yml

Expected idempotent result:

changed=0
failed=0
Current State

At the time this runbook was created, the Kubernetes nodes and operating system baseline are operational.

RKE2 installation is the next deployment step.

Commands referring to rke2-server, rke2-agent and Kubernetes resources become operational after RKE2 has been installed.
