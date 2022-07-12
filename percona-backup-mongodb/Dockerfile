FROM redhat/ubi8-minimal

# Please don't remove old-style LABEL since it's needed for RedHat certification
LABEL name="Percona Backup for MongoDB" \
    vendor="Percona" \
    summary="Percona Backup for MongoDB" \
    description="Percona Backup for MongoDB is a distributed, \
    low-impact solution for achieving consistent backups of MongoDB Sharded Clusters and Replica Sets." \
    org.opencontainers.image.authors="info@percona.com"

LABEL org.opencontainers.image.title="Percona Backup for MongoDB" \
    org.opencontainers.image.vendor="Percona" \
    org.opencontainers.image.description="Percona Backup for MongoDB is a distributed, \
    low-impact solution for achieving consistent backups of MongoDB Sharded Clusters and Replica Sets." \
    org.opencontainers.image.authors="info@percona.com"

ENV PBM_VERSION 1.8.1-1
ENV PBM_REPO_CH release
ENV PSMDB_REPO psmdb-42
ENV PSMDB_REPO_CH release
ENV OS_VER el8
ENV FULL_PBM_VERSION "$PBM_VERSION.$OS_VER"

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable pbm ${PBM_REPO_CH}; \
    percona-release enable ${PSMDB_REPO} ${PSMDB_REPO_CH}

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install \
        jq \
        oniguruma; \
    microdnf -y install \
        percona-backup-mongodb-${FULL_PBM_VERSION}; \
    microdnf -y install percona-server-mongodb-shell; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

# kubectl needed for Percona Operator for PSMDB
ENV KUBECTL_VERSION=v1.19.12
ENV KUBECTL_MD5SUM=7c6a25afdec07da2cf1e1c1caf9e4381
RUN set -ex; \
    curl -Lf -o /usr/bin/kubectl \
        https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/bin/kubectl; \
    echo "${KUBECTL_MD5SUM} /usr/bin/kubectl" | md5sum -c -; \
    mkdir -p /licenses; \
    curl -Lf  -o /licenses/LICENSE.kubectl \
        https://raw.githubusercontent.com/kubernetes/kubectl/master/LICENSE

USER nobody

# Containers should be started either with --mongodb-uri flag or with PBM_MONGODB_URI env variable
# Also, one can map volume to /etc (/etc/sysconfig/pbm-agent, /etc/pbm-storage.conf)
CMD ["pbm-agent"]
COPY ./start-agent.sh /start-agent.sh
ENTRYPOINT ["/start-agent.sh"]
