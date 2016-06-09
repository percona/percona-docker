FROM centos:7
MAINTAINER Percona Development <info@percona.com>


RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona

#ARG PXC_VERSION
#ENV PXC_VERSION ${PS_VERSION:-5.7.11}

RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum install --enablerepo=percona-testing-x86_64 -y which Percona-XtraDB-Cluster-57 perl-Digest-MD5

ADD node.cnf /etc/my.cnf
VOLUME /var/lib/mysql

COPY pxc-entry.sh /entrypoint.sh
COPY jq /usr/bin/jq
COPY clustercheckcron /usr/bin/clustercheckcron

RUN chmod a+x /usr/bin/jq
RUN chmod a+x /usr/bin/clustercheckcron
 
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 4567 4568
ONBUILD RUN yum update -y

CMD [""]
