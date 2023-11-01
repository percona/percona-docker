arg basever
FROM percona/percona-postgresql-operator:${basever}-postgres

USER 0

COPY build/postgres-postgis/oracle-linux-ol8.repo /etc/yum.repos.d/

RUN set -ex; \
    curl -Lf -o /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle https://yum.oracle.com/RPM-GPG-KEY-oracle-ol8; \
    microdnf -y module disable postgresql; \
    microdnf -y install percona-postgis33 percona-postgis33-client;
