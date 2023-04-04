FROM perconalab/percona-distribution-postgresql:15-ol9

LABEL org.opencontainers.image.authors="info@percona.com"

ENV POSTGIS_MAJOR 3
ENV PG_MAJOR 15
ENV POSTGIS_VERSION 3.3.1-1
ENV OS_VER el9

USER root

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D 68C9E2B91A37D136FE74D1761F16D2E1442DF0F8; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 68C9E2B91A37D136FE74D1761F16D2E1442DF0F8 > ${GNUPGHOME}/RPM-GPG-KEY-PGDG; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-PGDG; \
    rm -rf /tmp/percona-release.rpm; \
    dnf -y remove percona-release-1.0-27.noarch; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable ppg-15.2 testing; 

# Install epel, pgdg and enable codeready_builder repositories for the dependencies
RUN set -ex; \
    dnf install -y wget epel-release; \
    curl -Lf -o /tmp/pgdg-redhat-repo-latest.noarch.rpm https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/pgdg-redhat-repo-latest.noarch.rpm; \
    rpm -i /tmp/pgdg-redhat-repo-latest.noarch.rpm; \
    dnf -y install pgdg-srpm-macros; 
RUN dnf config-manager --set-enabled ol9_codeready_builder
RUN set -ex; \
    dnf install -y \
        percona-postgis33-$POSTGIS_VERSION.$OS_VER;

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh
COPY ./update-postgis.sh /usr/local/bin
