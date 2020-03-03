FROM centos:7

LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="Percona Server for MongoDB"
LABEL org.label-schema.vendor="Percona"
LABEL org.label-schema.description="Percona Server for MongoDB is our free and \
open-source drop-in replacement for MongoDB Community Edition. \
It offers all the features and benefits of MongoDB Community Edition, \
plus additional enterprise-grade functionality."
LABEL org.label-schema.license="SSPLv1"

LABEL org.opencontainers.image.title="Percona Server for MongoDB"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="Percona Server for MongoDB is our free and \
open-source drop-in replacement for MongoDB Community Edition. \
It offers all the features and benefits of MongoDB Community Edition, \
plus additional enterprise-grade functionality."
LABEL org.opencontainers.image.license="SSPLv1"
LABEL org.opencontainers.image.authors="info@percona.com"

ENV PSMDB_VERSION 3.6.17-4.0
LABEL org.label-schema.schema-version=${PSMDB_VERSION}
LABEL org.opencontainers.image.version=${PSMDB_VERSION}

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A; \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys 6341AB2753D78A78A7C27BB124C6A8A7F4A80EB5; \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys 91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5; \
    \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 6341AB2753D78A78A7C27BB124C6A8A7F4A80EB5 > ${GNUPGHOME}/RPM-GPG-KEY-CentOS-7; \
    gpg --batch --export --armor 91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-7; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-CentOS-7 ${GNUPGHOME}/RPM-GPG-KEY-EPEL-7; \
    \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY

# install exact version for repeatability
ENV OS_VER el7
ENV FULL_PERCONA_VERSION "$PSMDB_VERSION.$OS_VER"
ENV K8S_TOOLS_VERSION "0.5.0"

RUN set -ex; \
    curl -Lf -o /tmp/jq.rpm https://download.fedoraproject.org/pub/epel/7/x86_64/Packages/j/jq-1.6-1.el7.x86_64.rpm; \
    curl -Lf -o /tmp/oniguruma.rpm https://download.fedoraproject.org/pub/epel/7/x86_64/Packages/o/oniguruma-5.9.5-3.el7.x86_64.rpm; \
    rpmkeys --checksig /tmp/jq.rpm /tmp/oniguruma.rpm; \
    \
    rpm -i /tmp/jq.rpm /tmp/oniguruma.rpm; \
    rm -rf /tmp/jq.rpm /tmp/oniguruma.rpm

RUN set -ex; \
    sed -i '/nodocs/d' /etc/yum.conf || :; \
    yum install -y \
        yum-utils \
        shadow-utils \
        curl \
        procps-ng \
        Percona-Server-MongoDB-36-shell-${FULL_PERCONA_VERSION} \
        Percona-Server-MongoDB-36-mongos-${FULL_PERCONA_VERSION}; \
        repoquery -a --location \
            policycoreutils \
                | xargs curl -Lf -o /tmp/policycoreutils.rpm; \
        repoquery -a --location \
            Percona-Server-MongoDB-36-server-${FULL_PERCONA_VERSION} \
                | xargs curl -Lf -o /tmp/Percona-Server-MongoDB-36-server-${FULL_PERCONA_VERSION}.rpm; \
        rpm -iv /tmp/policycoreutils.rpm /tmp/Percona-Server-MongoDB-36-server-${FULL_PERCONA_VERSION}.rpm --nodeps; \
        \
        rm -rf /tmp/policycoreutils.rpm /tmp/Percona-Server-MongoDB-36-server-${FULL_PERCONA_VERSION}.rpm; \
        yum clean all; \
        rm -rf /var/cache/yum /data/db && mkdir -p /data/db; \
        chown -R 1001:0 /data/db

# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" mongodb

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/Percona-Server-MongoDB-36-server-$(echo ${FULL_PERCONA_VERSION} | cut -d - -f 1)/LICENSE-Community.txt /licenses/LICENSE.Percona-Server-for-MongoDB

RUN set -ex; \
    curl -fSL https://github.com/percona/mongodb-orchestration-tools/releases/download/${K8S_TOOLS_VERSION}/k8s-mongodb-initiator -o /usr/local/bin/k8s-mongodb-initiator; \
    curl -fSL  https://github.com/percona/mongodb-orchestration-tools/releases/download/${K8S_TOOLS_VERSION}/mongodb-healthcheck -o /usr/local/bin/mongodb-healthcheck; \
    curl -fSL  https://github.com/percona/mongodb-orchestration-tools/releases/download/${K8S_TOOLS_VERSION}/SHA256SUMS -o /tmp/SHA256SUMS; \
    echo "$(grep 'k8s-mongodb-initiator' /tmp/SHA256SUMS | awk '{print $1}')" /usr/local/bin/k8s-mongodb-initiator | sha256sum -c -; \
    echo "$(grep 'mongodb-healthcheck' /tmp/SHA256SUMS   | awk '{print $1}')" /usr/local/bin/mongodb-healthcheck   | sha256sum -c -; \
    rm -f /tmp/SHA256SUMS; \
    \
    chmod 0755 /usr/local/bin/k8s-mongodb-initiator /usr/local/bin/mongodb-healthcheck

VOLUME ["/data/db"]

COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 27017

USER 1001

CMD ["mongod"]
