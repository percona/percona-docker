FROM golang:1.22 AS go_builder

RUN git clone --branch=main https://github.com/percona/percona-xtradb-cluster-operator.git /go/src/github.com/percona/percona-xtradb-cluster-operator/
WORKDIR /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/peer-list
RUN go build

FROM redhat/ubi8-minimal

LABEL org.opencontainers.image.authors="info@percona.com"

ENV PXB_VERSION 2.4.29-1
ENV PXC_VERSION 5.7.44-31.65.1
ENV PXC_REPO release
ENV OS_VER el8
ENV FULL_PERCONA_XTRABACKUP_VERSION "$PXB_VERSION.$OS_VER"
ENV FULL_PERCONA_XTRADBCLUSTER_VERSION "$PXC_VERSION.$OS_VER"
ENV PXC_TELEMETRY_VERSION 5.7.44-31.65-1

# Do not report during Docker image creation.
# Note that doing so, would create telemetry config file
# which would prevent reporting when new container is started.
# If we want to track Docker image creation as well,
# remove telemetry config file after installing packages!
ARG PERCONA_TELEMETRY_DISABLE=1

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 76FD3DB13AB67410B89DB10E82562EA9AD986DA3; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    gpg --batch --export --armor 76FD3DB13AB67410B89DB10E82562EA9AD986DA3 > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8 ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable-only tools release; \
    percona-release enable pxc-57 ${PXC_REPO}

RUN set -ex; \
    curl -Lf -o /tmp/numactl-libs.rpm http://vault.centos.org/centos/8/BaseOS/x86_64/os/Packages/numactl-libs-2.0.12-13.el8.x86_64.rpm; \
    curl -Lf -o /tmp/libev.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libev-4.24-6.el8.x86_64.rpm; \
    curl -Lf -o /tmp/jq.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/jq-1.5-12.el8.x86_64.rpm; \
    curl -Lf -o /tmp/oniguruma.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/oniguruma-6.8.2-2.el8.x86_64.rpm; \
    curl -Lf -o /tmp/pv.rpm http://download.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/p/pv-1.6.6-7.el8.x86_64.rpm; \
    curl -Lf -o /tmp/socat.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/socat-1.7.4.1-1.el8.x86_64.rpm; \
    rpmkeys --checksig /tmp/socat.rpm /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm; \
    rpm -i /tmp/socat.rpm /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm; \
    rm -rf /tmp/socat.rpm /tmp/numactl-libs.rpm /tmp/libev.rpm /tmp/jq.rpm /tmp/oniguruma.rpm /tmp/pv.rpm

RUN set -ex; \
    rpm -e --nodeps tzdata; \
    microdnf --setopt=install_weak_deps=0 --best install -y \
        jemalloc \
        openssl \
        shadow-utils \
        hostname \
        curl \
        tzdata \
        diffutils \
        libaio \
        which \
        pam \
        procps-ng \
        qpress \
        krb5-libs \
        cracklib-dicts \
        libatomic \
        tar; \
    microdnf update \
        curl \
        glibc \
        libnghttp2 \
        python3; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

# create mysql user/group before mysql installation
RUN groupadd -g 1001 mysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

# we need licenses from docs
RUN set -ex; \
    # systemd is required for nss-pam-ldap
    curl -Lf -o /tmp/nss-pam-ldapd.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/nss-pam-ldapd-0.9.9-3.el8.x86_64.rpm; \
    rpmkeys --checksig /tmp/nss-pam-ldapd.rpm; \
    rpm -iv /tmp/nss-pam-ldapd.rpm --nodeps; \
    rm -rf /tmp/nss-pam-ldapd.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-server.rpm https://repo.percona.com/pxc-57/yum/${PXC_REPO}/8/RPMS/x86_64/Percona-XtraDB-Cluster-server-57-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-shared.rpm https://repo.percona.com/pxc-57/yum/${PXC_REPO}/8/RPMS/x86_64/Percona-XtraDB-Cluster-shared-57-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-client.rpm https://repo.percona.com/pxc-57/yum/${PXC_REPO}/8/RPMS/x86_64/Percona-XtraDB-Cluster-client-57-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtrabackup-24.rpm https://repo.percona.com/pxb-24/yum/${PXC_REPO}/8/RPMS/x86_64/percona-xtrabackup-24-${FULL_PERCONA_XTRABACKUP_VERSION}.x86_64.rpm; \
    rpmkeys --checksig /tmp/percona-xtrabackup-24.rpm /tmp/percona-xtradb-cluster-server.rpm /tmp/percona-xtradb-cluster-shared.rpm /tmp/percona-xtradb-cluster-client.rpm; \
    rpm -iv /tmp/percona-xtrabackup-24.rpm /tmp/percona-xtradb-cluster-server.rpm /tmp/percona-xtradb-cluster-shared.rpm /tmp/percona-xtradb-cluster-client.rpm --nodeps; \
    microdnf clean all; \
    rm -rf /tmp/percona-xtrabackup-24.rpm /tmp/percona-xtradb-cluster-server.rpm /tmp/percona-xtradb-cluster-shared.rpm /tmp/percona-xtradb-cluster-client.rpm; \
    rm -rf /usr/bin/mysqltest /usr/bin/perror /usr/bin/replace /usr/bin/resolve_stack_dump /usr/bin/resolveip; \
    rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql /usr/lib64/mysql/plugin/debug /usr/sbin/mysqld-debug /usr/lib64/mecab /usr/lib64/mysql/mecab /usr/bin/myisam*; \
    rpm -ql Percona-XtraDB-Cluster-client-57 | egrep -v "mysql$|mysqldump$" | xargs rm -rf

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-xtradb-cluster-galera/COPYING /licenses/LICENSE.galera; \
    cp /usr/share/doc/percona-xtradb-cluster-galera/LICENSE.* /licenses/

