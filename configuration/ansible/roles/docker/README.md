# Docker Role


## Purpose


The `docker` role installs and configures Docker Engine on Ubuntu servers in the Barou Platform homelab.


The role is designed to provide a reproducible and reusable container runtime layer that can be applied consistently through Ansible.


## Responsibilities


The role currently manages:


- Docker repository dependencies
- Docker APT keyring
- Docker repository signing key
- official Docker APT repository
- Docker Engine installation
- Docker CLI installation
- containerd installation
- Docker Buildx plugin
- Docker Compose plugin
- Docker service state
- Docker group membership for configured users


## Structure


The role currently uses the following structure:


```text
docker/
├── defaults/
│   └── main.yml
├── handlers/
└── tasks/
    └── main.yml

The role may be split into additional task files later when more Docker configuration is added.

Default Variables

Default variables are defined in:

defaults/main.yml

Current defaults:

docker_apt_arch: amd64
docker_apt_channel: stable


docker_packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin


docker_users:
  - moustafa
Docker Repository

Docker is installed from the official Docker repository.

The repository is configured using the Ansible deb822_repository module.

This avoids using the deprecated apt_repository module and keeps the role compatible with newer Ansible versions.

Repository source:

https://download.docker.com/linux/ubuntu

The repository signing key is stored in:

/etc/apt/keyrings/docker.asc
Installed Components

The role installs the following Docker components:

Docker Engine

Provides the Docker daemon responsible for managing containers, images, networks, and volumes.

Docker CLI

Provides the docker command used to interact with the Docker daemon.

containerd

Provides the container runtime used by Docker Engine.

Docker Buildx

Provides extended image build capabilities.

Validation example:

docker buildx version
Docker Compose

Provides multi-container application orchestration through:

docker compose

Validation example:

docker compose version
Service Management

The Docker service is configured to:

state: started
enabled: true

This means Docker is started immediately and automatically starts again after a server reboot.

Docker Group Access

Configured users are added to the local docker group.

Example:

docker_users:
  - moustafa

This allows these users to run Docker commands without sudo.

A new login session may be required before group membership becomes active.

Security Considerations

Membership of the docker group provides highly privileged access to the host.

Users with Docker access can effectively gain root-level control through the Docker daemon.

For that reason:

Docker group membership should be limited
only trusted administrative users should be added
production environments should apply stricter access controls
Docker socket permissions should not be exposed unnecessarily
remote Docker API access should not be enabled without authentication and encryption

The current homelab configuration allows the administrative moustafa account to use Docker directly for learning and platform management.

Idempotency

The Docker role is designed to be idempotent.

After the desired state has been applied, repeated Ansible runs should not introduce additional changes.

Validated result:

changed=0
failed=0
unreachable=0

The Docker role has been tested through repeated execution of:

ansible-playbook playbooks/bootstrap.yml --ask-become-pass
Runtime Validation

Docker was validated directly on the Terraform-managed Ubuntu server.

Docker Engine
docker --version

Validated output included:

Docker version 29.7.2
Docker Compose
docker compose version

Validated output included:

Docker Compose version v5.4.0
Docker Daemon
docker info

This confirmed that the Docker client could communicate successfully with the Docker daemon.

Container Validation

A basic runtime test was performed with the official Docker hello-world image:

docker run --rm hello-world

This validated the complete container flow:

Docker CLI
→ Docker daemon
→ image pull
→ container creation
→ container execution

The --rm option automatically removed the container after execution.

Docker Compose Validation

Docker Compose was validated using a temporary nginx workload.

Example configuration:

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"

The workload was started using:

docker compose up -d

The container status was verified with:

docker compose ps

HTTP connectivity was validated using:

curl http://localhost:8080

The temporary workload was removed afterwards using:

docker compose down
Usage

The role is currently executed from the Ubuntu bootstrap playbook.

Example:

---
- name: Bootstrap Ubuntu servers
  hosts: ubuntu_servers
  become: true


  roles:
    - common
    - security
    - docker

The bootstrap playbook is located at:

playbooks/bootstrap.yml
Validation Pipeline

Docker role changes are validated before they can be merged into main.

The current workflow includes:

local validation
→ Ansible syntax validation
→ ansible-lint
→ pull request
→ GitHub Actions
→ required CI checks
→ automatic squash merge
→ post-merge cleanup

This provides both local and remote quality gates.

Design Principles

The role follows these principles:

install Docker from the official repository
use modern Ansible modules
avoid deprecated repository configuration methods
keep configuration declarative
keep packages configurable through defaults
keep user access configurable
ensure services are enabled through Ansible
maintain idempotency
validate functionality after deployment
avoid unnecessary manual installation steps
Future Improvements

Potential future improvements include:

Docker daemon configuration through /etc/docker/daemon.json
log rotation configuration
resource limits
daemon metrics
centralized container logging
automated health checks
container security scanning
rootless Docker evaluation
dedicated Docker host role
reusable Compose application deployment role
integration with CI pipelines
migration toward Kubernetes workloads

The Docker role currently provides the container runtime foundation for the next phases of the Barou Platform homelab.
