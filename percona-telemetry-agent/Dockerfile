# https://github.com/docker-library/official-images:
# No official images can be derived from, or depend on, non-official images
# with the following notable exceptions...
FROM oraclelinux:9
LABEL org.opencontainers.image.authors="info@percona.com"
ENV PERCONA_TELEMETRY_CHECK_INTERVAL=86400
ENV PERCONA_TELEMETRY_HISTORY_KEEP_INTERVAL=604800
ENV PERCONA_TELEMETRY_RESEND_INTERVAL=60
ENV PERCONA_TELEMETRY_URL https://check.percona.com/v1/telemetry/GenericReport
ENV PERCONA_TELEMETRY_ROOT_PATH /usr/local/percona/telemetry

#For compatibility with telemetry from Pillars' docker images
ENV OS_VER el9
ENV FULL_PERCONA_VERSION "$OS_VER"

# It is intentionally used another GUID.
RUN set -ex; \
    groupdel input; \
    userdel systemd-coredump; \
    groupadd -g 1001 percona-telemetry;

COPY percona-telemetry-agent /usr/bin/percona-telemetry-agent
WORKDIR /usr/local/percona/telemetry/history

WORKDIR /
USER daemon:percona-telemetry
ENTRYPOINT ["/usr/bin/percona-telemetry-agent"]
CMD ["--log.verbose=true"]
