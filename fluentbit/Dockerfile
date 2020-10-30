FROM registry.access.redhat.com/ubi7/ubi-minimal AS ubi7

LABEL name="Fluent Bit" \
      description="Fluent Bit docker image" \
      vendor="Percona" \
      summary="Fluent Bit is a lightweight and high performance log processor" \
      org.opencontainers.image.authors="info@percona.com"

RUN export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver https://packages.fluentbit.io/fluentbit.key --recv-keys F209D8762A60CD49E680633B4FF8368B6EA0722A \
    && gpg --export --armor F209D8762A60CD49E680633B4FF8368B6EA0722A > ${GNUPGHOME}/RPM-GPG-KEY-Fluent \
    && gpg --batch --keyserver pool.sks-keyservers.net --recv-keys 567E347AD0044ADE55BA8A5F199E2F91FD431D51 \
    && gpg --batch --export --armor 567E347AD0044ADE55BA8A5F199E2F91FD431D51 > ${GNUPGHOME}/RPM-GPG-KEY-redhat-release \
    && rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Fluent ${GNUPGHOME}/RPM-GPG-KEY-redhat-release

RUN set -ex; \
    microdnf install -y postgresql-libs shadow-utils yum-utils; \
    repoquery -a --archlist=x86_64 --location \
        systemd-libs \
        | xargs curl -Lf -o /tmp/systemd-libs.rpm; \
    repoquery -a --archlist=x86_64 --location \
        elfutils-libs \
            | xargs curl -Lf -o /tmp/elfutils-libs.rpm; \
    curl -Lf https://packages.fluentbit.io/centos/7/x86_64/td-agent-bit-1.6.2-1.x86_64.rpm -o /tmp/td-agent-bit.rpm; \
    rpmkeys --checksig /tmp/td-agent-bit.rpm /tmp/elfutils-libs.rpm /tmp/systemd-libs.rpm; \
    rpm -i /tmp/td-agent-bit.rpm /tmp/systemd-libs.rpm /tmp/elfutils-libs.rpm /tmp/systemd-libs.rpm --nodeps; \
    rm -f /tmp/td-agent-bit.rpm /tmp/systemd-libs.rpm /tmp/elfutils-libs.rpm /tmp/systemd-libs.rpm; \
    rm -rf /var/cache 


RUN groupadd -g 1001 mysql
RUN useradd -u 1001 -r -g 1001 -s /sbin/nologin \
        -c "Default Application User" mysql

COPY dockerdir /

RUN set -ex; \
    ln -s /opt/td-agent-bit/bin/td-agent-bit /opt/td-agent-bit/bin/fluent-bit; \
    mkdir -p /etc/fluentbit; \
    chown -R 1001:1001 /etc/fluentbit
COPY LICENSE /licenses/LICENSE.Dockerfile


USER mysql

VOLUME ["/etc/fluentbit"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["fluent-bit"]
