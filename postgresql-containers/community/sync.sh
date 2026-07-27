#!/usr/bin/env bash
# Checks whether official Percona Dockerfiles have changed since the last sync,
# regenerates community Dockerfiles via transform.py, and reports diffs.
#
# Usage:
#   ./sync.sh           -- dry run: show what would change
#   ./sync.sh --apply   -- write changes to community Dockerfiles
#   ./sync.sh --force   -- regenerate even if source is unchanged
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TRANSFORM="${SCRIPT_DIR}/transform.py"
HASH_FILE="${SCRIPT_DIR}/.source-hashes"

DRY_RUN=true
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) DRY_RUN=false ;;
        --force) FORCE=true ;;
        -h|--help)
            sed -n '2,6p' "$0" | sed 's/^# //'
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# source Dockerfile → community target Dockerfile
declare -A TARGETS
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-18/Dockerfile"]="${SCRIPT_DIR}/build/postgres18/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-17/Dockerfile"]="${SCRIPT_DIR}/build/postgres17/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-16/Dockerfile"]="${SCRIPT_DIR}/build/postgres16/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-15/Dockerfile"]="${SCRIPT_DIR}/build/postgres15/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-14/Dockerfile"]="${SCRIPT_DIR}/build/postgres14/Dockerfile"
TARGETS["${REPO_ROOT}/percona-pgbackrest/Dockerfile"]="${SCRIPT_DIR}/build/pgbackrest/Dockerfile"
TARGETS["${REPO_ROOT}/percona-pgbouncer/Dockerfile"]="${SCRIPT_DIR}/build/pgbouncer/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-upgrade/Dockerfile"]="${SCRIPT_DIR}/build/upgrade/Dockerfile"

# UBI8 variants (no pgbackrest/pgbouncer — no Dockerfile-ubi8 source exists for those)
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-18/Dockerfile-ubi8"]="${SCRIPT_DIR}/build/postgres18-ubi8/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-17/Dockerfile-ubi8"]="${SCRIPT_DIR}/build/postgres17-ubi8/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-16/Dockerfile-ubi8"]="${SCRIPT_DIR}/build/postgres16-ubi8/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-15/Dockerfile-ubi8"]="${SCRIPT_DIR}/build/postgres15-ubi8/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-14/Dockerfile-ubi8"]="${SCRIPT_DIR}/build/postgres14-ubi8/Dockerfile"
TARGETS["${REPO_ROOT}/percona-distribution-postgresql-upgrade/Dockerfile-ubi8"]="${SCRIPT_DIR}/build/upgrade-ubi8/Dockerfile"

# entrypoint.sh, pgbackrest.conf, and LICENSE files are committed permanently
# in each build/ subdirectory — sync.sh only manages the Dockerfiles.

sha256_file() {
    if command -v sha256sum &>/dev/null; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

get_stored_hash() {
    local source="$1"
    local rel="${source#${REPO_ROOT}/}"
    [[ -f "$HASH_FILE" ]] && grep -F "$rel " "$HASH_FILE" 2>/dev/null | awk '{print $2}' || echo ""
}

store_hash() {
    local source="$1" hash="$2"
    local rel="${source#${REPO_ROOT}/}"
    touch "$HASH_FILE"
    local tmp
    tmp=$(mktemp)
    grep -vF "$rel " "$HASH_FILE" > "$tmp" || true
    echo "$rel $hash" >> "$tmp"
    mv "$tmp" "$HASH_FILE"
}

needs_apply=0
all_current=true

for source in "${!TARGETS[@]}"; do
    target="${TARGETS[$source]}"
    rel_source="${source#${REPO_ROOT}/}"

    echo "--- ${rel_source}"

    if [[ ! -f "$source" ]]; then
        echo "    ERROR: source file not found"
        continue
    fi

    current_hash=$(sha256_file "$source")
    stored_hash=$(get_stored_hash "$source")

    if [[ "$current_hash" == "$stored_hash" && "$FORCE" == false && -f "$target" ]]; then
        echo "    up to date"
        continue
    fi

    all_current=false

    if [[ -z "$stored_hash" ]]; then
        echo "    first sync"
    elif [[ "$current_hash" != "$stored_hash" ]]; then
        echo "    source changed since last sync"
    fi

    mkdir -p "$(dirname "$target")"
    proposed=$(python3 "$TRANSFORM" "$source")

    if [[ -f "$target" ]] && diff <(echo "$proposed") "$target" > /dev/null 2>&1; then
        echo "    transform output unchanged — recording hash"
        store_hash "$source" "$current_hash"
        continue
    fi

    if [[ -f "$target" ]]; then
        echo "    diff (current → proposed):"
        diff "$target" <(echo "$proposed") | head -80 | sed 's/^/      /' || true
    else
        echo "    target does not exist yet"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        needs_apply=1
        echo "    [dry run] pass --apply to write"
    else
        echo "$proposed" > "$target"
        store_hash "$source" "$current_hash"
        echo "    written: ${target#${SCRIPT_DIR}/}"
    fi
done

echo ""

if [[ "$all_current" == true ]]; then
    echo "All community Dockerfiles are up to date."
elif [[ $needs_apply -eq 1 ]]; then
    echo "Run with --apply to write the changes above."
fi
