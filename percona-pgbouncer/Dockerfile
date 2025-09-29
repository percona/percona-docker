FROM redhat/ubi9-minimal

LABEL name="Percona PgBouncer" \
      description="PgBouncer is a lightweight connection pooler for PostgreSQL that offers various pooling modes (session, transaction, statement), low memory usage, support for multiple backend hosts, and the ability to reconfigure or restart it online without downtime." \
      vendor="Percona" \
      summary="Lightweight connection pooler for PostgreSQL" \
      maintainer="Percona Development <info@percona.com>" \
      org.opencontainers.image.authors="info@percona.com"

ARG PG_VERSION=17.5
ARG PPG_REPO=release
ENV PG_VERSION=${PG_VERSION}
ENV PPG_REPO=${PPG_REPO}

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/prel/yum/release/9/RPMS/noarch/percona-release-1.0-29.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release disable all; \
    percona-release enable ppg-${PG_VERSION} ${PPG_REPO}

RUN ARCH=$(uname -m) && echo "Architecture is: $ARCH" && \
    curl -o c-ares.rpm https://mirror.stream.centos.org/9-stream/BaseOS/${ARCH}/os/Packages/c-ares-1.19.1-2.el9.${ARCH}.rpm && \
    rpm -i c-ares.rpm && \
    rm -f c-ares.rpm

RUN groupadd -g 1001 pgbouncer; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" pgbouncer

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install \
        procps-ng \
        percona-pgbouncer; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

COPY LICENSE /licenses/LICENSE.Dockerfile

RUN touch /etc/pgbouncer/userlist.txt && \
    chown -R 1001 /var/log/pgbouncer /var/run/pgbouncer /etc/pgbouncer

COPY --chown=1001 ["entrypoint.sh", "/"]
USER 1001

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
