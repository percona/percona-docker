"""
Unit tests for transform.py — community Dockerfile transformation logic.

Run with: pytest tests/test_transform.py -v
"""
import sys
import textwrap
from pathlib import Path

import pytest

# Make transform importable from the parent directory
sys.path.insert(0, str(Path(__file__).parent.parent))

from transform import (
    GPSBABEL_MARKER,
    ORACLE_EPEL_MARKER,
    ORACLE_LINE_FILTER,
    ORACLE_TOOL_MARKER,
    PACKAGES_TO_REMOVE,
    PERCONA_REPO_MARKER,
    PGAUDIT_LEGACY,
    PGDG_REPO_BLOCK,
    PGDG_VERSION_LOOP_BLOCK,
    TIMESCALEDB_CITUS_INSTALL,
    UPGRADE_DOWNLOADER_MARKER,
    UPGRADE_EXTRACT_MARKER,
    UPGRADE_LOOP_MARKER,
    apply_package_transforms,
    apply_var_transforms,
    collect_run_block,
    transform,
    transform_other_line,
    transform_run_block,
)


# ── apply_package_transforms ──────────────────────────────────────────────────

class TestPackageMap:
    def test_postgresql_server(self):
        assert apply_package_transforms("percona-postgresql17-server") == "postgresql17-server"

    def test_postgresql_contrib(self):
        assert apply_package_transforms("percona-postgresql17-contrib") == "postgresql17-contrib"

    def test_postgresql_libs(self):
        assert apply_package_transforms("percona-postgresql17-libs") == "postgresql17-libs"

    def test_postgresql_bare(self):
        assert apply_package_transforms("percona-postgresql17") == "postgresql17"

    def test_postgresql_llvmjit_removed_via_packages_to_remove(self):
        # llvmjit is not in PACKAGE_MAP but in PACKAGES_TO_REMOVE — verify it matches there
        assert PACKAGES_TO_REMOVE.search("percona-postgresql17-llvmjit")

    def test_pgvector(self):
        assert apply_package_transforms("percona-pgvector_17") == "pgvector_17"

    def test_pgvector_llvmjit_in_packages_to_remove(self):
        assert PACKAGES_TO_REMOVE.search("percona-pgvector_17-llvmjit")

    def test_pgaudit_set_user(self):
        assert apply_package_transforms("percona-pgaudit17_set_user") == "set_user_17"

    def test_pgaudit_bare(self):
        assert apply_package_transforms("percona-pgaudit17") == "pgaudit_17"

    def test_pg_repack(self):
        assert apply_package_transforms("percona-pg_repack17") == "pg_repack_17"

    def test_pg_cron_has_underscore_before_version(self):
        # Regression: percona-pg_cron_17 (underscore before version, unlike pg_repack)
        assert apply_package_transforms("percona-pg_cron_17") == "pg_cron_17"

    def test_wal2json(self):
        assert apply_package_transforms("percona-wal2json17") == "wal2json_17"

    def test_pgbackrest(self):
        assert apply_package_transforms("percona-pgbackrest") == "pgbackrest"

    def test_pgbouncer(self):
        assert apply_package_transforms("percona-pgbouncer") == "pgbouncer"

    def test_patroni(self):
        assert apply_package_transforms("percona-patroni") == "patroni"

    def test_postgis_bare(self):
        # PostGIS ends up in PACKAGES_TO_REMOVE, but the map entry still exists
        assert apply_package_transforms("percona-postgis35_17") == "postgis35_17"

    def test_postgis_client(self):
        assert apply_package_transforms("percona-postgis35_17-client") == "postgis35_17-client"

    def test_postgis_utils(self):
        assert apply_package_transforms("percona-postgis35_17-utils") == "postgis35_17-utils"

    def test_no_double_transform(self):
        # percona-pgaudit17_set_user must not also match pgaudit bare rule
        result = apply_package_transforms("percona-pgaudit17_set_user")
        assert result == "set_user_17"
        assert "pgaudit" not in result

    def test_shell_var_version(self):
        assert apply_package_transforms("percona-postgresql${PG_MAJOR_VERSION}-server") \
               == "postgresql${PG_MAJOR_VERSION}-server"

    def test_pg_cron_shell_var(self):
        assert apply_package_transforms("percona-pg_cron_${PG_MAJOR_VERSION}") \
               == "pg_cron_${PG_MAJOR_VERSION}"

    def test_pgaudit_shell_var(self):
        assert apply_package_transforms("percona-pgaudit${PG_MAJOR_VERSION}") \
               == "pgaudit_${PG_MAJOR_VERSION}"


