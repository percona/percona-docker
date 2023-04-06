FROM redhat/ubi8-minimal

LABEL name="Percona PostgreSQL Distribution upgrade" \
    vendor="Percona" \
    summary="Percona Distribution for PostgreSQL" \
    description="Percona Distribution for PostgreSQL is a collection of tools to assist you in managing your PostgreSQL database system" \
    maintainer="Percona Development <info@percona.com>"

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install glibc-langpack-en platform-python; \
    /usr/libexec/platform-python -m pip install pip --upgrade; \
    microdnf -y remove platform-python-pip; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
ARG PG_MAJOR=15

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
        430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
        99DB70FAE1D7CE227FB6488205B555B38483C65D \
        94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 \
        736AF5116D9C40E2AF6B074BF9B9FEE7764429E6; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    gpg --batch --export --armor 736AF5116D9C40E2AF6B074BF9B9FEE7764429E6 > ${GNUPGHOME}/RPM-GPG-KEY-CentOS-SIG-Cloud; \
    rpmkeys --import \
        ${GNUPGHOME}/RPM-GPG-KEY-Percona \
        ${GNUPGHOME}/RPM-GPG-KEY-centosofficial \
        ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8 \
        ${GNUPGHOME}/RPM-GPG-KEY-CentOS-SIG-Cloud; \
    microdnf install -y findutils; \
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
    percona-release enable ppg-${PG_MAJOR} release


RUN set -ex; \
    microdnf -y install \
        bind-utils \
        gettext \
        hostname \
        perl \
        libedit \
        procps-ng; \
    sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/epel*.repo; \
    microdnf -y module disable llvm-toolset; \
    microdnf -y install \
        libpq \
        llvm \
        percona-postgresql${PG_MAJOR//.}; \
    microdnf -y clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN set -ex; \
    microdnf -y install \
        --enablerepo="epel" \
        percona-pgaudit \
        percona-pgaudit${PG_MAJOR//.}_set_user \
        percona-postgresql${PG_MAJOR//.}-contrib \
        percona-postgresql${PG_MAJOR//.}-server \
        percona-postgresql${PG_MAJOR//.}-libs \
        percona-postgresql${PG_MAJOR//.}-plpython* \
        percona-postgresql${PG_MAJOR//.}-llvmjit \
        percona-wal2json${PG_MAJOR//.} \
        nss_wrapper \
        lz4 \
        unzip; \
    microdnf -y reinstall tzdata; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN for pg_version in 14 13 12; do \
        percona-release enable ppg-${pg_version} release; \
        microdnf -y install --nodocs \
            percona-pgaudit \
            percona-pgaudit${pg_version}_set_user \
            percona-postgresql${pg_version}-contrib \
            percona-postgresql${pg_version}-server \
            percona-postgresql${pg_version}-libs \
            percona-postgresql${pg_version}-plpython* \
            percona-postgresql${pg_version}-llvmjit \
            percona-wal2json${pg_version}; \
    done 

#    && microdnf -y clean all; \
#            microdnf clean all; \
#            rm -rf /var/cache/dnf /var/cache/yum

RUN mkdir -p /opt/crunchy/bin /pgolddata /pgnewdata /opt/crunchy/conf
COPY bin/upgrade/ /opt/crunchy/bin
COPY bin/common /opt/crunchy/bin
COPY conf/upgrade/ /opt/crunchy/conf

RUN chown -R postgres:postgres /opt/crunchy /pgolddata /pgnewdata && \
    chmod -R g=u /opt/crunchy /pgolddata /pgnewdata

VOLUME /pgolddata /pgnewdata

ENV NSS_WRAPPER_SUBDIR="upgrade"

ENTRYPOINT ["opt/crunchy/bin/uid_postgres.sh"]

USER 26

CMD ["/opt/crunchy/bin/start.sh"]
