FROM redhat/ubi9-minimal

LABEL org.opencontainers.image.authors="info@percona.com"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en

ENV XTRABACKUP_VERSION 8.0.35-32.1
ENV PS_VERSION 8.0.39-30.1
ENV OS_VER el9
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRABACKUP_VERSION "$XTRABACKUP_VERSION.$OS_VER"

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D FB5DB77FD5C118B80511ADA8A6310ACC4672475C; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor FB5DB77FD5C118B80511ADA8A6310ACC4672475C > ${GNUPGHOME}/RPM-GPG-KEY-aws; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-aws; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    curl -o /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip; \
    curl -o /tmp/awscliv2.sig https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sig; \
    gpg --verify /tmp/awscliv2.sig /tmp/awscliv2.zip; \
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

RUN set -ex; \
    unzip -q /tmp/awscliv2.zip -d /tmp/; \
    /tmp/aws/install; \
    rpm -i /tmp/libev.rpm; \
    rm -rf /tmp/libev.rpm /tmp/awscliv2.zip /tmp/awscliv2.sig /tmp/aws; \
    #dnf --setopt=install_weak_deps=False --best install -y \
    microdnf -y install \
        percona-xtrabackup-80-${FULL_PERCONA_XTRABACKUP_VERSION} \
        percona-xtradb-cluster-garbd-${FULL_PERCONA_VERSION} \
        percona-server-shared-${FULL_PERCONA_VERSION} \
        percona-server-client-${FULL_PERCONA_VERSION} \
        socat \
        hostname \
        jq \
        procps-ng \
        qpress \
        lz4 \
        zstd; \
    \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN install -d -o 1001 -g 0 -m 0775 /backup

VOLUME [ "/backup" ]
USER 1001

CMD ["/usr/bin/xtrabackup"]
