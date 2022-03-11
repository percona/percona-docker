FROM golang:1.17 AS go_builder
WORKDIR /go/src/github.com/mikefarah/yq

ARG GOOS=linux
ARG GOARCH=amd64
ARG CGO_ENABLED=0

ENV YQ_VERSION 3.3.4
RUN git clone -b $YQ_VERSION https://github.com/mikefarah/yq.git .; \
    mkdir -p build/_output/bin; \
    ./scripts/devtools.sh; \
    sed -i -e 's^dev: test ^dev: ^' ./Makefile; \
    CGO_ENABLED=$CGO_ENABLED GOOS=$GOOS GOARCH=$GOARCH \
    make local build

FROM redhat/ubi8-minimal

LABEL name="Percona PostgreSQL Distribution" \
    vendor="Percona" \
    summary="Percona Distribution for PostgreSQL" \
    description="Percona Distribution for PostgreSQL is a collection of tools to assist you in managing your PostgreSQL database system" \
    maintainer="Percona Development <info@percona.com>"

# platform-python-pip is removed due to CVE-2019-20916, VULNDB-229216
# python3-pip-wheel is required by platform-python
RUN set -ex; \
    microdnf -y update; \
    microdnf -y install glibc-langpack-en platform-python; \
    /usr/libexec/platform-python -m pip install pip --upgrade; \
    microdnf -y remove platform-python-pip; \
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum

ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
ARG PG_MAJOR=14

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
        430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
        99DB70FAE1D7CE227FB6488205B555B38483C65D \
        94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 \
        736AF5116D9C40E2AF6B074BF9B9FEE7764429E6; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    gpg --batch --export --armor 736AF5116D9C40E2AF6B074BF9B9FEE7764429E6 > ${GNUPGHOME}/RPM-GPG-KEY-CentOS-SIG-Cloud; \
    rpmkeys --import \
        ${GNUPGHOME}/RPM-GPG-KEY-Percona \
        ${GNUPGHOME}/RPM-GPG-KEY-centosofficial \
        ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8 \
        ${GNUPGHOME}/RPM-GPG-KEY-CentOS-SIG-Cloud; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/epel-release.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpm -i /tmp/percona-release.rpm /tmp/epel-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm /tmp/epel-release.rpm; \
    curl -Lf -o /tmp/python3-pyparsing.rpm https://vault.centos.org/8.5.2111/cloud/x86_64/openstack-train/Packages/p/python3-pyparsing-2.4.6-1.el8.noarch.rpm; \
    rpmkeys --checksig /tmp/python3-pyparsing.rpm; \
    rpm -i /tmp/python3-pyparsing.rpm; \
    rm -rf /tmp/python3-pyparsing.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable ppg-${PG_MAJOR} release

