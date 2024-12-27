FROM redhat/ubi9-minimal

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
        3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F \
        99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle; \
    rpmkeys --import \
        ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
        ${GNUPGHOME}/RPM-GPG-KEY-oracle \
        ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    microdnf install -y findutils yum-utils; \
    curl -Lf -o /tmp/oraclelinux-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/oraclelinux-release-el9-1.0-15.el9.x86_64.rpm; \
    curl -Lf -o /tmp/epel-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/oracle-epel-release-el9-1.0-1.el9.x86_64.rpm; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpm --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-oracle ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpmkeys --checksig /tmp/oraclelinux-release.rpm; \
    rpm -i /tmp/percona-release.rpm /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpmm /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    percona-release enable ppg-${PG_MAJOR} release

RUN set -ex; \
    yum-config-manager --disable ol9_appstream; \
    microdnf --disablerepo="ubi-9-appstream-rpms" -y install \
        llvm; \
    microdnf -y clean all

RUN set -ex; \
    microdnf --enablerepo="ol9_appstream" -y install \
        annobin-12.31-2.el9.x86_64; \
    microdnf -y clean all

RUN set -ex; \
    yum-config-manager --disable ol9_developer_EPEL ol9_UEKR7 ol9_baseos_latest; \
    microdnf -y install \
        bind-utils \
        gettext \
        hostname \
        python3-pyparsing \
        perl \
        libedit \
        procps-ng; \
    microdnf -y install \
        libpq \
        percona-postgresql${PG_MAJOR//.}; \
    microdnf -y clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN set -ex; \
    microdnf -y install \
        --enablerepo="ol9_developer_EPEL" \
        percona-pgaudit${PG_MAJOR//.} \
        percona-pgaudit${PG_MAJOR//.}_set_user \
        percona-postgresql${PG_MAJOR//.}-contrib \
        percona-postgresql${PG_MAJOR//.}-server \
        percona-postgresql${PG_MAJOR//.}-libs \
        percona-postgresql${PG_MAJOR//.}-llvmjit \
        percona-wal2json${PG_MAJOR//.} \
        percona-pg_stat_monitor${PG_MAJOR//.} \
        nss_wrapper \
        lz4 \
        unzip; \
    microdnf -y reinstall tzdata; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN for pg_version in 16 15 14 13 12; do \
        percona-release enable ppg-${pg_version} release; \
        microdnf -y install --nodocs \
            percona-pgaudit${pg_version} \
            percona-pgaudit${pg_version}_set_user \
            percona-postgresql${pg_version}-contrib \
            percona-postgresql${pg_version}-server \
            percona-postgresql${pg_version}-libs \
            percona-postgresql${pg_version}-llvmjit \
            percona-wal2json${pg_version} \
            percona-pg_stat_monitor${pg_version}; \
    done

#    && microdnf -y clean all; \
#            microdnf clean all; \
#            rm -rf /var/cache/dnf /var/cache/yum

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
