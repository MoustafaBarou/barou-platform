# Gitea Role


## Purpose


The `gitea` role deploys a self-hosted Gitea platform service using Docker Compose.


The deployment provides an internal Git service for the Barou Platform homelab and forms the source-control layer for the self-hosted CI/CD environment.


## Architecture


The role deploys:


- Gitea
- PostgreSQL
- Docker Compose
- persistent Gitea application data
- Docker-managed PostgreSQL storage
- internal container networking
- HTTP and SSH access
- application and database health checks


## Components


### Gitea


Gitea provides the self-hosted Git platform.


Default ports:


```text
HTTP: 3000
SSH:  2222
PostgreSQL

PostgreSQL provides the database backend for Gitea.

The database is only exposed inside the Docker network and is not published directly to the host network.

Persistent Storage

Gitea application data is stored under:

/opt/gitea/data

PostgreSQL data is stored in the Docker-managed volume:

gitea-postgres-data

This prevents Ansible and PostgreSQL from competing over filesystem ownership and permissions.

Secrets

The PostgreSQL password is not stored in Git.

The deployment expects the following environment variable on the Ansible control node:

GITEA_DB_PASSWORD

It is loaded into the playbook using:

gitea_db_password: "{{ lookup('env', 'GITEA_DB_PASSWORD') }}"

Local secret files must remain outside the repository.

Health Checks

The role validates PostgreSQL availability using:

pg_isready

The Gitea application endpoint is validated with the Ansible uri module.

A successful deployment confirms:

PostgreSQL is ready
Gitea accepts HTTP requests
containers are running
the application stack is operational
Idempotency

The role has been validated through repeated Ansible execution.

Expected result:

changed=0
failed=0
unreachable=0

Validated example:

gitea-01 : ok=7 changed=0 unreachable=0 failed=0
Usage

The role is executed using:

ansible-playbook playbooks/gitea.yml --ask-become-pass

The target host is selected through the gitea_servers inventory group.

Design Principles
infrastructure managed through Terraform
OS baseline managed through Ansible
application deployment managed through Ansible
container runtime provided by Docker
database separated from the application
secrets excluded from Git
persistent storage separated from container lifecycle
health checks included in deployment validation
idempotent configuration management
Future Improvements

Planned improvements include:

TLS termination
reverse proxy
DNS-based access
automated backups
SSO integration
monitoring and alerting
Gitea webhook integration with Jenkins
repository bootstrap automation
