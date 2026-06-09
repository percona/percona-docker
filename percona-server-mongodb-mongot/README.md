# Percona Search for MongoDB (mongot) — Docker images

Container images for [Percona Search for MongoDB](https://github.com/percona/percona-mongot)
(internal name **PS4M**, binary `mongot`).

## Build

```bash
# x86_64
docker buildx build --platform linux/amd64 \
    -t percona/percona-server-mongodb-mongot:0.50.0 \
    -f Dockerfile .

# aarch64 (buildx with an explicit platform, otherwise an amd64 host
# would produce an amd64 image under the -arm64 tag)
docker buildx build --platform linux/arm64 \
    -t percona/percona-server-mongodb-mongot:0.50.0-arm64 \
    -f Dockerfile.aarch64 .
```

## Run

The default config in `/etc/mongot/mongot.yml` has placeholders for the
sync source (mongod URI), username and password file. Mount your own
config and password file before starting:

```bash
docker run -d \
    --name mongot \
    -p 27028:27028 \
    -p 9946:9946 \
    -p 8080:8080 \
    -v $(pwd)/mongot.yml:/etc/mongot/mongot.yml:ro \
    -v $(pwd)/passwordFile:/etc/mongot/secrets/passwordFile:ro \
    -v mongot-data:/var/lib/mongot \
    percona/percona-server-mongodb-mongot:0.50.0
```

The image uses an entry point that forwards arguments to `mongot`, so you
can point the daemon at a config in a different location without restating
the binary. A plain `docker run` falls back to the bundled config, which is
only a placeholder — the container starts but won't connect to mongod until
you mount a real config and password file as shown above:

```bash
docker run -d \
    --name mongot \
    -v $(pwd)/custom.yml:/conf/mongot.yml:ro \
    percona/percona-server-mongodb-mongot:0.50.0 \
    --config /conf/mongot.yml
```

Exposed ports (defaults from the bundled `mongot.yml`):

| port | purpose |
|---|---|
| 27028 | gRPC query server (mongod ↔ mongot) |
| 9946  | Prometheus metrics |
| 8080  | health endpoint |

## Bundled JDK

The image ships the full Adoptium Temurin 21 runtime under
`/usr/lib/percona-server-mongodb-mongot/bin/jdk` (no system JDK
dependency). The `mongot` wrapper at `/usr/bin/mongot` resolves
`JAVA_HOME` to the bundled JDK automatically.

## Image layout

| path | purpose |
|---|---|
| `/usr/lib/percona-server-mongodb-mongot/` | bundle (JDK, jars, native .so libs, launcher) |
| `/usr/bin/mongot` | thin wrapper that execs the bundled launcher |
| `/etc/mongot/mongot.yml` | default config (placeholders, must be overridden) |
| `/etc/sysconfig/mongot` | env file (unused in container — kept for parity with RPM install) |
| `/var/lib/mongot` | data dir (declared as VOLUME) |
| `/var/log/mongot` | log dir |

## User

The container runs as **UID 1001** with primary group **0** (root), the
standard OpenShift compatibility pattern. Data and log directories are
chowned to `1001:0` and made group-writable so the daemon can write
under both this UID and any other UID OpenShift may assign.

The mongot RPM also creates a system `mongod:mongod` user during
install (PSMDB/PBM convention), but the container does not run as it.

## Custom config mount: host file permissions

The image's `/etc/mongot/` tree (config + password file dir) is owned by
**`1001:0`** so the container user can read it. When you bind-mount a
file from the host on top of one of those paths (a common pattern for
custom config and credentials), **the file keeps its host-side
permissions** — Docker does not translate ownership.

Practical implications:

- If the host file is `0644` (world-readable), the container reads it
  regardless of who owns it on the host.
- If the host file is `0600 root:root`, the container UID 1001 cannot
  open it and mongot fails to start with `Permission denied`.
- If the host file is `0640 root:<some-group>`, UID 1001 will only
  succeed if the host's GID 0 happens to be in `<some-group>` — usually
  it isn't.

Recommended pattern for mounted secrets (kept restricted on the host
but readable by the container user):

```bash
# Option A — world-readable on the host (simple, fine for dev).
chmod 0644 ./mongot.yml ./passwordFile

# Option B — owner-only on the host, owner = UID 1001 (production-ish).
sudo chown 1001:0 ./mongot.yml ./passwordFile
sudo chmod 0640   ./mongot.yml ./passwordFile

# Option C — kubernetes / podman / OpenShift: use a Secret or
# ConfigMap; the orchestrator handles the UID mapping for you.
```

## Notes

- **netty-tcnative (native OpenSSL) doesn't load on UBI9.** The bundled
  mongot ships a netty-tcnative built against OpenSSL 1.0 (`libssl.so.10`),
  which `ubi9-minimal` (OpenSSL 3.x) doesn't provide. mongot logs
  `netty-tcnative dynamic linking failed` at startup and falls back to the
  JDK SSL provider (JSSE). TLS to the mongod sync source and the mongot gRPC
  server (MTLS) still work — functionality is unaffected.

