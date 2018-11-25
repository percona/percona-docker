FROM debian:jessie                                                                                             
MAINTAINER Percona Development Team <opensource-dev@percona.com>                                               
                                                                                                               
RUN apt-get update && apt-get install -y --no-install-recommends \                                             
                apt-transport-https ca-certificates \                                                          
                pwgen jq \                                                                                     
        && rm -rf /var/lib/apt/lists/*                                                                         

RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 8507EFA5

RUN echo 'deb https://repo.percona.com/apt jessie testing' > /etc/apt/sources.list.d/percona.list
# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" mongodb

ENV PERCONA_MAJOR 36
ENV PERCONA_VERSION 3.6.8-2.0.jessie
ENV K8S_TOOLS_VERSION 0.4.1


RUN \
        apt-get update \
        && apt-get install -y --force-yes \
           curl jq percona-server-mongodb-$PERCONA_MAJOR=$PERCONA_VERSION \
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /data/db && mkdir -p /data/db \ 
        && chown -R 1001:0 /data/db

RUN curl -fSL https://github.com/percona/mongodb-orchestration-tools/releases/download/${K8S_TOOLS_VERSION}/k8s-mongodb-initiator -o /usr/local/bin/k8s-mongodb-initiator \
    && curl -fSL  https://github.com/percona/mongodb-orchestration-tools/releases/download/${K8S_TOOLS_VERSION}/mongodb-healthcheck -o /usr/local/bin/mongodb-healthcheck \
    && chmod 0755 /usr/local/bin/k8s-mongodb-initiator /usr/local/bin/mongodb-healthcheck

VOLUME ["/data/db"]


COPY ps-entry.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]


EXPOSE 27017

USER 1001

CMD ["mongod"]


