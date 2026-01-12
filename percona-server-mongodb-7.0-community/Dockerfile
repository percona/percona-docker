FROM redhat/ubi9-minimal

LABEL name="MongoDB Community Edition" \
	release="7.0" \
	vendor="MongoDB Inc." \
	summary="MongoDB Community Edition with Percona operator compatibility" \
	description="MongoDB Community Edition configured for use with Percona MongoDB operator" \
	maintainer="Percona Development <info@percona.com>"
LABEL org.opencontainers.image.authors="info@percona.com"

ENV PSMDB_VERSION 7.0.14
ENV OS_VER el9

# Do not report during Docker image creation.
ARG PERCONA_TELEMETRY_DISABLE=1

COPY mongodb.repo /etc/yum.repos.d/mongodb.repo

RUN set -ex; \
    microdnf -y update glibc; \
    microdnf -y update libgcrypt; \
    microdnf -y install \
        mongodb-org-${PSMDB_VERSION} \
        mongodb-org-database-${PSMDB_VERSION} \
        mongodb-org-server-${PSMDB_VERSION} \
        mongodb-mongosh \
        mongodb-org-mongos-${PSMDB_VERSION} \
        mongodb-org-tools-${PSMDB_VERSION} \
        numactl \
        numactl-libs \
        procps-ng \
        jq \
        tar \
        oniguruma \
        cyrus-sasl-gssapi \
        cyrus-sasl-plain \
        policycoreutils; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum /data/db && mkdir -p /data/db; \
    chown -R 1001:0 /data/db

# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -m -s /sbin/nologin \
            -c "Default Application User" mongodb; \
    chmod g+rwx /var/log/mongo; \
    chown :0 /var/log/mongo

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/mongodb-org-server/LICENSE-Community.txt /licenses/LICENSE.MongoDB-Community || \
    echo "MongoDB Community License" > /licenses/LICENSE.MongoDB-Community

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

COPY ps-entry.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 27017

USER 1001

CMD ["mongod"]