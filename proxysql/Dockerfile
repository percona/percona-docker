FROM golang:1.13 AS go_builder
WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/src

RUN go get k8s.io/apimachinery/pkg/util/sets \
    && curl -Lf -o /go/src/github.com/percona/percona-xtradb-cluster-operator/src/peer-list.go https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/master/cmd/peer-list/main.go \
    && go build peer-list.go

FROM centos:8 AS centos8

LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="ProxySQL"
LABEL org.label-schema.vendor="Percona"
LABEL org.label-schema.description="ProxySQL is a high performance, high availability, \
protocol aware proxy for MySQL and forks (like Percona Server and MariaDB). \
All the while getting the unlimited freedom that comes with a GPL license."
LABEL org.label-schema.license="GPL+"

LABEL org.opencontainers.image.title="ProxySQL"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="ProxySQL is a high performance, high availability, \
protocol aware proxy for MySQL and forks (like Percona Server and MariaDB). \
All the while getting the unlimited freedom that comes with a GPL license."
LABEL org.opencontainers.image.license="GPL+"
LABEL org.opencontainers.image.authors="info@percona.com"

ENV PXC_VERSION 8.0.19-10.1
ENV PROXYSQL_VERSION 2.0.14-1.1
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PXC_VERSION.$OS_VER"
ENV FULL_PROXYSQL_VERSION "$PROXYSQL_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PROXYSQL_VERSION}
LABEL org.opencontainers.image.version=${PROXYSQL_VERSION}

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
    dnf -y module disable mysql; \
    dnf -y module disable mysql perl-DBD-MySQL; \
    percona-release setup pxc80; \
    percona-release enable tools testing

RUN set -ex; \
    dnf install -y \
        percona-xtradb-cluster-client-${FULL_PERCONA_VERSION} \
        shadow-utils \
        which \
        hostname \
        perl-DBD-MySQL \
        perl-DBI \
        gnutls \
        oniguruma \
        jq \
        dnf-utils; \
    \
    dnf clean all; \
    rm -rf /var/cache/dnf

RUN groupadd -g 1001 proxysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" proxysql

# we need licenses from docs
RUN set -ex; \
    repoquery -a --location \
	proxysql2-${FULL_PROXYSQL_VERSION} | head -n1 \
	| xargs curl -Lf -o /tmp/proxysql2.rpm; \
    rpm -iv /tmp/proxysql2.rpm --nodeps; \
    rm -rf /tmp/proxysql2.rpm; \
    dnf -y remove dnf-utils; \
    dnf clean all; \
    rm -rf /var/cache/dnf /etc/proxysql /var/lib/proxysql; \
    rpm -ql percona-xtradb-cluster-client | egrep -v "mysql$|mysqldump$" | xargs rm -rf; \
    install -o 1001 -g 0 -m 775 -d /etc/proxysql /var/lib/proxysql

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/proxysql2/LICENSE /licenses/LICENSE.proxysql

COPY dockerdir /
COPY --from=go_builder /go/src/github.com/percona/percona-xtradb-cluster-operator/src/peer-list /usr/bin/
RUN chown 1001:1001 /etc/proxysql/proxysql.cnf /etc/proxysql-admin.cnf; \
    chmod 664 /etc/proxysql/proxysql.cnf /etc/proxysql-admin.cnf

USER 1001

VOLUME /var/lib/proxysql

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 6032
CMD ["/usr/bin/proxysql", "-f", "-c", "/etc/proxysql/proxysql.cnf"]
