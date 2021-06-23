FROM centos:8

LABEL org.opencontainers.image.authors="info@percona.com"

ENV XTRABACKUP_VERSION 8.0.25-17.1
ENV PS_VERSION 8.0.23-14.1
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRABACKUP_VERSION "$XTRABACKUP_VERSION.$OS_VER"

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D; \
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
