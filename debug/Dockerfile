FROM redhat/ubi9-minimal

LABEL org.opencontainers.image.authors="info@percona.com"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en


RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
        4D1BB29D63D98E422B2113B19334A25F8507EFA5 \
        3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F \
        99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle; \
    rpmkeys --import \
        ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
        ${GNUPGHOME}/RPM-GPG-KEY-oracle \
        ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    microdnf install -y findutils yum-utils; \
    curl -Lf -o /tmp/oraclelinux-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/oraclelinux-release-el9-1.0-15.el9.x86_64.rpm; \
    curl -Lf -o /tmp/epel-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/oracle-epel-release-el9-1.0-1.el9.x86_64.rpm; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpm --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-oracle ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpmkeys --checksig /tmp/oraclelinux-release.rpm; \
    rpm -i /tmp/percona-release.rpm /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    percona-release enable pt release

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install \
        percona-toolkit \
        perf \
        yum \
        vim \
        hostname \
        sysstat \
        tar \
        bzip2 \
        lz4 \
        procps-ng \
        strace \
        golang \
        mpfr-devel \
        elfutils \
        mpfr-devel \
        wget \
        aria2 \
        net-tools; \
    yum -y groupinstall "Development tools"; \
    microdnf clean all; \
    yum clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

WORKDIR /opt/src

# Fetch and extract the latest stable GDB version
RUN LATEST_VERSION=$(curl -s ftp://ftp.gnu.org/gnu/gdb/ | \
    awk '{print $NF}' | \
    grep -E '^gdb-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.gz$' | \
    sed -E 's/gdb-([0-9]+\.[0-9]+(\.[0-9]+)?)\.tar\.gz/\1/' | \
    sort -V | \
    tail -n 1) && \
    echo "Latest GDB version: $LATEST_VERSION" && \
    aria2c -x 8 -s 8 https://ftp.gnu.org/gnu/gdb/gdb-${LATEST_VERSION}.tar.gz && \
    tar -xzf gdb-${LATEST_VERSION}.tar.gz && \
    cd gdb-${LATEST_VERSION} && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /opt/src

RUN gdb --version

COPY LICENSE /licenses/LICENSE.Dockerfile
