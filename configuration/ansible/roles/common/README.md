# Common Role

## Purpose

The `common` role applies the baseline configuration used across Ubuntu servers in the Barou Platform homelab.

The role is intentionally focused on general operating system configuration and does not contain security-specific or application-specific settings.

## Responsibilities

The role currently manages:

- APT package cache updates
- baseline package installation
- system timezone configuration
- unattended security upgrades

## Default Variables

Default variables are defined in:

```text
defaults/main.yml

Current variables:

common_timezone: Europe/Amsterdam

common_apt_cache_valid_time: 3600

common_packages:
  - curl
  - git
  - htop
  - unzip
  - vim
  - jq
  - ca-certificates
  - gnupg
  - apt-transport-https

common_unattended_upgrades_enabled: true
Package Management

The role installs a small baseline package set required for administration, troubleshooting, automation, and future platform components.

The package list is configurable through:

common_packages

This allows inventories or host groups to extend or override the package list without modifying the role implementation.

Timezone

The default timezone is:

Europe/Amsterdam

It can be overridden through:

common_timezone
Unattended Upgrades

Automatic security updates are enabled by default.

This is controlled through:

common_unattended_upgrades_enabled: true

When enabled, the role ensures that unattended-upgrades is installed and configures APT periodic updates.

Idempotency

The role is designed to be idempotent.

Repeated executions should not result in unnecessary configuration changes once the desired state has been reached.

Example expected result on a second run:

changed=0
failed=0
unreachable=0
Usage

The role is currently applied through:

---
- name: Bootstrap Ubuntu servers
  hosts: ubuntu_servers
  become: true

  roles:
    - common

In the current platform, the common and security roles are both called from:

playbooks/bootstrap.yml
Design Principles

The role follows these principles:

simple defaults
declarative configuration
reusable variables
idempotent tasks
no application-specific configuration
no security configuration that belongs in the security role
