FROM golang:1.17 AS go_builder
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

FROM registry.access.redhat.com/ubi8/ubi-minimal

LABEL name="Percona PostgreSQL Distribution" \
    vendor="Percona" \
    summary="Percona Distribution for PostgreSQL" \
    description="Percona Distribution for PostgreSQL is a collection of tools to assist you in managing your PostgreSQL database system" \
    maintainer="Percona Development <info@percona.com>"

RUN microdnf -y update; \
    microdnf -y install glibc-langpack-en

ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
ARG PG_MAJOR=14

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    microdnf install -y findutils; \
    curl -Lf -o /tmp/epel-release.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpmkeys --checksig /tmp/epel-release.rpm; \
    rpm -i /tmp/percona-release.rpm /tmp/epel-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm /tmp/epel-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY

RUN if [[ "$PG_MAJOR" -le '13' ]] ; then \
        percona-release enable ppg-${PG_MAJOR} release; \
    else \
       percona-release enable ppg-${PG_MAJOR}.0 experimental; \
    fi

RUN set -ex; \
    microdnf -y update; \
    microdnf -y install \
        bind-utils \
        gettext \
        hostname \
        perl \
        procps-ng; \
    sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/epel*.repo; \
    microdnf -y install  \
        systemd \
        libpq \
        nss_wrapper \
        percona-postgresql${PG_MAJOR}-libs \
        libedit; \
    microdnf -y clean all

RUN set -ex; \
    curl -Lf -o /tmp/perl-DBI.rpm http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-DBI-1.641-3.module_el8.3.0+413+9be2aeb5.x86_64.rpm; \
    curl -Lf -o /tmp/perl-XML-Parser.rpm http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-XML-Parser-2.44-11.el8.x86_64.rpm; \
    curl -Lf -o /tmp/openssh.rpm http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/openssh-8.0p1-10.el8.x86_64.rpm; \
    curl -Lf -o /tmp/openssh-server.rpm http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/openssh-server-8.0p1-10.el8.x86_64.rpm; \
    curl -Lf -o /tmp/openssh-clients.rpm http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/openssh-clients-8.0p1-10.el8.x86_64.rpm; \
    curl -Lf -o /tmp/perl-libxml-perl.rpm http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-libxml-perl-0.08-33.el8.noarch.rpm; \
    curl -Lf -o /tmp/perl-DBD-Pg.rpm http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/perl-DBD-Pg-3.7.4-4.module_el8.3.0+426+0b4e9c0a.x86_64.rpm; \
    rpmkeys --checksig /tmp/openssh.rpm /tmp/perl-DBI.rpm /tmp/perl-XML-Parser.rpm /tmp/perl-libxml-perl.rpm /tmp/perl-DBD-Pg.rpm /tmp/openssh-server.rpm /tmp/openssh-clients.rpm; \
    rpm -i /tmp/openssh.rpm /tmp/perl-DBI.rpm /tmp/perl-XML-Parser.rpm /tmp/openssh-server.rpm /tmp/openssh-clients.rpm /tmp/perl-libxml-perl.rpm /tmp/perl-DBD-Pg.rpm; \
    rm -rf /tmp/openssh.rpm /tmp/perl-DBI.rpm /tmp/perl-XML-Parser.rpm /tmp/openssh-server.rpm /tmp/openssh-clients.rpm /tmp/perl-libxml-perl.rpm /tmp/perl-DBD-Pg.rpm; \
    microdnf -y install  \
        percona-pgbackrest; \
    microdnf -y clean all

RUN set -ex; \
    mkdir -p /opt/crunchy/bin /opt/crunchy/conf /pgdata /backrestrepo \
             /var/log/pgbackrest

COPY bin/pgbackrest-restore /opt/crunchy/bin
COPY conf/pgbackrest-restore /opt/crunchy/conf
COPY --from=go_builder /usr/local/bin/pgbackrest /opt/crunchy/bin/
COPY --from=go_builder /licenses /licenses
COPY bin/common /opt/crunchy/bin
COPY bin/pgbackrest-common /opt/crunchy/bin

RUN set -ex; \
    groupadd postgres -g 26; \
    useradd postgres -u 26 -g 26; \
    groupadd pgbackrest -g 2000; \
    useradd pgbackrest -u 2000 -g 2000

RUN set -ex; \
    chown -R pgbackrest:pgbackrest /opt/crunchy; \
    chown -R postgres:postgres /backrestrepo /var/log/pgbackrest /pgdata

COPY bin/pgbackrest-repo /usr/local/bin

RUN set -ex; \
    chmod +x /usr/local/bin/pgbackrest-repo.sh /usr/local/bin/archive-push-s3.sh \
      /usr/local/bin/archive-push-gcs.sh; \
    mkdir -p /etc/pgbackrest; \
    chown -R postgres:root /etc/pgbackrest; \
    chmod -R g=u /etc/pgbackrest; \
    rm -f /run/nologin

RUN rm -rf /var/spool/pgbackrest

RUN set -ex; \
    mkdir /.ssh; \
    chown pgbackrest:pgbackrest /.ssh; \
    chmod o+rwx /.ssh

COPY bin/pgbackrest-repo/uid_pgbackrest.sh /opt/crunchy/bin

VOLUME ["/sshd", "/pgdata", "/backrestrepo"]

USER 2000

# Defines a unique directory name that will be utilized by the nss_wrapper in the UID script
ENV NSS_WRAPPER_SUBDIR="pgbackrest-repo"

ENTRYPOINT ["/opt/crunchy/bin/uid_pgbackrest.sh"]

CMD ["pgbackrest-repo.sh"]
