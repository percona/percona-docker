# Community PostgreSQL Container Images

Community builds of Percona PostgreSQL container images using upstream
[PGDG](https://www.postgresql.org/download/linux/redhat/) packages instead of
Percona distribution packages.

## Purpose

The Percona PostgreSQL Operator requires a specific set of tools (pgBackRest,
pgBouncer, pgAudit, Patroni, etc.) in the container images. All of these are
available from upstream PGDG repositories. These Dockerfiles demonstrate that
the operator can work without Percona's own distribution packages.

---

## Images

### UBI9 / EL9 (default)

| Make target   | Image tag suffix                    | Description                          |
|---------------|-------------------------------------|--------------------------------------|
| `postgres18`  | `{TAG}-postgres18-community`        | PostgreSQL 18 + extensions           |
| `postgres17`  | `{TAG}-postgres17-community`        | PostgreSQL 17 + extensions           |
| `postgres16`  | `{TAG}-postgres16-community`        | PostgreSQL 16 + extensions           |
| `postgres15`  | `{TAG}-postgres15-community`        | PostgreSQL 15 + extensions           |
| `postgres14`  | `{TAG}-postgres14-community`        | PostgreSQL 14 + extensions           |
| `pgbackrest`  | `{TAG}-pgbackrest-community`        | pgBackRest backup tool               |
| `pgbouncer`   | `{TAG}-pgbouncer-community`         | pgBouncer connection pooler          |
| `upgrade`     | `{TAG}-upgrade-community`           | pg_upgrade image (PG 14–17 → 18)    |

### UBI8 / EL8

| Make target        | Image tag suffix                   | Description                     |
|--------------------|------------------------------------|---------------------------------|
| `postgres18-ubi8`  | `{TAG}-postgres18-community`       | PostgreSQL 18 (EL8)             |
| `postgres17-ubi8`  | `{TAG}-postgres17-community`       | PostgreSQL 17 (EL8)             |
| `postgres16-ubi8`  | `{TAG}-postgres16-community`       | PostgreSQL 16 (EL8)             |
| `postgres15-ubi8`  | `{TAG}-postgres15-community`       | PostgreSQL 15 (EL8)             |
| `postgres14-ubi8`  | `{TAG}-postgres14-community`       | PostgreSQL 14 (EL8)             |
| `upgrade-ubi8`     | `{TAG}-upgrade-community`          | pg_upgrade image (EL8)          |

> pgBackRest and pgBouncer have no UBI8 variant (no upstream `Dockerfile-ubi8`).

---

## Build options (Makefile variables)

| Variable           | Default                                    | Description                                                                      |
|--------------------|--------------------------------------------|----------------------------------------------------------------------------------|
| `REGISTRY`         | `perconalab/percona-postgresql-operator`   | Image registry and repository                                                    |
| `TAG`              | `main`                                     | Image tag prefix; full tag is `{TAG}-{image}-community`                          |
| `PLATFORMS`        | `linux/amd64,linux/arm64`                  | Target architectures for multi-platform build                                    |
| `OUTPUT`           | `--push`                                   | `--push` to push to registry, `--load` to load into local Docker (single arch only) |
| `TIMESCALEDB_MAJOR`| `2`                                        | TimescaleDB major version to install                                             |
| `PG_MAJOR`         | `18`                                       | Primary PG version for the upgrade image (the "new" version to upgrade to)       |
| `IMAGE`            | *(empty)*                                  | Fully custom image name for single-target builds; overrides `REGISTRY`/`TAG`/suffix entirely |

---

## How to build

### Prerequisites

Requires `docker buildx` with a multi-platform builder:

```bash
docker buildx create --use --name multiarch
```

### Build all images (UBI9)

```bash
# Build and push all UBI9 images with default tag
make all

# Build and push all UBI8 images
make all-ubi8 TAG=main-ubi8
```

### Build a single image

```bash
make postgres17
make pgbackrest
make pgbouncer
make upgrade
make postgres17-ubi8
```

### Custom registry and tag

```bash
# Custom tag → perconalab/percona-postgresql-operator:1.25.1-1-postgres17-community
make all TAG=1.25.1-1

# Custom registry → myrepo/pg:main-postgres17-community
make all REGISTRY=myrepo/pg

# Both
make all REGISTRY=myrepo/pg TAG=1.25.1-1
```

### Fully custom image name (skip registry/tag/suffix convention)

Use `IMAGE=` to name the image exactly as you want for a single target:

```bash
make pgbackrest IMAGE=docker.io/myorg/percona-pgbackrest:2.58.0-1
make postgres17  IMAGE=myrepo/pg17:1.25.0
make upgrade     IMAGE=myrepo/pg-upgrade:1.25.0 PG_MAJOR=17
make postgres17-ubi8 IMAGE=myrepo/pg17-ubi8:1.25.0
```

> `IMAGE=` has no effect on `make all` or `make all-ubi8`.

### Single architecture

```bash
# Build and push amd64 only
make all PLATFORMS=linux/amd64

# Build and load into local Docker (does not push)
make postgres17 PLATFORMS=linux/amd64 OUTPUT=--load
```

### TimescaleDB version

```bash
# Use TimescaleDB 3 instead of the default 2
make all TIMESCALEDB_MAJOR=3
```

### Upgrade image — select primary PG version

```bash
# Build upgrade image for PG 17 as the target version
make upgrade PG_MAJOR=17

# UBI8 upgrade image for PG 16
make upgrade-ubi8 PG_MAJOR=16
```

---

## Community additions

The postgres images include extensions that are **not** in the official Percona
distribution. They are installed from upstream third-party repositories:

| Extension    | Source repository                                              | Package name                                  |
|--------------|----------------------------------------------------------------|-----------------------------------------------|
| TimescaleDB  | `packagecloud.io/timescale/timescaledb/el/{EL_VER}/`          | `timescaledb-2-postgresql-{version}`          |
| Citus        | `repos.citusdata.com/community/el/{EL_VER}/`                  | `citus_{version}`                             |

> **Citus is not included in the upgrade image** — it is incompatible with
> `pg_upgrade`. TimescaleDB is included in both postgres and upgrade images.
>
> Package availability varies by PG version and EL version. If a package is
> not yet available for a particular combination, it is skipped gracefully
> (`|| true`).

---

## Package mapping

Percona packages are mapped to their upstream PGDG equivalents:

| Percona (official)                  | PGDG upstream (community)        |
|-------------------------------------|----------------------------------|
| `percona-postgresql{N}-server`      | `postgresql{N}-server`           |
| `percona-postgresql{N}-contrib`     | `postgresql{N}-contrib`          |
| `percona-postgresql{N}-libs`        | `postgresql{N}-libs`             |
| `percona-pgvector_{N}`              | `pgvector_{N}`                   |
| `percona-pgaudit{N}`                | `pgaudit_{N}` (PG ≥ 16)         |
| `percona-pgaudit14`                 | `pgaudit16_14` (PG 14 only)      |
| `percona-pgaudit15`                 | `pgaudit17_15` (PG 15 only)      |
| `percona-pgaudit{N}_set_user`       | `set_user_{N}`                   |
| `percona-pg_repack{N}`              | `pg_repack_{N}`                  |
| `percona-pg_cron_{N}`               | `pg_cron_{N}`                    |
| `percona-wal2json{N}`               | `wal2json_{N}`                   |
| `percona-pgbackrest`                | `pgbackrest`                     |
| `percona-pgbouncer`                 | `pgbouncer`                      |
| `percona-patroni`                   | `patroni`                        |

### Packages not included

| Percona package                    | Reason omitted                                              |
|------------------------------------|-------------------------------------------------------------|
| `percona-pg_tde{N}`                | Percona-only: Transparent Data Encryption                   |
| `percona-pg_oidc_validator{N}`     | Percona-only: OIDC authentication extension                 |
| `percona-pg_stat_monitor{N}`       | Percona-only: available separately if needed                |
| `percona-postgresql-common`        | Percona-only: packaging metadata                            |
| `percona-telemetry-agent`          | Percona-only: telemetry                                     |
| `postgresql{N}-llvmjit`            | Requires LLVM 20.1, not available in UBI9/UBI8 repos        |
| `pgvector_{N}-llvmjit`             | Same                                                        |
| `postgis35_{N}`                    | Requires `libqhull_r` from Oracle Linux extras              |

---

## Keeping Dockerfiles up to date

The Dockerfiles in `build/` are generated — do not edit them directly.
`sync.sh` tracks the SHA256 of each official source Dockerfile and regenerates
the community versions when sources change.

```bash
# Dry run — show what would change
./sync.sh

# Apply changes
./sync.sh --apply

# Force regeneration even if source is unchanged
./sync.sh --force --apply
```

### Run unit tests

```bash
make test
# or
python3 -m pytest tests/ -v
```

---

## How it works

`transform.py` converts an official Percona Dockerfile into a community build:

1. **Repo setup** — replaces the Percona repository RPM block with a dynamic
   PGDG + EPEL setup that detects the OS version at build time (`EL_VER` from
   `/etc/os-release`), supporting both EL8 and EL9 from the same Dockerfile.
2. **Package renaming** — maps `percona-*` package names to PGDG equivalents.
3. **Package removal** — drops Percona-only packages (pg_tde, pg_oidc_validator,
   llvmjit, postgis, telemetry-agent).
4. **Oracle Linux cleanup** — removes OracleLinux-specific repo setup blocks,
   the multi-stage downloader stage, and replaces `oraclelinux:9/8` with
   `almalinux:9/8`.
5. **Base image parameterisation** — replaces `FROM redhat/ubi9-minimal` with
   `ARG BASE_IMAGE=redhat/ubi9-minimal` / `FROM ${BASE_IMAGE}`.
6. **Community extensions injection** — adds TimescaleDB and Citus repo setup
   and install blocks (not present in Percona sources).
7. **Upgrade loop replacement** — replaces the Percona multi-version loop
   (PG 12–17) with a PGDG equivalent (PG 14–17, with correct pgaudit naming).
