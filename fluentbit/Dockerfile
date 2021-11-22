FROM redhat/ubi8-minimal AS ubi8

# Use Fluentbit repository only if --build-arg FLUENTBIT_SOURCE=fluentbit_repository
ARG FLUENTBIT_SOURCE=rpm

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
    && percona-release enable pdpxc-8.0.23 release

# install exact version of PS for repeatability
ENV PERCONA_VERSION 8.0.23-14.1.el8
ENV FLUENTBIT_VERSION 1.8.9-1

RUN set -ex; \
    if [ "$FLUENTBIT_SOURCE" == 'fluentbit_repository' ]; \
    then \
        echo '[td-agent-bit]' > /etc/yum.repos.d/td-agent-bit.repo; \
        echo 'name = TD Agent Bit' >> /etc/yum.repos.d/td-agent-bit.repo; \
        # centos/7 in baseurl due to td-agent-bit repo organization \
        echo 'baseurl = https://packages.fluentbit.io/centos/7/$basearch/' >> /etc/yum.repos.d/td-agent-bit.repo; \
        echo 'gpgcheck=1' >> /etc/yum.repos.d/td-agent-bit.repo; \
        echo 'gpgkey=https://packages.fluentbit.io/fluentbit.key' >> /etc/yum.repos.d/td-agent-bit.repo; \
        echo 'enabled=1' >> /etc/yum.repos.d/td-agent-bit.repo; \
    fi; \
    microdnf -y update; \
    microdnf -y install \
        logrotate \
        procps-ng \
        shadow-utils \
        tar \
        vim-minimal; \
    microdnf -y install \
        postgresql-libs; \
    microdnf -y install \
        percona-xtradb-cluster-client-${PERCONA_VERSION}; \
    if [ "$FLUENTBIT_SOURCE" == 'fluentbit_repository' ]; \
    then \
        microdnf -y install \
            td-agent-bit-${FLUENTBIT_VERSION}; \
    else \
        microdnf -y install \
            make \
            compat-openssl10; \
        curl -Lf -o /tmp/td-agent-bit.rpm https://packages.fluentbit.io/centos/7/x86_64/td-agent-bit-${FLUENTBIT_VERSION}.x86_64.rpm; \
        rpmkeys --checksig /tmp/td-agent-bit.rpm; \
        rpm -i /tmp/td-agent-bit.rpm; \
        rm -rf /tmp/td-agent-bit.rpm; \
    fi; \
    curl -Lf https://github.com/michaloo/go-cron/releases/download/v0.0.2/go-cron.tar.gz -o /tmp/go-cron.tar.gz; \
    tar xvf /tmp/go-cron.tar.gz -C /usr/bin; \
    rm -rf /tmp/go-cron.tar.gz; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN set -ex; \
    groupadd -g 1001 mysql; \
    useradd -u 1001 -r -g 1001 -s /sbin/nologin \
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
