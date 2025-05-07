FROM redhat/ubi9-minimal

LABEL org.opencontainers.image.authors="info@percona.com"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en

ENV XTRABACKUP_VERSION 2.4.29-1
ENV PS_VERSION 5.7.44-48.1
ENV PXC_VERSION 5.7.44-31.65.1
ENV OS_VER el9
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV FULL_PXC_VERSION "$PXC_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRABACKUP_VERSION "$XTRABACKUP_VERSION.$OS_VER"

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
    curl -o /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip; \
    curl -o /tmp/awscliv2.sig https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sig; \
    gpg --verify /tmp/awscliv2.sig /tmp/awscliv2.zip; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    #microdnf -y module disable mysql perl-DBD-MySQL; \
    percona-release enable tools testing; \
    percona-release enable pxc-57 testing; \
    percona-release enable ps-57 testing

RUN set -ex; \
     microdnf -y install \
         unzip

RUN set -ex; \
    curl -Lf -o /tmp/libev.rpm https://downloads.percona.com/downloads/packaging/libev-4.33-5.el9.x86_64.rpm; \
    unzip -q /tmp/awscliv2.zip -d /tmp/; \
    /tmp/aws/install; \
    rpm -i /tmp/libev.rpm; \
    rpm -i /tmp/packages-microsoft-prod.rpm; \
    rm -rf /tmp/libev.rpm /tmp/awscliv2.zip /tmp/awscliv2.sig /tmp/aws /tmp/packages-microsoft-prod.rpm; \
    #dnf --setopt=install_weak_deps=False install -y \
    microdnf -y install \
        percona-xtrabackup-24-${FULL_PERCONA_XTRABACKUP_VERSION} \
        Percona-XtraDB-Cluster-garbd-57-${FULL_PXC_VERSION} \
        Percona-Server-shared-57-${FULL_PERCONA_VERSION} \
        Percona-Server-client-57-${FULL_PERCONA_VERSION} \
        socat \
        hostname \
        jq \
        azure-cli \
        qpress; \
    \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

VOLUME [ "/backup" ]

CMD ["/usr/bin/xtrabackup"]
