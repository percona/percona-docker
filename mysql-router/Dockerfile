FROM redhat/ubi9-minimal AS ubi9

LABEL name="mysql-router" \
      description="MySQL Router is lightweight middleware that provides transparent routing between your application and back-end MySQL Servers" \
      vendor="Percona" \
      summary="MySQL Router is lightweight middleware that provides transparent routing between your application and back-end MySQL Servers" \
      org.opencontainers.image.authors="info@percona.com"

ENV ROUTE_VERSION 8.0.40-31.1
ENV MYSQL_SHELL_VERSION 8.0.40-1
ENV OS_VER el9
ENV FULL_ROUTE_VERSION "$ROUTE_VERSION.$OS_VER"
ENV FULL_MYSQL_SHELL_VERSION "$MYSQL_SHELL_VERSION.$OS_VER"

RUN set -ex; \
    # shadow-utils are needed for user/group manipulation on UBI-based images
    microdnf -y update; \
    microdnf -y install glibc-langpack-en \
        nss_wrapper \
        shadow-utils; \
    microdnf clean all; \
    groupadd -g 1001 mysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -m -c "Default Application User" mysql

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& microdnf install -y findutils \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D \
	&& gpg --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
	&& rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
	&& curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
        && percona-release enable ps-80 testing \
        && percona-release enable mysql-shell testing

RUN set -ex; \
    microdnf install -y \
        percona-mysql-router-${FULL_ROUTE_VERSION} \
        percona-mysql-shell-${FULL_MYSQL_SHELL_VERSION} \
        which \
        tar \
        openssl \
        vim-minimal \
        procps-ng \
        bind-utils \
        policycoreutils; \
    \
    microdnf clean all; \
    rm -rf /var/cache

COPY dockerdir /

RUN set -ex; \
    mkdir -p /tmp/mysqlrouter/run /var/lib/mysqlrouter ; \
    chown -R 1001:1001 /tmp/mysqlrouter/run /var/lib/mysqlrouter ; \
    chmod -R 777 /var/log/mysqlrouter ; \
    chmod -R 777 /tmp/mysqlrouter ; \
    chmod -R 777 /etc/mysqlrouter

VOLUME ["/var/lib/mysqlrouter"]

USER 1001
ENTRYPOINT ["/entrypoint.sh"]
CMD ["mysqlrouter"]
