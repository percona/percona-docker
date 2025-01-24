# Building Images

## Supported Percona Distribution for PostgreSQL Software

You can find the latest supported PostgreSQL versions by the latest Operator using the following [link](https://docs.percona.com/percona-operator-for-postgresql/2.0/System-Requirements.html?h=#supported-versions).

More information about Percona Distribution for PostgreSQL Software can be found using this [link](https://www.percona.com/postgresql/software/postgresql-distribution).

## Requirements

To build the images, you need to install the following software packages on your system:

- **[Docker](https://www.docker.com/)**: A platform for developing, shipping, and running applications in containers.

You will also need access to a repository to store the newly created Docker images. In our examples, we will use Percona's experimental repository `perconalab/percona-postgresql-operator`, which requires appropriate access rights for pushing images.

## Building PostgreSQL Image

To build a PostgreSQL image using Percona Distribution for PostgreSQL v16.6:

1. Use the `--build-arg` option with `PG_MAJOR=16.6` to specify the exact version.
2. To build the latest available minor version of PostgreSQL 16, use `PG_MAJOR=16` in `--build-arg`.

Example command:

```bash
docker build --platform x86_64 --no-cache --progress plain \
  --build-arg PG_MAJOR=16.6 \
  --build-arg PGO_TAG=v2.5.0 \
  -t perconalab/percona-postgresql-operator:2.5.0-ppg16.6-postgres \
  -f ./postgresql-containers/build/postgres/Dockerfile ./postgresql-containers/
```

## Building pgBouncer Image

To build a pgBouncer image using Percona Distribution for PostgreSQL v16.6:

1. Set the `--build-arg` option with `PG_MAJOR=16.6` to specify the exact version.
2. Use `PG_MAJOR=16` in `--build-arg` for the latest available minor version of PostgreSQL 16.

Example command:

```bash
docker build --platform x86_64 --no-cache --progress plain \
  --build-arg PG_MAJOR=16.6 \
  --build-arg PGO_TAG=v2.5.0 \
  -t perconalab/percona-postgresql-operator:2.5.0-ppg16.6-pgbouncer1.23.1 \
  -f ./postgresql-containers/build/pgbouncer/Dockerfile ./postgresql-containers/
```

## Building pgBackRest Image

To build a pgBackRest image using Percona Distribution for PostgreSQL v16.6:

1. Set the `--build-arg` option with `PG_MAJOR=16.6` to specify the exact version.
2. Use `PG_MAJOR=16` in `--build-arg` for the latest available minor version of PostgreSQL 16.

Example command:

```bash
docker build --platform x86_64 --no-cache --progress plain \
  --build-arg PG_MAJOR=16.6 \
  --build-arg PGO_TAG=v2.5.0 \
  -t perconalab/percona-postgresql-operator:2.5.0-ppg16.6-pgbackrest2.54-1 \
  -f ./postgresql-containers/build/pgbackrest/Dockerfile ./postgresql-containers/
```
