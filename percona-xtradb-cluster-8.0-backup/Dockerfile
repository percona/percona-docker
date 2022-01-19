FROM golang:1.17 AS go_builder

RUN git clone --branch=main https://github.com/percona/percona-xtradb-cluster-operator.git /go/src/github.com/percona/percona-xtradb-cluster-operator/

WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/peer-list
RUN go build

WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/pitr
RUN go build

ENV MC_VERSION=RELEASE.2021-01-05T05-03-58Z
ENV MC_SHA256SUM=cd63e436e45feff6e2fa035e4ade9a87d94bd0d1cc9b8616ec0c04d647c3cdb3
RUN curl -o /go/bin/mc -O https://dl.minio.io/client/mc/release/linux-amd64/archive/mc.${MC_VERSION} \
    && chmod +x /go/bin/mc \
    && echo "${MC_SHA256SUM} /go/bin/mc" | sha256sum -c - \
    && curl -o /go/bin/LICENSE.mc \
        https://raw.githubusercontent.com/minio/mc/${MC_VERSION}/LICENSE

FROM redhat/ubi8-minimal

# Please don't remove old-style LABEL since it's needed for RedHat certification
LABEL name="Percona XtraBackup" \
      release="8.0" \
      vendor="Percona" \
      summary="Percona XtraBackup is an open-source hot backup utility for MySQL - based servers that doesn’t lock your database during the backup" \
      description="Percona XtraBackup works with MySQL, MariaDB, and Percona Server. It supports completely non-blocking backups of InnoDB, XtraDB, and HailDB storage engines. In addition, it can back up the following storage engines by briefly pausing writes at the end of the backup: MyISAM, Merge, and Archive, including partitioned tables, triggers, and database options." \
      maintainer="Percona Development <info@percona.com>"

LABEL org.opencontainers.image.title="Percona XtraDB Cluster"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="Percona XtraDB Cluster is a high availability solution that \
helps enterprises avoid downtime and outages and meet expected customer experience."
LABEL org.opencontainers.image.license="GPL"

# do not use PXB 8.0.14-1 (PXB-2279)
ENV PXB_VERSION 8.0.26-18.1
ENV PS_VERSION 8.0.26-16.1
ENV PXC_VERSION 8.0.26-16.1
ENV PXC_REPO release
ENV KUBECTL_VERSION=v1.19.12
ENV KUBECTL_SHA256SUM=9a9123b58e3287fdca20db45ab003426d30e7a77ec57605fa25947bc68f6cabf
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRABACKUP_VERSION "$PXB_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRADBCLUSTER_VERSION "$PXC_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PXC_VERSION}
LABEL org.opencontainers.image.version=${PXC_VERSION}

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY

RUN set -ex; \
	curl -Lf -o /tmp/numactl-libs.rpm http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/numactl-libs-2.0.12-13.el8.x86_64.rpm; \
	curl -Lf -o /tmp/libev.rpm http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/libev-4.24-6.el8.x86_64.rpm; \
	curl -Lf -o /tmp/jq.rpm http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/jq-1.5-12.el8.x86_64.rpm; \
	curl -Lf -o /tmp/oniguruma.rpm http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/oniguruma-6.8.2-2.el8.x86_64.rpm; \
	curl -Lf -o /tmp/pv.rpm http://download.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/p/pv-1.6.6-7.el8.x86_64.rpm; \
	curl -Lf -o /tmp/socat.rpm http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/socat-1.7.4.1-1.el8.x86_64.rpm; \
	rpmkeys --checksig /tmp/socat.rpm /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm; \
	rpm -i /tmp/socat.rpm /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm; \
	rm -rf /tmp/socat.rpm /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm

RUN set -ex; \
	microdnf install -y \
		shadow-utils \
		hostname \
		libaio \
		iproute \
		tar \
		cracklib-dicts \
		findutils; \
	microdnf clean all; \
	rm -rf /var/cache/dnf /var/cache/yum

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

# we need licenses from docs
RUN set -ex; \
	curl -Lf -o /tmp/percona-xtrabackup.rpm http://repo.percona.com/tools/yum/release/8/RPMS/x86_64/percona-xtrabackup-80-${FULL_PERCONA_XTRABACKUP_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/percona-server-shared.rpm http://repo.percona.com/ps-80/yum/${PXC_REPO}/8/RPMS/x86_64/percona-server-shared-${FULL_PERCONA_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/percona-xtradb-cluster-garbd.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/8/RPMS/x86_64/percona-xtradb-cluster-garbd-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/percona-xtradb-cluster-client.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/8/RPMS/x86_64/percona-xtradb-cluster-client-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/procps-ng.rpm http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/procps-ng-3.3.15-6.el8.x86_64.rpm; \
	curl -Lf -o /tmp/iputils.rpm http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/iputils-20180629-7.el8.x86_64.rpm; \
	rpmkeys --checksig /tmp/procps-ng.rpm /tmp/iputils.rpm /tmp/percona-xtradb-cluster-garbd.rpm /tmp/percona-xtrabackup.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-server-shared.rpm; \
	rpm -iv /tmp/procps-ng.rpm /tmp/iputils.rpm /tmp/percona-xtradb-cluster-garbd.rpm /tmp/percona-xtrabackup.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-server-shared.rpm --nodeps; \
	rm -rf /tmp/procps-ng.rpm /tmp/percona-xtradb-cluster-garbd.rpm /tmp/percona-xtrabackup.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-server-shared.rpm; \
	rpm -ql percona-xtradb-cluster-client | egrep -v "mysql$|mysqldump$|mysqlbinlog$" | xargs rm -rf; \
	microdnf clean all; \
	rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtrabackup-80/LICENSE /licenses/LICENSE.xtrabackup; \
    cp /usr/share/doc/percona-xtradb-cluster-garbd-3/COPYING /licenses/LICENSE.garbd

RUN curl -o /usr/bin/kubectl \
        https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/bin/kubectl; \
    echo "${KUBECTL_SHA256SUM} /usr/bin/kubectl" | sha256sum -c -; \
    curl -o /licenses/LICENSE.kubectl \
        https://raw.githubusercontent.com/kubernetes/kubectl/master/LICENSE

RUN install -d -o 1001 -g 0 -m 0775 /backup; \
    mkdir /usr/lib/pxc

COPY lib/pxc /usr/lib/pxc
COPY recovery-*.sh run_backup.sh backup.sh get-pxc-state /usr/bin/
COPY --from=go_builder /go/bin/mc /usr/bin/
COPY --from=go_builder /go/bin/LICENSE.mc /licenses/LICENSE.mc
COPY --from=go_builder /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/peer-list /usr/bin/
COPY --from=go_builder /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/pitr/pitr /usr/bin/

VOLUME ["/backup"]
USER 1001

CMD ["sleep","infinity"]
