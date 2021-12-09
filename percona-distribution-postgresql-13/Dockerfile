FROM redhat/ubi8-minimal

LABEL org.opencontainers.image.authors="info@percona.com"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en

ENV PPG_VERSION 13.4-1
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PPG_VERSION.$OS_VER"

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    #percona-release setup -y ppg13; \
    percona-release enable ppg-13.4 release

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
    curl -Lf -o /tmp/perl-JSON.rpm http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-JSON-2.97.001-2.el8.noarch.rpm; \
    rpmkeys --checksig /tmp/perl-JSON.rpm; \
    rpm -i /tmp/perl-JSON.rpm

RUN set -ex; \
    microdnf install -y \
        percona-postgresql13-server-${FULL_PERCONA_VERSION} \
        percona-postgresql13-contrib-${FULL_PERCONA_VERSION} \
        percona-postgresql-common \
        percona-pg-stat-monitor13; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum /data/db && mkdir -p /data/db /docker-entrypoint-initdb.d; \
    chown -R 1001:0 /data/db docker-entrypoint-initdb.d

RUN set -ex; \
    sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/pgsql-13/share/postgresql.conf.sample; \
    grep -F "listen_addresses = '*'" /usr/pgsql-13/share/postgresql.conf.sample

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-postgresql13/COPYRIGHT /licenses/COPYRIGHT.PostgreSQL

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
