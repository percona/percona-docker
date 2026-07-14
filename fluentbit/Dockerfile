FROM registry.access.redhat.com/ubi9/ubi-minimal AS ubi9

LABEL name="Fluent Bit" \
      description="Fluent Bit docker image" \
      vendor="Percona" \
      maintainer="Percona Development <info@percona.com>" \
      summary="Fluent Bit is a lightweight and high performance log processor" \
      org.opencontainers.image.authors="info@percona.com"

ENV PERCONA_SERVER_VERSION=8.0.45
ENV PERCONA_SERVER_PERC_VERSION=36
ENV PERCONA_SERVER_BUILD_VERSION=1

# install exact version of PS for repeatability
ENV PERCONA_VERSION=${PERCONA_SERVER_VERSION}-${PERCONA_SERVER_PERC_VERSION}.${PERCONA_SERVER_BUILD_VERSION}.el9

# install exact version of Fluent Bit for repeatability
ENV FLUENTBIT_VERSION=5.0.9-1

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
    && percona-release setup pdpxc-${PERCONA_SERVER_VERSION} \
    && percona-release enable psmdb-80 release

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

# Install packages
# fluentbit does not have el8 repo and the doc suggests installing el7 rpm
RUN set -ex; \
    microdnf install -y \
      hostname \
      postgresql-libs \
      shadow-utils \
      yum-utils \
      fluent-bit-${FLUENTBIT_VERSION} \
      logrotate \
      make \
      libpq \
      procps-ng \
      compat-openssl11 \
      percona-mongodb-mongosh \
      percona-xtradb-cluster-client-${PERCONA_VERSION} \
      tar \
      vim-minimal; \
    curl -Lf https://github.com/michaloo/go-cron/releases/download/v0.0.2/go-cron.tar.gz -o /tmp/go-cron.tar.gz; \
    tar xvf /tmp/go-cron.tar.gz -C /usr/bin; \
    rm -rf /var/cache /tmp/go-cron.tar.gz


# Install supercronic for cron
ARG SUPERCRONIC_VERSION=v0.2.46
RUN set -ex; \
    cd /tmp; \
    arch=$(uname -m); \
    case "$arch" in \
        x86_64) \
            SUPERCRONIC=supercronic-linux-amd64; \
            SUPERCRONIC_SHA1SUM=5bcefed628e32adc08e32634db2d10e9230dbca0 ;; \
        i386|i686) \
            SUPERCRONIC=supercronic-linux-386; \
            SUPERCRONIC_SHA1SUM=7630904df9a240b6e0f8171cac46ec799fbe1ad9 ;; \
        armv7l|armv6l|armhf) \
            SUPERCRONIC=supercronic-linux-arm; \
            SUPERCRONIC_SHA1SUM=04be50a960eafa325185d037c9b4ad6cd88a0e0b ;; \
        aarch64) \
            SUPERCRONIC=supercronic-linux-arm64; \
            SUPERCRONIC_SHA1SUM=639ab81a72771990790df7ee87d9acfe88e5fa83 ;; \
        *) \
            echo "unsupported architecture: $arch" && exit 1 ;; \
    esac; \
    curl -fsSLO "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${SUPERCRONIC}"; \
    echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c -; \
    chmod +x "${SUPERCRONIC}"; \
    mv "${SUPERCRONIC}" "/usr/local/bin/${SUPERCRONIC}"; \
    ln -sf "/usr/local/bin/${SUPERCRONIC}" /usr/bin/supercronic

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
