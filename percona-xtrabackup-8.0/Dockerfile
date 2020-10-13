FROM centos:8

LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="Percona XtraBackup"
LABEL org.label-schema.vendor="Percona"
LABEL org.label-schema.description="Percona XtraBackup tools provide a method of performing a hot backup of your MySQL data while the system is running. \
Percona XtraBackup is a free, online, open source, \
complete database backups solution \
for all versions of Percona Server for MySQL and MySQL®."
LABEL org.label-schema.license="GPLv2"

LABEL org.opencontainers.image.title="Percona XtraBackup"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="Percona XtraBackup tools provide a method of performing a hot backup of your MySQL data while the system is running. \
Percona XtraBackup is a free, online, open source, \
complete database backups solution \
for all versions of Percona Server for MySQL and MySQL®."
LABEL org.opencontainers.image.license="GPLv2"
LABEL org.opencontainers.image.authors="info@percona.com"

ENV XTRABACKUP_VERSION 8.0.14-1
ENV PS_VERSION 8.0.21-12.2
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRABACKUP_VERSION "$XTRABACKUP_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${XTRABACKUP_VERSION}
LABEL org.opencontainers.image.version=${XTRABACKUP_VERSION}

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
    dnf -y module disable mysql perl-DBD-MySQL; \
    percona-release disable all; \
    percona-release setup -y ps-80; \
    percona-release enable tools testing

RUN set -ex; \
    dnf --setopt=install_weak_deps=False --best install -y \
      percona-xtrabackup-80-${FULL_PERCONA_XTRABACKUP_VERSION} \
      percona-server-shared-${FULL_PERCONA_VERSION} \
      qpress; \
    \
    dnf clean all; \
    rm -rf /var/cache/dnf

VOLUME [ "/backup" ]

CMD ["/usr/bin/xtrabackup"]
