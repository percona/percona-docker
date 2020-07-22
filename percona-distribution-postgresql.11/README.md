# What is Percona Distribution for PostgreSQL?

Percona Distribution for PostgreSQL is the best and most critical enterprise-level components from the open-source community, designed and tested to work together in one single source.

For more information and related downloads for Percona Distribution and other Percona products, please visit http://www.percona.com.

# Percona Distribution for PostgreSQL Docker Images

These are the only official Percona Distribution for PostgreSQL Docker images, created and maintained by the Percona team. The image has the Percona PG-Stat-Monitor plugin enabled

    Percona Distribution for PostgreSQL 11 (tag: 11)

Images are updated when new releases are published.

# How to Use the Images

## Start a Percona Distribution for PostgreSQL Instance

Start a Percona Distribution for PostgreSQL container as follows:

    docker run --name container-name -d perconalab/percona-distribution-postgresql:tag

Where `container-name` is the name you want to assign to your container and `tag` is the tag specifying the version you want. See the list above for relevant tags, or look at the [full list of tags](https://hub.docker.com/r/perconalab/percona-distribution-postgresql/tags/).

## Connect to Percona Distribution for PostgreSQL from an Application in Another Docker Container

This image exposes the standard PostgreSQL port (5432), so container linking makes the instance available to other containers. Start other containers like this in order to link it to the Percona Distribution for PostgreSQL container:

    docker run --name app-container-name --link container-name -d app-that-uses-postgresql

## Connect to Percona Distribution for PostgreSQL from the PSQL Command Line Client

The following command starts another container instance and runs the `psql` command line client against your original container, allowing you to execute SQL statements against your database:

    docker run -it --link container-name --rm perconalab/percona-distribution-postgresql:tag psql -h container-name -U user-name

where `container-name` is the name of your database container.


# Notes, Tips, Gotchas

## Where to Store Data

There are many two ways to store data used by applications that run in Docker containers. We maintain our usual stance and encourage users to investigate the options and use the method that best suits their use case. Here are some of the options available:

* Let Docker manage the storage of your database data by writing the database files to disk on the host system using its own internal volume management. The current solutions, devicemapper, aufs and overlayfs have negative performance records.
* Create a data directory on the host system (outside the container on high performance storage) and mount this to a directory visible from inside the container. This places the database files in a known location on the host system, and makes it easy for tools and applications on the host system to access the files. The user needs to make sure that the directory exists, and that permissions and other security mechanisms on the host system are set up correctly.

The Docker documentation is a good starting point for understanding the different storage options and variations, and there are multiple blog and forum postings that discuss and give advice in this area. We will simply show the basic procedure here for the latter option above:

1. Create a data directory on a suitable volume on your host system, e.g. `/local/datadir`.
2. Start your container like this:

```
    docker run --name container-name -v /local/datadir:/data/db -d perconalab/percona-distribution-postgresql:tag
```

The `-v /local/datadir:/data/db` part of the command mounts the `/local/datadir` directory from the underlying host system as `/data/db` inside the container, where PostgreSQL by default will write its data files.

## Enabling Percona PG-Stat-Monitor extension

After launching container, to enable Percona PG-Stat-Monitor extension, connect to server, select desired database and execute:

```
create extension pg_stat_monitor;
```

To ensure that everything setup correctly, run:

```
\d pg_stat_monitor;
```

You will see following output:

```
                          View "public.pg_stat_monitor"
       Column        |           Type           | Collation | Nullable | Default
---------------------+--------------------------+-----------+----------+---------
 bucket              | integer                  |           |          |
 bucket_start_time   | timestamp with time zone |           |          |
 userid              | oid                      |           |          |
 dbid                | oid                      |           |          |
 queryid             | text                     |           |          |
 query               | text                     |           |          |
 plan_calls          | bigint                   |           |          |
 plan_total_time     | numeric                  |           |          |
 plan_min_timei      | numeric                  |           |          |
 plan_max_time       | numeric                  |           |          |
 plan_mean_time      | numeric                  |           |          |
 plan_stddev_time    | numeric                  |           |          |
 plan_rows           | bigint                   |           |          |
 calls               | bigint                   |           |          |
 total_time          | numeric                  |           |          |
 min_time            | numeric                  |           |          |
 max_time            | numeric                  |           |          |
 mean_time           | numeric                  |           |          |
 stddev_time         | numeric                  |           |          |
 rows                | bigint                   |           |          |
 shared_blks_hit     | bigint                   |           |          |
 shared_blks_read    | bigint                   |           |          |
 shared_blks_dirtied | bigint                   |           |          |
 shared_blks_written | bigint                   |           |          |
 local_blks_hit      | bigint                   |           |          |
 local_blks_read     | bigint                   |           |          |
 local_blks_dirtied  | bigint                   |           |          |
 local_blks_written  | bigint                   |           |          |
 temp_blks_read      | bigint                   |           |          |
 temp_blks_written   | bigint                   |           |          |
 blk_read_time       | double precision         |           |          |
 blk_write_time      | double precision         |           |          |
 host                | bigint                   |           |          |
 client_ip           | inet                     |           |          |
 resp_calls          | text[]                   |           |          |
 cpu_user_time       | double precision         |           |          |
 cpu_sys_time        | double precision         |           |          |
 tables_names        | text[]                   |           |          |
 wait_event          | text                     |           |          |
 wait_event_type     | text                     |           |          |
 ```

## Passing options to the server

You can pass parameters to PostgreSQL server by appending them to the `env`:

    docker run --name my-container-name -e POSTGRES_PASSWORD=root -d perconalab/percona-distribution-postgresql:tag

# User Feedback

We welcome your feedback!
