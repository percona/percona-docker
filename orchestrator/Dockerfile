FROM redhat/ubi9-minimal AS ubi9

LABEL name="orchestrator" \
      description="orchestrator is a MySQL high availability and replication management tool" \
      vendor="Percona" \
      summary="orchestrator is a MySQL high availability and replication management tool" \
      org.opencontainers.image.authors="info@percona.com"

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& microdnf install -y findutils \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 \
	&& gpg --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
	&& rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
	&& curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
        && percona-release setup pdps-8.0 \
        && percona-release enable-only pdps-8.0 testing

RUN set -ex; \
    microdnf install -y \
        shadow-utils \
        percona-orchestrator \
        percona-orchestrator-client \
        which \
        tar \
        openssl \
        procps-ng \
        vim-minimal \
        bind-utils \
        policycoreutils; \
    microdnf -y update \
        curl-minimal \
        glibc \
        krb5-libs \
        pam \
        bind-utils \
        libnghttp2; \
    \
    microdnf clean all; \
    rm -rf /var/cache

RUN groupadd -g 1001 mysql
RUN useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

STOPSIGNAL SIGUSR1

RUN set -ex; \
    mkdir -p /etc/orchestrator /var/lib/orchestrator ; \
    chown -R 1001:1001 /etc/orchestrator /var/lib/orchestrator
COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-orchestrator/LICENSE /licenses/LICENSE.orchestrator

COPY dockerdir /

RUN set -ex; \
    chown 1001:1001 /etc/orchestrator/orchestrator.conf.json /etc/orchestrator/orc-topology.cnf

USER 1001
EXPOSE 3000 10008
VOLUME ["/var/lib/orchestrator"]

WORKDIR /usr/local/orchestrator
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/orchestrator/orchestrator", "-config", "/etc/orchestrator/orchestrator.conf.json", "http"]
