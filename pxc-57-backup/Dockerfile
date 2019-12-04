FROM registry.access.redhat.com/ubi7/ubi-minimal

LABEL name="Percona XtraBackup" \
	release="2.4" \
	vendor="Percona" \
	summary="Percona XtraBackup is an open-source hot backup utility for MySQL - based servers that doesn’t lock your database during the backup" \
	description="Percona XtraBackup works with MySQL, MariaDB, and Percona Server. It supports completely non-blocking backups of InnoDB, XtraDB, and HailDB storage engines. In addition, it can back up the following storage engines by briefly pausing writes at the end of the backup: MyISAM, Merge, and Archive, including partitioned tables, triggers, and database options." \
	maintainer="Percona Development <info@percona.com>"

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 6341AB2753D78A78A7C27BB124C6A8A7F4A80EB5 91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5 \
	&& gpg --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& gpg --export --armor 6341AB2753D78A78A7C27BB124C6A8A7F4A80EB5 > ${GNUPGHOME}/RPM-GPG-KEY-CentOS-7 \
	&& gpg --export --armor 91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-7 \
	&& rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-CentOS-7 ${GNUPGHOME}/RPM-GPG-KEY-EPEL-7 \
	&& curl -L -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY

# install exact version of PS for repeatability
ENV XTRABACKUP_VERSION 2.4.14-1.el7
ENV PS_VERSION 5.7.26-29.1.el7
ENV PXC_VERSION 5.7.26-31.37.1.el7
ENV KUBECTL_VERSION=v1.15.2
ENV KUBECTL_MD5SUM=daf020f5dc07314f4e388e4a6c9cc201

RUN curl -L -o /tmp/numactl-libs.rpm http://mirror.centos.org/centos/7/os/x86_64/Packages/numactl-libs-2.0.12-3.el7.x86_64.rpm \
	&& curl -L -o /tmp/libev.rpm http://mirror.centos.org/centos/7/extras/x86_64/Packages/libev-4.15-7.el7.x86_64.rpm \
	&& rpmkeys --checksig /tmp/numactl-libs.rpm /tmp/libev.rpm \
	&& rpm -i /tmp/numactl-libs.rpm /tmp/libev.rpm \
	&& rm -rf /tmp/numactl-libs.rpm /tmp/libev.rpm

RUN microdnf update -y \
        && microdnf install -y \
                Percona-Server-shared-57-${PS_VERSION} \
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
        && repoquery -a --location \
                iputils \
                    | xargs curl -L -o /tmp/iputils.rpm \
        && repoquery -a --location \
                Percona-XtraDB-Cluster-garbd-57-${PXC_VERSION} \
                    | xargs curl -L -o /tmp/Percona-XtraDB-Cluster-garbd-57.rpm \
        && repoquery -a --location \
                Percona-XtraDB-Cluster-client-57-${PXC_VERSION} \
                    | xargs curl -L -o /tmp/Percona-XtraDB-Cluster-client-57.rpm \
        && repoquery -a --location \
                 percona-xtrabackup-24 \
                    | xargs curl -L -o /tmp/percona-xtrabackup-24.rpm \
        && rpm -iv /tmp/iputils.rpm /tmp/Percona-XtraDB-Cluster-garbd-57.rpm /tmp/percona-xtrabackup-24.rpm /tmp/Percona-XtraDB-Cluster-client-57.rpm --nodeps \
        && rm -rf /tmp/iputils.rpm /tmp/Percona-XtraDB-Cluster-garbd-57.rpm /tmp/percona-xtrabackup-24.rpm /tmp/Percona-XtraDB-Cluster-client-57.rpm \
        && rpm -ql Percona-XtraDB-Cluster-client-57 | egrep -v "mysql$|mysqldump$" | xargs rm -rf \
        && microdnf remove -y \
               yum-utils \
               python-kitchen \
               python-chardet \
               libxml2-python \
               yum \	
        && microdnf clean all \
        && rm -rf /var/cache/yum /var/lib/mysql

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtrabackup-24-*/COPYING /licenses/LICENSE.xtrabackup \
	&& cp /usr/share/doc/percona-xtradb-cluster-garbd-3/COPYING /licenses/LICENSE.garbd

RUN curl -o /usr/bin/kubectl \
        https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && chmod +x /usr/bin/kubectl \
    && echo "${KUBECTL_MD5SUM} /usr/bin/kubectl" | md5sum -c - \
    && curl -o /licenses/LICENSE.kubectl \
        https://raw.githubusercontent.com/kubernetes/kubectl/master/LICENSE

RUN install -d -o 1001 -g 0 -m 0775 /backup
COPY mc /usr/bin/
COPY recovery-*.sh backup.sh get-pxc-state peer-list /usr/bin/

VOLUME ["/backup"]
USER 1001

CMD ["sleep","infinity"]
