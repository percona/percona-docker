FROM golang:1.23 AS go_builder
WORKDIR /go/src/github.com/percona/percona-docker/postgresql-containers/src

COPY . .

ARG GOOS=linux
ARG GOARCH=amd64
ARG CGO_ENABLED=0

RUN mkdir -p build/_output/bin; \
    CGO_ENABLED=$CGO_ENABLED GOOS=$GOOS GOARCH=$GOARCH \
    go build \
        -o build/_output/bin/pgbackrest ./cmd/pgbackrest; \
    cp -r build/_output/bin/pgbackrest /usr/local/bin/pgbackrest; \
    ./bin/license_aggregator.sh; \
    cp -r ./licenses /licenses

FROM redhat/ubi9-minimal

LABEL name="Percona PostgreSQL Distribution" \
    vendor="Percona" \
    summary="Percona Distribution for PostgreSQL" \
    description="Percona Distribution for PostgreSQL is a collection of tools to assist you in managing your PostgreSQL database system" \
    maintainer="Percona Development <info@percona.com>"

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install glibc-langpack-en; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
ARG PG_MAJOR=14

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
        4D1BB29D63D98E422B2113B19334A25F8507EFA5 \
        3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F \
        99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
    rpmkeys --import \
        ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
        ${GNUPGHOME}/RPM-GPG-KEY-oracle \
        ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    microdnf install -y findutils yum-utils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpm --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpmm; \
    percona-release enable ppg-${PG_MAJOR} release

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install \
        bind-utils \
        python3-pyparsing \
        gettext \
        hostname \
        perl \
        tar \
        openssh \
        openssh-server \
        openssh-clients \
        bzip2 \
        lz4 \
        procps-ng; \
    microdnf -y install  \
        systemd \
        libpq \
        nss_wrapper \
        percona-postgresql${PG_MAJOR%%.*}-libs \
        libedit; \
    microdnf -y clean all

RUN set -ex; \
    microdnf -y install \
        percona-pgbackrest; \
    microdnf -y clean all

RUN set -ex; \
    usermod -d /home/postgres postgres; \
    mkdir -p /opt/crunchy/bin /opt/crunchy/conf /pgdata /backrestrepo \
             /var/log/pgbackrest

COPY bin/pgbackrest-restore /opt/crunchy/bin
COPY conf/pgbackrest-restore /opt/crunchy/conf
COPY --from=go_builder /usr/local/bin/pgbackrest /opt/crunchy/bin/
COPY --from=go_builder /licenses /licenses
COPY bin/common /opt/crunchy/bin
COPY bin/pgbackrest-common /opt/crunchy/bin

RUN set -ex; \
    chown -R postgres:postgres /opt/crunchy  \
        /backrestrepo /var/log/pgbackrest /pgdata

COPY bin/pgbackrest-repo /usr/local/bin

RUN set -ex; \
    chmod +x /usr/local/bin/pgbackrest-repo.sh /usr/local/bin/archive-push-s3.sh \
      /usr/local/bin/archive-push-gcs.sh; \
    mkdir -p /etc/pgbackrest; \
    chown -R postgres:postgres /etc/pgbackrest; \
    chmod -R g=u /etc/pgbackrest; \
    rm -f /run/nologin \
          /etc/pgbackrest.conf

COPY conf/pgbackrest-repo/pgbackrest.conf /etc/pgbackrest.conf


RUN set -ex; \
    mkdir /.ssh; \
    chown postgres:postgres /.ssh; \
    chmod o+rwx /.ssh

# remove the default spool directory so that pgBackRest does not attempt to look there when
# performing a restore (pgBackRest will not have permissions to access to this dir in all envs)
RUN rm -rf /var/spool/pgbackrest

VOLUME ["/sshd", "/pgdata", "/backrestrepo"]

USER 26

# Defines a unique directory name that will be utilized by the nss_wrapper in the UID script
ENV NSS_WRAPPER_SUBDIR="pgbackrest"

ENTRYPOINT ["/opt/crunchy/bin/uid_postgres.sh"]

CMD ["/opt/crunchy/bin/start.sh"]
