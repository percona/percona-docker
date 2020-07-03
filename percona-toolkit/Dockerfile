FROM centos:8

LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="Percona Toolkit"
LABEL org.label-schema.vendor="Percona"
LABEL org.label-schema.description="Percona Toolkit is a collection of advanced command-line tools used by Percona support staff \
to perform a variety of MySQL, MongoDB, and system tasks \
 that are too difficult or complex to perform manually."
LABEL org.label-schema.license="GPLv2"

LABEL org.opencontainers.image.title="Percona Toolkit"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="Percona Toolkit is a collection of advanced command-line tools used by Percona support staff \
to perform a variety of MySQL, MongoDB, and system tasks \
 that are too difficult or complex to perform manually."
LABEL org.opencontainers.image.license="GPLv2"
LABEL org.opencontainers.image.authors="info@percona.com"

ENV PT_VERSION 3.2.0-1
ENV OS_VER el8
ENV FULL_PERCONA_PT_VERSION "$PT_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PS_VERSION}
LABEL org.opencontainers.image.version=${PS_VERSION}

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
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY;  \
    dnf -y module disable perl-DBD-MySQL; \
    percona-release enable tools testing

RUN set -ex; \
  dnf install -y \
    percona-toolkit-${FULL_PERCONA_PT_VERSION}; \
  \
  dnf clean all; \
  rm -rf /var/cache/dnf

RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" perconatoolkit

USER 1001
