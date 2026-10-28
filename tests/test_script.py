"""Run with python3 -m unittest discover -s tests -v."""
import os
import re
import shutil
import subprocess
import tempfile
import unicodedata
import unittest
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "nowhere-vps.sh"
KEY = "0123456789abcdef0123456789abcdef"


class ScriptTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="nowhere-script-test-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.config = self.directory / "nowhere.env"
        self.write_config()

    def write_config(self, **overrides):
        values = dict(
            NOWHERE_VERSION_VALUE="v2.2.1", NOWHERE_LANG_VALUE="en",
            NOWHERE_CLIENT_VALUE="anywhere", NOWHERE_PUBLIC_HOST_VALUE="proxy.example.com",
            NOWHERE_LISTEN_HOST_VALUE="", NOWHERE_KEY_VALUE=KEY,
            NOWHERE_TCP_CARRIER_VALUE="tcp", NOWHERE_TCP_PORT_VALUE="2077",
            NOWHERE_UDP_CARRIER_VALUE="udp", NOWHERE_UDP_PORT_VALUE="2077",
            NOWHERE_TLS_VALUE="1", NOWHERE_MORPH_VALUE="0",
            NOWHERE_MORPH_TCP_PRELUDE_VALUE="low7", NOWHERE_DIAL_VALUE="auto",
            NOWHERE_DIAL4_VALUE="auto", NOWHERE_DIAL6_VALUE="auto",
            NOWHERE_SOCKS_VALUE="none", NOWHERE_NEXT_VALUE="none",
            NOWHERE_VECTOR_MUX_VALUE="0", NOWHERE_TRANSPORT_MEMORY_PROFILE_VALUE="memory",
            NOWHERE_PORTAL=f"portal://{KEY}@*:2077?tls=1&morph=0")
        values.update(overrides)
        self.config.write_text("".join(f'{key}="{value}"\n' for key, value in values.items()))

    def shell(self, body, env=None, input=None, script=SCRIPT):
        environment = dict(os.environ, TEST_SCRIPT=str(script), TEST_DIR=str(self.directory))
        environment.update(env or {})
        setup = '''source "$TEST_SCRIPT" help >/dev/null
CONFIG_DIR="$TEST_DIR"; CONFIG_FILE="$TEST_DIR/nowhere.env"; SERVICE_FILE="$TEST_DIR/nowhere.service"
require_root() { :; }; require_systemd() { :; }
detect_public_host() { printf 203.0.113.10; }
'''
        return subprocess.run(["bash", "-c", setup + body], env=environment,
                              input=input, text=True, capture_output=True, timeout=20)

    def test_old_updater_preserves_service_and_loads_new_menu(self):
        old = self.directory / "nowhere-vps.sh"
        shutil.copyfile(ROOT / "tests/fixtures/legacy-updater.sh", old)
        old.chmod(0o755)
        original = old.read_bytes()
        service = self.directory / "nowhere.service"
        service.write_text("ExecStart=/usr/local/bin/nowhere ${NOWHERE_PORTAL}\n")
        binary = self.directory / "nowhere"
        binary.write_text("saved-binary")
        before = (self.config.read_bytes(), service.read_bytes(), binary.read_bytes())
        bindir = self.directory / "bin"
        bindir.mkdir()
        curl = bindir / "curl"
        curl.write_text('''#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
  case "$1" in -o) output="$2"; shift 2 ;; *) shift ;; esac
done
cp "$TEST_DOWNLOAD" "$output"
''')
        curl.chmod(0o755)
        env = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", TEST_DOWNLOAD=str(SCRIPT))
        result = subprocess.run(["bash", str(old)], env=env, text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(old.read_bytes(), SCRIPT.read_bytes())
        backups = list(self.directory.glob("nowhere-vps.sh.bak.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original)
        result = self.shell('''systemctl() { [[ "$1" == is-active ]] || return 99; printf active; }
BIN_PATH=/usr/bin/true; menu
''', input="q\n", script=old)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Nowhere VPS Manager", result.stdout)
        self.assertIn("v2.2.1", result.stdout)
        self.assertEqual(before, (self.config.read_bytes(), service.read_bytes(), binary.read_bytes()))

    def test_udp_only_links_for_both_protocols(self):
        for version in ("v2.2.1", "v3.0.0"):
            self.write_config(NOWHERE_VERSION_VALUE=version, NOWHERE_TCP_CARRIER_VALUE="none")
            result = self.shell("print_qr_code() { :; }; print_links")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("QUIC/UDP", result.stdout)
            self.assertNotIn("TLS/TCP", result.stdout)

    def test_fingerprint_survives_failed_live_probe(self):
        pin = "a" * 64
        self.write_config(NOWHERE_VERSION_VALUE="v3.0.0", NOWHERE_MORPH_VALUE="1")
        result = self.shell('''BIN_PATH=/usr/bin/false
systemctl() { [[ "$1" != show ]] || printf 0123456789abcdef0123456789abcdef; }
journalctl() {
  [[ "$*" == *"_SYSTEMD_INVOCATION_ID=0123456789abcdef0123456789abcdef"* ]] || return 1
  printf 'CERT_SHA256|%s\\n' "$TEST_PIN"
}
print_tls_fingerprint
''', env={"TEST_PIN": pin})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(pin, result.stdout)
        self.assertNotIn("unavailable", result.stderr.lower())

    def test_invalid_explicit_key_is_rejected(self):
        result = self.shell('''ASSUME_YES=1; NOWHERE_VERSION=v3.0.0
KEY_EXPLICIT=1; NOWHERE_KEY="$TEST_KEY"; configure_values
''', env={"TEST_KEY": KEY * 2})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly 32", result.stderr)

    def test_nw2_configuration_is_preserved(self):
        self.write_config(NOWHERE_KEY_VALUE=KEY * 2)
        result = self.shell('''ASSUME_YES=1; NOWHERE_VERSION=v2.2.1; configure_values
[[ "$NOWHERE_KEY" == "$TEST_KEY" ]]
[[ "$NOWHERE_TRANSPORT_MEMORY_PROFILE" == memory && "$NOWHERE_MORPH_TCP_PRELUDE" == low7 ]]
''', env={"TEST_KEY": KEY * 2})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_nw3_migration_rotates_long_saved_key(self):
        self.write_config(NOWHERE_KEY_VALUE=KEY * 2)
        result = self.shell('''ASSUME_YES=1; NOWHERE_VERSION=v3.0.0; configure_values
validate_nw3_key "$NOWHERE_KEY"
[[ "$NOWHERE_TRANSPORT_MEMORY_PROFILE" == memory && "$NOWHERE_MORPH_TCP_PRELUDE" == low7 ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Rotating", result.stderr)

    def test_key_migration_updates_both_service_url_fields(self):
        self.write_config(NOWHERE_VERSION_VALUE="v2.1.2", NOWHERE_KEY_VALUE="old-key",
                          NOWHERE_PORTAL="portal://old-key@*:2077?tls=1")
        result = self.shell('''ASSUME_YES=1; load_config
NOWHERE_KEY="$NOWHERE_KEY_VALUE"; NOWHERE_NEXT=none
migrate_shared_key_for_version v2.2.1; persist_shared_key_migration
source "$CONFIG_FILE"
[[ "$NOWHERE_SERVICE_URL" == "$NOWHERE_PORTAL" && "$NOWHERE_PORTAL" == *"$NOWHERE_KEY_VALUE@"* ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_release_picker_defaults_to_current_protocol_line(self):
        result = self.shell('''fetch_recent_releases() { printf '%s\\n' v3.1.0 v3.0.0 v2.2.1 v2.1.2 v1.8.3; }
choose_release_version v2.2.1 <<<""
[[ "$SELECTED_VERSION" == v2.2.1 ]]
choose_release_version <<<""
[[ "$SELECTED_VERSION" == v3.1.0 ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("v2.1.2", result.stdout)
        self.assertNotIn("v1.8.3", result.stdout)

    def test_prereleases_are_labelled_and_can_be_selected(self):
        result = self.shell('''fetch_recent_releases() { printf 'v3.2.0\\ttrue\\nv3.1.0\\tfalse\\n'; }
choose_release_version <<<""
[[ "$SELECTED_VERSION" == v3.1.0 ]]
choose_release_version <<<"1"
[[ "$SELECTED_VERSION" == v3.2.0 ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("v3.2.0 (pre)", result.stdout)
        self.assertNotIn("v3.1.0 (pre)", result.stdout)

    def test_release_metadata_parser(self):
        result = self.shell('''parse_release_metadata <<'JSON'
[{"prerelease":true,"tag_name":"v3.2.0","draft":false},
 {"draft":false,"tag_name":"v3.1.0","prerelease":false},
 {"tag_name":"v3.3.0","prerelease":false,"draft":true}]
JSON
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "v3.2.0\ttrue\nv3.1.0\tfalse\n")

    def test_release_fetch_failure_is_not_hidden(self):
        result = self.shell('''fetch_recent_releases() { return 1; }
choose_release_version <<<""
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Cannot fetch", result.stderr)

    def test_fade_support_and_defaults_follow_selected_version(self):
        for version, expected in (("v2.2.1", "full8"), ("v3.0.0", "full8"),
                                  ("v3.0.1", "fade"), ("v3.1.0", "fade"), ("v3.2.0", "fade")):
            with self.subTest(version=version):
                self.config.unlink(missing_ok=True)
                result = self.shell('''ASSUME_YES=1; NOWHERE_VERSION="$TEST_VERSION"
configure_values
[[ "$NOWHERE_MORPH_TCP_PRELUDE" == "$TEST_EXPECTED" ]]
if [[ "$TEST_EXPECTED" == fade ]]; then validate_morph_tcp_prelude fade
else ! validate_morph_tcp_prelude fade; fi
''', env={"TEST_VERSION": version, "TEST_EXPECTED": expected})
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_authenticated_prelude_confirmation(self):
        for current, selected, morph, carrier, role, allowed, success in (
            ("v3.1.0", "v3.2.0", "1", "tcp", "portal", "0", False),
            ("v3.1.0", "v3.2.0", "1", "tcp", "portal", "1", True),
            ("v3.0.0", "v3.1.0", "1", "tcp", "portal", "0", True),
            ("v3.2.0", "v3.2.1", "1", "tcp", "portal", "0", True),
            ("v3.1.0", "v3.2.0", "0", "tcp", "portal", "0", True),
            ("v3.1.0", "v3.2.0", "1", "none", "portal", "0", True),
            ("v3.1.0", "v3.2.0", "1", "tcp", "egress", "0", True),
        ):
            with self.subTest(current=current, selected=selected, morph=morph, carrier=carrier, role=role):
                result = self.shell('''ASSUME_YES=1
NOWHERE_ROLE="$TEST_ROLE"; NOWHERE_MORPH="$TEST_MORPH"; NOWHERE_TCP_CARRIER="$TEST_CARRIER"
ALLOW_PRELUDE_BREAKING_UPGRADE="$TEST_ALLOWED"
confirm_prelude_upgrade "$TEST_CURRENT" "$TEST_SELECTED"
''', env={"TEST_ROLE": role, "TEST_MORPH": morph, "TEST_CARRIER": carrier,
          "TEST_ALLOWED": allowed, "TEST_CURRENT": current, "TEST_SELECTED": selected})
                self.assertEqual(result.returncode == 0, success, result.stderr)

    def test_upgrade_guard_runs_before_replacing_binary(self):
        self.write_config(NOWHERE_VERSION_VALUE="v3.1.0", NOWHERE_MORPH_VALUE="1")
        for action in ("update_all", "install_all"):
            with self.subTest(action=action):
                result = self.shell('''ASSUME_YES=1; VERSION_EXPLICIT=1; NOWHERE_VERSION=v3.2.0
BIN_PATH=/usr/bin/true
install_binary() { printf UNEXPECTED_REPLACEMENT; }
''' + action)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("--allow-prelude-breaking-upgrade", result.stderr)
                self.assertNotIn("UNEXPECTED_REPLACEMENT", result.stdout)

    def test_dual_stack_override_replaces_saved_single_dial(self):
        self.write_config(NOWHERE_VERSION_VALUE="v3.0.0", NOWHERE_DIAL_VALUE="192.0.2.1")
        result = self.shell('''ASSUME_YES=1; NOWHERE_VERSION=v3.0.0
DIAL4_EXPLICIT=1; NOWHERE_DIAL4=192.0.2.2; configure_values
[[ "$NOWHERE_DIAL" == auto && "$NOWHERE_SERVICE_URL" == *"dial4=192.0.2.2"* ]]
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_authenticated_socks_delimiters(self):
        result = self.shell("encode_socks_query_value 'alice:p@ss:word@127.0.0.1:1080'")
        credentials, endpoint = result.stdout.split("@")
        username, password = credentials.split(":")
        self.assertEqual((unquote(username), unquote(password), unquote(endpoint)),
                         ("alice", "p@ss:word", "127.0.0.1:1080"))

    def test_saved_values_preserve_shell_metacharacters(self):
        result = self.shell('''printf 'ROUND_TRIP=%s\\n' "$(env_quote "$TEST_VALUE")" >"$TEST_DIR/round-trip.env"
source "$TEST_DIR/round-trip.env"
[[ "$ROUND_TRIP" == "$TEST_VALUE" ]]
''', env={"TEST_VALUE": 'literal$HOME' + chr(96) + 'uname' + chr(96) + '$(pwd)"\\tail'})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_nw2_tcp_only_vector_configuration(self):
        result = self.shell('''ASSUME_YES=1; NOWHERE_VERSION=v2.2.1
NOWHERE_CLIENT=vector; NOWHERE_UDP_CARRIER=none; configure_values
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_nw2_next_wizard_keeps_saved_path(self):
        next_value = f"{KEY}@127.0.0.1:2077"
        self.write_config(NOWHERE_NEXT_VALUE=next_value)
        result = self.shell('''NOWHERE_VERSION=v2.2.1
prompt_value() { printf '%s' "$3"; }
configure_values
[[ "$NOWHERE_NEXT" == "$TEST_NEXT" ]]
''', env={"TEST_NEXT": next_value})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_reinstall_restarts_service(self):
        result = self.shell('''BIN_PATH=/usr/bin/true; NOWHERE_VERSION=v2.2.1
configure_values() { NOWHERE_ROLE=portal; }
install_binary() { :; }; save_config() { :; }; write_service() { :; }
print_links() { :; }; print_tls_fingerprint() { :; }
systemctl() { printf 'SYSTEMCTL:%s\\n' "$*"; }; install_all
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SYSTEMCTL:enable nowhere", result.stdout)
        self.assertIn("SYSTEMCTL:restart nowhere", result.stdout)

    def test_reinstall_confirms_protocol_cutover(self):
        result = self.shell('''BIN_PATH=/usr/bin/true; NOWHERE_VERSION=v3.0.0; ASSUME_YES=1
install_binary() { printf UNEXPECTED_INSTALL; }; install_all
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("UNEXPECTED_INSTALL", result.stdout)
        self.assertIn("Refusing non-interactive", result.stderr)

    def test_menu_layout_and_error_recovery(self):
        for language in ("en", "zh"):
            for columns in (40, 80, 96):
                result = self.shell("load_config; menu_init_ui; menu_render",
                                    env={"NOWHERE_LANG": language, "COLUMNS": str(columns), "LC_ALL": "C"})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(re.findall(r"^\s*(\d+)\.", result.stdout, re.M),
                                 [str(value) for value in range(1, 23)])
                for line in result.stdout.splitlines():
                    cells = sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in line)
                    self.assertLessEqual(cells, columns)
        for choice in ("q", "0", "Q"):
            result = self.shell("run_generate_key() { die EXPECTED_FAILURE; }; menu", input=f"18\n{choice}\n")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("EXPECTED_FAILURE", result.stderr)


if __name__ == "__main__":
    unittest.main()
