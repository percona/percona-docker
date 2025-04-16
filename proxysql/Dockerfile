FROM redhat/ubi9-minimal AS ubi9

# Please don't remove old-style LABEL since it's needed for RedHat certification
LABEL name="ProxySQL" \
      release="2.0" \
      vendor="Percona" \
      summary="High-performance MySQL proxy with a GPL license" \
      description="ProxySQL is a high performance, high availability, protocol aware proxy for MySQL and forks (like Percona Server and MariaDB). All the while getting the unlimited freedom that comes with a GPL license." \
      maintainer="Percona Development <info@percona.com>"

LABEL org.opencontainers.image.title="ProxySQL"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="ProxySQL is a high performance, high availability, \
protocol aware proxy for MySQL and forks (like Percona Server and MariaDB). \
All the while getting the unlimited freedom that comes with a GPL license."
LABEL org.opencontainers.image.license="GPL+"
LABEL org.opencontainers.image.authors="info@percona.com"

ENV PXC_VERSION 8.0.41-32.1
ENV PROXYSQL_VERSION 2.7.1-1.2
ENV OS_VER el9
ENV FULL_PERCONA_VERSION "$PXC_VERSION.$OS_VER"
ENV FULL_PROXYSQL_VERSION "$PROXYSQL_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PROXYSQL_VERSION}
LABEL org.opencontainers.image.version=${PROXYSQL_VERSION}
LABEL org.opencontainers.image.authors="info@percona.com"

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-9; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-EPEL-9; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release setup pxc80; \
    percona-release enable proxysql testing

RUN set -ex; \
    microdnf install -y jq \
        util-linux \
        percona-xtradb-cluster-client-${FULL_PERCONA_VERSION} \
        shadow-utils \
        which \
        hostname \
        procps-ng \
        perl-DBD-MySQL \
        perl-DBI \
        krb5-libs \
        cpio \
        tar; \
    microdnf update -y glibc \
        pam \
        krb5-libs; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN groupadd -g 1001 proxysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" proxysql

# we need licenses from docs
RUN set -ex; \
    curl -Lf -o /tmp/proxysql2-${FULL_PROXYSQL_VERSION}.rpm http://repo.percona.com/proxysql/yum/testing/9/RPMS/x86_64/proxysql2-${FULL_PROXYSQL_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-server-${FULL_PERCONA_VERSION}.rpm http://repo.percona.com/pxc-80/yum/release/9/RPMS/x86_64/percona-xtradb-cluster-server-${FULL_PERCONA_VERSION}.x86_64.rpm; \
    rpmkeys --checksig /tmp/percona-xtradb-cluster-server-${FULL_PERCONA_VERSION}.rpm /tmp/proxysql2-${FULL_PROXYSQL_VERSION}.rpm; \
    rpm -iv /tmp/proxysql2-${FULL_PROXYSQL_VERSION}.rpm --nodeps; \
    rm -rf /tmp/proxysql2-${FULL_PROXYSQL_VERSION}.rpm; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum /etc/proxysql /var/lib/proxysql; \
    rpm -ql percona-xtradb-cluster-client | egrep -v "mysql$|mysqldump$" | xargs rm -rf; \
    install -o 1001 -g 0 -m 775 -d /etc/proxysql /var/lib/proxysql; \
    rpm2cpio /tmp/percona-xtradb-cluster-server-${FULL_PERCONA_VERSION}.rpm | cpio -idv ./usr/bin/my_print_defaults; \
    rm -rf /tmp/percona-xtradb-cluster-server-${FULL_PERCONA_VERSION}.rpm

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/proxysql2/LICENSE /licenses/LICENSE.proxysql

COPY dockerdir /
RUN chown 1001:1001 /etc/proxysql/proxysql.cnf /etc/proxysql-admin.cnf; \
    chmod 664 /etc/proxysql/proxysql.cnf /etc/proxysql-admin.cnf

USER 1001

VOLUME /var/lib/proxysql

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 6032
CMD ["/usr/bin/proxysql", "-f", "-c", "/etc/proxysql/proxysql.cnf", "--reload"]
