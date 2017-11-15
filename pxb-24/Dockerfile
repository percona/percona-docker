FROM debian:jessie

MAINTAINER Percona Development <info@percona.com>

RUN set -e; \
  apt-get update; \
  apt-get install --no-install-recommends --yes \
    apt-transport-https \
    ca-certificates pwgen wget \
  && rm -rf /var/lib/apt/lists/*

RUN wget https://repo.percona.com/apt/percona-release_0.1-4.jessie_all.deb \
  && dpkg -i percona-release_0.1-4.jessie_all.deb

RUN apt-get update \
  && apt-get install --no-install-recommends --yes \
  percona-xtrabackup-24\
  qpress \
  ; \
  rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["xtrabackup"]

CMD ["/bin/bash"]
