FROM centos:7
MAINTAINER Percona Development <info@percona.com>


RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona

RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum install -y which nc perl-Digest-MD5 percona-xtrabackup-24 Percona-Server-server-57 Percona-Server-client-57 Percona-Server-shared-57 Percona-Server-tokudb-57

# Install server

ADD my.cnf /etc/my.cnf
VOLUME /var/lib/mysql
VOLUME /var/log/mysql

COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

COPY master_nc /usr/bin/master_nc
RUN chmod a+x /usr/bin/master_nc

EXPOSE 3306
CMD [""]
