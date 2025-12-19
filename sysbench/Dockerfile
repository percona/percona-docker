FROM redhat/ubi9-minimal AS ubi9

LABEL name="HAproxy" \
      description="TCP proxy loadbalancer for Percona Xtradb Cluster" \
      vendor="Percona" \
      summary="TCP proxy for mysql protocol" \
      maintainer="Percona Development <info@percona.com>" \
      org.opencontainers.image.authors="info@percona.com"

# check repository package signature in secure way
RUN export GNUPGHOME="$(mktemp -d)" \
	&& microdnf install -y findutils \
	&& gpg --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F 4D1BB29D63D98E422B2113B19334A25F8507EFA5\
	&& gpg --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
        && gpg --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY \
	&& gpg --export --armor 3E6D826D3FBAB389C2F38E34BC4D06A08D8B756F > ${GNUPGHOME}/RPM-GPG-KEY-oracle \
	&& rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-oracle ${GNUPGHOME}/PERCONA-PACKAGING-KEY\
	&& curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm \
	&& rpmkeys --checksig /tmp/percona-release.rpm \
	&& rpm -i /tmp/percona-release.rpm \
	&& rm -rf "$GNUPGHOME" /tmp/percona-release.rpm \
	&& rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY \
        && percona-release enable sysbench testing


RUN set -ex; \
    microdnf install -y \
        sysbench \
        sysbench-tpcc \
        which \
        tar \
        procps-ng \
        vim-minimal \
        policycoreutils; \
    \
    microdnf clean all; \
    rm -rf /var/cache

RUN mkdir -p /sysbench
RUN chgrp -R 0 /sysbench && chmod -R g=u /sysbench 

WORKDIR /sysbench

CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
