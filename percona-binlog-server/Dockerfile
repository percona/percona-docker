FROM redhat/ubi9-minimal

LABEL name="Percona Binlog Server" \
        release="0.1.0" \
        vendor="Percona" \
        summary="binlog_server is a command line utility that can be considered as an enhanced version of mysqlbinlog" \
        description="binlog_server is a command line utility that serves as a replication client and can stream binary log events from a remote Oracle MySQL Server / Percona Server for MySQL both to a local filesystem and to a cloud storage." \
        maintainer="Percona Development <info@percona.com>"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en

ENV PBS_VERSION 0.1.0-1.el9

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
    percona-release enable pdps-84-lts; \
    percona-release enable tools experimental

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install  \
        shadow-utils \
        tar \
        hostname \
        percona-binlog-server-${PBS_VERSION} 

RUN   set -ex; \
      microdnf clean all; \
      rm -rf /var/cache/dnf /var/cache/yum

COPY LICENSE /licenses/LICENSE.Dockerfile

RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" pbs

USER 1001
