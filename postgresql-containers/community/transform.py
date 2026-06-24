#!/usr/bin/env python3
"""
Transform a Percona PostgreSQL Dockerfile into a community build
using upstream PGDG packages instead of Percona distribution packages.

Usage: python3 transform.py <source_dockerfile>
Output: transformed Dockerfile written to stdout
"""

import sys
import re
from pathlib import Path

# pgaudit changed version-alignment scheme with PG 16.
# For PG ≤ 15 PGDG ships pgaudit under its own extension version number.
PGAUDIT_LEGACY = {
    '14': ('pgaudit_${PG_MAJOR_VERSION}', 'pgaudit16_14'),
    '15': ('pgaudit_${PG_MAJOR_VERSION}', 'pgaudit17_15'),
}

# Version token: either a literal number or a shell variable like ${PG_MAJOR_VERSION}
_V = r'(\d+|\$\{[^}]+\})'
# End-of-token boundary that works for both digit endings and shell-variable endings (which end in '}')
_END = r'(?!\w)'

# Longest-match rules first to avoid partial replacements
PACKAGE_MAP = [
    (rf'percona-pgvector_{_V}-llvmjit{_END}',     r'pgvector_\1-llvmjit'),
    (rf'percona-pgvector_{_V}{_END}',              r'pgvector_\1'),
    (rf'percona-postgis\d+_{_V}-llvmjit{_END}',   r'postgis35_\1-llvmjit'),
    (rf'percona-postgis\d+_{_V}-client{_END}',     r'postgis35_\1-client'),
    (rf'percona-postgis\d+_{_V}-utils{_END}',      r'postgis35_\1-utils'),
    (rf'percona-postgis\d+_{_V}{_END}',            r'postgis35_\1'),
    (rf'percona-postgresql{_V}-server{_END}',      r'postgresql\1-server'),
    (rf'percona-postgresql{_V}-contrib{_END}',     r'postgresql\1-contrib'),
    (rf'percona-postgresql{_V}-libs{_END}',        r'postgresql\1-libs'),
    (rf'percona-postgresql{_V}-llvmjit{_END}',     r'postgresql\1-llvmjit'),
    (rf'percona-postgresql{_V}{_END}',             r'postgresql\1'),
    (r'percona-pgbackrest\b',                      r'pgbackrest'),
    (r'percona-pgbouncer\b',                       r'pgbouncer'),
    (rf'percona-pgaudit{_V}_set_user{_END}',       r'set_user_\1'),
    (rf'percona-pgaudit{_V}{_END}',                r'pgaudit_\1'),
    (rf'percona-pg_repack{_V}{_END}',              r'pg_repack_\1'),
    (rf'percona-pg_cron_{_V}{_END}',              r'pg_cron_\1'),
    (rf'percona-wal2json{_V}{_END}',               r'wal2json_\1'),
    (r'percona-patroni\b',                         r'patroni'),
]

# Package names whose entire install line should be dropped
PACKAGES_TO_REMOVE = re.compile(
    r'\bpercona-(?:pg_tde|pg_oidc_validator|pg_stat_monitor|postgresql-common|postgresql-client-common|telemetry-agent)\d*\b'
    r'|(?:percona-)?(?:postgresql|pgvector_|postgis\d+_)\S*-llvmjit\b'
    r'|\bpercona-postgis\d+_\S*'   # PostGIS: needs libqhull_r not in UBI9 standard repos
    r'|\bpostgis\d+_\S*'
    r'|\bpython3-etcd\b'           # Not in PGDG/EPEL for EL8; pulled as patroni dep
    r'|\bpython3-click\b'          # Not in PGDG/EPEL for EL8; pulled as patroni dep
)

# ENV variable names that are Percona-specific and should be removed
PERCONA_ENV_VARS = re.compile(
    r'^ENV\s+(PPG_VERSION|PPG_MINOR_VERSION|PPG_REPO\b|PPG_REPO_VERSION|FULL_PERCONA_VERSION)\s'
)

# ARG names that are Percona-specific and should be removed or renamed
PERCONA_ARG_VARS = re.compile(r'^ARG\s+PPG_REPO\b')

# Markers that identify a RUN block as a Percona repo setup block.
# Deliberately excludes "percona-release enable/disable" to avoid false-matching
# the multi-version loop in the upgrade Dockerfile.
PERCONA_REPO_MARKER = re.compile(
    r'repo\.percona\.com|percona-release-latest\.noarch\.rpm|4D1BB29D63D98E422B2113B19334A25F8507EFA5'
)

