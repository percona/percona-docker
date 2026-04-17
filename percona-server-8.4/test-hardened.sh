#!/usr/bin/env bash
#
# test-hardened.sh — acceptance tests for perconalab/percona-server:8.4-hardened
#
# Tests the single hardened image:
#   T1 — smoke boot + security posture
#   T2 — init-file path (password, MYSQL_DATABASE, MYSQL_USER, initdb.d/*.sql,
#        plugin INSTALL via init-file, unsupported-knob rejection)
#   T3 — runtime features (healthcheck, --read-only rootfs)
#   T4 — existing percona-docker test harness (utc, no-hard-coded-passwords)
#
# The hardened image has no mysql client, so verification uses:
#   - `mysqladmin` (authenticated — status/variables)
#   - `docker logs` grep (entrypoint markers, mysqld plugin errors)
#
# Usage:
#   ./test-hardened.sh                # all tiers
#   ./test-hardened.sh --tier 1       # only T1
#   ./test-hardened.sh --tier 1,2     # T1+T2
#   ./test-hardened.sh --verbose      # show container logs on failure
#   ./test-hardened.sh --keep         # don't rm containers/volumes after run
#

set -uo pipefail

# ---------- configuration --------------------------------------------------

IMAGE="${IMAGE:-perconalab/percona-server:8.4-hardened}"
CLIENT_IMAGE="${CLIENT_IMAGE:-mysql:8.4}"
WORK_DIR="${WORK_DIR:-/tmp/ps-hardened-test}"
TIERS="${TIERS:-1 2 3 4 5}"
VERBOSE="${VERBOSE:-0}"
KEEP="${KEEP:-0}"

PERCONA_DOCKER_ROOT="${PERCONA_DOCKER_ROOT:-/home/corvin/MYSQL_DOCKER/percona-docker}"
NS="ps-hardened-test"

# ---------- output helpers -------------------------------------------------

if [ -t 1 ]; then
    GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'
    BLUE=$'\033[34m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
    GREEN=""; RED=""; YELLOW=""; BLUE=""; BOLD=""; DIM=""; RESET=""
fi

declare -a RESULTS_PASS=()
declare -a RESULTS_FAIL=()
declare -a RESULTS_SKIP=()

info()  { printf '%s[info]%s %s\n' "$BLUE" "$RESET" "$*"; }
step()  { printf '%s[....]%s %s\n' "$DIM" "$RESET" "$*"; }
pass()  { printf '%s[PASS]%s %s\n' "$GREEN"  "$RESET" "$*"; RESULTS_PASS+=("$*"); }
fail()  { printf '%s[FAIL]%s %s\n' "$RED"    "$RESET" "$*"; RESULTS_FAIL+=("$*"); }
skip()  { printf '%s[SKIP]%s %s\n' "$YELLOW" "$RESET" "$*"; RESULTS_SKIP+=("$*"); }

show_logs_if_verbose() {
    [ "$VERBOSE" = "1" ] || return 0
    local cname="$1"
    printf '%s--- logs for %s (last 40 lines) ---%s\n' "$DIM" "$cname" "$RESET"
    docker logs "$cname" 2>&1 | tail -40 || true
    printf '%s--- end logs ---%s\n' "$DIM" "$RESET"
}

# ---------- cleanup --------------------------------------------------------

cleanup_containers() {
    local ids
    ids="$(docker ps -aq --filter "name=^${NS}-" 2>/dev/null)"
    [ -n "$ids" ] && docker rm -f $ids >/dev/null 2>&1 || true
}

cleanup_volumes() {
    local vols
    vols="$(docker volume ls -q 2>/dev/null | grep "^${NS}-" || true)"
    [ -n "$vols" ] && docker volume rm -f $vols >/dev/null 2>&1 || true
}

cleanup_all() {
    cleanup_containers
    cleanup_volumes
    rm -rf "$WORK_DIR"
}

final_cleanup() {
    [ "$KEEP" = "1" ] && { info "--keep set, leaving containers/volumes in place"; return; }
    cleanup_all
}
trap final_cleanup EXIT

# ---------- utility --------------------------------------------------------