# ── PACKAGES_TO_REMOVE ────────────────────────────────────────────────────────

class TestPackagesToRemove:
    def test_pg_tde(self):
        assert PACKAGES_TO_REMOVE.search("        percona-pg_tde18 \\")

    def test_pg_oidc_validator(self):
        assert PACKAGES_TO_REMOVE.search("        percona-pg_oidc_validator18 \\")

    def test_pg_stat_monitor(self):
        assert PACKAGES_TO_REMOVE.search("        percona-pg_stat_monitor18 \\")

    def test_postgresql_common(self):
        assert PACKAGES_TO_REMOVE.search("        percona-postgresql-common \\")

    def test_postgresql_client_common(self):
        assert PACKAGES_TO_REMOVE.search("        percona-postgresql-client-common \\")

    def test_telemetry_agent(self):
        assert PACKAGES_TO_REMOVE.search("        percona-telemetry-agent \\")

    def test_llvmjit(self):
        assert PACKAGES_TO_REMOVE.search("        percona-postgresql17-llvmjit \\")

    def test_pgvector_llvmjit(self):
        assert PACKAGES_TO_REMOVE.search("        percona-pgvector_17-llvmjit \\")

    def test_postgis(self):
        assert PACKAGES_TO_REMOVE.search("        percona-postgis35_17 \\")

    def test_postgis_client(self):
        assert PACKAGES_TO_REMOVE.search("        percona-postgis35_17-client \\")

    def test_python3_etcd(self):
        # Regression: not available in PGDG/EPEL for EL8
        assert PACKAGES_TO_REMOVE.search("        python3-etcd \\")

    def test_python3_click(self):
        # Regression: not available in PGDG/EPEL for EL8
        assert PACKAGES_TO_REMOVE.search("        python3-click \\")

    def test_does_not_match_plain_postgresql(self):
        assert not PACKAGES_TO_REMOVE.search("        postgresql17-server \\")

    def test_does_not_match_pgaudit(self):
        assert not PACKAGES_TO_REMOVE.search("        pgaudit_17 \\")

    def test_does_not_match_patroni(self):
        assert not PACKAGES_TO_REMOVE.search("        patroni \\")


# ── apply_var_transforms ──────────────────────────────────────────────────────

class TestVarTransforms:
    def test_ppg_major_version_braced(self):
        assert apply_var_transforms("postgresql${PPG_MAJOR_VERSION}-server") \
               == "postgresql${PG_MAJOR_VERSION}-server"

    def test_ppg_major_version_bare(self):
        assert apply_var_transforms("postgresql$PPG_MAJOR_VERSION-server") \
               == "postgresql$PG_MAJOR_VERSION-server"

    def test_full_percona_version_stripped(self):
        assert apply_var_transforms("percona-patroni-${FULL_PERCONA_VERSION}") \
               == "percona-patroni"

    def test_no_change_when_not_percona(self):
        line = "postgresql17-server"
        assert apply_var_transforms(line) == line


# ── transform_run_block — block-level decisions ───────────────────────────────

