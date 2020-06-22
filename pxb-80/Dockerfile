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
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release disable all; \
    percona-release setup ps-80

ENV XTRABACKUP_VERSION 8.0.13-1.el7
ENV PS_VERSION 8.0.19-10.1.el7

RUN set -ex; \
  yum install -y \
    percona-xtrabackup-80-${XTRABACKUP_VERSION} \
    percona-server-shared-${PS_VERSION} \
    qpress; \
  \
  yum clean all; \
  rm -rf /var/cache/yum 

VOLUME [ "/backup" ]

CMD ["/usr/bin/xtrabackup"]
