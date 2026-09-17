# GitLab Runner

Installs GitLab Runner and prepares a Docker executor registration template.

## Host

- Name: gitlab-runner-01
- Proxmox VM ID: 107
- IP address: 192.168.178.108
- DHCP reservation: BC:24:11:07:80:64
- GitLab instance: https://gitlab.com

## Access

From ubuntu-dev-01:

```bash
ssh moustafa@192.168.178.108
```

## Deploy

From configuration/ansible:

```bash
ansible-playbook playbooks/gitlab-runner.yml --limit gitlab_runners
```

## Operations

Run on gitlab-runner-01:

```bash
sudo systemctl status gitlab-runner --no-pager
sudo journalctl -u gitlab-runner -n 50 --no-pager
sudo gitlab-runner --version
sudo docker version
free -h
df -h /
```

## Configuration

- Active configuration: /etc/gitlab-runner/config.toml
- Registration template: /etc/gitlab-runner/registration-template.toml

The active configuration contains a secret runner authentication token.
Do not commit or share its contents.

The registration template is applied during registration.
Editing the template does not update an already registered runner.

## Network

- Inbound TCP 22: SSH management.
- Outbound TCP 443: GitLab, container registries and HTTPS package sources.
- Outbound DNS: name resolution.

## Status

Runner installation and registration preparation are managed by Ansible.
Project registration and a successful CI job must be completed separately.
