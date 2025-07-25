FROM redhat/ubi9-minimal

LABEL name="Percona XtraDB Cluster" \
      release="8.4" \
      vendor="Percona" \
      summary="A high availability clustering solution for MySQL" \
      description="Percona XtraDB Cluster is an open-source, high-availability solution for MySQL. It uses Galera replication to provide synchronous multi-master clustering" \
      maintainer="Percona Development <info@percona.com>"

LABEL org.opencontainers.image.authors="info@percona.com"

ENV PXC_VERSION 8.4.5-5.1
ENV PXC_REPO testing
ENV OS_VER el9
ENV FULL_PERCONA_VERSION "$PXC_VERSION.$OS_VER"
ENV PXC_TELEMETRY_VERSION 8.4.5-5-1

# Do not report during Docker image creation.
# Note that doing so, would create telemetry config file
# which would prevent reporting when new container is started.
# If we want to track Docker image creation as well,
# remove telemetry config file after installing packages!
ARG PERCONA_TELEMETRY_DISABLE=1

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 76FD3DB13AB67410B89DB10E82562EA9AD986DA3 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 BC5EDDCADF502C077F1582882AE81E8ACED7258B 6A2FAEA2352C64E5 8d8b756f; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 6A2FAEA2352C64E5 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-9; \
    gpg --batch --export --armor 8d8b756f > ${GNUPGHOME}/ORACLE-LINUX-RELEASE-KEY; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-EPEL-9 ${GNUPGHOME}/ORACLE-LINUX-RELEASE-KEY;\
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable telemetry ${PXC_REPO}; \
    percona-release enable pdpxc-84-lts ${PXC_REPO}; \
    percona-release enable pxc-84-lts ${PXC_REPO};

RUN set -ex; \
    curl -O https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9; \
    rpm --import RPM-GPG-KEY-EPEL-9; \
    curl -Lf -o /tmp/libev.rpm https://downloads.percona.com/downloads/packaging/libev-4.33-5.el9.x86_64.rpm; \
    curl -Lf -o /tmp/pv.rpm https://downloads.percona.com/downloads/packaging/pv-1.6.20-1.el9.x86_64.rpm; \
    rpmkeys --checksig /tmp/libev.rpm /tmp/pv.rpm; \
    rpm -i /tmp/pv.rpm; \
    rpm -i /tmp/libev.rpm; \
    rm -rf /tmp/libev.rpm /tmp/pv.rpm

RUN set -ex; \
    rpm -e --nodeps tzdata; \
    microdnf install -y \
        jemalloc \
        numactl-libs \
        jq \
        socat \
        krb5-libs \
        openssl \
        shadow-utils \
        hostname \
        tzdata \
        diffutils \
        libaio \
        which \
        pam \
        procps-ng \
        cracklib-dicts \
        percona-telemetry-agent \
        libatomic \
        kernel-headers \
        tar; \
    microdnf update -y \
        libksba \
        krb5-libs \
        libnghttp2 \
        glibc \
        libxml2 \
        pam; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

# tcmalloc is not available via package manager
# Install required build tools and dependencies, build tcmalloc and cleanup
ARG TCMALLOC_RELEASE_TAG=gperftools-2.16
RUN microdnf install -y git gcc gcc-c++ make autoconf automake libtool which tar patch \
    && git clone --depth 1 --branch ${TCMALLOC_RELEASE_TAG} https://github.com/gperftools/gperftools.git \
    && cd gperftools \
    && ./autogen.sh \
    && ./configure --prefix=/usr --disable-debugalloc \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf gperftools \
    && microdnf clean all \
    && ldconfig

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

# we need licenses from docs
RUN set -ex; \
    # systemd is required for nss-pam-ldap
    curl -Lf -o /tmp/nss-pam-ldapd.rpm https://downloads.percona.com/downloads/packaging/nss-pam-ldapd-0.9.10-13.el9.x86_64.rpm; \
    rpmkeys --checksig /tmp/nss-pam-ldapd.rpm; \
    rpm -iv /tmp/nss-pam-ldapd.rpm --nodeps; \
    rm -rf /tmp/nss-pam-ldapd.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-server.rpm https://repo.percona.com/pxc-84-lts/yum/${PXC_REPO}/9/RPMS/x86_64/percona-xtradb-cluster-server-${FULL_PERCONA_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-shared.rpm https://repo.percona.com/pxc-84-lts/yum/${PXC_REPO}/9/RPMS/x86_64/percona-xtradb-cluster-shared-${FULL_PERCONA_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-client.rpm https://repo.percona.com/pxc-84-lts/yum/${PXC_REPO}/9/RPMS/x86_64/percona-xtradb-cluster-client-${FULL_PERCONA_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-icu-data-files.rpm https://repo.percona.com/pxc-84-lts/yum/${PXC_REPO}/9/RPMS/x86_64/percona-xtradb-cluster-icu-data-files-${FULL_PERCONA_VERSION}.x86_64.rpm; \
    rpmkeys --checksig /tmp/percona-xtradb-cluster-server.rpm /tmp/percona-xtradb-cluster-shared.rpm /tmp/percona-xtradb-cluster-client.rpm; \
    rpm -iv /tmp/percona-xtradb-cluster-server.rpm /tmp/percona-xtradb-cluster-shared.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-xtradb-cluster-icu-data-files.rpm --nodeps; \
    microdnf clean all; \
    rm -rf /tmp/percona-xtradb-cluster-server.rpm /tmp/percona-xtradb-cluster-shared.rpm /tmp/percona-xtradb-cluster-client.rpm /tmp/percona-xtradb-cluster-icu-data-files.rpm; \
    rm -rf /usr/bin/mysqltest /usr/bin/perror /usr/bin/replace /usr/bin/resolve_stack_dump /usr/bin/resolveip; \
    rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql /usr/lib64/mysql/plugin/debug /usr/sbin/mysqld-debug /usr/lib64/mecab /usr/lib64/mysql/mecab /usr/bin/myisam*; \
    rpm -ql percona-xtradb-cluster-client | egrep -v "mysql$|mysqldump$|mysqladmin$|mysqlbinlog$" | xargs rm -rf

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtradb-cluster-galera/COPYING /licenses/LICENSE.galera; \
    cp /usr/share/doc/percona-xtradb-cluster-galera/LICENSE.* /licenses/

