# Proxmox Terraform Infrastructure

This directory contains the Terraform configuration used to provision Ubuntu virtual machines on my Proxmox VE homelab.

The goal is to manage virtual infrastructure through reproducible code instead of creating and configuring virtual machines manually.

## Overview

Terraform connects to the Proxmox VE API using a dedicated service account and API token.

The current configuration:

- Reads the available Proxmox nodes
- Clones an Ubuntu 24.04 Cloud-Init template
- Creates a full virtual machine clone
- Configures CPU and memory resources
- Connects the VM to the `vmbr0` network bridge
- Configures networking through DHCP
- Enables the QEMU Guest Agent
- Starts the VM automatically

## Architecture

```text
Windows Management Device
          |
          | SSH over Tailscale
          v
Ubuntu Management VM
ubuntu-dev-01
          |
          | Terraform
          | Proxmox API
          v
Proxmox VE
pve
          |
          | Clone template 9000
          v
Ubuntu Virtual Machine
ubuntu-tf-01
```

## Technology Stack

- Proxmox VE
- Ubuntu Server 24.04 LTS
- Terraform
- Cloud-Init
- QEMU Guest Agent
- Tailscale
- Git
- GitHub

## Project Structure

```text
infrastructure/proxmox/
├── .gitignore
├── .terraform.lock.hcl
├── main.tf
├── outputs.tf
├── providers.tf
└── README.md
```

## Terraform Files

### `providers.tf`

Defines:

- The `bpg/proxmox` Terraform provider
- The provider version constraint
- The Proxmox API endpoint
- TLS handling for the homelab environment

### `main.tf`

Defines the Ubuntu virtual machine resource.

The VM is cloned from Cloud-Init template `9000` and configured with:

- VM ID `103`
- Two virtual CPU cores
- 2 GB of memory
- VirtIO networking
- DHCP networking
- QEMU Guest Agent support
- Automatic startup

### `outputs.tf`

Reads the available Proxmox nodes and exposes their names as Terraform output.

## Prerequisites

Before using this configuration, the following must already exist:

- A working Proxmox VE node named `pve`
- An Ubuntu Cloud-Init template with VM ID `9000`
- A Proxmox service account for Terraform
- A dedicated API token
- A custom Proxmox RBAC role
- Network bridge `vmbr0`
- Storage named `local-lvm`

## Authentication

The Proxmox API token is supplied through an environment variable:

```bash
export PROXMOX_VE_API_TOKEN='terraform@pve!terraform-token=TOKEN_SECRET'
```

The token must never be stored in Terraform files or committed to Git.

## Usage

Initialize the Terraform working directory:

```bash
terraform init
```

Validate the configuration:

```bash
terraform validate
```

Review the proposed infrastructure changes:

```bash
terraform plan
```

Save a reviewed execution plan:

```bash
terraform plan -out=tfplan
```

Apply the saved plan:

```bash
terraform apply tfplan
```

## Validation

The configuration has been successfully tested.

Terraform created VM `103` from the Ubuntu Cloud-Init template.

A second Terraform plan returned:

```text
No changes. Your infrastructure matches the configuration.
```

This confirms that the configuration is idempotent and that the Terraform state matches the real Proxmox infrastructure.

## Security Considerations

- Terraform uses a dedicated Proxmox service account
- Root credentials are not used
- Authentication uses a dedicated API token
- The account is assigned a custom RBAC role
- Terraform state is excluded from Git
- Saved Terraform plans are excluded from Git
- Variable files containing secrets are excluded from Git
- Remote management is performed through Tailscale
- Proxmox and SSH ports are not exposed directly to the internet

## Current Limitations

- The Proxmox API currently uses a self-signed certificate
- Networking currently uses DHCP
- Terraform state is currently stored locally
- The VM configuration currently targets a single Proxmox node
- Resource values are currently defined directly in `main.tf`

## Planned Improvements

- Move configurable values into Terraform variables
- Add SSH public-key authentication for provisioned VMs
- Configure a remote Terraform state backend
- Add reusable Terraform modules
- Add automated Terraform checks through GitHub Actions
- Use Ansible for post-provisioning configuration
- Add monitoring and observability
- Add additional development and Kubernetes nodes
