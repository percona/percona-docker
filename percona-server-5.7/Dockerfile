FROM centos:8

LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="Percona Server for MySQL"
LABEL org.label-schema.vendor="Percona"
LABEL org.label-schema.description="Percona Server for MySQL® is a free, fully compatible, \
enhanced and open source drop-in replacement for any MySQL database. \
It provides superior performance, scalability and instrumentation."
LABEL org.label-schema.license="GPL"

LABEL org.opencontainers.image.title="Percona Server for MySQL"
LABEL org.opencontainers.image.vendor="Percona"
LABEL org.opencontainers.image.description="Percona Server for MySQL® is a free, fully compatible, \
enhanced and open source drop-in replacement for any MySQL database. \
It provides superior performance, scalability and instrumentation."
LABEL org.opencontainers.image.license="GPL"
LABEL org.opencontainers.image.authors="info@percona.com"

ENV PS_VERSION 5.7.31-34.1
ENV OS_VER el8
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
LABEL org.label-schema.schema-version=${PS_VERSION}
LABEL org.opencontainers.image.version=${PS_VERSION}

RUN groupadd -g 1001 mysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
		-c "Default Application User" mysql

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
    dnf -y module disable mysql

RUN set -ex; \
    dnf install -y \
        dnf-utils \
        jemalloc \
        cracklib-dicts \
        which; \
    \
    repoquery -a --location \
        policycoreutils \
            | xargs curl -Lf -o /tmp/policycoreutils.rpm; \
    repoquery -a --location \
        selinux-policy \
            | xargs curl -Lf -o /tmp/selinux-policy.rpm; \
    rpm -iv /tmp/policycoreutils.rpm /tmp/selinux-policy.rpm --nodeps; \
    rm -rf /tmp/policycoreutils.rpm /tmp/selinux-policy.rpm; \
    \
    dnf install -y \
        Percona-Server-server-57-${FULL_PERCONA_VERSION} \
        Percona-Server-devel-57-${FULL_PERCONA_VERSION} \
        Percona-Server-tokudb-57-${FULL_PERCONA_VERSION} \
        Percona-Server-rocksdb-57-${FULL_PERCONA_VERSION}; \
    dnf remove -y dnf-utils; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/lib/mysql

# purge and re-create /var/lib/mysql with appropriate ownership
RUN /usr/bin/install -m 0775 -o mysql -g root -d /var/lib/mysql /var/run/mysqld /docker-entrypoint-initdb.d; \
# comment out a few problematic configuration values
	find /etc/percona-server.cnf /etc/percona-server.conf.d /etc/my.cnf.d -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log|user)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log|user)/#&/'; \
# don't reverse lookup hostnames, they are usually another container
	printf '[mysqld]\nskip-host-cache\nskip-name-resolve\n' > /etc/my.cnf.d/docker.cnf; \
# TokuDB modifications
	/usr/bin/install -m 0664 -o mysql -g root /dev/null /etc/sysconfig/mysql; \
	echo "LD_PRELOAD=/usr/lib64/libjemalloc.so.1" >> /etc/sysconfig/mysql; \
	echo "THP_SETTING=never" >> /etc/sysconfig/mysql; \
# keep backward compatibility with debian images
	ln -s /etc/my.cnf.d /etc/mysql; \
# allow to change config files
	chown -R mysql:root /etc/percona-server.cnf /etc/percona-server.conf.d /etc/my.cnf.d; \
	chmod -R ug+rwX /etc/percona-server.cnf /etc/percona-server.conf.d /etc/my.cnf.d

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

COPY ps-entry.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

USER mysql
EXPOSE 3306
CMD ["mysqld"]