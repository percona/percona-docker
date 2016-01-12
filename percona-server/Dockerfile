FROM centos:centos7
MAINTAINER Percona Development <info@percona.com>

#ENV PACKAGE_URL https://repo.mysql.com/yum/mysql-5.6-community/docker/x86_64/mysql-community-server-minimal-5.6.28-2.el7.x86_64.rpm

RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona

RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum install -y which Percona-Server-server-56 Percona-Server-tokudb-56

# Install server

RUN mkdir /docker-entrypoint-initdb.d

VOLUME /var/lib/mysql

COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]
