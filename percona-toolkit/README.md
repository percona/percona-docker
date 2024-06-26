# What is Percona Toolkit?

Percona Toolkit is a collection of advanced command-line tools to perform a variety of MySQL, MongoDB, and system tasks that are too difficult or complex to perform manually.

These tools are ideal alternatives to private or "one-off" scripts, because they are professionally developed, formally tested, and fully documented. They are also fully self-contained, so installation is quick and easy, and no libraries are installed.

Percona Toolkit was derived from Maatkit and Aspersa, two of the best-known toolkits for MySQL server administration. It is developed and supported by Percona. For more information and other free, open-source software developed by Percona, visit http://www.percona.com/software/.

# Product Documentation

[Version 3](https://docs.percona.com/percona-toolkit/)

# Percona Toolkit Docker Images

Source code: [https://github.com/percona/percona-toolkit](https://github.com/percona/percona-toolkit)

These are the only official Percona Server Docker images, created and maintained by the Percona team. Images are updated when new releases are published.

You can see available versions in the [full list of tags](https://hub.docker.com/r/percona/percona-toolkit/tags)

# How to Use the Images

Specify network, tool name, and options:

    docker run [--network=<NETWORK>] percona/percona-toolkit <TOOL NAME> <OPTIONS>

For example, following snippet runs `pt-online-schema-change` on the `host` network with custom options:

    docker run --network="host" percona/percona-toolkit pt-online-schema-change h=127.0.0.1,P=12345,u=msandbox,p=msandbox,D=test,t=t1 --alter='ADD COLUMN f2 INT' --execute