# Markers that identify a RUN block as an Oracle Linux EPEL setup block (el8 or el9)
ORACLE_EPEL_MARKER = re.compile(
    r'oraclelinux-release-el[89]|oracle-epel-release-el[89]'
)

# Oracle Linux-specific tool blocks (llvm, annobin) — match only repo-flag usage,
# not file-path globs like /var/cache/dnf/ol9_appstream-*/
ORACLE_TOOL_MARKER = re.compile(
    r'yum-config-manager\b.*\bol[89]_appstream\b'
    r'|--(?:enable|disable)repo="?ol[89]_appstream'
)

# Upgrade-image downloader RUN block (Oracle-specific cache paths, drop it)
UPGRADE_DOWNLOADER_MARKER = re.compile(r'tar\s+-cvzf\s+downloaded-packages\.tar\.gz')

# Upgrade-image extraction RUN block (references downloaded-packages.tar.gz)
UPGRADE_EXTRACT_MARKER = re.compile(r'tar\s+-xvzf\s+downloaded-packages\.tar\.gz')

# gpsbabel download block (PostGIS dep from Oracle Linux EPEL; not needed without PostGIS)
GPSBABEL_MARKER = re.compile(r'gpsbabel')

# Multi-PG-version loop in upgrade image — replaced wholesale with PGDG equivalent
UPGRADE_LOOP_MARKER = re.compile(r'for\s+pg_version\s+in\s+\d+.*\bdo\b')

# Community replacement for the multi-version loop.
# - Drops PG 12/13 (no PGDG EL9 packages)
# - Fixes pgaudit naming for PG 14/15 (pgaudit16_14 / pgaudit17_15)
# - Adds timescaledb (community addition; Citus omitted — incompatible with pg_upgrade)
PGDG_VERSION_LOOP_BLOCK = r"""RUN for pg_version in 17 16 15 14; do \
        if [[ "${pg_version}" -lt 16 ]]; then \
            pgaudit_pkg=$([[ "${pg_version}" -eq 14 ]] && echo pgaudit16_14 || echo pgaudit17_15); \
        else \
            pgaudit_pkg="pgaudit_${pg_version}"; \
        fi; \
        microdnf -y install --nodocs \
            postgresql${pg_version}-server \
            postgresql${pg_version}-contrib \
            postgresql${pg_version}-libs \
            ${pgaudit_pkg} \
            set_user_${pg_version} \
            wal2json_${pg_version} \
            pgvector_${pg_version} \
            pg_repack_${pg_version} \
            timescaledb-${TIMESCALEDB_MAJOR}-postgresql-${pg_version} || true; \
    done && microdnf -y clean all && rm -rf /var/cache/dnf /var/cache/yum"""

# Oracle-specific enablerepo flags (el8 or el9) → PGDG common + EPEL
# patroni comes from pgdg-common; python3-click from epel on EL8 or pgdg-common on EL9
OL9_EPEL_REPO = re.compile(r'--enablerepo="ol[89]_developer_EPEL"')

# Per-line filter: Oracle-specific lines to drop from RUN blocks.
# Note: --enablerepo="ol9_developer_EPEL" is handled by OL9_EPEL_REPO (replaced, not dropped).
# Blocks containing ol9_appstream are dropped wholesale by ORACLE_TOOL_MARKER.
ORACLE_LINE_FILTER = re.compile(
    r'^\s*yum-config-manager\s'
    r'|\bpercona-release\s+enable\s+ppg-'
    r'|\bpercona-release\s+disable\b'
)

HEADER = """\
# Community build using upstream PGDG packages.
# Generated by sync.sh — do not edit manually, run sync.sh --apply to regenerate.
#
# Packages NOT included vs official Percona images:
#   - percona-pg_tde            (Percona-only: Transparent Data Encryption)
#   - percona-pg_oidc_validator (Percona-only: OIDC authentication extension)
#   - percona-pg_stat_monitor   (Percona-only: available separately if needed)
#   - percona-postgresql-common (Percona-only: packaging metadata)
#   - postgresql*-llvmjit       (requires LLVM 20.1 unavailable in UBI9 repos)
#   - pgvector*-llvmjit         (same)
#   - postgis35_*               (requires libqhull_r from Oracle Linux extras, not in standard UBI9)
"""

