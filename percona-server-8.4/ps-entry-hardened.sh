#!/bin/sh
#
# ps-entry-hardened.sh — entrypoint for perconalab/percona-server:8.4-hardened
#
# POSIX /bin/sh only (runs under dash). NO bash. NO libreadline. NO ncurses.
#
# On empty datadir: runs mysqld --initialize-insecure then mysqld --init-file
# with a bundled SQL file built from env vars + /docker-entrypoint-initdb.d/*.sql.
#
# Supported env vars (on empty datadir):
#   MYSQL_ROOT_PASSWORD, MYSQL_ROOT_PASSWORD_FILE
#   MYSQL_ALLOW_EMPTY_PASSWORD
#   MYSQL_DATABASE, MYSQL_DATABASE_FILE
#   MYSQL_USER, MYSQL_USER_FILE
#   MYSQL_PASSWORD, MYSQL_PASSWORD_FILE
#   PERCONA_TELEMETRY_DISABLE (set to 1 to skip telemetry supervisor)
#
# NOT supported (exits 1 with a clear error, pointing users at the
# non-hardened percona/percona-server:8.4 image):
#   MYSQL_RANDOM_ROOT_PASSWORD    — needs pwmake from cracklib
#   MYSQL_ROOT_HOST != localhost  — needs a second mysqld roundtrip
#   /docker-entrypoint-initdb.d/*.sh     — no bash in this image
#   /docker-entrypoint-initdb.d/*.sql.gz — no gunzip in this image
#   INIT_ROCKSDB / INIT_TOKUDB / MYSQL_ONETIME_PASSWORD — need a mysql client
#
# Supported /docker-entrypoint-initdb.d contents: *.sql files only. They are
# concatenated into a combined --init-file bundle that mysqld processes
# natively at first start, no client-side shell dance required.
#

set -e

# ---- argv massage ----------------------------------------------------------
case "${1:-}" in
    -*) set -- mysqld "$@" ;;
esac

# ---- detect --help/--version to skip init path ----------------------------
wantHelp=
for arg in "$@"; do
    case "$arg" in
        -'?'|--help|--print-defaults|-V|--version)
            wantHelp=1
            break
            ;;
    esac
done

# ---- helpers ---------------------------------------------------------------

# file_env VAR [DEFAULT]
# Reads value from $VAR, or from the file named in $VAR_FILE (Docker secrets
# pattern). Errors if both are set. POSIX sh has no ${!var}, so we use eval.
file_env() {
    var=$1
    fileVar="${var}_FILE"
    def=${2:-}

    eval "val=\${$var:-}"
    eval "fileVal=\${$fileVar:-}"

    if [ -n "$val" ] && [ -n "$fileVal" ]; then
        echo >&2 "error: both $var and $fileVar are set (exclusive)"
        exit 1
    fi

    if [ -z "$val" ] && [ -n "$fileVal" ]; then
        val=$(cat "$fileVal")
    fi
    if [ -z "$val" ]; then
        val=$def
    fi

    eval "export $var=\"\$val\""
    unset "$fileVar"
}

# sql_escape — double backslashes AND doubled single quotes. Survives both
# default MySQL sql_mode and NO_BACKSLASH_ESCAPES mode for the quote escape.
sql_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/''/g"
}

# sql_escape_ident — double backticks for backtick-quoted identifiers.
sql_escape_ident() {
    printf '%s' "$1" | sed 's/`/``/g'
}

# _get_config <name> <mysqld> [...flags]
# Parse mysqld --verbose --help output for a config value.
_get_config() {
    conf=$1
    shift
    "$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | \
        awk -v k="$conf" '$1 == k && /^[^ \t]/ { sub(/^[^ \t]+[ \t]+/, ""); print; exit }'
}

_die() {
    echo >&2 "ERROR: $*"
    echo >&2 "       This feature is not supported by the hardened image."
    echo >&2 "       Use percona/percona-server:8.4 (non-hardened) if you need it."
    exit 1
}

# ---- main init / start flow -----------------------------------------------

