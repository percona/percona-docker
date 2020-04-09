FROM centos:7

LABEL name="Percona XtraDB Cluster" \
	release="8.0" \
	vendor="Percona" \
	summary="Percona XtraDB Cluster is an active/active high availability and high scalability open source solution for MySQL clustering" \
	description="Percona XtraDB Cluster is a high availability solution that helps enterprises avoid downtime and outages and meet expected customer experience." \
	maintainer="Percona Development <info@percona.com>"

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 6341AB2753D78A78A7C27BB124C6A8A7F4A80EB5 91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5 \
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
ENV PS_VERSION 8.0.17-8.1.el7
ENV PXC_VERSION 8.0.18-9.2.el7
ENV PXC_REPO testing

RUN curl -Lf -o /tmp/numactl-libs.rpm http://mirror.centos.org/centos/7/os/x86_64/Packages/numactl-libs-2.0.12-3.el7.x86_64.rpm \
	&& curl -Lf -o /tmp/libev.rpm http://mirror.centos.org/centos/7/extras/x86_64/Packages/libev-4.15-7.el7.x86_64.rpm \
	&& curl -Lf -o /tmp/jq.rpm https://download.fedoraproject.org/pub/epel/7/x86_64/Packages/j/jq-1.6-1.el7.x86_64.rpm \
	&& curl -Lf -o /tmp/oniguruma.rpm https://download.fedoraproject.org/pub/epel/7/x86_64/Packages/o/oniguruma-5.9.5-3.el7.x86_64.rpm \
	&& curl -Lf -o /tmp/pv.rpm https://download.fedoraproject.org/pub/epel/7/x86_64/Packages/p/pv-1.4.6-1.el7.x86_64.rpm \
	&& rpmkeys --checksig /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm \
	&& rpm -i /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm \
	&& rm -rf /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm

RUN yum update -y \
	&& rpm -e --nodeps tzdata \
	&& percona-release setup ps80 \
	&& yum install -y \
		jemalloc \
		socat \
		openssl \
		shadow-utils \
		hostname \
		curl \
		tzdata \
		libaio \
		which \
		pam \
	&& yum clean all

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql \
	&& useradd -u 1001 -r -g 1001 -s /sbin/nologin \
		-c "Default Application User" mysql

# we need licenses from docs
RUN sed -i '/nodocs/d' /etc/yum.conf || : \
	&& yum install -y \
		yum-utils \
	&& curl -Lf -o /tmp/percona-xtradb-cluster-server.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/7/RPMS/x86_64/percona-xtradb-cluster-server-${PXC_VERSION}.x86_64.rpm \
	&& curl -Lf -o /tmp/percona-xtradb-cluster-shared.rpm  https://repo.percona.com/pxc-80/yum/${PXC_REPO}/7/RPMS/x86_64/percona-xtradb-cluster-shared-${PXC_VERSION}.x86_64.rpm \
	&& curl -Lf -o /tmp/percona-xtradb-cluster-client.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/7/RPMS/x86_64/percona-xtradb-cluster-client-${PXC_VERSION}.x86_64.rpm \
	&& curl -Lf -o /tmp/percona-xtradb-cluster-shared-compat.rpm https://repo.percona.com/pxc-80/yum/${PXC_REPO}/7/RPMS/x86_64/percona-xtradb-cluster-shared-compat-${PXC_VERSION}.x86_64.rpm \
	&& rpm -iv /tmp/percona-xtradb-cluster-server.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-xtradb-cluster-shared.rpm /tmp/percona-xtradb-cluster-shared-compat.rpm --nodeps \
	&& rm -rf /tmp/percona-xtradb-cluster-server.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-xtradb-cluster-shared-compat.rpm /tmp/percona-xtradb-cluster-shared.rpm \
	&& yum clean all \
	&& rm -rf /usr/bin/mysqltest /usr/bin/perror /usr/bin/replace /usr/bin/resolve_stack_dump /usr/bin/resolveip \
	&& rm -rf /var/cache/yum /var/lib/mysql /usr/lib64/mysql/plugin/debug /usr/sbin/mysqld-debug /usr/lib64/mecab /usr/lib64/mysql/mecab /usr/bin/myisam* \
	&& rpm -ql percona-xtradb-cluster-client | egrep -v "mysql$|mysqldump$|mysqladmin$" | xargs rm -rf

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtradb-cluster-galera/COPYING /licenses/LICENSE.galera \
	&& cp /usr/share/doc/percona-xtradb-cluster-galera/LICENSE.* /licenses/


RUN rmdir /etc/my.cnf.d \
	&& ln -s /etc/mysql/conf.d /etc/my.cnf.d \
	&& rm -f /etc/percona-xtradb-cluster.conf.d/*.cnf \
	&& echo '!include /etc/mysql/node.cnf' > /etc/my.cnf \
	&& echo '!includedir /etc/my.cnf.d/' >> /etc/my.cnf \
	&& echo '!includedir /etc/percona-xtradb-cluster.conf.d/' >> /etc/my.cnf

COPY dockerdir /
RUN mkdir -p /etc/mysql/conf.d/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d /etc/percona-xtradb-cluster.conf.d \
	&& chown -R 1001:1001 /etc/mysql/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d /etc/percona-xtradb-cluster.conf.d \
	&& chmod -R g=u /etc/mysql/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d /etc/percona-xtradb-cluster.conf.d

ARG DEBUG
RUN if [[ -n $DEBUG ]] ; then \
		sed -i '/\[mysqld\]/a wsrep_log_conflicts\nlog_error_verbosity=3\nwsrep_debug=1' /etc/mysql/node.cnf \
		&& sed -i 's/exec "$@" $wsrep_start_position_opt/"$@" $wsrep_start_position_opt || sleep infinity/' /entrypoint.sh \
		&& yum install -y \
			gdb \
			net-tools \
			telnet \
			nc \
		&& yum clean all; \
	fi

USER 1001

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 4567 4568 33060
CMD ["mysqld"]
