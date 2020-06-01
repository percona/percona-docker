FROM centos:7

LABEL org.opencontainers.image.authors="info@percona.com"

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    yum install -y /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY

ENV XTRABACKUP_VERSION 2.4.20-1.el7
ENV PS_VERSION 5.7.30-33.1.el7

RUN set -ex; \
  yum install -y \
    percona-xtrabackup-24-${XTRABACKUP_VERSION} \
    Percona-Server-shared-57-${PS_VERSION} \
    qpress; \
  \
  yum clean all; \
  rm -rf /var/cache/yum 

VOLUME [ "/backup" ]

CMD ["/usr/bin/xtrabackup"]