RUN mkdir /usr/bin/pxc_extra/pxb-8.4/lib/plugin/ && cp /usr/bin/pxc_extra/pxb-8.4/lib/lib64/xtrabackup/plugin/* /usr/bin/pxc_extra/pxb-8.4/lib/plugin/
COPY dockerdir /

RUN set -ex; \
    rmdir /etc/my.cnf.d; \
    ln -s /etc/mysql/conf.d /etc/my.cnf.d; \
    rm -f /etc/percona-xtradb-cluster.conf.d/*.cnf; \
    echo '!include /etc/mysql/node.cnf' > /etc/my.cnf; \
    echo '!includedir /etc/my.cnf.d/' >> /etc/my.cnf; \
    echo '!includedir /etc/percona-xtradb-cluster.conf.d/' >> /etc/my.cnf

RUN set -ex; \
    mkdir -p /etc/mysql/conf.d/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d /etc/percona-xtradb-cluster.conf.d; \
    chown -R 1001:1001 /etc/mysql/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d /etc/percona-xtradb-cluster.conf.d; \
    chmod -R g=u /etc/mysql/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d /etc/percona-xtradb-cluster.conf.d

ARG DEBUG
RUN if [[ -n $DEBUG ]] ; then \
    set -ex; \
    sed -i '/\[mysqld\]/a wsrep_log_conflicts\nlog_error_verbosity=3\nwsrep_debug=1' /etc/mysql/node.cnf; \
    mv /usr/sbin/mysqld /usr/sbin/mysqld-ps; \
    cp /usr/local/bin/mysqld-debug /usr/sbin/mysqld; \
    percona-release enable pdpxc-84-lts ${PXC_REPO}; \
    microdnf install -y \
        net-tools \
        nc \
        percona-toolkit \
        gdb; \
    percona-release disable pdpxc-84-lts ${PXC_REPO}; \
    curl -Lf -o /tmp/telnet.rpm https://downloads.percona.com/downloads/packaging/telnet-0.17-85.el9.x86_64.rpm; \
    curl -Lf -o /tmp/tcpdump.rpm https://downloads.percona.com/downloads/packaging/tcpdump-4.99.0-9.el9.x86_64.rpm; \
    curl -Lf -o /tmp/perf.rpm https://downloads.percona.com/downloads/packaging/perf-5.14.0-503.35.1.el9_5.x86_64.rpm; \
    curl -Lf -o /tmp/strace.rpm https://downloads.percona.com/downloads/packaging/strace-6.12-1.el9.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-debuginfo.rpm https://repo.percona.com/pxc-84-lts/yum/${PXC_REPO}/9/RPMS/x86_64/percona-xtradb-cluster-debuginfo-${FULL_PERCONA_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-server-debuginfo.rpm https://repo.percona.com/pxc-84-lts/yum/${PXC_REPO}/9/RPMS/x86_64/percona-xtradb-cluster-server-debuginfo-${FULL_PERCONA_VERSION}.x86_64.rpm; \
    rpmkeys --checksig /tmp/telnet.rpm /tmp/tcpdump.rpm /tmp/perf.rpm /tmp/strace.rpm /tmp/percona-xtradb-cluster-debuginfo.rpm /tmp/percona-xtradb-cluster-server-debuginfo.rpm; \
    rpm -i /tmp/telnet.rpm /tmp/tcpdump.rpm /tmp/perf.rpm /tmp/strace.rpm /tmp/percona-xtradb-cluster-debuginfo.rpm /tmp/percona-xtradb-cluster-server-debuginfo.rpm --nodeps; \
    rm -rf /tmp/telnet.rpm /tmp/tcpdump.rpm /tmp/perf.rpm /tmp/strace.rpm /tmp/percona-xtradb-cluster-debuginfo.rpm /tmp/percona-xtradb-cluster-server-debuginfo.rpm; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum; \
fi

ADD https://raw.githubusercontent.com/Percona-Lab/telemetry-agent/phase-0/call-home.sh /call-home.sh
RUN chmod a+rx call-home.sh
RUN mkdir -p /usr/local/percona
RUN chown mysql:mysql /usr/local/percona
ENV CALL_HOME_OPTIONAL_PARAMS=" -s ${OS_VER}"

COPY telemetry-agent-supervisor.sh /usr/bin/
RUN set -ex; \
    chown  mysql /usr/bin/telemetry-agent-supervisor.sh; \
    chown  mysql /usr/bin/percona-telemetry-agent; \
    chown  mysql /usr/local/percona/telemetry/history; \
    chown -R mysql /var/log/percona; \
    chmod ug+rwx /usr/bin/telemetry-agent-supervisor.sh
ENV PERCONA_TELEMETRY_CHECK_INTERVAL=86400
ENV PERCONA_TELEMETRY_HISTORY_KEEP_INTERVAL=604800
ENV PERCONA_TELEMETRY_RESEND_INTERVAL=60
ENV PERCONA_TELEMETRY_URL=https://check.percona.com/v1/telemetry/GenericReport
USER 1001

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 4567 4568 33060
CMD ["mysqld"]
