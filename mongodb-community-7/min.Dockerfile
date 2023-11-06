FROM --platform=arm64 percona/percona-server-mongodb:6.0-arm64

USER root

RUN dnf remove percona-server-mongodb-server; \
        dnf remove percona-server-mongodb-mongos; \
        dnf remove percona-mongodb-mongosh

RUN dnf install -y openssl; \
        curl -Lf -o mongos.rpm https://repo.mongodb.org/yum/redhat/8Server/mongodb-org/6.0/aarch64/RPMS/mongodb-org-mongos-6.0.9-1.el8.aarch64.rpm; \
        rpm -i mongos.rpm; \
        rm -f mongos.rpm; \
        curl -Lf -o mongod.rpm https://repo.mongodb.org/yum/redhat/8Server/mongodb-org/6.0/aarch64/RPMS/mongodb-org-server-6.0.9-1.el8.aarch64.rpm; \
        rpm -i mongod.rpm; \
        rm -f mongod.rpm; \
        curl -Lf -o mongo.rpm https://repo.mongodb.org/yum/redhat/8Server/mongodb-org/6.0/aarch64/RPMS/mongodb-mongosh-2.0.1.aarch64.rpm; \
        rpm -i mongo.rpm; \
        rm -f mongo.rpm; \
        dnf clean all;

USER 1001