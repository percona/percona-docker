FROM redhat/ubi9-minimal

LABEL name="XtraBackup" \
      description="Percona XtraBackup is an open-source tool that performs hot, non-blocking backups of MySQL and Percona Server databases with minimal downtime" \
      vendor="Percona" \
      summary="Percona XtraBackup is a powerful backup utility for MySQL and Percona Server" \
      maintainer="Percona Development <info@percona.com>" \
      org.opencontainers.image.authors="info@percona.com"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en

ENV XTRABACKUP_VERSION 8.0.35-33.1
ENV PS_VERSION 8.0.41-32.1
ENV OS_VER el9
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV PXB_TELEMETRY_VERSION "$XTRABACKUP_VERSION"
ENV FULL_PERCONA_XTRABACKUP_VERSION "$XTRABACKUP_VERSION.$OS_VER"
ENV CALL_HOME_DOWNLOAD_SHA256 5e84d2f1a5d57f44c46e6a1f16794d649d3de09fe8021f0294bc321c89e51068
ENV KEY_RPM_DOWNLOAD_SHA256 fcf0eab4f05a1c0de6363ac4b707600a27a9d774e9b491059e59e6921b255a84
ENV CALL_HOME_VERSION 0.1
# Do not report during Docker image creation.
# Note that doing so, would create telemetry config file
# which would prevent reporting when new container is started.
# If we want to track Docker image creation as well,
# remove telemetry config file after installing packages!
ARG PERCONA_TELEMETRY_DISABLE=1

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D FB5DB77FD5C118B80511ADA8A6310ACC4672475C BC528686B50D79E339D3721CEB3E94ADBE1229CF; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor FB5DB77FD5C118B80511ADA8A6310ACC4672475C > ${GNUPGHOME}/RPM-GPG-KEY-aws; \
    gpg --batch --export --armor BC528686B50D79E339D3721CEB3E94ADBE1229CF > ${GNUPGHOME}/RPM-GPG-KEY-Microsoft; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-aws ${GNUPGHOME}/RPM-GPG-KEY-Microsoft; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    curl -Lf -o /tmp/packages-microsoft-prod.rpm https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    #microdnf -y module disable mysql perl-DBD-MySQL; \
    percona-release disable all; \
    #percona-release setup -y ps-80; \
    percona-release enable ps-80; \
    percona-release enable tools testing; \
    percona-release enable pxc-80 testing; \
    percona-release enable pxb-80 testing

RUN set -ex; \
    microdnf -y install \
        tar \
        unzip \
        shadow-utils

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

RUN if [ "$(uname -m)" = "x86_64" ]; then \
        curl -Lf -o /tmp/libev.rpm https://downloads.percona.com/downloads/packaging/libev-4.33-5.el9.x86_64.rpm; \
    else \
        curl -Lf -o /tmp/libev.rpm https://mirror.stream.centos.org/9-stream/BaseOS/aarch64/os/Packages/libev-4.33-5.el9.aarch64.rpm; \
    fi

RUN if [ "$(uname -m)" = "x86_64" ]; then \
        curl -o /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip; \
        curl -o /tmp/awscliv2.sig https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sig; \
    else \
        curl -o /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip; \
        curl -o /tmp/awscliv2.sig https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip.sig; \
    fi

RUN set -ex; \
    unzip -q /tmp/awscliv2.zip -d /tmp/; \
    /tmp/aws/install; \
    rpm -i /tmp/libev.rpm; \
    rpm -i /tmp/packages-microsoft-prod.rpm; \
    rm -rf /tmp/libev.rpm /tmp/awscliv2.zip /tmp/awscliv2.sig /tmp/aws /tmp/packages-microsoft-prod.rpm; \
    #dnf --setopt=install_weak_deps=False --best install -y \
    microdnf -y install \
        percona-xtrabackup-80-${FULL_PERCONA_XTRABACKUP_VERSION} \
        percona-xtradb-cluster-garbd \
        percona-server-shared-${FULL_PERCONA_VERSION} \
        percona-server-client-${FULL_PERCONA_VERSION} \
        socat \
        hostname \
        jq \
        procps-ng \
        qpress \
        lz4 \
        azure-cli \
        zstd; \
    \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN install -d -o 1001 -g 0 -m 0775 /backup

RUN set -eux; \
    curl -fL "https://github.com/Percona-Lab/telemetry-agent/archive/refs/tags/phase-$CALL_HOME_VERSION.tar.gz" -o "phase-$CALL_HOME_VERSION.tar.gz"; \
    echo "$CALL_HOME_DOWNLOAD_SHA256 phase-$CALL_HOME_VERSION.tar.gz" | sha256sum --strict --check; \
    tar -xvf phase-$CALL_HOME_VERSION.tar.gz; \
    cp telemetry-agent-phase-$CALL_HOME_VERSION/call-home.sh .;\
    rm -rf telemetry-agent-phase-$CALL_HOME_VERSION phase-$CALL_HOME_VERSION.tar.gz; \
    chmod a+rx /call-home.sh; \
    mkdir -p /usr/local/percona; \
    chown mysql:mysql /usr/local/percona
ENV CALL_HOME_OPTIONAL_PARAMS=" -s ${OS_VER}"

COPY LICENSE /licenses/LICENSE.Dockerfile

COPY pxb-entry.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

VOLUME [ "/backup" ]
USER 1001

CMD ["/usr/bin/xtrabackup"]
