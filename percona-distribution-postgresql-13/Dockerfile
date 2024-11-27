FROM redhat/ubi8-minimal

LABEL org.opencontainers.image.authors="info@percona.com"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en

ENV PPG_VERSION 13.16-1
ENV PPG_MAJOR_VERSION 13
ENV PPG_MINOR_VERSION 16
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "${PPG_VERSION}.${OS_VER}"
ENV PPG_REPO testing
ENV PPG_REPO_VERSION "${PPG_MAJOR_VERSION}.${PPG_MINOR_VERSION}"

# Do not report during Docker image creation.
# Note that doing so, would create telemetry config file
# which would prevent reporting when new container is started.
# If we want to track Docker image creation as well,
# remove telemetry config file after installing packages!
ARG PERCONA_TELEMETRY_DISABLE=1

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    #percona-release setup -y ppg${PPG_MAJOR_VERSION}; \
    percona-release enable telemetry ${PPG_REPO}; \
    percona-release enable ppg-${PPG_REPO_VERSION} ${PPG_REPO};

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install \
        bind-utils \
        gettext \
        hostname \
        perl \
        tar \
        bzip2 \
        lz4 \
        procps-ng; \
    microdnf -y install  \
        nss_wrapper \
        shadow-utils \
        libpq \
        libedit; \
    microdnf clean all

# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" postgres

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    curl -Lf -o /tmp/perl-JSON.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-JSON-2.97.001-2.el8.noarch.rpm; \
    rpmkeys --checksig /tmp/perl-JSON.rpm; \
    rpm -i /tmp/perl-JSON.rpm

ENV PGDATA /data/db

RUN set -ex; \
    microdnf install -y \
        percona-postgresql${PPG_MAJOR_VERSION}-server-${FULL_PERCONA_VERSION} \
        percona-postgresql${PPG_MAJOR_VERSION}-contrib-${FULL_PERCONA_VERSION} \
        percona-postgresql-common \
        percona-pg_stat_monitor${PPG_MAJOR_VERSION} \
        percona-pg_repack${PPG_MAJOR_VERSION} \
        percona-pgaudit${PPG_MAJOR_VERSION} \
        percona-pgaudit${PPG_MAJOR_VERSION}_set_user \
	percona-pgvector_${PPG_MAJOR_VERSION} \
        percona-wal2json${PPG_MAJOR_VERSION}; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum $PGDATA && mkdir -p $PGDATA /docker-entrypoint-initdb.d; \
    chown -R 1001:0 $PGDATA docker-entrypoint-initdb.d

RUN set -ex; \
    sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/pgsql-${PPG_MAJOR_VERSION}/share/postgresql.conf.sample; \
    grep -F "listen_addresses = '*'" /usr/pgsql-${PPG_MAJOR_VERSION}/share/postgresql.conf.sample

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-postgresql${PPG_MAJOR_VERSION}/COPYRIGHT /licenses/COPYRIGHT.PostgreSQL

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

COPY entrypoint.sh /entrypoint.sh

ADD https://raw.githubusercontent.com/Percona-Lab/telemetry-agent/phase-0/call-home.sh /call-home.sh
RUN chmod a+rx call-home.sh
RUN mkdir -p /usr/local/percona
RUN chown 1001:0 /usr/local/percona
ENV CALL_HOME_OPTIONAL_PARAMS=" -s ${OS_VER}"

COPY telemetry-agent-supervisor.sh /usr/bin/
RUN set -ex; \
    chown  1001:0 /usr/bin/telemetry-agent-supervisor.sh; \
    chown  1001:0 /usr/bin/percona-telemetry-agent; \
    chown  1001:0 /usr/local/percona/telemetry/history; \
    chown -R 1001:0 /var/log/percona; \
    chmod ug+rwx /usr/bin/telemetry-agent-supervisor.sh;
ENV PERCONA_TELEMETRY_CHECK_INTERVAL=86400
ENV PERCONA_TELEMETRY_HISTORY_KEEP_INTERVAL=604800
ENV PERCONA_TELEMETRY_RESEND_INTERVAL=60
ENV PERCONA_TELEMETRY_URL=https://check.percona.com/v1/telemetry/GenericReport

VOLUME ["/data/db"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 5432

USER 1001

CMD ["postgres"]
