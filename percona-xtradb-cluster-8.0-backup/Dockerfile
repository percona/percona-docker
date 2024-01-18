FROM golang:1.21 AS go_builder

RUN git clone --branch=main https://github.com/percona/percona-xtradb-cluster-operator.git /go/src/github.com/percona/percona-xtradb-cluster-operator/

WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/peer-list
RUN go build

WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/pitr
RUN go build

ENV MC_VERSION=RELEASE.2024-01-16T16-06-34Z
ENV MC_SHA256SUM=142090f6e5096d27b932c1a4590e07affc60c9fb6dbeacc7e3f770eeed4ac25e
RUN curl -o /go/bin/mc -O https://dl.minio.io/client/mc/release/linux-amd64/archive/mc.${MC_VERSION} \
	&& chmod +x /go/bin/mc \
	&& echo "${MC_SHA256SUM} /go/bin/mc" | sha256sum -c - \
	&& curl -o /go/bin/LICENSE.mc \
	https://raw.githubusercontent.com/minio/mc/${MC_VERSION}/LICENSE

FROM redhat/ubi9-minimal

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

ENV PXB_VERSION 8.0.34-29.1
ENV PS_VERSION 8.0.33-25.1

ENV PXC_VERSION 8.0.33-25.1
ENV KUBECTL_VERSION=v1.24.14
ENV KUBECTL_SHA512SUM=3ec6e321be772291cc6396bd10079f66ac6e690d776108fe2f24724ed51a0557a764228c45aa597a991733c04d052179b220ce8cdedc70c2783621a8925d1945
ENV PXC_REPO release
ENV OS_VER el9
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRABACKUP_VERSION "$PXB_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRADBCLUSTER_VERSION "$PXC_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PXC_VERSION}
LABEL org.opencontainers.image.version=${PXC_VERSION}

# check repository package signature in secure way
RUN set -ex; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F; \
	gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
	gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
	rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona  ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
	microdnf install -y findutils; \
	curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
	rpmkeys --checksig /tmp/percona-release.rpm; \
	rpm -i /tmp/percona-release.rpm; \
	rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
	rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY

RUN set -ex; \
	curl -Lf -o /tmp/libev.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/libev-4.33-5.el9.x86_64.rpm; \
	curl -Lf -o /tmp/pv.rpm https://yum.oracle.com/repo/OracleLinux/OL9/developer/EPEL/x86_64/getPackage/pv-1.6.20-1.el9.x86_64.rpm; \
	curl -Lf -o /tmp/boost-program-options.rpm https://yum.oracle.com/repo/OracleLinux/OL9/appstream/x86_64/getPackage/boost-program-options-1.75.0-8.el9.x86_64.rpm; \
	rpmkeys --checksig /tmp/libev.rpm /tmp/pv.rpm /tmp/boost-program-options.rpm; \
	rpm -i /tmp/libev.rpm /tmp/pv.rpm /tmp/boost-program-options.rpm; \
	rm -rf /tmp/libev.rpm /tmp/pv.rpm /tmp/boost-program-options.rpm

RUN set -ex; \
	microdnf install -y \
	shadow-utils \
	hostname \
	libaio \
	iproute \
	tar \
	cracklib-dicts \
	openssl \
	numactl-libs \
	jq \
	socat \
	iputils \
	procps-ng \
	util-linux \
	findutils; \
	microdnf clean all; \
	rm -rf /var/cache/dnf /var/cache/yum

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql; \
	useradd -u 1001 -r -g 1001 -s /sbin/nologin \
	-c "Default Application User" mysql

# we need licenses from docs
RUN set -ex; \
	curl -Lf -o /tmp/percona-xtrabackup.rpm http://repo.percona.com/tools/yum/release/9/RPMS/x86_64/percona-xtrabackup-80-${FULL_PERCONA_XTRABACKUP_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/percona-server-shared.rpm http://repo.percona.com/ps-80/yum/${PXC_REPO}/9/RPMS/x86_64/percona-server-shared-${FULL_PERCONA_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/percona-xtradb-cluster-garbd.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/9/RPMS/x86_64/percona-xtradb-cluster-garbd-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
	curl -Lf -o /tmp/percona-xtradb-cluster-client.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/9/RPMS/x86_64/percona-xtradb-cluster-client-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
	rpmkeys --checksig /tmp/percona-xtradb-cluster-garbd.rpm /tmp/percona-xtrabackup.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-server-shared.rpm; \
	rpm -iv /tmp/percona-xtradb-cluster-garbd.rpm /tmp/percona-xtrabackup.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-server-shared.rpm --nodeps; \
	rm -rf /tmp/percona-xtradb-cluster-garbd.rpm /tmp/percona-xtrabackup.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-server-shared.rpm; \
	rpm -ql percona-xtradb-cluster-client | egrep -v "mysql$|mysqldump$|mysqlbinlog$" | xargs rm -rf; \
	microdnf clean all; \
	rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtrabackup-80/LICENSE /licenses/LICENSE.xtrabackup; \
	cp /usr/share/doc/percona-xtradb-cluster-garbd-3/COPYING /licenses/LICENSE.garbd

RUN curl -o /usr/bin/kubectl \
	https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl; \
	chmod +x /usr/bin/kubectl; \
	echo "${KUBECTL_SHA512SUM} /usr/bin/kubectl" | sha512sum -c -; \
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
