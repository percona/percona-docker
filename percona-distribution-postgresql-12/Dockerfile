FROM centos:8

LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="Percona Distribution for PostgreSQL"
LABEL org.label-schema.vendor="Percona"
LABEL org.label-schema.description="PostgreSQL is an advanced Object-Relational database management system (DBMS). \
The postgresql11-server package contains the programs needed to create \
and run a PostgreSQL server, which will in turn allow you to create \
and maintain PostgreSQL databases."
LABEL org.label-schema.license="PostgreSQL"

LABEL org.opencontainers.image.title="Percona Distribution for PostgreSQL"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="PostgreSQL is an advanced Object-Relational database management system (DBMS). \
The postgresql11-server package contains the programs needed to create \
and run a PostgreSQL server, which will in turn allow you to create \
and maintain PostgreSQL databases."
LABEL org.opencontainers.image.license="PostgreSQL"
LABEL org.opencontainers.image.authors="info@percona.com"

ENV PPG_VERSION 12.4-2
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PPG_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PPG_VERSION}
LABEL org.opencontainers.image.version=${PPG_VERSION}

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    dnf install -y /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release setup -y ppg12; \
    percona-release enable ppg-12.4 testing

# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" postgres

RUN set -ex; \
    dnf install -y \
        nss_wrapper \
        shadow-utils \
        percona-postgresql12-server-${FULL_PERCONA_VERSION} \
        percona-postgresql12-contrib-${FULL_PERCONA_VERSION} \
        percona-postgresql-common \
        percona-pg-stat-monitor12; \
    dnf clean all; \
    rm -rf /var/cache/dnf /data/db && mkdir -p /data/db /docker-entrypoint-initdb.d; \
    chown -R 1001:0 /data/db docker-entrypoint-initdb.d

RUN set -ex; \
	sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/pgsql-12/share/postgresql.conf.sample; \
	grep -F "listen_addresses = '*'" /usr/pgsql-12/share/postgresql.conf.sample

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-postgresql12/COPYRIGHT /licenses/COPYRIGHT.PostgreSQL

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

VOLUME ["/data/db"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 5432

USER 1001

CMD ["postgres"]
