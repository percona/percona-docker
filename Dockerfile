FROM centos:centos7
MAINTAINER Percona Development <info@percona.com>

RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona

RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum install -y which Percona-Server-server-56-5.6.28-rel76.1.el7 Percona-Server-tokudb-56-5.6.28-rel76.1.el7

# Install server
RUN mkdir /docker-entrypoint-initdb.d

VOLUME /var/lib/mysql

COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld","--user=mysql"]