PGDG_REPO_BLOCK = """\
# Install PGDG and EPEL repositories
RUN set -ex; \\
    ARCH=$(uname -m); \\
    EL_VER=$(. /etc/os-release && echo "${VERSION_ID%%.*}"); \\
    curl -Lf -o /tmp/pgdg-repo.rpm \\
        "https://download.postgresql.org/pub/repos/yum/reporpms/EL-${EL_VER}-${ARCH}/pgdg-redhat-repo-latest.noarch.rpm"; \\
    curl -Lf -o /tmp/epel-release.rpm \\
        "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${EL_VER}.noarch.rpm"; \\
    rpm -i /tmp/pgdg-repo.rpm /tmp/epel-release.rpm; \\
    rm /tmp/pgdg-repo.rpm /tmp/epel-release.rpm; \\
    microdnf clean all"""

# Oracle EPEL blocks are skipped — EPEL is already included in PGDG_REPO_BLOCK above
EPEL_BLOCK = None

# ── Community-only additions (not derived from Percona source Dockerfiles) ────
#
# TimescaleDB: https://packagecloud.io/timescale/timescaledb/el/9/
#   Package names: timescaledb-2-postgresql-{version}
# Citus:        https://repos.citusdata.com/community/el/9/
#   Package names: citus_{version}
#   Note: Citus is added to postgres images only — it is incompatible with pg_upgrade.
#
# $basearch in .repo files is a yum/dnf variable expanded at install time, not by bash.

# Repo setup for postgres images (both TimescaleDB and Citus)
# $basearch is a yum/dnf variable — escaped as \$basearch so bash does not expand it,
# leaving the literal string $basearch in the .repo file for yum to expand at install time.
EXTRA_REPOS_BLOCK = """\
# ── Community additions ────────────────────────────────────────────────────────
# These extensions are not part of the official Percona distribution.
# They are installed from upstream third-party repositories.
#   TimescaleDB source: https://packagecloud.io/timescale/timescaledb/el/{EL_VER}/
#   Citus source:       https://repos.citusdata.com/community/el/{EL_VER}/
ARG TIMESCALEDB_MAJOR=2

RUN set -ex; \\
    EL_VER=$(. /etc/os-release && echo "${VERSION_ID%%.*}"); \\
    printf "[timescale_timescaledb]\\nname=timescale_timescaledb\\nbaseurl=https://packagecloud.io/timescale/timescaledb/el/${EL_VER}/\\$basearch\\nrepo_gpgcheck=1\\ngpgcheck=0\\nenabled=1\\ngpgkey=https://packagecloud.io/timescale/timescaledb/gpgkey\\nsslverify=1\\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt\\nmetadata_expire=300\\n" \\
        > /etc/yum.repos.d/timescale_timescaledb.repo; \\
    printf "[citusdata_community]\\nname=citusdata_community\\nbaseurl=https://repos.citusdata.com/community/el/${EL_VER}/\\$basearch\\nrepo_gpgcheck=1\\ngpgcheck=1\\nenabled=1\\ngpgkey=https://repos.citusdata.com/community/gpgkey\\nsslverify=1\\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt\\nmetadata_expire=300\\n" \\
        > /etc/yum.repos.d/citusdata_community.repo; \\
    microdnf clean all"""

# Install block for postgres images (|| true: packages may not exist for all PG/EL version combos)
TIMESCALEDB_CITUS_INSTALL = """\
RUN set -ex; \\
    microdnf -y install --nodocs \\
        timescaledb-${TIMESCALEDB_MAJOR}-postgresql-${PG_MAJOR_VERSION} \\
        citus_${PG_MAJOR_VERSION} || true; \\
    microdnf clean all; \\
    rm -rf /var/cache/dnf /var/cache/yum"""

