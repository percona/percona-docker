FROM centos:7
MAINTAINER Percona Development <info@percona.com>

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
        && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
        && gpg --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona \
        && rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 \
        && curl -L -o /tmp/percona-release.rpm http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm \
        && rpmkeys --checksig /tmp/percona-release.rpm \
        && yum install -y /tmp/percona-release.rpm \
        && rm -rf "$GNUPGHOME" /tmp/percona-release.rpm
                                                                                                               
# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" mongodb

ENV PERCONA_MAJOR 36
ENV PERCONA_VERSION 3.6.8-2.0.el7
ENV K8S_TOOLS_VERSION 0.4.1

RUN yum install -y \
                Percona-Server-MongoDB-36-server-${PERCONA_VERSION} \
                curl \
                jq \
        && yum clean all \
        && rm -rf /var/cache/yum /data/db  && mkdir -p /data/db \
        && chown -R 1001:0 /data/db


RUN curl -fSL https://github.com/percona/mongodb-orchestration-tools/releases/download/${K8S_TOOLS_VERSION}/k8s-mongodb-initiator -o /usr/local/bin/k8s-mongodb-initiator \
    && curl -fSL  https://github.com/percona/mongodb-orchestration-tools/releases/download/${K8S_TOOLS_VERSION}/mongodb-healthcheck -o /usr/local/bin/mongodb-healthcheck \
    && chmod 0755 /usr/local/bin/k8s-mongodb-initiator /usr/local/bin/mongodb-healthcheck

VOLUME ["/data/db"]


COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]


EXPOSE 27017

USER 1001

CMD ["mongod"]