COPY dockerdir /
COPY --from=go_builder /go/src/github.com/percona/percona-xtradb-cluster-operator/cmd/peer-list /usr/bin/

RUN set -ex; \
    rm -rf /etc/my.cnf.d; \
    ln -s /etc/mysql/conf.d /etc/my.cnf.d; \
    rm -f /etc/percona-xtradb-cluster.conf.d/*.cnf; \
    echo '!include /etc/mysql/node.cnf' > /etc/my.cnf; \
    echo '!includedir /etc/my.cnf.d/' >> /etc/my.cnf; \
    echo '!includedir /etc/percona-xtradb-cluster.conf.d/' >> /etc/my.cnf; \
    mkdir -p /etc/mysql/conf.d/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d; \
    chown -R 1001:1001 /etc/mysql/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d; \
    chmod -R g=u /etc/mysql/ /var/log/mysql /var/lib/mysql /docker-entrypoint-initdb.d

ARG DEBUG
RUN if [[ -n $DEBUG ]] ; then \
    set -ex; \
    sed -i '/\[mysqld\]/a wsrep_log_conflicts\nlog_error_verbosity=3\nwsrep_debug=1' /etc/mysql/node.cnf; \
    mv /usr/sbin/mysqld /usr/sbin/mysqld-ps; \
    cp /usr/local/bin/mysqld-debug /usr/sbin/mysqld; \
    microdnf install -y \
        net-tools \
        nc \
        gdb; \
    curl -Lf -o /tmp/telnet.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/telnet-0.17-76.el8.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-debuginfo.rpm https://repo.percona.com/pxc-57/yum/${PXC_REPO}/8/RPMS/x86_64/Percona-XtraDB-Cluster-57-debuginfo-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
    curl -Lf -o /tmp/percona-xtradb-cluster-server-debuginfo.rpm https://repo.percona.com/pxc-57/yum/${PXC_REPO}/8/RPMS/x86_64/Percona-XtraDB-Cluster-server-57-debuginfo-${FULL_PERCONA_XTRADBCLUSTER_VERSION}.x86_64.rpm; \
    rpmkeys --checksig /tmp/telnet.rpm /tmp/percona-xtradb-cluster-debuginfo.rpm /tmp/percona-xtradb-cluster-server-debuginfo.rpm; \
    rpm -i /tmp/telnet.rpm /tmp/percona-xtradb-cluster-debuginfo.rpm /tmp/percona-xtradb-cluster-server-debuginfo.rpm --nodeps; \
    rm -rf /tmp/telnet.rpm /tmp/percona-xtradb-cluster-debuginfo.rpm /tmp/percona-xtradb-cluster-server-debuginfo.rpm; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum; \
fi

ADD https://raw.githubusercontent.com/Percona-Lab/telemetry-agent/phase-0/call-home.sh /call-home.sh
RUN chmod a+rx /call-home.sh
RUN mkdir -p /usr/local/percona
RUN chown mysql:mysql /usr/local/percona
ENV CALL_HOME_OPTIONAL_PARAMS=" -s ${OS_VER}"

USER 1001

VOLUME ["/var/lib/mysql", "/var/log/mysql"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306 4567 4568
CMD ["mysqld"]