class TestTransformRunBlock:
    def _block(self, text):
        return text.strip().splitlines()

    def test_percona_repo_replaced_with_pgdg(self):
        block = self._block("""
            RUN set -ex; \\
                curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \\
                rpm -i /tmp/percona-release.rpm
        """)
        assert transform_run_block(block) == PGDG_REPO_BLOCK

    def test_percona_gpg_key_triggers_repo_replace(self):
        block = self._block("""
            RUN gpg --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5
        """)
        assert transform_run_block(block) == PGDG_REPO_BLOCK

    def test_oracle_epel_block_dropped(self):
        block = self._block("""
            RUN curl -o /tmp/epel.rpm https://yum.oracle.com/.../oracle-epel-release-el9-1.0-1.el9.rpm; \\
                rpm -i /tmp/epel.rpm
        """)
        assert transform_run_block(block) is None

    def test_oracle_epel_el8_block_dropped(self):
        block = self._block("""
            RUN curl -o /tmp/epel.rpm https://yum.oracle.com/.../oraclelinux-release-el8-1.0.rpm; \\
                rpm -i /tmp/epel.rpm
        """)
        assert transform_run_block(block) is None

    def test_oracle_tool_block_dropped(self):
        block = self._block("""
            RUN yum-config-manager --set-enabled ol9_appstream; \\
                microdnf install -y llvm-toolset annobin-annocheck annobin-plugin-gcc
        """)
        assert transform_run_block(block) is None

    def test_oracle_enablerepo_block_dropped(self):
        block = self._block("""
            RUN microdnf install -y --enablerepo="ol9_appstream" libqhull_r; \\
                microdnf clean all
        """)
        assert transform_run_block(block) is None

    def test_upgrade_downloader_dropped(self):
        block = self._block("""
            RUN yum install -y --downloadonly perl-JSON; \\
                tar -cvzf downloaded-packages.tar.gz downloaded-packages
        """)
        assert transform_run_block(block) is None

    def test_upgrade_extract_dropped(self):
        block = self._block("""
            RUN tar -xvzf downloaded-packages.tar.gz; \\
                rpm -Uvh --replacepkgs *.rpm
        """)
        assert transform_run_block(block) is None

    def test_gpsbabel_block_dropped(self):
        # Regression: PostGIS dep downloaded from Oracle Linux repos
        block = self._block("""
            RUN curl -Lf -o /tmp/gpsbabel.rpm https://yum.oracle.com/.../gpsbabel-1.6.0-3.el8.x86_64.rpm; \\
                rpmkeys --checksig /tmp/gpsbabel.rpm; \\
                rpm -i --nodeps /tmp/gpsbabel.rpm; \\
                rm -f /tmp/gpsbabel.rpm
        """)
        assert transform_run_block(block) is None

    def test_upgrade_loop_replaced(self):
        block = self._block("""
            RUN for pg_version in 17 16 15 14 13 12; do \\
                    percona-release enable ppg-${pg_version} release; \\
                    microdnf -y install --nodocs percona-postgresql${pg_version}-server; \\
                done
        """)
        assert transform_run_block(block) == PGDG_VERSION_LOOP_BLOCK

    def test_packages_to_remove_dropped_per_line(self):
        block = self._block("""
            RUN microdnf install -y \\
                    postgresql17-server \\
                    percona-pg_tde17 \\
                    pgaudit_17; \\
                microdnf clean all
        """)
        result = transform_run_block(block)
        assert "percona-pg_tde17" not in result
        assert "postgresql17-server" in result
        assert "pgaudit_17" in result

    def test_python3_etcd_dropped(self):
        block = self._block("""
            RUN microdnf install -y \\
                    postgresql17-server \\
                    python3-etcd \\
                    wal2json_17; \\
                microdnf clean all
        """)
        result = transform_run_block(block)
        assert "python3-etcd" not in result
        assert "postgresql17-server" in result

    def test_python3_click_dropped(self):
        block = self._block("""
            RUN microdnf install -y \\
                    python3-click \\
                    patroni; \\
                microdnf clean all
        """)
        result = transform_run_block(block)
        assert "python3-click" not in result
        assert "patroni" in result

    def test_percona_release_enable_line_dropped(self):
        block = self._block("""
            RUN percona-release enable ppg-17 release; \\
                microdnf install -y postgresql17-server; \\
                microdnf clean all
        """)
        result = transform_run_block(block)
        assert "percona-release" not in result
        assert "postgresql17-server" in result

    def test_ol9_epel_repo_replaced(self):
        block = self._block("""
            RUN microdnf install -y --enablerepo="ol9_developer_EPEL" \\
                    patroni; \\
                microdnf clean all
        """)
        result = transform_run_block(block)
        assert 'ol9_developer_EPEL' not in result
        assert '--enablerepo="pgdg-common"' in result
        assert '--enablerepo="epel"' in result

    def test_ol8_epel_repo_replaced(self):
        # Regression: pattern must match ol8 as well as ol9
        block = self._block("""
            RUN microdnf install -y --enablerepo="ol8_developer_EPEL" \\
                    patroni; \\
                microdnf clean all
        """)
        result = transform_run_block(block)
        assert 'ol8_developer_EPEL' not in result
        assert '--enablerepo="pgdg-common"' in result

    def test_timescaledb_citus_install_has_or_true(self):
        # Packages may not exist for all PG/EL version combos
        assert '|| true' in TIMESCALEDB_CITUS_INSTALL

    def test_pgdg_loop_has_or_true(self):
        assert '|| true' in PGDG_VERSION_LOOP_BLOCK


