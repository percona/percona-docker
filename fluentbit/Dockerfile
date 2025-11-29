FROM registry.access.redhat.com/ubi9/ubi-minimal AS ubi9

LABEL name="Fluent Bit" \
      description="Fluent Bit docker image" \
      vendor="Percona" \
      maintainer="Percona Development <info@percona.com>" \
      summary="Fluent Bit is a lightweight and high performance log processor" \
      org.opencontainers.image.authors="info@percona.com"

RUN export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver https://packages.fluentbit.io/fluentbit.key --recv-keys C3C0A28534B9293EAF51FABD9F9DDC083888C1CD \
    && gpg --export --armor C3C0A28534B9293EAF51FABD9F9DDC083888C1CD > ${GNUPGHOME}/RPM-GPG-KEY-Fluent \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 567E347AD0044ADE55BA8A5F199E2F91FD431D51 \
    && gpg --batch --export --armor 567E347AD0044ADE55BA8A5F199E2F91FD431D51 > ${GNUPGHOME}/RPM-GPG-KEY-redhat-release \
    && rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Fluent ${GNUPGHOME}/RPM-GPG-KEY-redhat-release \
    && gpg --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 \
    && gpg --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
    && rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
    && microdnf install -y findutils \
    && curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
    && rpmkeys --checksig /tmp/percona-release.rpm \
    && rpm -i /tmp/percona-release.rpm \
    && rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
    && rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
    && percona-release setup pdpxc-8.0.42 \
    && percona-release enable psmdb-80 release

# install exact version of PS for repeatability
ENV PERCONA_VERSION=8.0.42-33.1.el9

# Add Fluent Bit repo
RUN printf "%s\n" \
    "[fluent-bit]" \
    "name=Fluent Bit" \
    "baseurl=https://packages.fluentbit.io/centos/9/" \
    "gpgcheck=1" \
    "gpgkey=https://packages.fluentbit.io/fluentbit.key" \
    "repo_gpgcheck=1" \
    "enabled=1" \
    > /etc/yum.repos.d/fluent-bit.repo

# fluentbit does not have el8 repo and the doc suggests installing el7 rpm
RUN set -ex; \
    microdnf install -y hostname postgresql-libs shadow-utils yum-utils fluent-bit logrotate make libpq procps-ng compat-openssl11 percona-mongodb-mongosh \
    percona-xtradb-cluster-client-${PERCONA_VERSION} tar vim-minimal; \
    curl -Lf https://github.com/michaloo/go-cron/releases/download/v0.0.2/go-cron.tar.gz -o /tmp/go-cron.tar.gz; \
    tar xvf /tmp/go-cron.tar.gz -C /usr/bin; \
    rm -rf /var/cache


RUN groupadd -g 1001 mysql
RUN useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

COPY dockerdir /

RUN set -ex; \
    mkdir -p /etc/fluentbit; \
    chown -R 1001:1001 /etc/fluentbit /opt/percona /usr/local/bin; \
    chmod 664 /etc/passwd; \
    chmod -R 775 /opt/percona
COPY LICENSE /licenses/LICENSE.Dockerfile


USER 1001

VOLUME ["/etc/fluentbit"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["fluent-bit"]
