FROM scratch

COPY ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY percona-telemetry-agent /usr/bin/percona-telemetry-agent

CMD ["/usr/bin/percona-telemetry-agent"]