# ── transform_other_line ──────────────────────────────────────────────────────

class TestTransformOtherLine:
    def test_ubi9_from_parameterised(self):
        result = transform_other_line("FROM redhat/ubi9-minimal")
        assert result == "ARG BASE_IMAGE=redhat/ubi9-minimal\nFROM ${BASE_IMAGE}"

    def test_ubi8_from_parameterised(self):
        result = transform_other_line("FROM redhat/ubi8-minimal")
        assert result == "ARG BASE_IMAGE=redhat/ubi8-minimal\nFROM ${BASE_IMAGE}"

    def test_oraclelinux9_replaced_with_almalinux(self):
        result = transform_other_line("FROM oraclelinux:9 AS downloader")
        # The AS downloader line is dropped entirely
        assert result is None

    def test_oraclelinux9_bare_replaced(self):
        # oraclelinux:9 without AS stage → almalinux
        result = transform_other_line("FROM oraclelinux:9")
        assert result is not None
        assert "almalinux:9" in result

    def test_oraclelinux8_replaced(self):
        result = transform_other_line("FROM oraclelinux:8")
        assert result is not None
        assert "almalinux:8" in result

    def test_downloader_from_dropped(self):
        assert transform_other_line("FROM oraclelinux:9 AS downloader") is None
        assert transform_other_line("FROM almalinux:9 AS downloader") is None

    def test_copy_from_downloader_dropped(self):
        assert transform_other_line("COPY --from=downloader /downloaded-packages.tar.gz .") is None

    def test_percona_env_var_dropped(self):
        assert transform_other_line("ENV PPG_VERSION 17.4") is None
        assert transform_other_line("ENV PPG_MINOR_VERSION 17") is None
        assert transform_other_line("ENV FULL_PERCONA_VERSION 17.4-1") is None

    def test_percona_arg_var_dropped(self):
        assert transform_other_line("ARG PPG_REPO=ppg-17") is None

    def test_ppg_major_version_env_renamed(self):
        result = transform_other_line("ENV PPG_MAJOR_VERSION 17")
        assert result is not None
        assert "PG_MAJOR_VERSION" in result
        assert "PPG_MAJOR_VERSION" not in result

    def test_vendor_percona_replaced(self):
        line = '    vendor="Percona" \\'
        result = transform_other_line(line)
        assert 'vendor="community"' in result
        assert 'vendor="Percona"' not in result

    def test_env_legacy_format_normalised(self):
        # "ENV key value" → "ENV key=value"
        result = transform_other_line("ENV OS_VER el9")
        assert result == "ENV OS_VER=el9"

    def test_env_modern_format_unchanged(self):
        result = transform_other_line("ENV OS_VER=el9")
        assert result == "ENV OS_VER=el9"

    def test_repo_comment_dropped(self):
        assert transform_other_line("# check repository package signature in secure way") is None

    def test_unrelated_lines_pass_through(self):
        line = "COPY entrypoint.sh /entrypoint.sh"
        assert transform_other_line(line) == line


# ── pgaudit legacy naming ─────────────────────────────────────────────────────

