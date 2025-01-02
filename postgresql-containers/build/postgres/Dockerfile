FROM golang:1.22 AS go_builder
WORKDIR /go/src/github.com/mikefarah/yq

ARG GOOS=linux
ARG GOARCH=amd64
ARG CGO_ENABLED=0

ENV YQ_VERSION 3.3.4
RUN git clone -b $YQ_VERSION https://github.com/mikefarah/yq.git .; \
    go get -u ./...; \
    mkdir -p build/_output/bin; \
    ./scripts/devtools.sh; \
    sed -i -e 's^dev: test ^dev: ^' ./Makefile; \
    CGO_ENABLED=$CGO_ENABLED GOOS=$GOOS GOARCH=$GOARCH \
    make local build

FROM redhat/ubi9-minimal

LABEL name="Percona PostgreSQL Distribution" \
    vendor="Percona" \
    summary="Percona Distribution for PostgreSQL" \
    description="Percona Distribution for PostgreSQL is a collection of tools to assist you in managing your PostgreSQL database system" \
    maintainer="Percona Development <info@percona.com>"

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install glibc-langpack-en platform-python; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
ARG PG_MAJOR=17.2

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
        4D1BB29D63D98E422B2113B19334A25F8507EFA5 \
        3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F \
        99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle; \
    gpg --batch --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle; \
    rpmkeys --import \
        ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
        ${GNUPGHOME}/RPM-GPG-KEY-oracle \
        ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    microdnf install -y findutils yum-utils; \
    curl -Lf -o /tmp/oraclelinux-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/oraclelinux-release-el9-1.0-15.el9.x86_64.rpm; \
    curl -Lf -o /tmp/epel-release.rpm https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/oracle-epel-release-el9-1.0-1.el9.x86_64.rpm; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpm --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-oracle ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpmkeys --checksig /tmp/oraclelinux-release.rpm; \
    rpm -i /tmp/percona-release.rpm /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpmm /tmp/oraclelinux-release.rpm /tmp/epel-release.rpm; \
    percona-release enable ppg-${PG_MAJOR} testing

RUN set -ex; \
    microdnf -y install perl-DBI perl-DBD-Pg perl-XML-Parser; \
    yum-config-manager --disable ol9_appstream; \
    microdnf --disablerepo="ubi-9-appstream-rpms" -y install \
        llvm; \
    microdnf -y clean all

RUN set -ex; \
    microdnf --enablerepo="ol9_appstream" -y install \
        annobin-12.31-2.el9.x86_64; \
    microdnf -y clean all

RUN set -ex; \
    yum-config-manager --disable ol9_developer_EPEL ol9_UEKR7 ol9_baseos_latest; \
    microdnf -y install \
        bind-utils \
        gettext \
        hostname \
        python3-pyparsing \
        perl \
        libedit \
        openssh \
        openssh-server \
        openssh-clients \
        procps-ng; \
    sed -i 's/install_langs C.utf8/install_langs all/' /etc/rpm/macros.image-language-conf; \
    microdnf -y install \
        libpq \
        glibc-all-langpacks \
        percona-postgresql${PG_MAJOR%.*}; \
    microdnf -y clean all

# Preserving PGVERSION out of paranoia
ENV PGROOT="/usr/pgsql-${PG_MAJOR%.*}" PGVERSION="${PG_MAJOR}"

RUN set -ex; \
    microdnf -y install \
        --enablerepo="ol9_developer_EPEL" \
        percona-pgaudit${PG_MAJOR%.*} \
        percona-pgaudit${PG_MAJOR%.*}_set_user \
        percona-pgbackrest \
        percona-postgresql${PG_MAJOR%.*}-contrib \
        percona-postgresql${PG_MAJOR%.*}-server \
        percona-postgresql${PG_MAJOR%.*}-libs \
        percona-pg_stat_monitor${PG_MAJOR%.*} \
        percona-postgresql${PG_MAJOR%.*}-llvmjit \
        percona-wal2json${PG_MAJOR%.*} \
        percona-pg_repack${PG_MAJOR%.*} \
        percona-postgresql-client-common \
        percona-postgresql-server-dev-all \
        psmisc \
        rsync \
        perl \
        nss_wrapper \
        tar \
        bzip2 \
        lz4 \
        file \
        tzdata \
        unzip; \
        microdnf -y reinstall tzdata; \
# patroni block starts
# Provided by Percona
    microdnf -y install --enablerepo="ol9_developer_EPEL" \
        python3-psycopg2 \
        python3-ydiff \
        python3-dateutil \
        python3-urllib3 \
        python3-pyyaml \
        python3-click \
        ydiff; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

RUN if [[ "${PG_MAJOR%.*}" -le '16' ]]; then \
        microdnf -y install --enablerepo="ol9_developer_EPEL" percona-patroni-3*; \
    else \
        microdnf -y install --enablerepo="ol9_developer_EPEL" percona-patroni; \
    fi; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

ENV PATH="${PGROOT}/bin:${PATH}"

RUN set -ex; \
    mkdir -p /opt/crunchy/bin /opt/crunchy/conf /pgdata /pgwal /pgconf /backrestrepo /tablespaces; \
    chown -R postgres:postgres /opt/crunchy /var/lib/pgsql \
        /pgdata /pgwal /pgconf /backrestrepo /tablespaces /usr/pgsql-${PG_MAJOR%.*}; \
    chmod -R g=u /opt/crunchy /var/lib/pgsql \
        /pgdata /pgwal /pgconf /backrestrepo /tablespaces

RUN rm -rf /var/spool/pgbackrest

# open up the postgres port
EXPOSE 5432

COPY bin/postgres_common /opt/crunchy/bin
COPY bin/common /opt/crunchy/bin
COPY conf/postgres_common /opt/crunchy/conf
COPY licenses /licenses

COPY --from=go_builder /go/src/github.com/mikefarah/yq/LICENSE /licenses/LICENSE.yq
COPY --from=go_builder /go/src/github.com/mikefarah/yq/yq /opt/crunchy/bin/

RUN set -ex; \
    mkdir /.ssh; \
    chown 26:0 /.ssh; \
    chmod g+rwx /.ssh; \
    rm -f /run/nologin \
        /etc/pgbackrest.conf

COPY conf/pgbackrest-repo/pgbackrest.conf /etc/pgbackrest.conf
COPY bin/relocate-extensions.sh /usr/local/bin/relocate-extensions.sh

RUN echo "huge_pages = off" >> ${PGROOT}/share/postgresql.conf.sample

# remove the default spool directory so that pgBackRest does not attempt to look there when
# performing a restore (pgBackRest will not have permissions to access to this dir in all envs)
RUN rm -rf /var/spool/pgbackrest

# add volumes to allow override of pg_hba.conf and postgresql.conf
# add volumes to offer a restore feature
# add volumes to allow storage of postgres WAL segment files
# add volumes for pgbackrest to write to
# The VOLUME directive must appear after all RUN directives to ensure the proper
# volume permissions are applied when building the image
VOLUME ["/sshd", "/pgconf", "/pgdata", "/pgwal", "/backrestrepo"]

# Defines a unique directory name that will be utilized by the nss_wrapper in the UID script
ENV NSS_WRAPPER_SUBDIR="postgres"

ENTRYPOINT ["/opt/crunchy/bin/postgres-ha/bootstrap-postgres-ha.sh"]

USER 26

CMD ["/usr/bin/patroni"]
