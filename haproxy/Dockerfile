FROM golang:1.22 AS go_builder

RUN git clone --branch=main https://github.com/percona/percona-xtradb-cluster-operator.git /go/src/github.com/percona/percona-xtradb-cluster-operator/
WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/peer-list
RUN go build

FROM redhat/ubi9-minimal AS ubi9

LABEL name="HAproxy" \
      description="TCP proxy loadbalancer for Percona Xtradb Cluster" \
      vendor="Percona" \
      summary="TCP proxy for mysql protocol" \
      org.opencontainers.image.authors="info@percona.com"

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& microdnf install -y findutils \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F 4D1BB29D63D98E422B2113B19334A25F8507EFA5\
	&& gpg --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
    && gpg --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
	&& gpg --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle \
	&& rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-oracle ${GNUPGHOME}/PERCONA-PACKAGING-KEY\
	&& curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
	&& percona-release setup pdpxc-8.0.35

# install exact version of PS for repeatability
ENV PERCONA_VERSION 8.0.35-27.1.el9

RUN set -ex; \
    microdnf install -y \
        shadow-utils \
        percona-haproxy \
        percona-xtradb-cluster-client-${PERCONA_VERSION} \
        which \
        tar \
        socat \
        procps-ng \
        vim-minimal \
        policycoreutils; \
    microdnf update -y glibc; \
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
COPY --from=go_builder /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/peer-list /usr/bin/

RUN set -ex; \
    chown 1001:1001 /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy-global.cfg /usr/local/bin/check_pxc.sh

USER 1001

VOLUME ["/etc/haproxy/pxc"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["haproxy"]
