<!--
  Condensed overview for Docker Hub.

  Docker Hub has TWO description fields per repo:

    1. "Short description" (100 char limit) — shown in docker search results
       and at the top of the repo page. Copy the line below the ">>>" marker.

    2. "Full description / Overview" (markdown, unlimited) — shown as the
       repo landing page. Paste the markdown after the "===" divider.

  The long-form README-hardened.md (689 lines) is the authoritative doc;
  link to it from the short version.
-->

>>> SHORT DESCRIPTION (≤100 chars) >>>

Percona Server 8.4 LTS, hardened: DHI base, non-root, no shell, pruned libs, SBOM, stubbed libsystemd.

===============================================================================

# Percona Server 8.4 — Hardened

A Docker Hardened Image (DHI) build of **Percona Server 8.4 LTS** with minimal
attack surface for production deployments.

**Image**: `evgeniypatlan/test-images:percona-server-8.4-hardened`
**Base**: `dhi.io/debian-base:trixie` (signed + SBOM'd by Docker)
**Runs as**: `mysql` (uid 1001)
**Arch**: `linux/amd64`

## Quick start

```bash
# Single node with password
docker run -d --name ps \
    -e MYSQL_ROOT_PASSWORD=secret \
    -v ps-data:/var/lib/mysql \
    evgeniypatlan/test-images:percona-server-8.4-hardened

# With bootstrap schema + app user
docker run -d --name ps \
    -e MYSQL_ROOT_PASSWORD=rootpw \
    -e MYSQL_DATABASE=app \
    -e MYSQL_USER=appuser \
    -e MYSQL_PASSWORD=apppw \
    -v ps-data:/var/lib/mysql \
    -v $(pwd)/initdb:/docker-entrypoint-initdb.d:ro \
    evgeniypatlan/test-images:percona-server-8.4-hardened

# Hardened runtime profile
docker run -d --name ps \
    --read-only \
    --tmpfs /tmp:rw,size=64m,mode=1777 \
    --tmpfs /var/run/mysqld:rw,size=8m,uid=1001,gid=1001,mode=0755 \
    --security-opt no-new-privileges:true \
    --cap-drop ALL --cap-add CHOWN --cap-add SETGID --cap-add SETUID \
    -e MYSQL_ROOT_PASSWORD=secret \
    -v ps-data:/var/lib/mysql \
    evgeniypatlan/test-images:percona-server-8.4-hardened
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | *(required)* | Root password (also `_FILE`) |
| `MYSQL_ALLOW_EMPTY_PASSWORD` | unset | Set `yes` for no password |
| `MYSQL_DATABASE` | unset | App database to create on first boot |
| `MYSQL_USER` / `MYSQL_PASSWORD` | unset | App user to create |
| `PERCONA_TELEMETRY_DISABLE` | `0` (on) | Set `1` to disable telemetry |

**Not supported** (exits with a clear error → use `percona/percona-server:8.4`):
`MYSQL_RANDOM_ROOT_PASSWORD`, `MYSQL_ROOT_HOST != localhost`,
`MYSQL_ONETIME_PASSWORD`, `INIT_ROCKSDB`, `INIT_TOKUDB`, `.sh` / `.sql.gz`
files in `/docker-entrypoint-initdb.d/`.

## Connecting

The image has **no `mysql` client** — use a sidecar client container:

```bash
# TCP via shared network namespace (use MYSQL_USER@'%', not root)
docker run --rm --network container:ps \
    mysql:8.4 mysql -h127.0.0.1 -uappuser -papppw app

# Admin via docker exec (uses the socket)
docker exec ps mysqladmin -uroot -p"$MYSQL_ROOT_PASSWORD" status
```

Root access over TCP is deliberately blocked: the server has
`skip-name-resolve` and the entrypoint creates only `root@localhost`, which
only matches UNIX socket connections.

## Healthcheck

Built in. `mysqladmin ping -h127.0.0.1` every 30s, 60s start period, 3 retries.
`docker ps` shows `(healthy)` once mysqld accepts connections — use with
Docker Compose `depends_on: condition: service_healthy`.

## Security posture

- **Non-root** — `USER mysql` (uid 1001), no setuid binaries
- **DHI base** — `dhi.io/debian-base:trixie`, signed + SBOM'd by Docker
- **Distroless-style** — no `apt`, `dpkg`, `bash`, `mysql` client, `mysqlsh`,
  `mysqldump`, `mysql_upgrade`, or interactive shell
- **POSIX sh only** — `dash` as `/bin/sh`, no `libreadline` / `libtinfo` /
  `ncurses` (kills 4 HIGH CVEs vs. a naive Debian base)
- **Stubbed `libsystemd.so.0`** — replaced with a ~30-line compiled no-op
  so `sd_notify()` calls resolve but the CVE surface is gone
- **Pruned lib closure** — only libraries `ldd` says are needed, not a full
  Debian userland
- **Minimal `/etc/passwd`** — `root` and `mysql` only
- **Inline SBOM** — SPDX 2.3 at `/usr/local/percona-server.spdx.json`
- **Full Percona plugin set preserved** — InnoDB, RocksDB, audit_log,
  keyring_vault, group_replication, thread_pool; all loadable via
  `INSTALL PLUGIN`

## CVE status

Freshly built image, scanned with Trivy:

- **0 CRITICAL**
- **3 HIGH** — all in `percona-telemetry-agent` Go stdlib (≤1.26.1); fix
  requires a Percona rebuild with Go 1.26.2. Set `PERCONA_TELEMETRY_DISABLE=1`
  at runtime if those CVEs block you.

## What's different from `percona/percona-server:8.4`

| | Non-hardened | Hardened |
|---|---|---|
| Image size | ~700 MB | ~300–400 MB |
| `mysql` client | yes | no |
| `mysqlsh` / `mysqldump` / `mysql_upgrade` | yes | no |
| `MYSQL_RANDOM_ROOT_PASSWORD` | yes | no |
| `.sh` / `.sql.gz` init files | yes | no |
| Shell | bash | dash |
| Base | `redhat/ubi9-minimal` | `dhi.io/debian-base:trixie` |
| libsystemd | real | stub |

Same Percona Server binaries, different runtime environment. If any "no"
above matters, use the non-hardened image.

## More details

Full technical documentation — architecture, build internals, libsystemd
stub rationale, test suite — is in
[`README-hardened.md`](README-hardened.md) in the source repo.

## Support

- Commercial support: https://hubs.ly/Q02ZTHbG0
- Community forum: https://forums.percona.com/
- Bug reports: https://jira.percona.com
- Source: https://github.com/percona/percona-docker

Percona Server is released under the GNU GPLv2.