RUN set -ex; \
    microdnf -y install \
        bind-utils \
        gettext \
        hostname \
        perl \
        libedit \
        procps-ng; \
    sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/epel*.repo; \
    microdnf -y module disable llvm-toolset; \
    microdnf -y install \
        libpq \
        llvm \
        percona-postgresql${PG_MAJOR//.}; \
    microdnf -y clean all

# Preserving PGVERSION out of paranoia
ENV PGROOT="/usr/pgsql-${PG_MAJOR}" PGVERSION="${PG_MAJOR}"

RUN set -ex; \
    curl -Lf -o /tmp/openssh.rpm http://vault.centos.org/centos/8/BaseOS/x86_64/os/Packages/openssh-8.0p1-10.el8.x86_64.rpm; \
    curl -Lf -o /tmp/openssh-server.rpm http://vault.centos.org/centos/8/BaseOS/x86_64/os/Packages/openssh-server-8.0p1-10.el8.x86_64.rpm; \
    curl -Lf -o /tmp/openssh-clients.rpm http://vault.centos.org/centos/8/BaseOS/x86_64/os/Packages/openssh-clients-8.0p1-10.el8.x86_64.rpm; \
    curl -Lf -o /tmp/perl-libxml-perl.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-libxml-perl-0.08-33.el8.noarch.rpm; \
    curl -Lf -o /tmp/perl-DBD-Pg.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-DBD-Pg-3.7.4-4.module_el8.3.0+426+0b4e9c0a.x86_64.rpm; \
    curl -Lf -o /tmp/perl-XML-Parser.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-XML-Parser-2.44-11.el8.x86_64.rpm; \
    curl -Lf -o /tmp/perl-DBI.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-DBI-1.641-3.module_el8.3.0+413+9be2aeb5.x86_64.rpm; \
    curl -Lf -o /tmp/python3-psutil.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/python3-psutil-5.4.3-11.el8.x86_64.rpm; \
    curl -Lf -o /tmp/python3-prettytable.rpm  http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/python3-prettytable-0.7.2-14.el8.noarch.rpm; \
    curl -Lf -o /tmp/python3-click.rpm http://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/python3-click-6.7-8.el8.noarch.rpm; \
    rpmkeys --checksig /tmp/perl-DBI.rpm /tmp/perl-DBI.rpm /tmp/perl-XML-Parser.rpm /tmp/perl-libxml-perl.rpm /tmp/perl-DBD-Pg.rpm /tmp/openssh-server.rpm \
                       /tmp/openssh.rpm /tmp/openssh-clients.rpm /tmp/python3-psutil.rpm /tmp/python3-prettytable.rpm /tmp/python3-click.rpm; \
    rpm -i /tmp/perl-DBI.rpm /tmp/perl-DBI.rpm /tmp/perl-XML-Parser.rpm /tmp/perl-libxml-perl.rpm /tmp/perl-DBD-Pg.rpm \
           /tmp/openssh.rpm /tmp/openssh-server.rpm /tmp/openssh-clients.rpm /tmp/python3-psutil.rpm /tmp/python3-prettytable.rpm /tmp/python3-click.rpm; \
    rm -rf /tmp/perl-DBI.rpm /tmp/perl-DBI.rpm /tmp/perl-XML-Parser.rpm /tmp/perl-libxml-perl.rpm /tmp/perl-DBD-Pg.rpm \
           /tmp/openssh.rpm /tmp/openssh-server.rpm /tmp/openssh-clients.rpm /tmp/python3-psutil.rpm /tmp/python3-prettytable.rpm /tmp/python3-click.rpm

ENV PATRONI_VERSION='2.1.1-1'

RUN set -ex; \
    microdnf -y install \
        --enablerepo="epel" \
        percona-pgaudit \
        percona-pgaudit${PG_MAJOR//.}_set_user \
        percona-pgbackrest \
        percona-postgresql${PG_MAJOR//.}-contrib \
        percona-postgresql${PG_MAJOR//.}-server \
        percona-postgresql${PG_MAJOR//.}-libs \
        percona-postgresql${PG_MAJOR//.}-plpython* \
        percona-pg-stat-monitor${PG_MAJOR//.} \
        percona-postgresql${PG_MAJOR//.}-llvmjit \
        psmisc \
        rsync \
        perl \
        nss_wrapper \
        tar \
        bzip2 \
        lz4 \
        percona-wal2json${PG_MAJOR//.} \
        file \
        unzip; \
    microdnf -y reinstall tzdata; \
# patroni block starts
# Provided by Percona
    microdnf -y install \
        python3-psycopg2 \
        python3-ydiff \
        ydiff; \
#    pip install click; \
#    pip install prettytable; \
#    pip install psutil; \
    pip install python-dateutil; \
#    pip install psycopg2; \
    pip install pyyaml; \
    pip install six; \
    pip install urllib3; \
#    pip install ydiff; \
    curl -Lf -o /tmp/percona-patroni.rpm https://repo.percona.com/ppg-${PG_MAJOR//.}/yum/release/8/RPMS/x86_64/percona-patroni-${PATRONI_VERSION}.el8.x86_64.rpm; \
    rpmkeys --checksig /tmp/percona-patroni.rpm; \
    rpm -i --nodeps /tmp/percona-patroni.rpm; \
    rm -rf /tmp/percona-patroni.rpm; \
# patroni block ends
    microdnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum


ENV PATH="${PGROOT}/bin:${PATH}"

RUN set -ex; \
    mkdir -p /opt/crunchy/bin /opt/crunchy/conf /pgdata /pgwal /pgconf /recover /backrestrepo /tablespaces; \
    chown -R postgres:postgres /opt/crunchy /var/lib/pgsql \
        /pgdata /pgwal /pgconf /recover /backrestrepo /tablespaces; \
    chmod -R g=u /opt/crunchy /var/lib/pgsql \
        /pgdata /pgwal /pgconf /recover /backrestrepo /tablespaces

RUN rm -rf /var/spool/pgbackrest

# open up the postgres port
EXPOSE 5432

COPY bin/postgres_common /opt/crunchy/bin
COPY bin/common /opt/crunchy/bin
COPY conf/postgres_common /opt/crunchy/conf
COPY redhat/atomic/help.1 /help.1
COPY redhat/atomic/help.md /help.md
COPY licenses /licenses
COPY bin/postgres-ha /opt/crunchy/bin/postgres-ha
COPY conf/postgres-ha /opt/crunchy/conf/postgres-ha

COPY --from=go_builder /go/src/github.com/mikefarah/yq/LICENSE /licenses/LICENSE.yq
COPY --from=go_builder /go/src/github.com/mikefarah/yq/yq /opt/crunchy/bin/

RUN set -ex; \
    mkdir /.ssh; \
    chown 26:0 /.ssh; \
    chmod g+rwx /.ssh; \
    rm -f /run/nologin

# add volumes to allow override of pg_hba.conf and postgresql.conf
# add volumes to offer a restore feature
# add volumes to allow storage of postgres WAL segment files
# add volumes to locate WAL files to recover with
# add volumes for pgbackrest to write to
# The VOLUME directive must appear after all RUN directives to ensure the proper
# volume permissions are applied when building the image
VOLUME ["/sshd", "/pgconf", "/pgdata", "/pgwal", "/recover", "/backrestrepo"]

# Defines a unique directory name that will be utilized by the nss_wrapper in the UID script
ENV NSS_WRAPPER_SUBDIR="postgres"

ENTRYPOINT ["/opt/crunchy/bin/postgres-ha/bootstrap-postgres-ha.sh"]

USER 26

CMD ["/usr/bin/patroni"]
