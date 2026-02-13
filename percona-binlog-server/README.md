# What is Percona Binlog Server?
binlog_server is a command line utility that can be considered as an enhanced version of mysqlbinlog in --read-from-remote-server mode which serves as a replication client and can stream binary log events from a remote Oracle MySQL Server / Percona Server for MySQL both to a local filesystem and to a cloud storage (currently to AWS S3 or S3-compatible service like MinIO). It is capable of automatically reconnecting to the remote server and resume operation from the point when it was previously stopped / terminated.

It is written in portable c++ following the c++20 standard best practices.

# Product Documentation

https://docs.percona.com/percona-binlog-server/

# Percona Binlog Server 

Source code: [https://github.com/percona-lab/percona-binlog-server](https://github.com/percona-lab/percona-binlog-server)

These are the only official Percona Binlog Server Docker images, created and maintained by the Percona team. Images are updated when new releases are published.

You can see available versions in the [full list of tags](https://hub.docker.com/r/perconalab/percona-binlog-server/tags)

# How to Use the Images

Specify network and options:

    docker run [--network=<NETWORK>] perconalab/percona-binlog-server binlog_server <OPTIONS>

