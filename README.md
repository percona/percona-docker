![logo](https://www.percona.com/blog/wp-content/uploads/2014/05/percona_server.jpeg)

# What is Percona Server?

Percona Server is an enhanced drop-in replacement for MySQL. With Percona Server, Your queries will run faster and more consistently. You will consolidate servers on powerful hardware. You will delay sharding, or avoid it entirely.

For more information and related downloads for Percona Server and other Percona products, please visit http://www.percona.com.

# Percona Server Docker Images

These are the only official Percona Server Docker images, created and maintained by the Percona team. The available versions are:

    Percona Server 5.5 (tag: 5.5)
    Percona Server 5.6 (tag: 5.6)

Images are updated when new releases are published.

# How to Use the Images

## Start a Percona Server Instance

Start a Percona Server container as follows:

    docker run --name container-name -e MYSQL_ROOT_PASSWORD=secret -d percona/percona-server:tag

Where `container-name` is the name you want to assign to your container, `secret` is the password to be set for the root user and `tag` is the tag specifying the version you want. See the list above for relevant tags, or look at the [full list of tags](https://registry.hub.docker.com/u/percona/percona-server/tags/manage/).

## Connect to Percona Server from an Application in Another Docker Container

This image exposes the standard MySQL port (3306), so container linking makes the instance available to other containers. Start other containers like this in order to link it to the Percona Server container:

    docker run --name app-container-name --link container-name -d app-that-uses-mysql

## Connect to Percona Server from the MySQL Command Line Client

The following command starts another container instance and runs the `mysql` command line client against your original container, allowing you to execute SQL statements against your database:

    docker run -it --link container-name --rm percona/percona-server:tag mysql -h container-name -P 3306 -uroot -psecret'

... where `container-name` is the name of your database container.

# Environment Variables

When you start a Percona Server container, you can adjust the configuration of the instance by passing one or more environment variables on the `docker run` command line. Do note that none of the variables below will have any effect if you start the container with a data directory that already contains a database: any pre-existing database will always be left untouched on container startup.

Most of the variables listed below are optional, but one of the variables `MYSQL_ROOT_PASSWORD`, `MYSQL_ALLOW_EMPTY_PASSWORD`, `MYSQL_RANDOM_ROOT_PASSWORD` must be given.

## `MYSQL_ROOT_PASSWORD`

This variable specifies a password that will be set for the root superuser account. In the above example, it was set to `secret`. **NOTE:** Setting the MySQL root user password on the command line is insecure.

## `MYSQL_RANDOM_ROOT_PASSWORD`

When this variable is set to `yes`, a random password for the server's root user will be generated. The password will be printed to stdout in the container, and it can be obtained by using the command `docker logs container-name`.

## `MYSQL_ONETIME_PASSWORD`

This variable is optional. When set to `yes`, the root user's password will be set as expired, and must be changed before we can login normally. This is only supported by version 5.6 or newer.

## `MYSQL_DATABASE`

This variable is optional. It allows you to specify the name of a database to be created on image startup. If a user/password was supplied (see below) then that user will be granted superuser access (corresponding to GRANT ALL) to this database.

## `MYSQL_USER`, `MYSQL_PASSWORD`

These variables are optional, used in conjunction to create a new user and set that user's password. This user will be granted superuser permissions (see above) for the database specified by the `MYSQL_DATABASE` variable. Both variables are required for a user to be created.

Do note that there is no need to use this mechanism to create the `root` superuser, that user gets created by default with the password set by either of the mechanisms (given or generated) discussed above.

## `MYSQL_ALLOW_EMPTY_PASSWORD`

Set to `yes` to allow the container to be started with a blank password for the root user. **NOTE:** Setting this variable to `yes` is not recommended unless you really know what you are doing, since this will leave your instance completely unprotected, allowing anyone to gain complete superuser access.

# Notes, Tips, Gotchas

## Secure Container Startup

In many use cases, employing the `MYSQL_ROOT_PASSWORD` variable to specify the MySQL root user password on initial container startup is insecure. Instead, to keep your setup as secure as possible, we strongly recommend using the `MYSQL_RANDOM_ROOT_PASSWORD` option. To further secure your instance, we also recommend using the `MYSQL_ONETIME_PASSWORD` variable if you use version 5.6 or higher.

This is the full procedure:

    docker run --name container-name -e MYSQL_RANDOM_ROOT_PASSWORD=yes -e MYSQL_ONETIME_PASSWORD=yes -d percona/percona-server:tag
    docker logs container-name

Look for the "GENERATED ROOT PASSWORD" line in the output.

Start the MySQL command line client and log in using the randomly set root password:

    mysql -u root -p

And finally, on the mysql client command line, set a new, secure root password for MySQL:

    ALTER USER root IDENTIFIED BY 'my-secret-pw';

## Where to Store Data

There are basically two ways to store data used by applications that run in Docker containers. We encourage users of MySQL with Docker to familiarize themselves with the options available, including:

* Let Docker manage the storage of your database data by writing the database files to disk on the host system using its own internal volume management. This is the default and is easy and fairly transparent to the user. The downside is that the files may be hard to locate for tools and applications that run directly on the host system, i.e. outside containers.
* Create a data directory on the host system (outside the container) and mount this to a directory visible from inside the container. This places the database files in a known location on the host system, and makes it easy for tools and applications on the host system to access the files. The downside is that the user needs to make sure that the directory exists, and that e.g. directory permissions and other security mechanisms on the host system are set up correctly.

The Docker documentation is a good starting point for understanding the different storage options and variations, and there are multiple blog and forum postings that discuss and give advice in this area. We will simply show the basic procedure here for the latter option above:

1. Create a data directory on a suitable volume on your host system, e.g. `/local/datadir`.
2. Start your container like this:

```
    docker run --name container-name -v /local/datadir:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=secret -d percona/percona-server:tag
```

The `-v /local/datadir:/var/lib/mysql` part of the command mounts the `/local/datadir` directory from the underlying host system as `/var/lib/mysql` inside the container, where MySQL by default will write its data files.

Note that users on systems with SELinux enabled may experience problems with this. The current workaround is to assign the relevant SELinux policy type to the new data directory so that the container will be allowed to access it:

    chcon -Rt svirt_sandbox_file_t /local/datadir

## Usage Against an Existing Database

If you start your MySQL container instance with a data directory that already contains a database (specifically, a `mysql` subdirectory), the `$MYSQL_ROOT_PASSWORD` variable should be omitted from the `docker run` command line; it will in any case be ignored, and the pre-existing database will not be changed in any way.

## Port forwarding

Docker allows mapping of ports on the container to ports on the host system by using the -p option. If you start the container as follows, you can connect to the database by connecting your client to a port on the host machine, in this example port 6603:

    docker run --name container-name -p 6603:3306 -d percona/percona-server
    mysql -h 127.0.0.1 -P 6603

## Passing options to the server

You can pass arbitrary command line options to the MySQL server by appending them to the `run command`:

    docker run --name my-container-name -d percona/percona-server --option1=value --option2=value

In this case, the values of option1 and option2 will be passed directly to the server when it is started. The following command will for instance start your container with UTF-8 as the default setting for character set and collation for all databases in MySQL:

    docker run --name container-name -d  percona/percona-server --character-set-server=utf8 --collation-server=utf8_general_ci

## Using a Custom MySQL Config File

The MySQL startup configuration in these Docker images is specified in the file `/etc/my.cnf`. If you want to customize this configuration for your own purposes, you can create your alternative configuration file in a directory on the host machine and then mount this file in the appropriate location inside the MySQL container, effectively replacing the standard configuration file.

If you want to base your changes on the standard configuration file, start your MySQL container in the standard way described above, then do:

    docker exec -it my-container-name cat /etc/my.cnf > /my/custom/config-file

... where ´/local/config-file´ is the path and name of the new configuration file. Then start a new MySQL container like this:

    docker run --name my-new-container-name -v /my/custom/config-file:/etc/my.cnf -e MYSQL_ROOT_PASSWORD=secret -d mysql/mysql-server:tag

This will start a new MySQL container ´my-new-container-name´ where the MySQL instance uses the startup options specified in ´/my/custom/config-file´.

Note that users on systems where SELinux is enabled may experience problems with this. The current workaround is to assign the relevant SELinux policy type to your new config file so that the container will be allowed to mount it:

    chcon -Rt svirt_sandbox_file_t /my/custom/config-file

## Docker Optimized MySQL Install

These Docker images are optimized for size, which means that we have reduced the contents to what is expected to be relevant for a large majority of users who run Docker based MySQL instances. The key differences compared to a default MySQL install are:

* All binaries are stripped, non-debug only
* Included binaries are limited to:

```
    /usr/bin/my_print_defaults
    /usr/bin/mysql
    /usr/bin/mysql_config
    /usr/bin/mysql_install_db
    /usr/bin/mysql_tzinfo_to_sql
    /usr/bin/mysql_upgrade
    /usr/bin/mysqldump
    /usr/sbin/mysqld
```

# Supported Docker Versions

These images are officially supported by the MySQL team on Docker version 1.9. Support for older versions (down to 1.0) is provided on a best-effort basis, but we strongly recommend running on the most recent version, since that is assumed for parts of the documentation above.

# User Feedback

We welcome your feedback! For general comments or discussion, please drop us a line in the Comments section below. For bugs and issues, please submit a bug report at http://bugs.mysql.com under the category "MySQL Package Repos and Docker Images".