# Repo setup + ARG declaration for upgrade image (TimescaleDB only; Citus omitted)
TIMESCALEDB_REPO_ONLY_BLOCK = """\
# ── Community additions ────────────────────────────────────────────────────────
# These extensions are not part of the official Percona distribution.
#   TimescaleDB source: https://packagecloud.io/timescale/timescaledb/el/{EL_VER}/
#   Note: Citus is omitted from the upgrade image — it is incompatible with pg_upgrade.
ARG TIMESCALEDB_MAJOR=2

RUN set -ex; \\
    EL_VER=$(. /etc/os-release && echo "${VERSION_ID%%.*}"); \\
    printf "[timescale_timescaledb]\\nname=timescale_timescaledb\\nbaseurl=https://packagecloud.io/timescale/timescaledb/el/${EL_VER}/\\$basearch\\nrepo_gpgcheck=1\\ngpgcheck=0\\nenabled=1\\ngpgkey=https://packagecloud.io/timescale/timescaledb/gpgkey\\nsslverify=1\\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt\\nmetadata_expire=300\\n" \\
        > /etc/yum.repos.d/timescale_timescaledb.repo; \\
    microdnf clean all"""

# Install block for the primary PG version in the upgrade image (uses ${PG_MAJOR//.})
TIMESCALEDB_INSTALL_UPGRADE = """\
RUN set -ex; \\
    microdnf -y install --nodocs \\
        timescaledb-${TIMESCALEDB_MAJOR}-postgresql-${PG_MAJOR//.} || true; \\
    microdnf clean all; \\
    rm -rf /var/cache/dnf /var/cache/yum"""


def collect_run_block(lines: list, start: int) -> tuple:
    """Collect a multi-line RUN block. Returns (block_lines, last_index).
    Blank lines within a continuation (after a line ending in \\) are kept —
    Docker/bash treats them as whitespace, not block terminators.
    """
    block = []
    i = start
    while i < len(lines):
        line = lines[i]
        block.append(line)
        stripped = line.rstrip()
        # Blank line: stay in block (continuation already active from previous \\)
        if stripped == '':
            i += 1
            continue
        if not stripped.endswith('\\'):
            break
        i += 1
    return block, i


def apply_package_transforms(line: str) -> str:
    for pattern, replacement in PACKAGE_MAP:
        line = re.sub(pattern, replacement, line)
    return line


def apply_var_transforms(line: str) -> str:
    """Replace Percona-specific variable references with generic equivalents."""
    line = line.replace('${PPG_MAJOR_VERSION}', '${PG_MAJOR_VERSION}')
    line = line.replace('$PPG_MAJOR_VERSION', '$PG_MAJOR_VERSION')
    line = line.replace('${PPG_REPO}', '${PG_REPO}')
    line = line.replace('$PPG_REPO', '$PG_REPO')
    # Strip Percona version suffix from package install lines
    line = line.replace('-${FULL_PERCONA_VERSION}', '')
    return line


def transform_run_block(block_lines: list) -> str:
    block_text = '\n'.join(block_lines)

    if PERCONA_REPO_MARKER.search(block_text):
        return PGDG_REPO_BLOCK

    if ORACLE_EPEL_MARKER.search(block_text):
        return EPEL_BLOCK

    # Drop Oracle Linux-specific tool blocks (llvm build deps, annobin, etc.)
    if ORACLE_TOOL_MARKER.search(block_text):
        return None

    # Drop upgrade downloader and extraction blocks (Oracle-specific cache paths)
    if UPGRADE_DOWNLOADER_MARKER.search(block_text):
        return None
    if UPGRADE_EXTRACT_MARKER.search(block_text):
        return None
    if GPSBABEL_MARKER.search(block_text):
        return None

    # Replace multi-version loop with community equivalent
    if UPGRADE_LOOP_MARKER.search(block_text):
        return PGDG_VERSION_LOOP_BLOCK

    result = []
    for line in block_lines:
        if PACKAGES_TO_REMOVE.search(line):
            continue
        if ORACLE_LINE_FILTER.search(line):
            continue
        line = apply_package_transforms(line)
        line = apply_var_transforms(line)
        line = OL9_EPEL_REPO.sub('--enablerepo="pgdg-common" --enablerepo="epel"', line)
        result.append(line)

    result_text = '\n'.join(result)

    return result_text