if [ "$1" = 'mysqld' ] && [ -z "$wantHelp" ]; then
    # Apply jemalloc LD_PRELOAD from baked /etc/default/mysql
    if [ -r /etc/default/mysql ]; then
        # shellcheck disable=SC1091
        . /etc/default/mysql
        [ -n "${LD_PRELOAD:-}" ] && export LD_PRELOAD
    fi

    DATADIR=$(_get_config 'datadir' "$@")
    DATADIR=${DATADIR:-/var/lib/mysql}

    if [ ! -d "$DATADIR/mysql" ]; then
        # --- pre-flight: reject unsupported knobs -----------------------------
        [ -n "${MYSQL_RANDOM_ROOT_PASSWORD:-}" ] && \
            _die "MYSQL_RANDOM_ROOT_PASSWORD is not supported (needs pwmake)."
        [ -n "${INIT_ROCKSDB:-}" ] && \
            _die "INIT_ROCKSDB is not supported (needs mysql client + ps-admin)."
        [ -n "${INIT_TOKUDB:-}" ] && \
            _die "INIT_TOKUDB is not supported (TokuDB is EOL)."
        [ -n "${MYSQL_ONETIME_PASSWORD:-}" ] && \
            _die "MYSQL_ONETIME_PASSWORD is not supported (needs mysql client)."

        file_env 'MYSQL_ROOT_HOST' 'localhost'
        if [ "$MYSQL_ROOT_HOST" != "localhost" ]; then
            _die "MYSQL_ROOT_HOST=$MYSQL_ROOT_HOST is not supported (runtime creates root@localhost only)."
        fi

        # Reject unsupported /docker-entrypoint-initdb.d contents
        bad_found=0
        bad_list=
        for f in /docker-entrypoint-initdb.d/*.sh /docker-entrypoint-initdb.d/*.sql.gz; do
            [ -e "$f" ] || continue
            bad_list="${bad_list:+$bad_list }$f"
            bad_found=1
        done
        if [ "$bad_found" = "1" ]; then
            echo >&2 "  found: $bad_list"
            _die "/docker-entrypoint-initdb.d/*.sh and *.sql.gz are not supported (no bash or gunzip in this image)."
        fi

        # --- password required ------------------------------------------------
        file_env 'MYSQL_ROOT_PASSWORD'
        if [ -z "$MYSQL_ROOT_PASSWORD" ] && [ -z "${MYSQL_ALLOW_EMPTY_PASSWORD:-}" ]; then
            echo >&2 'ERROR: database is uninitialized and no password option is set.'
            echo >&2 '       Set MYSQL_ROOT_PASSWORD=<secret> or MYSQL_ALLOW_EMPTY_PASSWORD=yes.'
            exit 1
        fi

        mkdir -p "$DATADIR"

        # --- phase 1: let mysqld build the system tables ---------------------
        echo 'hardened: mysqld --initialize-insecure ...'
        "$@" --initialize-insecure --datadir="$DATADIR"
        echo 'hardened: system tables created'

        # --- phase 2: assemble the combined --init-file SQL bundle -----------
        INIT_FILE=$(mktemp /tmp/ps-init.XXXXXX.sql)
        chmod 0600 "$INIT_FILE"

        file_env 'MYSQL_DATABASE'
        file_env 'MYSQL_USER'
        file_env 'MYSQL_PASSWORD'

        {
            echo "-- ps-entry-hardened.sh generated init-file"
            echo "SET @@SESSION.SQL_LOG_BIN = 0;"

            if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
                esc_pw=$(sql_escape "$MYSQL_ROOT_PASSWORD")
                printf "ALTER USER 'root'@'localhost' IDENTIFIED BY '%s';\n" "$esc_pw"
            fi

            echo "DROP DATABASE IF EXISTS test;"

            if [ -n "$MYSQL_DATABASE" ]; then
                esc_db=$(sql_escape_ident "$MYSQL_DATABASE")
                printf "CREATE DATABASE IF NOT EXISTS \`%s\`;\n" "$esc_db"
            fi

            if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
                esc_u=$(sql_escape "$MYSQL_USER")
                esc_p=$(sql_escape "$MYSQL_PASSWORD")
                printf "CREATE USER '%s'@'%%' IDENTIFIED BY '%s';\n" "$esc_u" "$esc_p"
                if [ -n "$MYSQL_DATABASE" ]; then
                    printf "GRANT ALL ON \`%s\`.* TO '%s'@'%%';\n" "$esc_db" "$esc_u"
                fi
            fi

            # User-provided SQL from /docker-entrypoint-initdb.d (lex order)
            for f in /docker-entrypoint-initdb.d/*.sql; do
                [ -e "$f" ] || continue
                echo "-- BEGIN $f"
                cat "$f"
                printf '\n'
                echo "-- END $f"
            done

            echo "FLUSH PRIVILEGES;"
        } > "$INIT_FILE"

        set -- "$@" --init-file="$INIT_FILE"
        echo "hardened: init-file prepared at $INIT_FILE"
    fi
fi

# ---- telemetry supervisor + exec mysqld -----------------------------------
# Telemetry is ON by default; set PERCONA_TELEMETRY_DISABLE=1 to opt out.
if [ "${PERCONA_TELEMETRY_DISABLE:-0}" = "1" ]; then
    exec "$@" --percona_telemetry_disable=1
else
    /usr/bin/telemetry-agent-supervisor.sh &
    exec "$@"
fi