class TestPgauditLegacy:
    def test_pg14_mapping(self):
        wrong, correct = PGAUDIT_LEGACY['14']
        assert wrong == 'pgaudit_${PG_MAJOR_VERSION}'
        assert correct == 'pgaudit16_14'

    def test_pg15_mapping(self):
        wrong, correct = PGAUDIT_LEGACY['15']
        assert wrong == 'pgaudit_${PG_MAJOR_VERSION}'
        assert correct == 'pgaudit17_15'

    def test_pg16_not_in_legacy(self):
        assert '16' not in PGAUDIT_LEGACY

    def test_full_transform_pg14_uses_pgaudit16_14(self, tmp_path):
        # Real Dockerfiles use ${PG_MAJOR_VERSION}; legacy fixup targets that form
        src = tmp_path / "percona-distribution-postgresql-14" / "Dockerfile"
        src.parent.mkdir()
        src.write_text(textwrap.dedent("""\
            FROM redhat/ubi9-minimal
            ENV PG_MAJOR_VERSION=14
            RUN microdnf install -y \\
                    percona-pgaudit${PG_MAJOR_VERSION} \\
                    percona-postgresql${PG_MAJOR_VERSION}-server; \\
                microdnf clean all
            COPY LICENSE /licenses/LICENSE.Dockerfile
        """))
        result = transform(src)
        assert "pgaudit16_14" in result
        assert "pgaudit17_15" not in result
        assert "pgaudit_${PG_MAJOR_VERSION}" not in result

    def test_full_transform_pg15_uses_pgaudit17_15(self, tmp_path):
        src = tmp_path / "percona-distribution-postgresql-15" / "Dockerfile"
        src.parent.mkdir()
        src.write_text(textwrap.dedent("""\
            FROM redhat/ubi9-minimal
            ENV PG_MAJOR_VERSION=15
            RUN microdnf install -y \\
                    percona-pgaudit${PG_MAJOR_VERSION} \\
                    percona-postgresql${PG_MAJOR_VERSION}-server; \\
                microdnf clean all
            COPY LICENSE /licenses/LICENSE.Dockerfile
        """))
        result = transform(src)
        assert "pgaudit17_15" in result
        assert "pgaudit16_14" not in result
        assert "pgaudit_${PG_MAJOR_VERSION}" not in result

    def test_full_transform_pg17_uses_pgaudit_17(self, tmp_path):
        src = tmp_path / "percona-distribution-postgresql-17" / "Dockerfile"
        src.parent.mkdir()
        src.write_text(textwrap.dedent("""\
            FROM redhat/ubi9-minimal
            ENV PG_MAJOR_VERSION=17
            RUN microdnf install -y \\
                    percona-pgaudit${PG_MAJOR_VERSION} \\
                    percona-postgresql${PG_MAJOR_VERSION}-server; \\
                microdnf clean all
            COPY LICENSE /licenses/LICENSE.Dockerfile
        """))
        result = transform(src)
        assert "pgaudit_${PG_MAJOR_VERSION}" in result
        assert "pgaudit16_" not in result
        assert "pgaudit17_15" not in result


# ── collect_run_block ─────────────────────────────────────────────────────────

class TestCollectRunBlock:
    def test_single_line_block(self):
        lines = ["RUN microdnf clean all", "ENV FOO=bar"]
        block, last = collect_run_block(lines, 0)
        assert block == ["RUN microdnf clean all"]
        assert last == 0

    def test_multi_line_block(self):
        lines = [
            "RUN microdnf install -y \\",
            "    postgresql17-server; \\",
            "    microdnf clean all",
            "ENV FOO=bar",
        ]
        block, last = collect_run_block(lines, 0)
        assert len(block) == 3
        assert last == 2

    def test_blank_line_inside_block_kept(self):
        lines = [
            "RUN microdnf install -y \\",
            "",
            "    postgresql17-server; \\",
            "    microdnf clean all",
        ]
        block, last = collect_run_block(lines, 0)
        assert "" in block
        assert last == 3


# ── full transform — community additions injection ────────────────────────────

