FROM oraclelinux:9 AS downloader

RUN yum install -y epel-release; \
    yum config-manager --set-enabled ol9_codeready_builder; \
    yum install -y --downloadonly perl-JSON; \
    mkdir -p downloaded-packages; \
    cp -rp /var/cache/dnf/ol9_appstream-*/packages/*.rpm downloaded-packages; \
    tar -cvzf downloaded-packages.tar.gz downloaded-packages

FROM redhat/ubi9-minimal

LABEL org.opencontainers.image.authors="info@percona.com"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en

ENV PPG_VERSION 17.5-2
ENV PPG_MAJOR_VERSION 17
ENV PPG_MINOR_VERSION 5
ENV OS_VER el9
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
    microdnf -y reinstall tzdata; \
    microdnf clean all

ENV PGDATA /data/db
ENV PGROOT="/usr/pgsql-${PPG_MAJOR_VERSION}"
ENV PATH="/pgdata:${PGROOT}/bin:${PATH}"

COPY --from=downloader /downloaded-packages.tar.gz .
RUN tar -xvzf downloaded-packages.tar.gz; \
        cd downloaded-packages; \
        rpm -ivh perl-*.rpm; \
	rpm -ivh perl-JSON*.rpm; \
        rm -f /downloaded-packages.tar.gz; \
        cd -; \
        rm -rf /downloaded-packages /var/cache/dnf /var/cache/yum

RUN set -ex; \
    microdnf install -y \
        percona-postgresql${PPG_MAJOR_VERSION}-server-${FULL_PERCONA_VERSION} \
        percona-postgresql${PPG_MAJOR_VERSION}-contrib-${FULL_PERCONA_VERSION} \
        percona-postgresql-common \
        percona-pg_stat_monitor${PPG_MAJOR_VERSION} \
        percona-pg_repack${PPG_MAJOR_VERSION} \
        percona-pgaudit${PPG_MAJOR_VERSION} \
        percona-pgaudit${PPG_MAJOR_VERSION}_set_user \
        percona-pgbackrest \
	percona-pgvector_${PPG_MAJOR_VERSION} \
        percona-wal2json${PPG_MAJOR_VERSION}; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum $PGDATA && mkdir -p $PGDATA /docker-entrypoint-initdb.d; \
    chown -R postgres:postgres $PGDATA docker-entrypoint-initdb.d

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F ; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
    microdnf install -y yum-utils; \
    curl -Lf -o /tmp/oraclelinux-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/oraclelinux-release-el9-1.0-15.el9.x86_64.rpm; \
    curl -Lf -o /tmp/epel-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/oracle-epel-release-el9-1.0-1.el9.x86_64.rpm; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpmkeys --checksig /tmp/oraclelinux-release.rpm; \
    rpm -i /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/epel-release.rpm /tmp/oraclelinux-release.rpm;

RUN set -ex; \
    microdnf -y update; \
    microdnf install -y --enablerepo="ol9_developer_EPEL"\
        python3-click \
        percona-patroni; \
    microdnf clean all

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
RUN chown postgres:postgres /usr/local/percona
ENV CALL_HOME_OPTIONAL_PARAMS=" -s ${OS_VER}"

COPY telemetry-agent-supervisor.sh /usr/bin/
RUN set -ex; \
    chown  postgres:postgres /usr/bin/telemetry-agent-supervisor.sh; \
    chown  postgres:postgres /usr/bin/percona-telemetry-agent; \
    chown  postgres:postgres /usr/local/percona/telemetry/history; \
    chown -R postgres:postgres /var/log/percona; \
    chmod ug+rwx /usr/bin/telemetry-agent-supervisor.sh;
ENV PERCONA_TELEMETRY_CHECK_INTERVAL=86400
ENV PERCONA_TELEMETRY_HISTORY_KEEP_INTERVAL=604800
ENV PERCONA_TELEMETRY_RESEND_INTERVAL=60
ENV PERCONA_TELEMETRY_URL=https://check.percona.com/v1/telemetry/GenericReport

VOLUME ["/data/db"]

RUN rm -f /etc/pgbackrest.conf

# add volumes to allow override of pg_hba.conf and postgresql.conf
# add volumes to offer a restore feature
# add volumes to allow storage of postgres WAL segment files
# add volumes for pgbackrest to write to
# The VOLUME directive must appear after all RUN directives to ensure the proper
# volume permissions are applied when building the image
VOLUME ["/sshd", "/pgconf", "/pgdata", "/pgwal", "/backrestrepo"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 5432

USER 26

CMD ["postgres"]
