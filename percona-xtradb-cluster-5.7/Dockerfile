FROM golang:1.13 AS go_builder
WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/src

RUN go get k8s.io/apimachinery/pkg/util/sets; \
    curl -Lf -o /go/src/github.com/percona/percona-xtradb-cluster-operator/src/peer-list.go https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/master/cmd/peer-list/main.go; \ 
    go build peer-list.go

FROM centos:8 AS centos8

LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="Percona XtraDB Cluster"
LABEL org.label-schema.vendor="Percona"
LABEL org.label-schema.description="Percona XtraDB Cluster is a high availability solution that \
helps enterprises avoid downtime and outages and meet expected customer experience."
LABEL org.label-schema.license="GPL"

LABEL org.opencontainers.image.title="Percona XtraDB Cluster"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="Percona XtraDB Cluster is a high availability solution that \
helps enterprises avoid downtime and outages and meet expected customer experience."
LABEL org.opencontainers.image.license="GPL"

ENV PXB_VERSION 2.4.20-1
ENV PS_VERSION 5.7.31-34.1
ENV PXC_VERSION 5.7.31-31.45.1
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRABACKUP_VERSION "$PXB_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRADBCLUSTER_VERSION "$PXC_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PXC_VERSION}
LABEL org.opencontainers.image.version=${PXC_VERSION}

# check repository package signature in secure way
RUN set -ex; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1; \
	gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
	gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
	gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
	rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8 ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
	curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
	rpmkeys --checksig /tmp/percona-release.rpm; \
	dnf install -y /tmp/percona-release.rpm; \
	rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
	rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
	dnf -y module disable mysql; \
	percona-release enable tools release

RUN set -ex; \
	curl -Lf -o /tmp/pv.rpm https://download.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/p/pv-1.6.6-7.el8.x86_64.rpm; \
	rpmkeys --checksig /tmp/pv.rpm; \
	rpm -i /tmp/pv.rpm; \
	rm -rf /tmp/pv.rpm

RUN set -ex; \
	dnf --setopt=install_weak_deps=False --best install -y \
		Percona-Server-shared-57-${FULL_PERCONA_VERSION} \
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
		nss-pam-ldapd \
		diffutils \
		numactl-libs \
		libev \
		jq \
		qpress \
		oniguruma \
		cracklib-dicts \
		dnf-utils; \
	dnf clean all; \
	rm -rf /var/cache/dnf

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql; \
	useradd -u 1001 -r -g 1001 -s /sbin/nologin \
		-c "Default Application User" mysql

# we need licenses from docs
RUN set -ex; \
	percona-release disable tools release; \
	repoquery -a --location \
		Percona-XtraDB-Cluster-server-57-${FULL_PERCONA_XTRADBCLUSTER_VERSION} \
		| xargs curl -Lf -o /tmp/Percona-XtraDB-Cluster-server-57.rpm; \
	repoquery -a --location \
		Percona-XtraDB-Cluster-shared-57-${FULL_PERCONA_XTRADBCLUSTER_VERSION} \
		| xargs curl -Lf -o /tmp/Percona-XtraDB-Cluster-shared-57.rpm; \
	repoquery -a --location \
		Percona-XtraDB-Cluster-client-57-${FULL_PERCONA_XTRADBCLUSTER_VERSION} \
		| xargs curl -Lf -o /tmp/Percona-XtraDB-Cluster-client-57.rpm; \
	repoquery -a --location \
		percona-xtrabackup-24-${FULL_PERCONA_XTRABACKUP_VERSION} \
		| xargs curl -Lf -o /tmp/percona-xtrabackup-24.rpm; \
	rpm -iv /tmp/Percona-XtraDB-Cluster-server-57.rpm /tmp/percona-xtrabackup-24.rpm /tmp/Percona-XtraDB-Cluster-shared-57.rpm /tmp/Percona-XtraDB-Cluster-client-57.rpm --nodeps; \
	rm -rf /tmp/Percona-XtraDB-Cluster-server-57.rpm /tmp/percona-xtrabackup-24.rpm /tmp/Percona-XtraDB-Cluster-shared-57.rpm /tmp/Percona-XtraDB-Cluster-client-57.rpm \
	       /usr/bin/mysqltest /usr/bin/perror /usr/bin/replace /usr/bin/resolve_stack_dump /usr/bin/resolveip \
	       /var/cache/dnf /var/lib/mysql /usr/lib64/mysql/plugin/debug /usr/sbin/mysqld-debug /usr/lib64/mecab /usr/lib64/mysql/mecab /usr/bin/myisam*; \
	dnf clean all; \
	rpm -ql Percona-XtraDB-Cluster-client-57 | egrep -v "mysql$|mysqldump$" | xargs rm -rf;

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtradb-cluster-galera/COPYING /licenses/LICENSE.galera; \
	cp /usr/share/doc/percona-xtradb-cluster-galera/LICENSE.* /licenses/

COPY dockerdir /
COPY --from=go_builder /go/src/github.com/percona/percona-xtradb-cluster-operator/src/peer-list /usr/bin/

RUN rm -rf /etc/my.cnf.d; \
	ln -s /etc/mysql/conf.d /etc/my.cnf.d; \
	rm -f /etc/percona-xtradb-cluster.conf.d/*.cnf; \
	echo '!include /etc/mysql/node.cnf' > /etc/my.cnf; \
	echo '!includedir /etc/my.cnf.d/' >> /etc/my.cnf; \
	echo '!includedir /etc/percona-xtradb-cluster.conf.d/' >> /etc/my.cnf; \
	mkdir -p /etc/mysql/conf.d/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d; \
	chown -R 1001:1001 /etc/mysql/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d; \
	chmod -R g=u /etc/mysql/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d

ARG DEBUG
RUN if [[ -n $DEBUG ]] ; then \
                set -ex; \
		sed -i '/\[mysqld\]/a wsrep_log_conflicts\nlog_error_verbosity=3\nwsrep_debug=1' /etc/mysql/node.cnf; \
		mv /usr/sbin/mysqld /usr/sbin/mysqld-ps; \
		cp /usr/local/bin/mysqld-debug /usr/sbin/mysqld; \
		repoquery -a --location \
			Percona-XtraDB-Cluster-57-debuginfo-${FULL_PERCONA_XTRADBCLUSTER_VERSION} \
			| xargs curl -Lf -o /tmp/Percona-XtraDB-Cluster-57-debuginfo-57.rpm; \
		rpmkeys --checksig /tmp/Percona-XtraDB-Cluster-57-debuginfo-57.rpm; \
		rpm -i /tmp/Percona-XtraDB-Cluster-57-debuginfo-57.rpm --nodeps; \
		rm -rf /tmp/Percona-XtraDB-Cluster-57-debuginfo-57.rpm; \
		dnf install -y \
			net-tools \
			telnet \
			nc \
			gdb; \
		dnf clean all; \
		rm -rf /var/cache/dnf; \
	fi

USER 1001

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 4567 4568
CMD ["mysqld"]
