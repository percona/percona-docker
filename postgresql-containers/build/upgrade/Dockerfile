FROM redhat/ubi8-minimal

LABEL name="Percona PostgreSQL Distribution upgrade" \
    vendor="Percona" \
    summary="Percona Distribution for PostgreSQL" \
    description="Percona Distribution for PostgreSQL is a collection of tools to assist you in managing your PostgreSQL database system" \
    maintainer="Percona Development <info@percona.com>"

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install glibc-langpack-en platform-python; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
ARG PG_MAJOR=17

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
        4D1BB29D63D98E422B2113B19334A25F8507EFA5 \
        99DB70FAE1D7CE227FB6488205B555B38483C65D \
        94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 \
        736AF5116D9C40E2AF6B074BF9B9FEE7764429E6; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    gpg --batch --export --armor 736AF5116D9C40E2AF6B074BF9B9FEE7764429E6 > ${GNUPGHOME}/RPM-GPG-KEY-CentOS-SIG-Cloud; \
    rpmkeys --import \
        ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
        ${GNUPGHOME}/RPM-GPG-KEY-centosofficial \
        ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8 \
        ${GNUPGHOME}/RPM-GPG-KEY-CentOS-SIG-Cloud; \
    microdnf install -y findutils yum-utils; \
    curl -Lf -o /tmp/epel-release.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpm -i /tmp/percona-release.rpm /tmp/epel-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm /tmp/epel-release.rpm; \
    curl -Lf -o /tmp/python3-pyparsing.rpm https://vault.centos.org/8.5.2111/cloud/x86_64/openstack-train/Packages/p/python3-pyparsing-2.4.6-1.el8.noarch.rpm; \
    rpmkeys --checksig /tmp/python3-pyparsing.rpm; \
    rpm -i /tmp/python3-pyparsing.rpm; \
    rm -rf /tmp/python3-pyparsing.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable ppg-${PG_MAJOR//.} release

RUN set -ex; \
    microdnf -y module disable llvm-toolset; \
    microdnf -y clean all

RUN set -ex; \
    microdnf -y install \
        bind-utils \
        gettext \
        hostname \
        perl \
        libedit \
        procps-ng; \
    microdnf -y install \
        libpq \
        llvm \
        percona-postgresql${PG_MAJOR//.}-17.5-2.el8; \
    microdnf -y clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN set -ex; \
    for pg_version in 12 13 14 15 16; do \
        percona-release enable ppg-${pg_version} release; \
    done; \
    microdnf -y install --nodocs \
        percona-postgresql12-12.22-1.el8 \
        percona-pgaudit12 percona-pgaudit12_set_user \
        percona-postgresql12-contrib-12.22-1.el8 \
        percona-postgresql12-server-12.22-1.el8 \
        percona-postgresql12-libs-12.22-1.el8 \
        percona-postgresql12-llvmjit-12.22-1.el8 \
        percona-wal2json12 percona-pg_stat_monitor12 \
        percona-postgresql13-13.21-1.el8 \
        percona-pgaudit13-1.5.3-7.el8 percona-pgaudit13_set_user-4.1.0-4.el8 \
        percona-postgresql13-contrib-13.21-1.el8 \
        percona-postgresql13-server-13.21-1.el8 \
        percona-postgresql13-libs-13.21-1.el8 \
        percona-postgresql13-llvmjit-13.21-1.el8 \
        percona-wal2json13-2.6-1.el8 percona-pg_stat_monitor13-2.2.0-1.el8 \
        percona-pg_repack13-1.5.2-1.el8 percona-pg-telemetry13-1.1.2-1.el8 \
        percona-pgvector_13-0.8.0-1.el8 percona-pgvector_13-llvmjit-0.8.0-1.el8 \
        percona-postgresql14-14.18-1.el8 \
        percona-pgaudit14-1.6.3-7.el8 percona-pgaudit14_set_user-4.1.0-4.el8 \
        percona-postgresql14-contrib-14.18-1.el8 \
        percona-postgresql14-server-14.18-1.el8 \
        percona-postgresql14-libs-14.18-1.el8 \
        percona-postgresql14-llvmjit-14.18-1.el8 \
        percona-wal2json14-2.6-1.el8 percona-pg_stat_monitor14-2.2.0-1.el8 \
        percona-pg_repack14-1.5.2-1.el8 percona-pg-telemetry14-1.1.2-1.el8 \
        percona-pgvector_14-0.8.0-1.el8 percona-pgvector_14-llvmjit-0.8.0-1.el8 \
        percona-postgresql15-15.13-1.el8 \
        percona-pgaudit15-1.7.1-7.el8 percona-pgaudit15_set_user-4.1.0-4.el8 \
        percona-postgresql15-contrib-15.13-1.el8 \
        percona-postgresql15-server-15.13-1.el8 \
        percona-postgresql15-libs-15.13-1.el8 \
        percona-postgresql15-llvmjit-15.13-1.el8 \
        percona-wal2json15-2.6-1.el8 percona-pg_stat_monitor15-2.2.0-1.el8 \
        percona-pg_repack15-1.5.2-1.el8 percona-pg-telemetry15-1.1.2-1.el8 \
        percona-pgvector_15-0.8.0-1.el8 percona-pgvector_15-llvmjit-0.8.0-1.el8 \
        percona-postgresql16-16.9-1.el8 \
        percona-pgaudit16-16.0-2.el8 percona-pgaudit16_set_user-4.1.0-2.el8 \
        percona-postgresql16-contrib-16.9-1.el8 \
        percona-postgresql16-server-16.9-1.el8 \
        percona-postgresql16-libs-16.9-1.el8 \
        percona-postgresql16-llvmjit-16.9-1.el8 \
        percona-wal2json16-2.6-1.el8 percona-pg_stat_monitor16-2.2.0-1.el8 \
        percona-pg_repack16-1.5.2-1.el8 percona-pg-telemetry16-1.1.2-1.el8 \
        percona-pgvector_16-0.8.0-1.el8 percona-pgvector_16-llvmjit-0.8.0-1.el8 \
        percona-pgaudit${PG_MAJOR//.}-17.1-1.el8 \
        percona-pgaudit${PG_MAJOR//.}_set_user-4.1.0-2.el8 \
        percona-postgresql${PG_MAJOR//.}-contrib-17.5-2.el8 \
        percona-postgresql${PG_MAJOR//.}-server-17.5-2.el8 \
        percona-postgresql${PG_MAJOR//.}-libs-17.5-2.el8 \
        percona-postgresql${PG_MAJOR//.}-llvmjit-17.5-2.el8 \
        percona-wal2json${PG_MAJOR//.}-2.6-1.el8 \
        percona-pg_stat_monitor${PG_MAJOR//.}-2.2.0-1.el8 \
        percona-pg_repack${PG_MAJOR//.}-1.5.2-1.el8 \
        percona-pg-telemetry${PG_MAJOR//.}-1.1.2-1.el8 \
        percona-pgvector_${PG_MAJOR//.}-0.8.0-1.el8 \
        percona-pgvector_${PG_MAJOR//.}-llvmjit-0.8.0-1.el8 \
        nss_wrapper \
        lz4 \
        unzip; \
    microdnf -y reinstall tzdata; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN mkdir -p /opt/crunchy/bin /pgolddata /pgnewdata /opt/crunchy/conf
COPY bin/upgrade/ /opt/crunchy/bin
COPY bin/common /opt/crunchy/bin
COPY conf/upgrade/ /opt/crunchy/conf
COPY bin/relocate-extensions.sh /usr/local/bin/relocate-extensions.sh

RUN chown -R postgres:postgres /opt/crunchy /pgolddata /pgnewdata && \
    chmod -R g=u /opt/crunchy /pgolddata /pgnewdata

VOLUME /pgolddata /pgnewdata

ENV NSS_WRAPPER_SUBDIR="upgrade"

ENTRYPOINT ["opt/crunchy/bin/uid_postgres.sh"]

USER 26

CMD ["/opt/crunchy/bin/start.sh"]
