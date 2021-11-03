FROM golang:1.16 AS go_builder
RUN apt-get update -y && apt-get install -y libkrb5-dev
RUN git clone https://github.com/percona/percona-backup-mongodb.git /opt/pbm
WORKDIR /opt/pbm
RUN make install

FROM redhat/ubi8-minimal

LABEL org.opencontainers.image.title="Percona Backup for MongoDB" \
    org.opencontainers.image.vendor="Percona" \
    org.opencontainers.image.description="Percona Backup for MongoDB is a distributed, \
    low-impact solution for achieving consistent backups of MongoDB Sharded Clusters and Replica Sets." \
    org.opencontainers.image.authors="info@percona.com"

COPY --from=go_builder /go/bin/pbm /go/bin/pbm-agent /go/bin/pbm-speed-test /usr/local/bin/
COPY --from=go_builder /opt/pbm/LICENSE /licenses/

USER nobody

# Containers should be started either with --mongodb-uri flag or with PBM_MONGODB_URI env variable
CMD ["pbm-agent"]