# wait_for_mysqld CONTAINER ROOTPW [TIMEOUT_S]
#
# Uses `mysqladmin status` (authenticated) — not `ping` (no auth, would pass
# during temp-mysqld phase on some images). For the hardened image there's
# no temp mysqld (the entrypoint runs mysqld --initialize-insecure inline and
# then mysqld --init-file), so this only needs to poll for auth success.
wait_for_mysqld() {
    local cname="$1" rootpw="$2" timeout="${3:-180}" i
    for ((i=1; i<=timeout; i++)); do
        if ! docker inspect --format '{{.State.Running}}' "$cname" 2>/dev/null | grep -q true; then
            return 2
        fi
        if docker exec "$cname" mysqladmin -uroot -p"$rootpw" status >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

image_exists() { docker image inspect "$1" >/dev/null 2>&1; }

# mysql_exec CONTAINER USER PASSWORD SQL
#
# Runs SQL against CONTAINER using a throwaway mysql client container
# that shares CONTAINER's network namespace (--network container:...).
# That lets us connect over TCP to 127.0.0.1 inside the shared ns —
# which is the server's loopback — without exposing a host port.
#
# Uses the testuser@'%' account created by MYSQL_USER/MYSQL_PASSWORD,
# because the server runs with skip-name-resolve: root@localhost only
# matches unix-socket connections, not TCP 127.0.0.1.
mysql_exec() {
    local cname="$1" user="$2" pass="$3" sql="$4"
    docker run --rm \
        --network "container:$cname" \
        --entrypoint mysql \
        "$CLIENT_IMAGE" \
        -h127.0.0.1 -u"$user" -p"$pass" -Nse "$sql" 2>/dev/null
}

# ensure_client_image — pull once if missing
ensure_client_image() {
    if ! image_exists "$CLIENT_IMAGE"; then
        info "pulling client image $CLIENT_IMAGE (first run only) …"
        docker pull "$CLIENT_IMAGE" >/dev/null 2>&1 || {
            echo "${RED}ERROR${RESET}: failed to pull $CLIENT_IMAGE" >&2
            return 1
        }
    fi
    return 0
}

# ---------- T1 — smoke + security ------------------------------------------

t1_smoke_boot() {
    local cname="${NS}-smoke"
    local volname="${NS}-smoke-data"
    step "T1.1 smoke: boot hardened image, check mysqladmin auth + version"
    cleanup_containers
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    if ! docker run -d --name "$cname" \
            -e MYSQL_ROOT_PASSWORD=secret \
            -v "$volname:/var/lib/mysql" \
            "$IMAGE" >/dev/null 2>&1; then
        fail "T1.1 smoke: docker run failed"
        return
    fi

    wait_for_mysqld "$cname" secret 180
    if [ $? -ne 0 ]; then
        fail "T1.1 smoke: mysqld not ready (auth check failed)"
        show_logs_if_verbose "$cname"
        docker rm -f "$cname" >/dev/null 2>&1 || true
        docker volume rm -f "$volname" >/dev/null 2>&1 || true
        return
    fi

    local ver
    ver="$(docker exec "$cname" mysqladmin -uroot -psecret variables 2>/dev/null \
           | awk -F'|' '/ version /{gsub(/ /,"",$3); print $3; exit}')"
    if [ -n "$ver" ]; then
        pass "T1.1 smoke: mysqld running, version='$ver'"
    else
        fail "T1.1 smoke: mysqladmin variables didn't return a version"
        show_logs_if_verbose "$cname"
    fi

    docker rm -f "$cname" >/dev/null 2>&1 || true
    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

t1_security() {
    step "T1.2 security: uid, setuid, SBOM, /etc/passwd, bash absence"

    local uid
    uid="$(docker run --rm "$IMAGE" id -u 2>/dev/null || true)"
    if [ "$uid" = "1001" ]; then
        pass "T1.2a security: runs as uid=1001 (mysql)"
    else
        fail "T1.2a security: uid='$uid' (expected 1001)"
    fi

    local setuid_count
    setuid_count="$(docker run --rm --entrypoint "" "$IMAGE" \
        find / -xdev -perm /6000 -type f 2>/dev/null | wc -l)"
    if [ "$setuid_count" -eq 0 ]; then
        pass "T1.2b security: no setuid binaries"
    else
        fail "T1.2b security: found $setuid_count setuid binaries"
    fi

    if docker run --rm --entrypoint "" "$IMAGE" \
            test -f /usr/local/percona-server.spdx.json 2>/dev/null; then
        pass "T1.2c security: SBOM present at /usr/local/percona-server.spdx.json"
    else
        fail "T1.2c security: SBOM missing"
    fi

    local passwd_lines
    passwd_lines="$(docker run --rm --entrypoint "" "$IMAGE" \
        cat /etc/passwd 2>/dev/null | wc -l)"
    if [ "$passwd_lines" = "2" ]; then
        pass "T1.2d security: /etc/passwd is 2 lines (root+mysql)"
    else
        fail "T1.2d security: /etc/passwd has $passwd_lines lines (expected 2)"
    fi

    # No bash → /bin/sh must be dash (or at least not bash)
    local sh_link
    sh_link="$(docker run --rm --entrypoint "" "$IMAGE" readlink /bin/sh 2>/dev/null || true)"
    if [ "$sh_link" = "dash" ] || [ "$sh_link" = "/bin/dash" ]; then
        pass "T1.2e security: /bin/sh → dash (no bash/readline/ncurses)"
    else
        fail "T1.2e security: /bin/sh → '$sh_link' (expected dash)"
    fi

    # Bash must NOT be installed
    if ! docker run --rm --entrypoint "" "$IMAGE" test -e /bin/bash 2>/dev/null \
       && ! docker run --rm --entrypoint "" "$IMAGE" test -e /usr/bin/bash 2>/dev/null; then
        pass "T1.2f security: bash is absent from the image"
    else
        fail "T1.2f security: bash found in the image"
    fi

    # mysql client must NOT be installed (attack-surface reduction)
    if ! docker run --rm --entrypoint "" "$IMAGE" test -e /usr/bin/mysql 2>/dev/null; then
        pass "T1.2g security: mysql client absent (use separate client container)"
    else
        fail "T1.2g security: mysql client found in the image"
    fi

    # ncurses / libreadline / libtinfo must NOT be installed (CVE carriers)
    local ncurses_hits
    ncurses_hits="$(docker run --rm --entrypoint "" "$IMAGE" \
        find / -xdev \( -name 'libreadline.so*' -o -name 'libtinfo.so*' \
                        -o -name 'libncurses*.so*' -o -name 'libhistory.so*' \) \
        2>/dev/null | wc -l)"
    if [ "$ncurses_hits" -eq 0 ]; then
        pass "T1.2h security: no libreadline/libtinfo/libncurses libs"
    else
        fail "T1.2h security: $ncurses_hits readline/ncurses libs present"
    fi

    # libsystemd.so.0 must be present (mysqld's ELF needs DT_NEEDED satisfied)
    # BUT must be our stub — we detect via file size. The real libsystemd0 on
    # Debian Trixie is ~500KB; our stub compiles to <10KB.
    local libsystemd_size
    libsystemd_size="$(docker run --rm --entrypoint "" "$IMAGE" \
        stat -c '%s' /usr/lib/x86_64-linux-gnu/libsystemd.so.0 2>/dev/null || echo 0)"
    if [ "$libsystemd_size" -gt 0 ] && [ "$libsystemd_size" -lt 100000 ]; then
        pass "T1.2i security: libsystemd.so.0 is the stub (${libsystemd_size} bytes)"
    elif [ "$libsystemd_size" -eq 0 ]; then
        fail "T1.2i security: libsystemd.so.0 missing (mysqld ELF will fail to load)"
    else
        fail "T1.2i security: libsystemd.so.0 is ${libsystemd_size} bytes — probably the real lib, not our stub"
    fi
}

# ---------- T2 — init-file path --------------------------------------------

t2_init_password_db_user() {
    local cname="${NS}-initdb"
    local volname="${NS}-initdb-data"
    local start_fails="${#RESULTS_FAIL[@]}"
    step "T2.1 init-file: MYSQL_ROOT_PASSWORD + MYSQL_DATABASE + MYSQL_USER"
    cleanup_containers
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    if ! docker run -d --name "$cname" \
            -e MYSQL_ROOT_PASSWORD=rootpw \
            -e MYSQL_DATABASE=appdb \
            -e MYSQL_USER=appuser \
            -e MYSQL_PASSWORD=apppw \
            -v "$volname:/var/lib/mysql" \
            "$IMAGE" >/dev/null 2>&1; then
        fail "T2.1 init-file: docker run failed"
        return
    fi

    wait_for_mysqld "$cname" rootpw 180
    if [ $? -ne 0 ]; then
        fail "T2.1 init-file: mysqld not ready (root password not set?)"
        show_logs_if_verbose "$cname"
        docker rm -f "$cname" >/dev/null 2>&1 || true
        docker volume rm -f "$volname" >/dev/null 2>&1 || true
        return
    fi

    # Root auth works (implicit: wait_for_mysqld passed with rootpw)
    pass "T2.1a init-file: MYSQL_ROOT_PASSWORD applied via ALTER USER in --init-file"

    # Verify app user auth works (no mysql client, so use mysqladmin).
    # mysqladmin connects via socket; app user lives at 'appuser'@'%',
    # which matches socket connections from localhost.
    if docker exec "$cname" mysqladmin -uappuser -papppw status >/dev/null 2>&1; then
        pass "T2.1b init-file: MYSQL_USER created, can authenticate"
    else
        fail "T2.1b init-file: MYSQL_USER cannot authenticate"
    fi

    # Verify the entrypoint logged that it built the init-file
    local logs
    logs="$(docker logs "$cname" 2>&1)"
    if echo "$logs" | grep -q "hardened: init-file prepared"; then
        pass "T2.1c init-file: entrypoint built --init-file bundle"
    else
        fail "T2.1c init-file: entrypoint did not print 'init-file prepared'"
    fi

    if [ "${#RESULTS_FAIL[@]}" -gt "$start_fails" ]; then
        show_logs_if_verbose "$cname"
    fi
    docker rm -f "$cname" >/dev/null 2>&1 || true
    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

t2_initdb_sql() {
    local cname="${NS}-sql"
    local volname="${NS}-sql-data"
    local start_fails="${#RESULTS_FAIL[@]}"
    step "T2.2 init-file: /docker-entrypoint-initdb.d/*.sql bundled + mysqld --init-file"
    cleanup_containers
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    mkdir -p "$WORK_DIR/initdb"
    cat > "$WORK_DIR/initdb/01-schema.sql" <<'EOF'
CREATE DATABASE IF NOT EXISTS demo;
USE demo;
CREATE TABLE items (id INT PRIMARY KEY, name VARCHAR(50));
INSERT INTO items VALUES (1,'first'),(2,'second');
EOF

    if ! docker run -d --name "$cname" \
            -e MYSQL_ROOT_PASSWORD=secret \
            -v "$WORK_DIR/initdb:/docker-entrypoint-initdb.d:ro" \
            -v "$volname:/var/lib/mysql" \
            "$IMAGE" >/dev/null 2>&1; then
        fail "T2.2 initdb sql: docker run failed"
        return
    fi

    wait_for_mysqld "$cname" secret 180
    if [ $? -ne 0 ]; then
        fail "T2.2 initdb sql: mysqld not ready"
        show_logs_if_verbose "$cname"
        docker rm -f "$cname" >/dev/null 2>&1 || true
        docker volume rm -f "$volname" >/dev/null 2>&1 || true
        return
    fi

    local logs
    logs="$(docker logs "$cname" 2>&1)"

    if echo "$logs" | grep -q "hardened: init-file prepared"; then
        pass "T2.2a initdb sql: --init-file bundle built"
    else
        fail "T2.2a initdb sql: no 'init-file prepared' marker"
    fi

    if echo "$logs" | grep -iE "\[ERROR\].*init.?file" >/dev/null 2>&1; then
        fail "T2.2b initdb sql: mysqld reported --init-file error"
    else
        pass "T2.2b initdb sql: no --init-file errors in mysqld log"
    fi

    if [ "${#RESULTS_FAIL[@]}" -gt "$start_fails" ]; then
        show_logs_if_verbose "$cname"
    fi
    docker rm -f "$cname" >/dev/null 2>&1 || true
    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

t2_plugin_load_via_initfile() {
    local cname="${NS}-plugins"
    local volname="${NS}-plugins-data"
    local start_fails="${#RESULTS_FAIL[@]}"
    step "T2.3 init-file: INSTALL PLUGIN via /docker-entrypoint-initdb.d/*.sql"
    cleanup_containers
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    mkdir -p "$WORK_DIR/plugin-initdb"
    cat > "$WORK_DIR/plugin-initdb/01-plugins.sql" <<'EOF'
-- Exercise dlopen'd plugins to verify the ldd closure captured their deps
INSTALL PLUGIN ROCKSDB SONAME 'ha_rocksdb.so';
INSTALL PLUGIN audit_log SONAME 'audit_log.so';
EOF

    if ! docker run -d --name "$cname" \
            -e MYSQL_ROOT_PASSWORD=secret \
            -v "$WORK_DIR/plugin-initdb:/docker-entrypoint-initdb.d:ro" \
            -v "$volname:/var/lib/mysql" \
            "$IMAGE" >/dev/null 2>&1; then
        fail "T2.3 plugin load: docker run failed"
        return
    fi

    wait_for_mysqld "$cname" secret 180
    if [ $? -ne 0 ]; then
        fail "T2.3 plugin load: mysqld not ready (--init-file INSTALL PLUGIN crashed it?)"
        show_logs_if_verbose "$cname"
        docker rm -f "$cname" >/dev/null 2>&1 || true
        docker volume rm -f "$volname" >/dev/null 2>&1 || true
        return
    fi

    local logs
    logs="$(docker logs "$cname" 2>&1)"

    if echo "$logs" | grep -iE "ha_rocksdb.so.*cannot open|audit_log.so.*cannot open|undefined symbol" >/dev/null 2>&1; then
        fail "T2.3a plugin load: plugin library load error in mysqld log"
    else
        pass "T2.3a plugin load: no plugin lib errors in mysqld log"
    fi

    # Double-check the server is still running (if INSTALL PLUGIN failed fatally in --init-file,
    # mysqld would have exited).
    if docker exec "$cname" mysqladmin -uroot -psecret status >/dev/null 2>&1; then
        pass "T2.3b plugin load: mysqld stayed up after INSTALL PLUGIN statements"
    else
        fail "T2.3b plugin load: mysqld not responsive after plugin INSTALL"
    fi

    if [ "${#RESULTS_FAIL[@]}" -gt "$start_fails" ]; then
        show_logs_if_verbose "$cname"
    fi
    docker rm -f "$cname" >/dev/null 2>&1 || true
    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

t2_reject_random_pw() {
    step "T2.4 reject: MYSQL_RANDOM_ROOT_PASSWORD"
    local volname="${NS}-reject-rpw"
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    local output rc
    output="$(docker run --rm \
        -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
        -v "$volname:/var/lib/mysql" \
        "$IMAGE" 2>&1)"
    rc=$?

    if [ $rc -ne 0 ] && echo "$output" | grep -q "MYSQL_RANDOM_ROOT_PASSWORD"; then
        pass "T2.4 reject: MYSQL_RANDOM_ROOT_PASSWORD rejected (rc=$rc)"
    else
        fail "T2.4 reject: expected clean rejection, got rc=$rc output='${output:0:200}'"
    fi

    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

t2_reject_sh_init() {
    step "T2.5 reject: /docker-entrypoint-initdb.d/*.sh"
    local volname="${NS}-reject-sh"
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    mkdir -p "$WORK_DIR/sh-initdb"
    cat > "$WORK_DIR/sh-initdb/01-should-fail.sh" <<'EOF'
#!/bin/sh
echo "this should not run"
EOF

    local output rc
    output="$(docker run --rm \
        -e MYSQL_ROOT_PASSWORD=secret \
        -v "$WORK_DIR/sh-initdb:/docker-entrypoint-initdb.d:ro" \
        -v "$volname:/var/lib/mysql" \
        "$IMAGE" 2>&1)"
    rc=$?

    if [ $rc -ne 0 ] && echo "$output" | grep -q "not supported"; then
        pass "T2.5 reject: .sh initdb file rejected cleanly"
    else
        fail "T2.5 reject: expected rejection, got rc=$rc"
    fi

    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

# ---------- T3 — runtime features ------------------------------------------

t3_healthcheck() {
    step "T3.1 runtime: healthcheck transitions to 'healthy'"

    local cname="${NS}-hc"
    local volname="${NS}-hc-data"
    cleanup_containers
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    if ! docker run -d --name "$cname" \
            -e MYSQL_ROOT_PASSWORD=hc \
            -v "$volname:/var/lib/mysql" \
            "$IMAGE" >/dev/null 2>&1; then
        fail "T3.1 healthcheck: docker run failed"
        return
    fi

    local status="" i
    for ((i=1; i<=18; i++)); do
        sleep 10
        status="$(docker inspect --format '{{.State.Health.Status}}' "$cname" 2>/dev/null || echo unknown)"
        if [ "$status" = "healthy" ]; then
            pass "T3.1 healthcheck: healthy after $((i*10))s"
            docker rm -f "$cname" >/dev/null 2>&1 || true
            docker volume rm -f "$volname" >/dev/null 2>&1 || true
            return
        fi
    done
    fail "T3.1 healthcheck: never reached healthy (last='$status')"
    show_logs_if_verbose "$cname"
    docker rm -f "$cname" >/dev/null 2>&1 || true
    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

t3_readonly_rootfs() {
    step "T3.2 runtime: --read-only rootfs + tmpfs /tmp + tmpfs /var/run/mysqld"

    local cname="${NS}-ro"
    local volname="${NS}-ro-data"
    cleanup_containers
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    # Telemetry disabled for read-only test because the supervisor writes to
    # /var/log/percona/telemetry-agent.log, which is read-only under --read-only
    # unless we add another tmpfs mount. Simpler to just disable telemetry here.
    if ! docker run -d --name "$cname" \
            --read-only \
            --tmpfs /tmp:rw,size=64m,mode=1777 \
            --tmpfs /var/run/mysqld:rw,size=8m,uid=1001,gid=1001,mode=0755 \
            -e MYSQL_ROOT_PASSWORD=ropw \
            -e PERCONA_TELEMETRY_DISABLE=1 \
            -v "$volname:/var/lib/mysql" \
            "$IMAGE" >/dev/null 2>&1; then
        fail "T3.2 readonly: docker run failed"
        docker volume rm -f "$volname" >/dev/null 2>&1 || true
        return
    fi

    wait_for_mysqld "$cname" ropw 180
    if [ $? -eq 0 ]; then
        pass "T3.2 readonly: mysqld runs under --read-only rootfs"
    else
        fail "T3.2 readonly: mysqld did not come up under --read-only"
        show_logs_if_verbose "$cname"
    fi

    docker rm -f "$cname" >/dev/null 2>&1 || true
    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

# ---------- T5 — SQL functional tests via sidecar client ------------------

t5_sql_functional() {
    local cname="${NS}-sql"
    local volname="${NS}-sql-data"
    local start_fails="${#RESULTS_FAIL[@]}"
    step "T5 sql: boot once, run 12 SQL assertions via sidecar client"

    ensure_client_image || { fail "T5 sql: client image $CLIENT_IMAGE unavailable"; return; }

    cleanup_containers
    docker volume rm -f "$volname" >/dev/null 2>&1 || true

    mkdir -p "$WORK_DIR/sql-initdb"
    cat > "$WORK_DIR/sql-initdb/01-plugins.sql" <<'EOF'
INSTALL PLUGIN ROCKSDB SONAME 'ha_rocksdb.so';
EOF

    if ! docker run -d --name "$cname" \
            -e MYSQL_ROOT_PASSWORD=rootpw \
            -e MYSQL_DATABASE=testdb \
            -e MYSQL_USER=testuser \
            -e MYSQL_PASSWORD=testpw \
            -v "$WORK_DIR/sql-initdb:/docker-entrypoint-initdb.d:ro" \
            -v "$volname:/var/lib/mysql" \
            "$IMAGE" >/dev/null 2>&1; then
        fail "T5 sql: docker run failed"
        return
    fi

    wait_for_mysqld "$cname" rootpw 180
    if [ $? -ne 0 ]; then
        fail "T5 sql: mysqld not ready"
        show_logs_if_verbose "$cname"
        docker rm -f "$cname" >/dev/null 2>&1 || true
        docker volume rm -f "$volname" >/dev/null 2>&1 || true
        return
    fi

    local val

    # T5.1 — SELECT VERSION()
    val="$(mysql_exec "$cname" testuser testpw "SELECT VERSION()")"
    if echo "$val" | grep -q '^8\.4\.'; then
        pass "T5.1 sql: SELECT VERSION() → '$val'"
    else
        fail "T5.1 sql: VERSION() returned '$val'"
    fi

    # T5.2 — arithmetic
    val="$(mysql_exec "$cname" testuser testpw "SELECT 40+2")"
    [ "$val" = "42" ] && pass "T5.2 sql: arithmetic 40+2=42" \
                      || fail "T5.2 sql: 40+2='$val'"

    # T5.3 — testuser sees testdb
    val="$(mysql_exec "$cname" testuser testpw "USE testdb; SELECT DATABASE()")"
    [ "$val" = "testdb" ] && pass "T5.3 sql: testuser landed in testdb" \
                          || fail "T5.3 sql: DATABASE()='$val'"

    # T5.4 — CREATE TABLE + INSERT
    mysql_exec "$cname" testuser testpw "
        USE testdb;
        CREATE TABLE items (
            id INT PRIMARY KEY AUTO_INCREMENT,
            name VARCHAR(50) NOT NULL,
            price DECIMAL(10,2),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB;
        INSERT INTO items (name, price)
            VALUES ('Widget', 9.99), ('Gadget', 19.99), ('Gizmo', 29.99);
    " >/dev/null
    val="$(mysql_exec "$cname" testuser testpw "SELECT COUNT(*) FROM testdb.items")"
    [ "$val" = "3" ] && pass "T5.4 crud: CREATE + INSERT (3 rows)" \
                     || fail "T5.4 crud: row count '$val' (expected 3)"

    # T5.5 — aggregate
    val="$(mysql_exec "$cname" testuser testpw \
        "SELECT ROUND(AVG(price),2) FROM testdb.items")"
    [ "$val" = "19.99" ] && pass "T5.5 crud: AVG(price)=19.99" \
                         || fail "T5.5 crud: AVG='$val'"

    # T5.6 — UPDATE
    mysql_exec "$cname" testuser testpw \
        "UPDATE testdb.items SET price=price*2 WHERE name='Widget'" >/dev/null
    val="$(mysql_exec "$cname" testuser testpw \
        "SELECT price FROM testdb.items WHERE name='Widget'")"
    [ "$val" = "19.98" ] && pass "T5.6 crud: UPDATE (Widget 9.99 → 19.98)" \
                         || fail "T5.6 crud: UPDATE price='$val'"

    # T5.7 — DELETE
    mysql_exec "$cname" testuser testpw \
        "DELETE FROM testdb.items WHERE name='Gizmo'" >/dev/null
    val="$(mysql_exec "$cname" testuser testpw \
        "SELECT COUNT(*) FROM testdb.items")"
    [ "$val" = "2" ] && pass "T5.7 crud: DELETE (2 rows remain)" \
                     || fail "T5.7 crud: count after DELETE='$val'"

    # T5.8 — transaction rollback
    mysql_exec "$cname" testuser testpw "
        START TRANSACTION;
        INSERT INTO testdb.items (name, price) VALUES ('Doohickey', 4.99);
        ROLLBACK;
    " >/dev/null
    val="$(mysql_exec "$cname" testuser testpw \
        "SELECT COUNT(*) FROM testdb.items")"
    [ "$val" = "2" ] && pass "T5.8 txn: ROLLBACK (still 2 rows)" \
                     || fail "T5.8 txn: rollback leaked, count='$val'"

    # T5.9 — InnoDB is the default engine
    val="$(mysql_exec "$cname" testuser testpw \
        "SELECT support FROM information_schema.engines WHERE engine='InnoDB'")"
    [ "$val" = "DEFAULT" ] && pass "T5.9 engines: InnoDB=DEFAULT" \
                           || fail "T5.9 engines: InnoDB='$val'"

    # T5.10 — RocksDB loaded and available
    val="$(mysql_exec "$cname" testuser testpw \
        "SELECT support FROM information_schema.engines WHERE engine='ROCKSDB'")"
    if [ "$val" = "YES" ] || [ "$val" = "DEFAULT" ]; then
        pass "T5.10 engines: ROCKSDB=$val"
    else
        fail "T5.10 engines: ROCKSDB='$val'"
    fi

    # T5.11 — utf8mb4 default character set
    val="$(mysql_exec "$cname" testuser testpw "SELECT @@character_set_server")"
    [ "$val" = "utf8mb4" ] && pass "T5.11 vars: @@character_set_server=utf8mb4" \
                           || fail "T5.11 vars: charset='$val'"

    # T5.12 — Unicode roundtrip (BMP + astral plane)
    mysql_exec "$cname" testuser testpw "
        CREATE TABLE testdb.unicode_test (t VARCHAR(100)) CHARSET=utf8mb4;
        INSERT INTO testdb.unicode_test VALUES ('Hello 世界 🌍 Привет');
    " >/dev/null
    val="$(mysql_exec "$cname" testuser testpw \
        "SELECT t FROM testdb.unicode_test")"
    if [ "$val" = "Hello 世界 🌍 Привет" ]; then
        pass "T5.12 unicode: utf8mb4 roundtrip (BMP + astral + Cyrillic)"
    else
        fail "T5.12 unicode: got '$val'"
    fi

    if [ "${#RESULTS_FAIL[@]}" -gt "$start_fails" ]; then
        show_logs_if_verbose "$cname"
    fi
    docker rm -f "$cname" >/dev/null 2>&1 || true
    docker volume rm -f "$volname" >/dev/null 2>&1 || true
}

# ---------- T4 — percona-docker test harness -------------------------------

t4_harness() {
    step "T4 percona-docker test harness"
    if [ ! -x "$PERCONA_DOCKER_ROOT/test/run.sh" ]; then
        skip "T4 harness: $PERCONA_DOCKER_ROOT/test/run.sh not found"
        return
    fi

    local testname
    for testname in utc no-hard-coded-passwords; do
        (
            cd "$PERCONA_DOCKER_ROOT" && \
            ./test/run.sh -t "$testname" "$IMAGE"
        ) >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            pass "T4 harness: $testname"
        else
            fail "T4 harness: $testname failed"
        fi
    done
}

# ---------- main -----------------------------------------------------------

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --tier N              Run only tier N (1,2,3,4,5). Comma list: --tier 1,2
  --image IMG           Image tag (default: $IMAGE)
  --client-image IMG    Client image for SQL tests (default: $CLIENT_IMAGE)
  --work-dir DIR        Working dir for bind-mounted initdb.d (default: $WORK_DIR)
  --verbose             Dump container logs (tail 40) on failure
  --keep                Don't clean up containers/volumes/workdir after run
  --help                Show this help

Tiers:
  1   smoke + security posture
  2   init-file path (password, MYSQL_DATABASE, initdb.d, plugin load, rejections)
  3   runtime features (healthcheck, --read-only rootfs)
  4   existing percona-docker test harness (utc, no-hard-coded-passwords)
  5   SQL functional tests via sidecar $CLIENT_IMAGE client

Environment variables (same as long flags):
  IMAGE, CLIENT_IMAGE, WORK_DIR, TIERS, VERBOSE, KEEP, PERCONA_DOCKER_ROOT

Examples:
  $0                              # all tiers
  $0 --tier 1                     # just smoke + security
  $0 --tier 1,2 --verbose         # T1+T2 with logs on failure
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --tier)          TIERS="${2//,/ }"; shift 2 ;;
        --image)         IMAGE="$2";        shift 2 ;;
        --client-image)  CLIENT_IMAGE="$2"; shift 2 ;;
        --work-dir)      WORK_DIR="$2";     shift 2 ;;
        --verbose)       VERBOSE=1;         shift ;;
        --keep)          KEEP=1;            shift ;;
        -h|--help)       usage; exit 0 ;;
        *)               echo "unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac
done

info "image:        $IMAGE"
info "client image: $CLIENT_IMAGE (for T5 SQL tests)"
info "workdir:      $WORK_DIR"
info "tiers:        $TIERS"
info "verbose:      $VERBOSE    keep: $KEEP"
info ""

if ! image_exists "$IMAGE"; then
    echo "${RED}ERROR${RESET}: image '$IMAGE' not found locally." >&2
    echo "Build with:" >&2
    echo "  docker build --build-arg REPO_CHANNEL=testing -t $IMAGE -f Dockerfile.hardened ." >&2
    exit 2
fi

cleanup_all
mkdir -p "$WORK_DIR"

for tier in $TIERS; do
    info ""
    info "================ TIER $tier ================"
    case "$tier" in
        1)
            t1_smoke_boot
            t1_security
            ;;
        2)
            t2_init_password_db_user
            t2_initdb_sql
            t2_plugin_load_via_initfile
            t2_reject_random_pw
            t2_reject_sh_init
            ;;
        3)
            t3_healthcheck
            t3_readonly_rootfs
            ;;
        4)
            t4_harness
            ;;
        5)
            t5_sql_functional
            ;;
        *)
            echo "${YELLOW}unknown tier: $tier${RESET}"
            ;;
    esac
done

# ---------- summary --------------------------------------------------------

info ""
info "================ SUMMARY ================"
printf '%s  passed: %d%s\n' "$GREEN"  "${#RESULTS_PASS[@]}" "$RESET"
printf '%s  failed: %d%s\n' "$RED"    "${#RESULTS_FAIL[@]}" "$RESET"
printf '%s skipped: %d%s\n' "$YELLOW" "${#RESULTS_SKIP[@]}" "$RESET"

if [ "${#RESULTS_FAIL[@]}" -gt 0 ]; then
    info ""
    info "Failures:"
    for f in "${RESULTS_FAIL[@]}"; do
        printf '  %s✗%s %s\n' "$RED" "$RESET" "$f"
    done
fi

exit "${#RESULTS_FAIL[@]}"