class TestCommunityAdditionsInjection:
    def _minimal_postgres_src(self, tmp_path, pg_version="17"):
        d = tmp_path / f"percona-distribution-postgresql-{pg_version}"
        d.mkdir()
        src = d / "Dockerfile"
        src.write_text(textwrap.dedent(f"""\
            FROM redhat/ubi9-minimal
            ENV PG_MAJOR_VERSION={pg_version}
            RUN microdnf install -y \\
                    percona-postgresql{pg_version}-server; \\
                microdnf clean all
            COPY LICENSE /licenses/LICENSE.Dockerfile
        """))
        return src

    def _minimal_upgrade_src(self, tmp_path, ubi8=False):
        d = tmp_path / "percona-distribution-postgresql-upgrade"
        d.mkdir()
        fname = "Dockerfile-ubi8" if ubi8 else "Dockerfile"
        src = d / fname
        base = "redhat/ubi8-minimal" if ubi8 else "redhat/ubi9-minimal"
        src.write_text(textwrap.dedent(f"""\
            FROM {base}
            ARG PG_MAJOR=18
            RUN set -ex; \\
                curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \\
                rpm -i /tmp/percona-release.rpm
            RUN for pg_version in 17 16 15 14 13 12; do \\
                    percona-release enable ppg-${{pg_version}} release; \\
                done
            RUN mkdir -p /opt/crunchy/bin /pgolddata /pgnewdata /opt/crunchy/conf
        """))
        return src

    def test_postgres_gets_timescaledb_citus_repos(self, tmp_path):
        src = self._minimal_postgres_src(tmp_path)
        result = transform(src)
        assert "timescale_timescaledb" in result
        assert "citusdata_community" in result

    def test_postgres_gets_timescaledb_citus_install(self, tmp_path):
        src = self._minimal_postgres_src(tmp_path)
        result = transform(src)
        assert "timescaledb-${TIMESCALEDB_MAJOR}-postgresql-${PG_MAJOR_VERSION}" in result
        assert "citus_${PG_MAJOR_VERSION}" in result

    def test_postgres_timescaledb_install_has_or_true(self, tmp_path):
        src = self._minimal_postgres_src(tmp_path)
        result = transform(src)
        # Find the citus install line and confirm || true follows
        assert "citus_${PG_MAJOR_VERSION} || true" in result

    def test_postgres_community_injected_before_copy_license(self, tmp_path):
        src = self._minimal_postgres_src(tmp_path)
        result = transform(src)
        ts_pos = result.find("timescale_timescaledb")
        license_pos = result.find("COPY LICENSE /licenses/LICENSE.Dockerfile")
        assert ts_pos < license_pos

    def test_upgrade_gets_timescaledb_repo_only(self, tmp_path):
        src = self._minimal_upgrade_src(tmp_path)
        result = transform(src)
        assert "timescale_timescaledb" in result
        assert "citusdata_community" not in result  # Citus incompatible with pg_upgrade

    def test_upgrade_gets_pgdg_version_loop(self, tmp_path):
        src = self._minimal_upgrade_src(tmp_path)
        result = transform(src)
        # Community loop drops PG 12/13
        assert "for pg_version in 17 16 15 14" in result
        assert "12" not in result.split("for pg_version in")[1].split(";")[0]

    def test_ubi8_source_gets_ubi8_base_image(self, tmp_path):
        src = self._minimal_upgrade_src(tmp_path, ubi8=True)
        result = transform(src)
        assert "ARG BASE_IMAGE=redhat/ubi8-minimal" in result

    def test_ubi9_source_gets_ubi9_base_image(self, tmp_path):
        src = self._minimal_postgres_src(tmp_path)
        result = transform(src)
        assert "ARG BASE_IMAGE=redhat/ubi9-minimal" in result

    def test_header_present(self, tmp_path):
        src = self._minimal_postgres_src(tmp_path)
        result = transform(src)
        assert "Community build using upstream PGDG packages" in result

    def test_percona_vendor_label_replaced(self, tmp_path):
        d = tmp_path / "percona-distribution-postgresql-17"
        d.mkdir()
        src = d / "Dockerfile"
        src.write_text(textwrap.dedent("""\
            FROM redhat/ubi9-minimal
            LABEL vendor="Percona"
            RUN microdnf clean all
            COPY LICENSE /licenses/LICENSE.Dockerfile
        """))
        result = transform(src)
        assert 'vendor="community"' in result
        assert 'vendor="Percona"' not in result
