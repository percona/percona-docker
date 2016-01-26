FROM centos:centos7
MAINTAINER Percona Development <info@percona.com>


RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona

ARG PS_VERSION
ENV PS_VERSION ${PS_VERSION:-5.6.28}

RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum install -y which Percona-Server-server-56-${PS_VERSION} Percona-Server-client-56-${PS_VERSION} Percona-Server-shared-56-${PS_VERSION} Percona-Server-tokudb-56-${PS_VERSION}

# Install server

RUN mkdir /docker-entrypoint-initdb.d

VOLUME /var/lib/mysql

COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
CMD [""]
