FROM redhat/ubi9-minimal

LABEL org.opencontainers.image.authors="info@percona.com"

ENV PG_VERSION 17.4
ENV PPG_REPO release

# check repository package signature in secure way
RUN set -ex; \
    ARCH=$(uname -m) && echo "Architecture is: $ARCH" && \
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
    curl -Lf -o /tmp/oraclelinux-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/${ARCH}/getPackage/oraclelinux-release-el9-1.0-15.el9.${ARCH}.rpm; \
    curl -Lf -o /tmp/epel-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/${ARCH}/getPackage/oracle-epel-release-el9-1.0-1.el9.${ARCH}.rpm; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpm --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-oracle ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpmkeys --checksig /tmp/oraclelinux-release.rpm; \
    rpm -i /tmp/percona-release.rpm /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    percona-release enable ppg-${PG_VERSION} ${PPG_REPO}

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install \
        --enablerepo="ol9_developer_EPEL" \
        percona-pgbackrest \
        nss_wrapper; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

COPY pgbackrest.conf /etc/pgbackrest.conf

USER 26

CMD ["/usr/bin/pgbackrest", "version"]
