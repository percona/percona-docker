FROM debian:jessie
MAINTAINER Percona Development <info@percona.com>

RUN groupadd -r mysql && useradd -r -g mysql mysql


RUN apt-get update && apt-get install -y --no-install-recommends \
		apt-transport-https ca-certificates \
		pwgen wget \
	&& rm -rf /var/lib/apt/lists/*

RUN wget https://repo.percona.com/apt/percona-release_0.1-4.jessie_all.deb \
  && dpkg -i percona-release_0.1-4.jessie_all.deb

ENV PERCONA_MAJOR 5.7
ENV PERCONA_VERSION 5.7.16-27.19-1.jessie

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter

ENV DEBIAN_FRONTEND noninteractive

RUN     apt-get update \
	&& apt-get install -y --force-yes \
		percona-xtradb-cluster-57 curl \
	&& rm -rf /var/lib/apt/lists/* \
# comment out any "user" entires in the MySQL config ("docker-entrypoint.sh" or "--user" will handle user switching)
	&& sed -ri 's/^user\s/#&/' /etc/mysql/my.cnf \
# purge and re-create /var/lib/mysql with appropriate ownership
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 777 /var/run/mysqld

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
RUN sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf \
	&& echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf \
	&& mv /tmp/my.cnf /etc/mysql/my.cnf

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

RUN sed -Ei '/log-error/s/^/#/g' -i /etc/mysql/my.cnf

ADD node.cnf /etc/mysql/conf.d/node.cnf

COPY entrypoint.sh /entrypoint.sh
COPY jq /usr/bin/jq
COPY clustercheckcron /usr/bin/clustercheckcron

RUN chmod a+x /usr/bin/jq
RUN chmod a+x /usr/bin/clustercheckcron


EXPOSE 3306 4567 4568

LABEL vendor=Percona
LABEL com.percona.package="Percona XtraDB Cluster"
LABEL com.percona.version="5.7"

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
CMD [""]
