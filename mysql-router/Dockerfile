FROM redhat/ubi8-minimal AS ubi8

LABEL name="mysql-router" \
      description="MySQL Router is lightweight middleware that provides transparent routing between your application and back-end MySQL Servers" \
      vendor="Percona" \
      summary="MySQL Router is lightweight middleware that provides transparent routing between your application and back-end MySQL Servers" \
      org.opencontainers.image.authors="info@percona.com"

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& microdnf install -y findutils \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
	&& gpg --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona \
	&& curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
        && percona-release setup pdps-8.0 \
        && curl -Lf -o /tmp/numactl-libs.rpm http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/numactl-libs-2.0.12-11.el8.x86_64.rpm\
        && rpmkeys --checksig /tmp/numactl-libs.rpm \
        && rpm -i /tmp/numactl-libs.rpm \
        && rm -rf /tmp/numactl-libs.rpm

RUN set -ex; \
    microdnf install -y \
        shadow-utils \
        percona-server-server \
        percona-mysql-router \
        percona-mysql-shell \
        which \
        tar \
        openssl \
        procps-ng \
        bind-utils \
        policycoreutils; \
    \
    microdnf clean all; \
    rm -rf /var/cache

RUN groupadd -g 1001 mysql
RUN useradd -m -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

STOPSIGNAL SIGUSR1

COPY dockerdir /

RUN set -ex; \
    mkdir -p /tmp/mysqlrouter/run /var/lib/mysqlrouter ; \
    chown -R 1001:1001 /tmp/mysqlrouter/run /var/lib/mysqlrouter

VOLUME ["/var/lib/mysqlrouter"]

USER 1001
ENTRYPOINT ["/entrypoint.sh"]
CMD ["mysqlrouter", "-c", "/tmp/router/mysqlrouter.conf"]
