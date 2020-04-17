FROM registry.access.redhat.com/ubi7/ubi-minimal

LABEL org.opencontainers.image.release="8.0"
LABEL org.opencontainers.image.title="Percona XtraBackup"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="Percona XtraBackup works with MySQL, MariaDB, and \
Percona Server. It supports completely non-blocking backups of InnoDB, XtraDB, and HailDB storage engines. \
In addition, it can back up the following storage engines by briefly pausing writes at the end of the backup: \
MyISAM, Merge, and Archive, including partitioned tables, triggers, and database options."
LABEL org.opencontainers.image.license="Apache 2.0"
LABEL org.opencontainers.image.authors="info@percona.com"
LABEL org.opencontainers.image.maintainer="Percona Development <info@percona.com>"

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
	&& gpg --batch --keyserver pool.sks-keyservers.net --recv-keys 6341AB2753D78A78A7C27BB124C6A8A7F4A80EB5 \
	&& gpg --batch --keyserver pool.sks-keyservers.net --recv-keys 91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5 \
	&& gpg --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& gpg --export --armor 6341AB2753D78A78A7C27BB124C6A8A7F4A80EB5 > ${GNUPGHOME}/RPM-GPG-KEY-CentOS-7 \
	&& gpg --export --armor 91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-7 \
	&& rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-CentOS-7 ${GNUPGHOME}/RPM-GPG-KEY-EPEL-7 \
	&& curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY

# install exact version of PS for repeatability
ENV XTRABACKUP_VERSION 8.0.11-1.el7
ENV PS_VERSION 8.0.18-9.1.el7
ENV PXC_VERSION 8.0.18-9.2.el7
ENV PXC_REPO testing
ENV KUBECTL_VERSION=v1.15.6
ENV KUBECTL_SHA256SUM=522115e0f11d83c08435a05e76120c89ea320782ccaff8e301bd14588ec50145

RUN curl -Lf -o /tmp/numactl-libs.rpm http://mirror.centos.org/centos/7/os/x86_64/Packages/numactl-libs-2.0.12-3.el7.x86_64.rpm \
	&& curl -Lf -o /tmp/libev.rpm http://mirror.centos.org/centos/7/extras/x86_64/Packages/libev-4.15-7.el7.x86_64.rpm \
	&& curl -Lf -o /tmp/jq.rpm https://download.fedoraproject.org/pub/epel/7/x86_64/Packages/j/jq-1.6-1.el7.x86_64.rpm \
	&& curl -Lf -o /tmp/oniguruma.rpm https://download.fedoraproject.org/pub/epel/7/x86_64/Packages/o/oniguruma-5.9.5-3.el7.x86_64.rpm \
	&& rpmkeys --checksig /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm \
	&& rpm -i /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm \
	&& rm -rf /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm

RUN microdnf update -y \
	&& microdnf install -y \
		socat \
		shadow-utils \
		hostname \
		yum-utils \
		libaio \
	&& microdnf clean all

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql \
	&& useradd -u 1001 -r -g 1001 -s /sbin/nologin \
		-c "Default Application User" mysql

# we need licenses from docs
RUN sed -i '/nodocs/d' /etc/yum.conf || : \
	&& repoquery -a --location iputils | xargs curl -Lf -o /tmp/iputils.rpm \
	&& curl -Lf -o /tmp/percona-xtrabackup.rpm http://repo.percona.com/tools/yum/testing/7/RPMS/x86_64/percona-xtrabackup-80-${XTRABACKUP_VERSION}.x86_64.rpm \
	&& curl -Lf -o /tmp/percona-server-shared.rpm http://repo.percona.com/ps-80/yum/release/7/RPMS/x86_64/percona-server-shared-${PS_VERSION}.x86_64.rpm \
	&& curl -Lf -o /tmp/percona-xtradb-cluster-garbd.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/7/RPMS/x86_64/percona-xtradb-cluster-garbd-${PXC_VERSION}.x86_64.rpm \
	&& curl -Lf -o /tmp/percona-xtradb-cluster-client.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/7/RPMS/x86_64/percona-xtradb-cluster-client-${PXC_VERSION}.x86_64.rpm \
	&& rpm -iv /tmp/iputils.rpm /tmp/percona-xtradb-cluster-garbd.rpm /tmp/percona-xtrabackup.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-server-shared.rpm --nodeps \
	&& rm -rf /tmp/iputils.rpm /tmp/percona-xtradb-cluster-garbd.rpm /tmp/percona-xtrabackup.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-server-shared.rpm \
	&& rpm -ql percona-xtradb-cluster-client | egrep -v "mysql$|mysqldump$" | xargs rm -rf \
	&& microdnf remove -y \
		yum-utils \
		python-kitchen \
		python-chardet \
		libxml2-python \
		yum \
	&& microdnf clean all \
	&& rm -rf /var/cache/yum /var/lib/mysql

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtrabackup-80-*/LICENSE /licenses/LICENSE.xtrabackup \
	&& cp /usr/share/doc/percona-xtradb-cluster-garbd-3/COPYING /licenses/LICENSE.garbd

RUN curl -o /usr/bin/kubectl \
        https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && chmod +x /usr/bin/kubectl \
    && echo "${KUBECTL_SHA256SUM} /usr/bin/kubectl" | sha256sum -c - \
    && curl -o /licenses/LICENSE.kubectl \
        https://raw.githubusercontent.com/kubernetes/kubectl/master/LICENSE

RUN install -d -o 1001 -g 0 -m 0775 /backup \
	&& mkdir /usr/lib/pxc

COPY lib/pxc /usr/lib/pxc
COPY mc /usr/bin/
COPY recovery-*.sh backup.sh get-pxc-state peer-list /usr/bin/

VOLUME ["/backup"]
USER 1001

CMD ["sleep","infinity"]
