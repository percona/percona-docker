FROM redhat/ubi9-minimal

# Please don't remove old-style LABEL since it's needed for RedHat certification
LABEL name="Percona Search for MongoDB" \
    maintainer="Percona Development <info@percona.com>" \
    vendor="Percona" \
    summary="Percona Search for MongoDB (mongot)" \
    description="Percona Search for MongoDB is the Percona-supported distribution of \
    MongoDB Search (mongot). It provides Full Text and Vector Search capabilities for \
    MongoDB and is intended to run alongside Percona Server for MongoDB to serve \
    search queries and manage search indexes." \
    org.opencontainers.image.authors="info@percona.com"

LABEL org.opencontainers.image.title="Percona Search for MongoDB" \
    org.opencontainers.image.vendor="Percona" \
    org.opencontainers.image.description="Percona Search for MongoDB is the Percona-supported \
    distribution of MongoDB Search (mongot). It provides Full Text and Vector Search capabilities \
    for MongoDB and is intended to run alongside Percona Server for MongoDB." \
    org.opencontainers.image.authors="info@percona.com" \
    org.opencontainers.image.licenses="SSPL-1.0" \
    org.opencontainers.image.url="https://www.percona.com/software/mongodb/percona-search-for-mongodb" \
    org.opencontainers.image.documentation="https://github.com/percona/percona-mongot/blob/main/percona-packaging/PACKAGING.md" \
    org.opencontainers.image.source="https://github.com/percona/percona-mongot"

# Supply-chain provenance: stamp the exact source revision and build
# timestamp into the image so it can be mapped back to the code it was
# built from (SBOM / vulnerability management / attestation flows).
# These are ARG (not ENV) so they end up in the image manifest labels
# only — they don't leak into the runtime environment.
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.created="$BUILD_DATE"

ENV MONGOT_VERSION=0.50.0-1
ENV MONGOT_REPO_CH=release
ENV PSMDB_REPO=psmdb-83
ENV OS_VER=el9
ENV FULL_MONGOT_VERSION="$MONGOT_VERSION.$OS_VER"
LABEL org.opencontainers.image.version="$MONGOT_VERSION"

# Check repository package signature in secure way.
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-9; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-EPEL-9; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable ${PSMDB_REPO} ${MONGOT_REPO_CH}

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install \
        vim-minimal \
        jq \
        oniguruma; \
    microdnf -y install \
        percona-server-mongodb-mongot-${FULL_MONGOT_VERSION}; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

# The mongot RPM creates a `mongod` user during install (matching the PSMDB
# convention). For OpenShift compatibility we also add a fixed-UID `mongodb`
# user in group 0 and chown the data/log dirs to that group — OpenShift
# assigns dynamic UIDs but always keeps group 0, so group-writable layout is
# the portable choice.
RUN set -ex; \
    useradd -u 1001 -r -g 0 -m -s /sbin/nologin \
            -c "Default Application User" mongodb; \
    # The RPM %post chowns /etc/mongot to root:mongod (0750) so that the
    # systemd service (User=mongod) can read it. In the container we run
    # as UID 1001 with primary group 0 (OpenShift convention) and never
    # join the `mongod` supplementary group, so `chmod g+rX` on a
    # mongod-owned dir buys us nothing. Re-chown the entire mongot tree
    # (data, log, config) to 1001:0 to match the container's user model.
    chown -R 1001:0 /var/lib/mongot /var/log/mongot /etc/mongot; \
    chmod -R g+rwX  /var/lib/mongot /var/log/mongot; \
    chmod -R g+rX   /etc/mongot

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/lib/percona-server-mongodb-mongot/LICENSE/LICENSE /licenses/LICENSE.Percona-Search-for-MongoDB

USER 1001

VOLUME ["/var/lib/mongot"]

# 27028 grpc query server, 9946 metrics, 8080 health check (defaults from
# /etc/mongot/mongot.yml; override by mounting your own config).
EXPOSE 27028 9946 8080

# Default config has placeholders for syncSource.replicaSet and a
# passwordFile path — mount /etc/mongot/mongot.yml and the password file
# before starting the container.
CMD ["/usr/bin/mongot", "--config", "/etc/mongot/mongot.yml"]
