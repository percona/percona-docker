FROM golang:1.14 AS go_builder
WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/src

RUN go get k8s.io/apimachinery/pkg/util/sets \
    && curl -Lf -o /go/src/github.com/percona/percona-xtradb-cluster-operator/src/peer-list.go https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/master/cmd/peer-list/main.go \
    && go build peer-list.go

FROM registry.access.redhat.com/ubi8/ubi-minimal AS ubi8

LABEL name="HAproxy" \
      description="TCP proxy loadbalancer for Percona Xtradb Cluster" \
      vendor="Percona" \
      summary="TCP proxy for mysql protocol" \
      org.opencontainers.image.authors="info@percona.com"

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& microdnf install -y findutils \
	&& gpg --keyserver pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
	&& gpg --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
	&& percona-release setup pdpxc-8.0.19

# install exact version of PS for repeatability
ENV PERCONA_VERSION 8.0.19-10.1.el8

RUN set -ex; \
    microdnf install -y \
        shadow-utils \
        percona-haproxy \
        percona-xtradb-cluster-client-${PERCONA_VERSION} \
        which \
        tar \
        socat \
        policycoreutils; \
    \
    microdnf clean all; \
    rm -rf /var/cache

RUN groupadd -g 1001 mysql
RUN useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

STOPSIGNAL SIGUSR1

RUN set -ex; \
    mkdir -p /etc/haproxy/pxc /etc/haproxy-custom; \
    chown -R 1001:1001 /run /etc/haproxy /etc/haproxy/pxc /etc/haproxy-custom
COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/licenses/percona-haproxy/LICENSE /licenses/LICENSE.haproxy

COPY dockerdir /
COPY --from=go_builder /go/src/github.com/percona/percona-xtradb-cluster-operator/src/peer-list /usr/bin/

RUN set -ex; \
    chown 1001:1001 /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy-global.cfg /usr/local/bin/check_pxc.sh

USER mysql

VOLUME ["/etc/haproxy/pxc"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["haproxy"]
