FROM debian:jessie
MAINTAINER Percona Development <info@percona.com>
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update && apt-get install -y --no-install-recommends \
                apt-transport-https ca-certificates \
                pwgen wget jq curl \
        && rm -rf /var/lib/apt/lists/*

RUN wget https://repo.percona.com/apt/percona-release_0.1-4.jessie_all.deb \
    && dpkg -i percona-release_0.1-4.jessie_all.deb



RUN \
    apt-get update && apt-get install -y --force-yes \
      percona-server-client-5.7 proxysql

ADD proxysql.cnf /etc/proxysql.cnf

COPY proxysql-entry.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

COPY add_cluster_nodes.sh /usr/bin/add_cluster_nodes.sh
RUN chmod a+x /usr/bin/add_cluster_nodes.sh

VOLUME /var/lib/proxysql

EXPOSE 3306 6032

CMD [""]
