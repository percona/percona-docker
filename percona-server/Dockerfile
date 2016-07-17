FROM centos:7
MAINTAINER Percona Development <info@percona.com>

RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona

RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum install -y which Percona-Server-server-57 Percona-Server-client-57 Percona-Server-tokudb-57

VOLUME /var/lib/mysql

COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
CMD [""]
