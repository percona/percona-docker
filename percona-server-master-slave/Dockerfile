FROM debian:jessie
MAINTAINER Percona Development <info@percona.com>

RUN apt-get update && apt-get install -y --no-install-recommends \
		apt-transport-https ca-certificates \
		pwgen netcat wget \
	&& rm -rf /var/lib/apt/lists/*

RUN wget https://repo.percona.com/apt/percona-release_0.1-4.jessie_all.deb \
  && dpkg -i percona-release_0.1-4.jessie_all.deb

# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" mysql

ENV PERCONA_MAJOR 5.7
ENV PERCONA_VERSION 5.7.17-11-1.jessie
ENV DEBIAN_FRONTEND=noninteractive

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter
RUN { \
		echo percona-server-server-$PERCONA_MAJOR percona-server-server/root_password password 'unused'; \
		echo percona-server-server-$PERCONA_MAJOR percona-server-server/root_password_again password 'unused'; \
	} | debconf-set-selections \
	&& apt-get update \
	&& apt-get install -y --force-yes \
		percona-server-server-$PERCONA_MAJOR=$PERCONA_VERSION \
	&& apt-get -q install -y --force-yes percona-xtrabackup-24 \
	&& rm -rf /var/lib/apt/lists/* \
# purge and re-create /var/lib/mysql with appropriate ownership
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R 1001:0 /var/lib/mysql /var/run/mysqld \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 777 /var/run/mysqld

ADD my.cnf /etc/mysql/my.cnf

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

COPY master_nc /usr/bin/master_nc
RUN chmod a+x /usr/bin/master_nc

EXPOSE 3306 4565 4566

USER 1001

CMD [""]
