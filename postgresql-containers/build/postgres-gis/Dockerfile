ARG PG_MAJOR=14
ARG PGO_TAG=main
ARG ORG_NAME=perconalab

FROM ${ORG_NAME}/percona-postgresql-operator:${PGO_TAG}-ppg${PG_MAJOR}-postgres

LABEL name="Percona PostgreSQL Distribution" \
    vendor="Percona" \
    summary="Percona Distribution for PostgreSQL" \
    description="Percona Distribution for PostgreSQL is a collection of tools to assist you in managing your PostgreSQL database system" \
    maintainer="Percona Development <info@percona.com>"

USER 0

COPY build/postgres-gis/oracle-linux-ol8.repo /etc/yum.repos.d/

ARG PG_MAJOR=14

RUN set -ex; \
    curl -Lf -o /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle https://yum.oracle.com/RPM-GPG-KEY-oracle-ol8; \
    microdnf -y remove epel-release; \
    microdnf -y module disable postgresql; \
    microdnf -y install epel-release; \
    microdnf -y install percona-postgis33_${PG_MAJOR%%.*} percona-postgis33_${PG_MAJOR%%.*}-client

EXPOSE 5432

COPY bin/postgres-gis /opt/crunchy/bin/postgres

ENTRYPOINT ["/opt/crunchy/bin/uid_postgres.sh"]

USER 26

CMD ["/opt/crunchy/bin/start.sh"]
