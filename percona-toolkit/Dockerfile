FROM debian:jessie
MAINTAINER Percona Development <info@percona.com>

RUN apt-get update && apt-get install -y --force-yes --no-install-recommends \
                apt-transport-https ca-certificates \
                pwgen \
        && rm -rf /var/lib/apt/lists/*

RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A

RUN echo 'deb https://repo.percona.com/apt jessie main' > /etc/apt/sources.list.d/percona.list

RUN  apt-get update \
        && apt-get install -y --force-yes percona-toolkit \
        && rm -rf /var/lib/apt/lists/* 

ENV PERCONA_VERSION 3.0.4

WORKDIR /
