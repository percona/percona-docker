FROM registry.access.redhat.com/ubi8/ubi-minimal AS ubi8

LABEL name="orchestrator" \
      description="orchestrator is a MySQL high availability and replication management tool" \
      vendor="Percona" \
      summary="orchestrator is a MySQL high availability and replication management tool" \
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
	&& percona-release setup pdps-8.0


RUN set -ex; \
    microdnf install -y \
        shadow-utils \
        percona-orchestrator \
        which \
        tar \
        openssl \
        procps-ng \
        vim-minimal \
        policycoreutils; \
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
CMD ["/usr/local/orchestrator/orchestrator", "-quiet", "-config", "/etc/orchestrator/orchestrator.conf.json", "http"]
