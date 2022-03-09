FROM registry.access.redhat.com/ubi8/ubi-minimal AS ubi8

LABEL name="Fluent Bit" \
      description="Fluent Bit docker image" \
      vendor="Percona" \
      summary="Fluent Bit is a lightweight and high performance log processor" \
      org.opencontainers.image.authors="info@percona.com"

RUN export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver https://packages.fluentbit.io/fluentbit.key --recv-keys F209D8762A60CD49E680633B4FF8368B6EA0722A \
    && gpg --export --armor F209D8762A60CD49E680633B4FF8368B6EA0722A > ${GNUPGHOME}/RPM-GPG-KEY-Fluent \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 567E347AD0044ADE55BA8A5F199E2F91FD431D51 \
    && gpg --batch --export --armor 567E347AD0044ADE55BA8A5F199E2F91FD431D51 > ${GNUPGHOME}/RPM-GPG-KEY-redhat-release \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 99DB70FAE1D7CE227FB6488205B555B38483C65D \
    && gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial \
    && rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Fluent ${GNUPGHOME}/RPM-GPG-KEY-redhat-release ${GNUPGHOME}/RPM-GPG-KEY-centosofficial \
    && gpg --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
    && gpg --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona \
    && rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona \
    && microdnf install -y findutils \
    && curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
    && rpmkeys --checksig /tmp/percona-release.rpm \
    && rpm -i /tmp/percona-release.rpm \
    && rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
    && rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
    && percona-release setup pdpxc-8.0.26

# install exact version of PS for repeatability
ENV PERCONA_VERSION 8.0.26-16.1.el8

# fluentbit does not have el8 repo and the doc suggests installing el7 rpm
RUN set -ex; \
    microdnf install -y postgresql-libs shadow-utils yum-utils logrotate make libpq compat-openssl10 \
    percona-xtradb-cluster-client-${PERCONA_VERSION} tar vim-minimal; \
    curl -Lf -o /tmp/procps-ng.rpm http://vault.centos.org/centos/8/BaseOS/x86_64/os/Packages/procps-ng-3.3.15-6.el8.x86_64.rpm; \
    curl -Lf https://github.com/michaloo/go-cron/releases/download/v0.0.2/go-cron.tar.gz -o /tmp/go-cron.tar.gz; \
    tar xvf /tmp/go-cron.tar.gz -C /usr/bin; \
    curl -Lf https://packages.fluentbit.io/centos/7/x86_64/td-agent-bit-1.8.11-1.x86_64.rpm -o /tmp/td-agent-bit.rpm; \
    rpmkeys --checksig /tmp/procps-ng.rpm /tmp/td-agent-bit.rpm; \
    rpm -i /tmp/td-agent-bit.rpm /tmp/procps-ng.rpm --nodeps; \
    rm -f /tmp/td-agent-bit.rpm /tmp/procps-ng.rpm; \
    rm -rf /var/cache 


RUN groupadd -g 1001 mysql
RUN useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

COPY dockerdir /

RUN set -ex; \
    ln -s /opt/td-agent-bit/bin/td-agent-bit /opt/td-agent-bit/bin/fluent-bit; \
    mkdir -p /etc/fluentbit; \
    chown -R 1001:1001 /etc/fluentbit /opt/percona /usr/local/bin; \
    chmod 664 /etc/passwd; \
    chmod -R 775 /opt/percona
COPY LICENSE /licenses/LICENSE.Dockerfile


USER 1001

VOLUME ["/etc/fluentbit"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["fluent-bit"]
