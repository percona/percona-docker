FROM centos:7

LABEL name="ProxySQL" \
	release="2.0" \
	vendor="Percona" \
	summary="High-performance MySQL proxy with a GPL license" \
	description="ProxySQL is a high performance, high availability, protocol aware proxy for MySQL and forks (like Percona Server and MariaDB). All the while getting the unlimited freedom that comes with a GPL license." \
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
ENV PS_VERSION 5.7.26-29.1.el7
ENV PROXYSQL_VERSION 2.0.4-1.2.el7

RUN yum update -y \
	&& yum install -y \
		Percona-Server-client-57-${PS_VERSION} \
		Percona-Server-shared-57-${PS_VERSION} \
		shadow-utils \
		which \
	&& yum clean all

RUN groupadd -g 1001 proxysql \
    && useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" proxysql

# we need licenses from docs
RUN sed -i '/nodocs/d' /etc/yum.conf || : \
	&& yum install -y \
		proxysql2-${PROXYSQL_VERSION} \
	&& yum clean all \
	&& rm -rf /var/cache/yum /etc/proxysql /var/lib/proxysql \
	&& install -o 1001 -g 0 -m 775 -d /etc/proxysql /var/lib/proxysql

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/proxysql2-$(echo ${PROXYSQL_VERSION} | cut -d - -f 1)/LICENSE /licenses/LICENSE.proxysql

COPY dockerdir /
RUN chown 1001:1001 /etc/proxysql/proxysql.cnf /etc/proxysql-admin.cnf \
    && chmod 664 /etc/proxysql/proxysql.cnf /etc/proxysql-admin.cnf

USER 1001

VOLUME /var/lib/proxysql

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 6032
CMD ["/usr/bin/proxysql", "-f", "-c", "/etc/proxysql/proxysql.cnf"]
