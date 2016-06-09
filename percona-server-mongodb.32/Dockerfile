FROM centos:centos7
MAINTAINER Percona Development <info@percona.com>

RUN groupadd -r mongodb && useradd -r -g mongodb mongodb

RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona

RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum install -y which Percona-Server-MongoDB-32

# Install server


RUN mkdir -p /data/db && chown -R mongodb:mongodb /data/db

VOLUME /data/db

COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 27017
CMD ["mongod"]
