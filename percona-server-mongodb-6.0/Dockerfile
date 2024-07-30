FROM oraclelinux:8

LABEL org.opencontainers.image.authors="info@percona.com"

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY

ENV PSMDB_VERSION 6.0.16-13
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PSMDB_VERSION.$OS_VER"
ENV K8S_TOOLS_VERSION "0.5.0"
ENV PSMDB_REPO release

# Do not report during Docker image creation.
ARG PERCONA_TELEMETRY_DISABLE=1

RUN set -ex; \
    percona-release enable psmdb-60 ${PSMDB_REPO}; \
    percona-release enable telemetry ${PSMDB_REPO}; \
    dnf config-manager --enable ol8_u4_security_validation; \
    dnf -y update openssh; \
    dnf -y update bind-export-libs; \
    dnf -y update glibc; \
    dnf -y update libgcrypt; \
    dnf -y install \
        percona-server-mongodb-mongos-${FULL_PERCONA_VERSION} \
        percona-server-mongodb-tools-${FULL_PERCONA_VERSION} \
        percona-mongodb-mongosh \
        numactl \
        procps-ng \
        jq \
        tar \
        oniguruma \
        cyrus-sasl-gssapi \
        policycoreutils; \
        \
    curl -Lf -o /tmp/Percona-Server-MongoDB-server.rpm http://repo.percona.com/psmdb-60/yum/${PSMDB_REPO}/8/RPMS/x86_64/percona-server-mongodb-server-${FULL_PERCONA_VERSION}.x86_64.rpm; \
    rpmkeys --checksig /tmp/Percona-Server-MongoDB-server.rpm; \
    rpm -iv /tmp/Percona-Server-MongoDB-server.rpm --nodeps; \
    rm -rf /tmp/Percona-Server-MongoDB-server.rpm; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum /data/db && mkdir -p /data/db; \
    chown -R 1001:0 /data/db

# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -m -s /sbin/nologin \
            -c "Default Application User" mongodb; \
    chmod g+rwx /var/log/mongo; \
    chown :0 /var/log/mongo

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-server-mongodb-server/LICENSE-Community.txt /licenses/LICENSE.Percona-Server-for-MongoDB

ENV GOSU_VERSION=1.11
RUN set -eux; \
    curl -Lf -o /usr/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64; \
    curl -Lf -o /usr/bin/gosu.asc https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64.asc; \
    \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/bin/gosu.asc /usr/bin/gosu; \
    rm -rf "$GNUPGHOME" /usr/bin/gosu.asc; \
    \
    chmod +x /usr/bin/gosu; \
    curl -f -o /licenses/LICENSE.gosu https://raw.githubusercontent.com/tianon/gosu/${GOSU_VERSION}/LICENSE

VOLUME ["/data/db"]

RUN set -ex; \
    curl -fSL https://cdnjs.cloudflare.com/ajax/libs/js-yaml/4.1.0/js-yaml.min.js -o /js-yaml.js; \
    echo "45dc3dd03dc07a06705a2c2989b8c7f709013f04bd5386e3279d4e447f07ebd7  /js-yaml.js" | sha256sum -c -

ADD https://raw.githubusercontent.com/Percona-Lab/telemetry-agent/phase-0/call-home.sh /call-home.sh
RUN chmod a+rx call-home.sh
RUN mkdir -p /usr/local/percona
RUN chown 1001:1001 /usr/local/percona
ENV CALL_HOME_OPTIONAL_PARAMS=" -s ${OS_VER}"

COPY ps-entry.sh /entrypoint.sh
COPY telemetry-agent-supervisor.sh /usr/bin/
RUN set -ex; \
    chown  mongodb /usr/bin/telemetry-agent-supervisor.sh; \
    chown  mongodb /usr/bin/percona-telemetry-agent; \
    chown  mongodb /usr/local/percona/telemetry/history; \
    chown  mongodb:percona-telemetry /usr/local/percona/telemetry/psmdb; \
    chown  mongodb:percona-telemetry /usr/local/percona/telemetry/psmdbs; \
    chmod ug+rwx /usr/bin/telemetry-agent-supervisor.sh; \
    chmod -R go+w /var/log/percona
ENV PERCONA_TELEMETRY_CHECK_INTERVAL=86400
ENV PERCONA_TELEMETRY_HISTORY_KEEP_INTERVAL=604800
ENV PERCONA_TELEMETRY_RESEND_INTERVAL=60
ENV PERCONA_TELEMETRY_URL=https://check.percona.com/v1/telemetry/GenericReport

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 27017

USER 1001

CMD ["mongod"]