def transform_other_line(line: str) -> str:
    # Drop the multi-stage downloader (Oracle-specific cache paths, replaced by PGDG+EPEL deps)
    if re.match(r'^FROM\s+\S+\s+AS\s+downloader\b', line):
        return None
    if re.match(r'^COPY\s+--from=downloader\b', line):
        return None

    # Parameterise the base image so callers can switch variants
    if re.match(r'^FROM redhat/ubi9-minimal\b', line):
        return 'ARG BASE_IMAGE=redhat/ubi9-minimal\nFROM ${BASE_IMAGE}'
    if re.match(r'^FROM redhat/ubi8-minimal\b', line):
        return 'ARG BASE_IMAGE=redhat/ubi8-minimal\nFROM ${BASE_IMAGE}'

    # Use almalinux instead of oraclelinux for the downloader build stage
    if re.match(r'^FROM oraclelinux:9\b', line):
        return line.replace('oraclelinux:9', 'almalinux:9')
    if re.match(r'^FROM oraclelinux:8\b', line):
        return line.replace('oraclelinux:8', 'almalinux:8')

    # Drop Percona-specific ENV vars
    if PERCONA_ENV_VARS.match(line):
        return None

    # Drop Percona-specific ARG vars
    if PERCONA_ARG_VARS.match(line):
        return None

    # Rename PPG_* env declarations (fall through to format fix below)
    if re.match(r'^ENV\s+PPG_MAJOR_VERSION\b', line):
        line = line.replace('PPG_MAJOR_VERSION', 'PG_MAJOR_VERSION')
    elif re.match(r'^ENV\s+PPG_REPO\b', line):
        return None

    # Update LABEL
    if 'vendor="Percona"' in line:
        line = line.replace('vendor="Percona"', 'vendor="community"')

    # Drop orphaned "check repository" comment that precedes replaced repo blocks
    if line.strip() == '# check repository package signature in secure way':
        return None

    line = apply_var_transforms(line)

    # Convert legacy "ENV key value" to "ENV key=value"
    m = re.match(r'^(ENV\s+)(\w+)(\s+)(\S.*)$', line)
    if m and '=' not in m.group(2):
        line = f'ENV {m.group(2)}={m.group(4)}'

    return line


def transform(source_path: Path) -> str:
    lines = source_path.read_text().split('\n')

    # Detect PG major version from source directory name (e.g. percona-distribution-postgresql-15)
    m = re.search(r'postgresql-(\d+)', str(source_path))
    pg_version = m.group(1) if m else None

    is_postgres = bool(re.search(r'percona-distribution-postgresql-\d+', str(source_path)))
    is_upgrade = 'build/upgrade' in str(source_path) or 'postgresql-upgrade' in str(source_path)

    output = [HEADER.rstrip(), '']

    i = 0
    while i < len(lines):
        line = lines[i]

        if re.match(r'^RUN\b', line):
            block, i = collect_run_block(lines, i)
            result = transform_run_block(block)
            if result is not None:
                output.append(result)
            i += 1
        else:
            transformed = transform_other_line(line)
            if transformed is not None:
                output.append(transformed)
            i += 1

    result = '\n'.join(output)

    # Apply pgaudit legacy name fixup for PG ≤ 15
    if pg_version and pg_version in PGAUDIT_LEGACY:
        wrong, correct = PGAUDIT_LEGACY[pg_version]
        result = result.replace(wrong, correct)

    # Inject community-only additions
    if is_postgres:
        # TimescaleDB + Citus: repo setup and install, placed just before COPY LICENSE
        inject = EXTRA_REPOS_BLOCK + '\n\n' + TIMESCALEDB_CITUS_INSTALL + '\n\n'
        result = result.replace(
            'COPY LICENSE /licenses/LICENSE.Dockerfile',
            inject + 'COPY LICENSE /licenses/LICENSE.Dockerfile',
            1,
        )
    elif is_upgrade:
        # TimescaleDB repo: injected right after the PGDG repo block
        result = result.replace(
            PGDG_REPO_BLOCK,
            PGDG_REPO_BLOCK + '\n\n' + TIMESCALEDB_REPO_ONLY_BLOCK,
            1,
        )
        # TimescaleDB install for the primary PG version, before the mkdir step
        result = result.replace(
            'RUN mkdir -p /opt/crunchy/bin /pgolddata /pgnewdata /opt/crunchy/conf',
            TIMESCALEDB_INSTALL_UPGRADE + '\n\nRUN mkdir -p /opt/crunchy/bin /pgolddata /pgnewdata /opt/crunchy/conf',
            1,
        )

    return result


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f'Usage: {sys.argv[0]} <source_dockerfile>', file=sys.stderr)
        sys.exit(1)

    sys.stdout.write(transform(Path(sys.argv[1])))
