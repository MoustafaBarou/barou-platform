# Security Role

## Purpose

The `security` role applies the baseline security configuration used across Ubuntu servers in the Barou Platform homelab.

The role currently focuses on host firewall configuration and SSH hardening.

## Responsibilities

The role currently manages:

- UFW installation
- SSH firewall access
- default firewall policies
- UFW logging
- SSH password authentication
- SSH root login
- SSH public key authentication
- empty password protection
- X11 forwarding
- maximum SSH authentication attempts
- SSH client keepalive configuration

## Structure

The role is split into focused task files:

```text
security/
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
└── tasks/
    ├── firewall.yml
    ├── main.yml
    └── ssh.yml

tasks/main.yml acts as the role orchestrator.

Firewall configuration is implemented in:

tasks/firewall.yml

SSH hardening is implemented in:

tasks/ssh.yml
Default Variables

Default variables are defined in:

defaults/main.yml

Current SSH defaults include:

security_sshd_password_authentication: "no"
security_sshd_permit_root_login: "no"
security_sshd_pubkey_authentication: "yes"

security_sshd_permit_empty_passwords: "no"
security_sshd_x11_forwarding: "no"
security_sshd_max_auth_tries: 3
security_sshd_client_alive_interval: 300
security_sshd_client_alive_count_max: 2

Firewall defaults include:

security_ufw_ssh_profile: OpenSSH
security_ufw_logging: low
Firewall Baseline

The role configures UFW with the following baseline:

Incoming traffic: deny
Outgoing traffic: allow
SSH access: allow
Logging: low

This creates a deny-by-default inbound firewall policy while maintaining normal outbound connectivity.

SSH Hardening

The SSH configuration currently enforces:

PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

These settings reduce the SSH attack surface while preserving key-based administration.

Configuration Validation

Changes to /etc/ssh/sshd_config are validated before they are applied.

The role uses:

/usr/sbin/sshd -t -f %s

This validation helps prevent an invalid SSH configuration from being applied.

Without this check, a configuration error could prevent future SSH access to the server.

Handler

SSH configuration changes notify the following handler:

- name: Restart SSH
  ansible.builtin.service:
    name: ssh
    state: restarted

The handler only runs when the SSH configuration actually changes.

This prevents unnecessary SSH service restarts.

Idempotency

The role is designed to be idempotent.

After the desired state has been applied, repeated executions should result in:

changed=0
failed=0
unreachable=0

Idempotency has been validated against the current Terraform-managed Ubuntu VM.

This means the role can be executed repeatedly without introducing unnecessary configuration changes.

Usage

The role is currently applied through the Ubuntu bootstrap playbook.

Example:

---
- name: Bootstrap Ubuntu servers
  hosts: ubuntu_servers
  become: true

  roles:
    - security

In the current platform, both the common and security roles are called from:

playbooks/bootstrap.yml
Security Considerations

SSH password authentication is disabled.

The target server must therefore have working SSH public key authentication before this role is applied.

The role validates SSH configuration before applying changes, but SSH access should still be tested after modifying SSH-related settings.

The firewall intentionally permits SSH before UFW is enabled to reduce the risk of remote lockout.

Direct root login is disabled.

SSH public key authentication remains enabled as the primary remote administration method.

The default inbound firewall policy is deny.

Outbound traffic remains allowed to support package installation, updates, monitoring, and other platform services.

Design Principles

The role follows these principles:

deny inbound traffic by default
preserve administrative access before enabling the firewall
prefer SSH key authentication over passwords
validate configuration before restarting SSH
restart services only when configuration changes
keep security configuration separated from general system configuration
keep tasks idempotent
keep defaults configurable where operationally useful
Validation

The role is validated locally before changes are submitted.

The current validation process includes:

Ansible syntax validation
ansible-lint

The same validation is executed again through GitHub Actions before changes can be merged into main.

This provides both a local and remote quality gate.

Future Improvements

Potential future additions include:

Fail2ban
additional sysctl hardening
audit logging
file permission checks
more advanced SSH policies
centralized log forwarding
integration with monitoring
optional CIS-aligned controls
automated security testing

Additional hardening will only be introduced when its purpose and operational impact are understood.

The goal is to improve security without introducing unnecessary complexity or breaking normal platform operations.
