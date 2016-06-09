![logo](https://www.percona.com/sites/all/themes/percona2015/images/product-logos/server-mongoDB-big.png)

# What is Percona Server for MongoDB?

Percona Server for MongoDB® is a free, enhanced, fully compatible, open source, drop-in replacement for the MongoDB® Community Edition that includes enterprise-grade features and functionality.

For more information and related downloads for Percona Server and other Percona products, please visit http://www.percona.com.

# Percona Server for MongoDB Docker Images

These are the only official Percona Server for MongoDB Docker images, created and maintained by the Percona team. The image has the Percona Fractal Tree based storage engine `PerconaFT`, `RocksDB` and `WiredTiger` enabled. The available versions are:

    Percona Server for MontoDB 3.0.8 (tag: 3.0)

Images are updated when new releases are published.

# How to Use the Images

## Start a Percona Server for MongoDB Instance

Start a Percona Server for MongoDB container as follows:

    docker run --name container-name  -d percona/percona-server-mongodb:tag

Where `container-name` is the name you want to assign to your container and `tag` is the tag specifying the version you want. See the list above for relevant tags, or look at the [full list of tags](https://hub.docker.com/r/percona/percona-server-mongodb/tags/).

## Connect to Percona Server from an Application in Another Docker Container

This image exposes the standard MongoDB port (27017), so container linking makes the instance available to other containers. Start other containers like this in order to link it to the Percona Server for MongoDB container:

    docker run --name app-container-name --link container-name -d app-that-uses-mongodb

## Connect to Percona Server for MongoDB from the MongoDB Command Line Client

The following command starts another container instance and runs the `mongo` command line client against your original container, allowing you to execute SQL statements against your database:

    docker run -it --link container-name --rm percona/percona-server-mongodb:tag mongo -h container-name

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
    docker run --name container-name -v /local/datadir:/data/db -d percona/percona-server-mongodb:tag
```

The `-v /local/datadir:/data/db` part of the command mounts the `/local/datadir` directory from the underlying host system as `/data/db` inside the container, where MongoDB by default will write its data files.

## Port forwarding

Docker allows mapping of ports on the container to ports on the host system by using the -p option. If you start the container as follows, you can connect to the database by connecting your client to a port on the host machine. This can greatly simplfy consolidating many instances to a single host. In this example port 6603, the we use the address of the Docker host to connect to the TCP port the Docker deamon is forwarding from:

    docker run --name container-name `-p 6603:3306` -d percona/percona-server-mongodb
    mongo docker_host_ip:6603

## Passing options to the server

You can pass arbitrary command line options to the MySQL server by appending them to the `run command`:

    docker run --name my-container-name -d percona/percona-server-mongodb --option1=value --option2=value

In this case, the values of option1 and option2 will be passed directly to the server when it is started. The following command will for instance start your container with RocksDB storage engine:

    docker run --name container-name -d  percona/percona-server-mongodb --storageEngine=RocksDB

# Supported Docker Versions

These images are officially supported by the MySQL team on Docker version 1.9. Support for older versions (down to 1.0) is provided on a best-effort basis, but we strongly recommend running on the most recent version, since that is assumed for parts of the documentation above.

# User Feedback

We welcome your feedback!
