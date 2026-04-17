# Percona Server 8.4 — Hardened Docker Image

A **Docker Hardened Image (DHI) build** of Percona Server 8.4 LTS, targeting
minimal attack surface for production deployments.

**Image**: `evgeniypatlan/test-images:percona-server-8.4-hardened`
**Base**: `dhi.io/debian-base:trixie` (Debian 13, signed + SBOM'd by Docker)
**Runs as**: `mysql` (uid/gid 1001)
**Architecture**: `linux/amd64`

---

## TL;DR

```bash
docker run -d --name ps \
    -e MYSQL_ROOT_PASSWORD=supersecret \
    -v ps-data:/var/lib/mysql \
    evgeniypatlan/test-images:percona-server-8.4-hardened

docker ps                           # wait for STATUS to show (healthy)
docker exec ps mysqladmin ping      # mysqld is alive
```

That's it. First boot initializes the datadir, sets the root password, and
starts mysqld. Subsequent boots just start mysqld against the existing datadir.

---

## What this image is

This is **not** the standard `percona/percona-server:8.4` image. It's a
re-engineered, security-hardened variant that:

- Boots on **Docker Hardened Images** (`dhi.io/debian-base:trixie`), a signed,
  CVE-scanned, minimal Debian base produced by Docker.
- Ships **no bash, no mysql client, no MySQL Shell, no package manager** at
  runtime. The only shell is POSIX `dash` (no `libreadline`, no `libtinfo`,
  no `ncurses` — kills four HIGH CVEs vs. the stock Debian base).
- Uses an **`ldd`-pruned shared-library closure** so only the libraries
  `mysqld` + its plugins actually need are present — not the thousands of
  unused libs a normal Debian install would ship.
- Replaces **`libsystemd.so.0`** with a compiled no-op stub (~5 KB) so
  mysqld's `sd_notify()` calls resolve to empty functions, eliminating the
  real libsystemd's CVE surface without breaking the ELF loader.
- Runs **non-root** (`USER mysql`, uid 1001).
- Ships a minimal `/etc/passwd` with only `root` and `mysql` — no `nobody`,
  `sshd`, `systemd-*`, `messagebus`, `_apt`, etc.
- Embeds an **inline SPDX 2.3 SBOM** at `/usr/local/percona-server.spdx.json`.
- Includes the **Percona telemetry agent** (can be opted out via
  `PERCONA_TELEMETRY_DISABLE=1`).
- Keeps the **full Percona Server plugin set**: InnoDB, RocksDB, audit_log,
  keyring_vault, group_replication, thread_pool, etc. — all still loadable
  via `INSTALL PLUGIN`.

It's intended as a drop-in production server: mount a volume at
`/var/lib/mysql`, set `MYSQL_ROOT_PASSWORD`, go.

---

## Quick start

### Development — no password, no persistence

```bash
docker run -d --name ps \
    -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
    evgeniypatlan/test-images:percona-server-8.4-hardened
```

### Production — password, named volume, healthcheck

```bash
docker volume create ps-data

docker run -d --name ps \
    -e MYSQL_ROOT_PASSWORD="$(openssl rand -base64 24)" \
    -v ps-data:/var/lib/mysql \
    -p 127.0.0.1:3306:3306 \
    --restart unless-stopped \
    evgeniypatlan/test-images:percona-server-8.4-hardened
```

### Production with a bootstrap schema

```bash
mkdir -p ./initdb
cat > ./initdb/01-schema.sql <<'SQL'
CREATE DATABASE app;
CREATE TABLE app.users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100)
) ENGINE=InnoDB;
SQL

docker run -d --name ps \
    -e MYSQL_ROOT_PASSWORD=rootpw \
    -e MYSQL_DATABASE=app \
    -e MYSQL_USER=appuser \
    -e MYSQL_PASSWORD=apppw \
    -v ps-data:/var/lib/mysql \
    -v $(pwd)/initdb:/docker-entrypoint-initdb.d:ro \
    evgeniypatlan/test-images:percona-server-8.4-hardened
```

`01-schema.sql` is concatenated into an `--init-file` bundle and executed by
`mysqld` natively on first boot (no client-side shell dance needed).

### With a hardened runtime profile

```bash
docker run -d --name ps \
    --read-only \
    --tmpfs /tmp:rw,size=64m,mode=1777 \
    --tmpfs /var/run/mysqld:rw,size=8m,uid=1001,gid=1001,mode=0755 \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --cap-add CHOWN --cap-add SETGID --cap-add SETUID \
    -e MYSQL_ROOT_PASSWORD=secret \
    -e PERCONA_TELEMETRY_DISABLE=1 \
    -v ps-data:/var/lib/mysql \
    evgeniypatlan/test-images:percona-server-8.4-hardened
```

Read-only root filesystem, no new privileges, all Linux capabilities dropped
except the three mysqld actually needs during init (`CHOWN` to set datadir
ownership, `SETGID`/`SETUID` for the `setpriv`-style user drop during startup).

---

## What's inside the image

```
/usr/sbin/mysqld                             # server binary
/usr/sbin/mysqld.my                          # component manifest marker
/usr/bin/mysqladmin                          # healthcheck + administrative
/usr/bin/percona-telemetry-agent             # telemetry Go binary
/usr/bin/my_print_defaults                   # mysqld config parser (entrypoint uses it)
/usr/bin/telemetry-agent-supervisor.sh       # POSIX sh supervisor
/usr/lib/mysql/plugin/                       # full plugin set (wholesale)
/usr/lib/mysql/private/                      # ICU regex data files
/usr/lib/x86_64-linux-gnu/                   # ldd-pruned lib closure
/usr/lib/x86_64-linux-gnu/libjemalloc.so.2   # LD_PRELOAD'd allocator
/usr/lib/x86_64-linux-gnu/libsystemd.so.0    # STUB — empty sd_notify*
/usr/share/mysql/                            # errmsg.sys, SQL bootstraps, charsets
/usr/share/mysql-8.4/                        # server share dir
/usr/share/icu/                              # ICU data for full Unicode
/usr/local/percona-server.spdx.json          # inline SBOM (SPDX 2.3)
/usr/local/bin/docker-entrypoint.sh          # POSIX sh entrypoint (dash)
/etc/mysql/                                  # baked config
/etc/mysql/conf.d/docker.cnf                 # host_cache_size=0; skip-name-resolve
/etc/default/mysql                           # LD_PRELOAD=libjemalloc, THP=never
/etc/passwd                                  # root + mysql (2 entries only)
/etc/group                                   # root + mysql
/etc/nsswitch.conf                           # files-only (no NIS, no LDAP)
/bin/dash                                    # POSIX /bin/sh
/bin/sh → dash                               # symlink
/var/lib/mysql/                              # datadir (VOLUME, mysql:mysql, 0750)
/var/lib/mysql-files/                        # --secure-file-priv path (mysql:mysql, 0750)
/var/run/mysqld/                             # socket + pid file (mysql:mysql)
/var/log/percona/                            # telemetry agent logs (mysql:mysql)
/docker-entrypoint-initdb.d/                 # user init SQL scripts
```

**What's explicitly NOT in the image** (unlike `percona/percona-server:8.4`):

| Removed | Why |
|---|---|
| `bash` | Links `libreadline` → `libtinfo` → `ncurses` (4 HIGH CVEs) |
| `libreadline8` / `libhistory8` | CVE carrier, only bash used it |
| `libtinfo6` / `libncurses*` | CVE carrier, only bash used them |
| `/bin/mysql` (client) | Links readline; use a sidecar client container |
| `mysqlsh` (MySQL Shell) | Python + V8 + readline — huge attack surface |
| `mysqldump` | Init-only tool; use `docker exec` with a client image |
| `mysql_upgrade` | Init-only tool |
| `mysql_tzinfo_to_sql` | Init-only tool |
| `ps-admin` | Not relevant in hardened workflow |
| `pwmake` / `cracklib-dicts` | Only used by `MYSQL_RANDOM_ROOT_PASSWORD` (unsupported) |
| `apt`, `dpkg`, `gpg`, `wget`, `curl` | No runtime package installation |
| Package manager + build tools | Runtime base is distroless-style |

---

## Architecture — how the image is built

The build is a **single `Dockerfile.hardened` with three linear stages**, each
copying forward from the previous. One `docker build` command produces the
image.

### Stage 1 — `package-install` (FROM `dhi.io/debian-base:trixie-dev`)

Runs as root, uses `apt` from the DHI `-dev` variant.

1. Installs prereqs: `ca-certificates`, `wget`, `gnupg`, `gpgv`, `curl`,
   `lsb-release`, `bsdutils`, plus `gcc` + `libc6-dev` (needed temporarily to
   compile the libsystemd stub — discarded from the final image).
2. Creates the `mysql` system user (uid/gid `1001` — matches existing
   Percona image for backward compatibility).
3. Downloads `percona-release.deb`, installs it, enables the **`pdps-8.4.8`**
   distribution channel plus the `telemetry` channel, both from
   `--build-arg REPO_CHANNEL=testing` (default).
4. `apt install --no-install-recommends`:
   - `percona-server-server` — the mysqld binary + default config
   - `percona-server-client` — shared client libs (the `mysql` CLI itself
     does not ship to the final image)
   - `percona-server-rocksdb` — the RocksDB engine plugin
   - `percona-telemetry-agent` — the Go binary that sends usage telemetry
   - `libjemalloc2` — alternative malloc, `LD_PRELOAD`'d
   - `dash` — POSIX /bin/sh replacement
   - `mawk` — minimal AWK (no ncurses dep)
5. Bakes `/etc/mysql/conf.d/docker.cnf` with `host_cache_size=0` and
   `skip-name-resolve` (hostname lookups are pointless and slow in
   containers).
6. Bakes `/etc/default/mysql` with `LD_PRELOAD=.../libjemalloc.so.2` and
   `THP_SETTING=never`.
7. Generates an inline SPDX 2.3 SBOM from the installed package version.
8. **Detects the plugin directory** dynamically (`ha_rocksdb.so` or
   `auth_socket.so` — different Debian layouts use
   `/usr/lib/mysql/plugin` vs. `/usr/lib/x86_64-linux-gnu/mysql/plugin`)
   and writes the path to a scratch file for later stages.
9. Writes the `mysqld.my` and `component_keyring_vault.cnf` marker files
   to the detected plugin dir (same behavior as the non-hardened Percona
   image).
10. **Compiles `libsystemd-stub.c`** — a ~30-line C file with no-op
    implementations of `sd_notify`, `sd_notifyf`, `sd_booted`, `sd_pid_notify`,
    `sd_watchdog_enabled`, `sd_listen_fds`, and related functions. The
    compiled `libsystemd.so.0` replaces the real `libsystemd.so.0` from
    Debian. See `libsystemd-stub.c` in the repo.

### Stage 2 — `assemble` (FROM `package-install`)

Builds a clean `/runtime` staging tree that will be COPY'd wholesale into the
final image. Nothing else from the `package-install` stage (apt, gcc,
/var/cache, /tmp clutter) reaches the final image.

1. Creates the target directory skeleton: `/runtime/bin`, `/runtime/usr/sbin`,
   `/runtime/usr/bin`, `/runtime/var/lib/mysql`, `/runtime/var/lib/mysql-files`,
   `/runtime/var/run/mysqld`, `/runtime/var/log/percona`,
   `/runtime/docker-entrypoint-initdb.d`, `/runtime/etc`, `/runtime/usr/share`.
2. Copies `mysqld` + `mysqld.my` from `/usr/sbin/`.
3. Copies `/bin/dash` and creates `/bin/sh → dash`.
4. Copies a short, curated list of utility binaries from `/usr/bin/`:
   `mysqladmin`, `percona-telemetry-agent`, `my_print_defaults`, `sed`, `cat`,
   `ls`, `cp`, `mv`, `rm`, `mkdir`, `chmod`, `chown`, `mktemp`, `head`, `tail`,
   `sleep`, `id`, `env`, `readlink`, `dirname`, `basename`, `grep`, `awk`,
   `find`, `printf`, `tee`, `getent`. The rest of the `-dev` image's userland
   is left behind.
5. Copies the **whole mysql lib tree wholesale** (`/usr/lib/mysql/` or
   equivalent) — picks up the plugin dir **and** the `private/` subdir that
   holds ICU regex data.
6. Walks `mysqld` + every `*.so*` under the mysql lib tree + every copied
   binary + `libjemalloc.so.2` through `ldd`, resolves transitive shared
   libraries, and copies them into `/runtime/usr/lib/…` preserving the
   merged-usr path layout (`/lib/` → `/usr/lib/`).
7. Copies share data: `/usr/share/mysql`, `/usr/share/mysql-8.4`,
   `/usr/share/icu`. No `zoneinfo`, no `cracklib` — init-only things we don't
   need.
8. Copies the baked `/etc/mysql` tree and `/etc/default/mysql`.
9. Copies the SBOM.
10. Sets ownership: `/var/lib/mysql`, `/var/lib/mysql-files`, `/var/run/mysqld`,
    `/var/log/percona`, `/docker-entrypoint-initdb.d`, `/etc/mysql` all owned
    by `mysql:mysql` (1001:1001). `0750` on the data dirs, `0755` on others.
11. Writes a **minimal `/etc/passwd`** containing only `root` and `mysql`, and
    a matching `/etc/group`. Everything else (`daemon`, `nobody`, `_apt`,
    `systemd-*`, `messagebus`, …) is dropped.
12. Writes a minimal `/etc/nsswitch.conf` (`passwd: files`, `group: files`,
    `hosts: files dns`) to prevent glibc from trying NIS/LDAP/sss lookups
    that would fail.
13. Copies `ps-entry-hardened.sh` to `/runtime/usr/local/bin/docker-entrypoint.sh`
    and `telemetry-agent-supervisor-hardened.sh` to
    `/runtime/usr/bin/telemetry-agent-supervisor.sh`.

### Stage 3 — final image (FROM `dhi.io/debian-base:trixie`)

A fresh DHI runtime base (no apt, no gcc, no `-dev` clutter).

1. `USER root` — DHI's default is `USER nonroot`, which we override because
   we replaced `/etc/passwd` and `nonroot` no longer exists.
2. A single long `RUN` that **strips cruft the DHI base ships**:
   - Removes `/bin/bash`, `/usr/bin/bash`, `/usr/bin/rbash`.
   - Removes `libreadline*`, `libhistory*`, `libtinfo*`, `libncurses*`,
     `libtic*`, `libmenu*`, `libpanel*`, `libform*`.
   - Removes `/usr/share/terminfo`, `/usr/share/bash-completion`,
     `/etc/bash.bashrc`, `/root/.bash*`, etc.
   - Edits `/var/lib/dpkg/status` **and** `/var/lib/dpkg/status.d/<package>`
     to remove metadata entries for `bash`, `libreadline8`, `libtinfo6`,
     `libncurses6`, `ncurses-*`, `libsystemd0` — so CVE scanners (Trivy,
     Scout) don't report vulnerabilities for packages whose files are gone.
   - Verifies mysqld and dash are still executable (`test -x`).
3. `COPY --from=assemble /runtime/… /…` — copies the staged tree wholesale
   into the final image.
4. `VOLUME /var/lib/mysql`, `EXPOSE 3306 33060`, `HEALTHCHECK`, `USER mysql`,
   `WORKDIR /var/lib/mysql`, `ENTRYPOINT` + `CMD ["mysqld"]`.

---

## Where packages come from

### Source repositories

- **Percona Server 8.4.8**: `https://repo.percona.com/pdps-8.4.8/apt/` —
  the Percona Distribution for MySQL 8.4.8 channel.
- **Telemetry agent**: `https://repo.percona.com/telemetry/apt/`
- **Everything else** (libc, libssl, libgcc, libjemalloc2, dash, mawk, …):
  standard Debian Trixie apt mirrors via the DHI `-dev` base.

The repo channel (`testing` / `release` / `experimental`) is a build-time
argument: `docker build --build-arg REPO_CHANNEL=release …`. Defaults to
`testing`.

### Why `pdps-8.4.8` and not `ps-84-lts`?

The original plan used `ps-84-lts`, which is the floating Percona Server 8.4
LTS channel. But:

1. `ps-84-lts` has MySQL Shell only up to Bookworm — **no Trixie build**.
2. `pdps-8.4.8` is the version-locked 8.4.8 distribution channel and has
   **full Trixie coverage** including `percona-mysql-shell` (though the
   hardened image doesn't install it).
3. Version-locked is a better fit for a reproducible hardened build —
   `ps-84-lts` could silently bump to 8.4.9 on the next rebuild, which is
   surprising behavior for a signed image.

When Percona publishes the 8.4.9 distribution channel, you bump
`pdps-8.4.8` → `pdps-8.4.9` in the Dockerfile and rebuild.

### The `libsystemd.so.0` stub

`libsystemd-stub.c` is a ~30-line C file living next to the Dockerfile. It
provides empty implementations of:

```
sd_notify, sd_notifyf, sd_pid_notify, sd_pid_notifyf,
sd_pid_notify_with_fds, sd_booted, sd_watchdog_enabled,
sd_listen_fds, sd_listen_fds_with_names, sd_is_socket,
sd_is_socket_unix, sd_is_socket_inet, sd_is_mq, sd_is_fifo,
sd_is_special
```

All return 0 with empty bodies. This is exactly what the real `libsystemd`
does in practice when `NOTIFY_SOCKET` is unset (which is always the case in
a container without systemd) — the only thing our stub drops is the
function-body machinery that checks `NOTIFY_SOCKET` before returning 0.
Behaviorally identical, attack-surface zero.

The stub is compiled with:

```sh
gcc -shared -fPIC -Wl,-soname,libsystemd.so.0 \
    -o libsystemd.so.0 libsystemd-stub.c
```

...and the result replaces `/usr/lib/x86_64-linux-gnu/libsystemd.so.0`
(both the symlink target and the symlink itself). `mysqld` loads the stub,
resolves `sd_notifyf`, calls it, gets 0, continues startup.

---

## Environment variables

### First-boot init (empty datadir)

| Variable | Default | Description |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | *(required)* | Root password. Either this or `MYSQL_ALLOW_EMPTY_PASSWORD` must be set. Also readable from `MYSQL_ROOT_PASSWORD_FILE` (Docker secret path). |
| `MYSQL_ALLOW_EMPTY_PASSWORD` | unset | Set to `yes` to allow a passwordless root account. |
| `MYSQL_DATABASE` | unset | Name of an application database to create on first boot. |
| `MYSQL_USER` | unset | Non-root user to create (also `MYSQL_USER_FILE`). |
| `MYSQL_PASSWORD` | unset | Password for `MYSQL_USER` (also `MYSQL_PASSWORD_FILE`). |

### Ongoing runtime

| Variable | Default | Description |
|---|---|---|
| `PERCONA_TELEMETRY_DISABLE` | `0` (on) | Set to `1` to disable the telemetry agent. |
| `PERCONA_TELEMETRY_CHECK_INTERVAL` | `86400` (24h) | How often the agent reports. |
| `PERCONA_TELEMETRY_URL` | `https://check.percona.com/v1/telemetry/GenericReport` | Where the agent sends data. |
| `PERCONA_TELEMETRY_HISTORY_KEEP_INTERVAL` | `604800` (7d) | How long local history is kept. |
| `PERCONA_TELEMETRY_RESEND_INTERVAL` | `60` | Retry interval on failure. |

### Explicitly **not** supported (exit 1 with a clear error pointing at the non-hardened image)

| Variable | Why |
|---|---|
| `MYSQL_RANDOM_ROOT_PASSWORD` | Requires `pwmake` from `cracklib` — stripped |
| `MYSQL_ROOT_HOST != localhost` | Would need a second mysqld roundtrip via client |
| `MYSQL_ONETIME_PASSWORD` | Requires an interactive mysql client session |
| `INIT_ROCKSDB` | Requires `ps-admin` — stripped |
| `INIT_TOKUDB` | TokuDB is EOL in MySQL 8.0+ |

---

## `/docker-entrypoint-initdb.d/`

On first boot with an empty datadir, the entrypoint runs `mysqld
--initialize-insecure`, then concatenates **`*.sql`** files from
`/docker-entrypoint-initdb.d/` (in lexicographic order) into a single
`--init-file` bundle that `mysqld` processes natively on its real startup.

| Pattern | Supported | Why / why not |
|---|---|---|
| `*.sql` | **yes** | Concatenated into the init-file bundle |
| `*.sh` | **no** | Would require bash, not in the image |
| `*.sql.gz` | **no** | Would require gunzip, not in the image |

Unsupported files cause the entrypoint to exit 1 with a message listing the
offending files — so you don't get silently-ignored init scripts. If you
need `.sh` or `.sql.gz` support, use the non-hardened
`percona/percona-server:8.4` image.

The entrypoint also prepends generated SQL to the bundle in this order:

```sql
SET @@SESSION.SQL_LOG_BIN = 0;
ALTER USER 'root'@'localhost' IDENTIFIED BY '<escaped MYSQL_ROOT_PASSWORD>';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS `<escaped MYSQL_DATABASE>`;
CREATE USER '<escaped MYSQL_USER>'@'%' IDENTIFIED BY '<escaped MYSQL_PASSWORD>';
GRANT ALL ON `<escaped MYSQL_DATABASE>`.* TO '<escaped MYSQL_USER>'@'%';
-- … then your /docker-entrypoint-initdb.d/*.sql files …
FLUSH PRIVILEGES;
```

All identifiers and string literals are escaped against both standard SQL
mode (`''`-doubling) and backslash-escape mode (`\\`-doubling), so passwords
with quotes or backslashes round-trip cleanly.

---

## Healthcheck

Built-in `HEALTHCHECK`:

```
Test:        mysqladmin ping -h127.0.0.1 || exit 1
Interval:    30s
Timeout:     5s
StartPeriod: 60s
Retries:     3
```

After ~60 seconds on an empty datadir (first init) or ~10 seconds on a
pre-initialized datadir, `docker ps` shows `(healthy)`:

```
CONTAINER ID   IMAGE   …   STATUS                    PORTS           NAMES
abc123def456   evg…    …   Up 2 minutes (healthy)    3306/tcp, …     ps
```

Docker Compose users can gate dependent services on the healthcheck:

```yaml
services:
  db:
    image: evgeniypatlan/test-images:percona-server-8.4-hardened
    environment:
      MYSQL_ROOT_PASSWORD: secret
    volumes: ["ps-data:/var/lib/mysql"]

  app:
    image: myapp:latest
    depends_on:
      db:
        condition: service_healthy
```

---

## Connecting to the server

The hardened image has **no mysql client**. Connect using a **separate client
container**:

```bash
# Client over shared network namespace (auth as MYSQL_USER@'%' via TCP)
docker run --rm --network container:ps \
    mysql:8.4 mysql -h127.0.0.1 -uappuser -papppw app

# Or via a docker network
docker network create mysql-net
docker run -d --name ps --network mysql-net \
    -e MYSQL_ROOT_PASSWORD=x \
    evgeniypatlan/test-images:percona-server-8.4-hardened
docker run --rm -it --network mysql-net \
    mysql:8.4 mysql -hps -uappuser -papppw
```

**Root access over TCP is blocked by design.** The server has
`skip-name-resolve`, and the entrypoint creates only `root@localhost`.
Because `localhost` is resolved by name (not IP), it only matches UNIX
socket connections — not `127.0.0.1` TCP connections. Remote clients must
use `MYSQL_USER@'%'`.

For admin operations, use `docker exec` (runs inside the server's network
namespace, uses the socket):

```bash
docker exec ps mysqladmin -uroot -p"$MYSQL_ROOT_PASSWORD" status
docker exec ps mysqladmin -uroot -p"$MYSQL_ROOT_PASSWORD" shutdown
```

---

## CVE status

Scanning with Trivy 0.52+ against a freshly built image:

| Severity | Count | Notes |
|---|---|---|
| CRITICAL | 0 | — |
| HIGH | 3 | all in `percona-telemetry-agent` (Go stdlib ≤1.26.1) |
| MEDIUM | *(varies)* | — |
| LOW | *(varies)* | — |

### Known HIGH CVEs (all in the Go stdlib of the telemetry agent)

| CVE | Component | Fix |
|---|---|---|
| CVE-2026-32280 | Go `crypto/x509` chain building | Needs Go ≥ 1.26.2 rebuild |
| CVE-2026-32282 | Go `syscall.Root.Chmod` symlink escape | Needs Go ≥ 1.26.2 rebuild |
| CVE-2026-33810 | Go `crypto/x509` DNS constraint bypass | Needs Go ≥ 1.26.2 rebuild |

All three are in the `percona-telemetry-agent` binary. None are exploitable
in the hardened image's runtime context — the telemetry agent does a single
one-shot HTTPS POST to `check.percona.com`, never builds cert chains under
attacker control, and doesn't invoke `Root.Chmod`. They will be picked up
in the next Percona rebuild with Go 1.26.2.

If you need a zero-Go-CVE image, set `PERCONA_TELEMETRY_DISABLE=1` at
runtime — the agent still exists on disk but never runs.

### HIGH CVEs we eliminated vs. a naive DHI build

- `libsystemd0 CVE-2026-29111` — stubbed out
- `libtinfo6 CVE-2025-69720` — removed (no bash, no readline)
- `ncurses-base CVE-2025-69720` — removed
- `ncurses-bin CVE-2025-69720` — removed
- `ncurses-term CVE-2025-69720` — removed

---

## Building from source

```bash
git clone https://github.com/percona/percona-docker
cd percona-docker/percona-server-8.4

docker build \
    --build-arg REPO_CHANNEL=testing \
    -t perconalab/percona-server:8.4-hardened \
    -f Dockerfile.hardened .
```

Build arguments:

| Arg | Default | Purpose |
|---|---|---|
| `REPO_CHANNEL` | `testing` | Percona repo channel: `testing`, `release`, `experimental` |

Files next to `Dockerfile.hardened` that contribute to the build:

- `Dockerfile.hardened` — the build definition (3 stages)
- `libsystemd-stub.c` — the ~30-line libsystemd replacement
- `ps-entry-hardened.sh` — the POSIX sh entrypoint
- `telemetry-agent-supervisor-hardened.sh` — the POSIX sh telemetry supervisor

---

## Testing

`test-hardened.sh` next to the Dockerfile runs a 5-tier test suite:

```bash
./test-hardened.sh                   # all tiers
./test-hardened.sh --tier 1          # just smoke + security
./test-hardened.sh --tier 5          # just SQL functional
./test-hardened.sh --verbose         # show container logs on failure
```

| Tier | Tests | Time |
|---|---|---|
| 1 | Boot, version, security posture (uid, setuid, SBOM, passwd, bash absence, ncurses absence, libsystemd stub) | ~2 min |
| 2 | init-file path, MYSQL_DATABASE/USER, initdb.d SQL, plugin INSTALL, unsupported-knob rejection | ~5 min |
| 3 | Healthcheck transition, read-only rootfs | ~3 min |
| 4 | Existing percona-docker test harness (`utc`, `no-hard-coded-passwords`) | ~1 min |
| 5 | SQL functional via sidecar `mysql:8.4` client — 12 assertions including CRUD, aggregates, transactions, InnoDB/RocksDB engines, utf8mb4 unicode roundtrip | ~2 min |

Total ~13 minutes end-to-end (first run includes pulling the client image).

---

## Volumes, ports, socket

| Path | Purpose | Notes |
|---|---|---|
| `/var/lib/mysql` | **Declared VOLUME** — datadir | Back this with a named volume or bind mount |
| `/var/lib/mysql-files` | `--secure-file-priv` target | Shipped empty, mysql:mysql 0750 |
| `/var/run/mysqld` | Socket (`mysqld.sock`) + pid | Must be writable; use a tmpfs under `--read-only` |
| `/docker-entrypoint-initdb.d` | User init SQL | Read-only bind mount expected |
| `/tmp` | Entrypoint workspace (`--init-file` target) | Must be writable; use a tmpfs under `--read-only` |

Exposed ports:
- **3306** — classic MySQL protocol
- **33060** — MySQL X Protocol (if enabled)

---

## Security model

### Threat model assumptions

- You run this image in a trusted container runtime (Docker, Podman, K8s).
- The host kernel is up to date; container escapes via kernel bugs are out
  of scope for this image.
- Network exposure is controlled by the deployer — the image binds to
  `0.0.0.0:3306` by default but users are expected to publish the port only
  where needed (`-p 127.0.0.1:3306:3306`).

### Hardening features

| Feature | Mechanism |
|---|---|
| Non-root runtime | `USER mysql` (uid 1001) |
| Minimal user database | `/etc/passwd` has 2 entries |
| No package manager | No `apt`, `dpkg`, `yum` in the runtime image |
| No interactive shell | `dash` only, no bash/readline |
| No mysql client | Can't `docker exec mysql …` to get SQL shell; use sidecar |
| No setuid binaries | Verified in the test suite (T1.2b) |
| Pruned lib closure | Only libs `ldd` says are needed |
| Stubbed libsystemd | Real libsystemd replaced with no-op stub |
| Built-in SBOM | `/usr/local/percona-server.spdx.json` |
| DHI-signed base | `dhi.io/debian-base:trixie` is signed by Docker |
| Supports `--read-only` | Datadir, `/var/run/mysqld`, `/tmp` are the only writable paths needed |
| Supports capability drop | `CAP_DROP=ALL` + `CAP_ADD CHOWN,SETGID,SETUID` works |
| Supports `no-new-privileges` | No setuid → trivially compatible |

### What this image does NOT protect against

- **Malicious SQL in `/docker-entrypoint-initdb.d/*.sql`** — any SQL you
  mount there runs with full root privilege on first boot. Treat it like
  code, not data.
- **Weak root passwords** — use a password generator.
- **Exposed TCP port 3306** — bind to localhost unless you intentionally
  want remote clients.
- **Stale images** — rebuild and repush on a cadence (monthly minimum) to
  pick up Debian security updates and Percona patch releases.

---

## Known limitations vs. the non-hardened image

| Feature | Non-hardened `percona/percona-server:8.4` | This image |
|---|---|---|
| Docker image size | ~700 MB | ~300–400 MB |
| `mysql` client in image | yes | **no** |
| `mysqldump` in image | yes | **no** |
| `mysqlsh` (MySQL Shell) | yes | **no** |
| `mysql_upgrade` in image | yes | **no** |
| `mysql_tzinfo_to_sql` | yes | **no** |
| Timezone table populated on init | yes | **no** (`mysql.time_zone_name` empty — users can import manually via sidecar) |
| `MYSQL_RANDOM_ROOT_PASSWORD` | yes | **no** |
| `MYSQL_ROOT_HOST=%` | yes | **no** (`localhost` only) |
| `/docker-entrypoint-initdb.d/*.sh` | yes | **no** |
| `/docker-entrypoint-initdb.d/*.sql.gz` | yes | **no** |
| `INIT_ROCKSDB` env var | yes | **no** (plugin still loadable via `INSTALL PLUGIN`) |
| Base image | `redhat/ubi9-minimal` | `dhi.io/debian-base:trixie` |
| Shell | `bash` | `dash` |
| libsystemd | real | stub |
| Runs as | `mysql` (uid 1001) | `mysql` (uid 1001) |

If any of the "no" rows matter to you, use the non-hardened image. Both are
built from the same Percona Server binaries.

---

## License

Percona Server is released under the [GNU General Public License v2](https://github.com/percona/percona-server/blob/8.4/LICENSE).
The contents of this image include third-party components under their
respective licenses — see the SBOM at `/usr/local/percona-server.spdx.json`
and Percona's [third-party notices](https://docs.percona.com/percona-server/8.4/copyright-and-licensing-information.html).

## Support

- **Commercial support** — [Percona Support](https://hubs.ly/Q02ZTHbG0)
- **Community forum** — [forums.percona.com](https://forums.percona.com/)
- **Bug reports** — [jira.percona.com](https://jira.percona.com)
- **Source** — [github.com/percona/percona-docker](https://github.com/percona/percona-docker)
