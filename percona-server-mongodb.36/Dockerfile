FROM debian:jessie                                                                                             
MAINTAINER Percona Development Team <opensource-dev@percona.com>                                               
                                                                                                               
RUN apt-get update && apt-get install -y --no-install-recommends \                                             
                apt-transport-https ca-certificates \                                                          
                pwgen jq \                                                                                     
        && rm -rf /var/lib/apt/lists/*                                                                         

RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 8507EFA5

RUN echo 'deb https://repo.percona.com/apt jessie testing' > /etc/apt/sources.list.d/percona.list
RUN echo 'deb http://httpredir.debian.org/debian jessie testing' >> /etc/apt/sources.list
# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" mongodb

ENV PERCONA_MAJOR 36
ENV PERCONA_VERSION 3.6.0-1.0.jessie


RUN \
        apt-get update \
        && apt-get install -y --force-yes \
           jq percona-server-mongodb-$PERCONA_MAJOR=$PERCONA_VERSION \
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /data/db && mkdir -p /data/db \ 
        && chown -R 1001:0 /data/db

VOLUME ["/data/db"]


COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]


EXPOSE 27017

USER 1001

CMD ["mongod"]


