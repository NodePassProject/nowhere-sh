"""Optional integration: NW2_BINARY=/path NW3_BINARY=/path python3 -m unittest discover -s tests -v."""
import os
import re
import socket
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "nowhere-vps.sh"
KEY = "0123456789abcdef0123456789abcdef"


@unittest.skipUnless(os.environ.get("NW2_BINARY") and os.environ.get("NW3_BINARY"),
                     "set NW2_BINARY and NW3_BINARY for native localhost tests")
class NativeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="nowhere-native-test-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)

    @staticmethod
    def unused_port():
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            return listener.getsockname()[1]

    def shell(self, body, **env):
        setup = '''source "$TEST_SCRIPT" help >/dev/null
CONFIG_DIR="$TEST_DIR"; CONFIG_FILE="$TEST_DIR/nowhere.env"
BIN_PATH="$TEST_BINARY"; ASSUME_YES=1; NOWHERE_LANG=en
require_root() { :; }
detect_public_host() { printf 127.0.0.1; }
systemctl() { [[ "$1" != is-active ]] || return 0; return 1; }
journalctl() { [[ -n "${TEST_LOG:-}" ]] && cat "$TEST_LOG"; }
'''
        result = subprocess.run(["bash", "-c", setup + body], capture_output=True, text=True,
                                timeout=20, env=dict(os.environ, TEST_SCRIPT=str(SCRIPT),
                                                    TEST_DIR=str(self.directory), **env))
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def start(self, binary, url):
        log = self.directory / f"native-{time.monotonic_ns()}.log"
        output = log.open("w")
        process = subprocess.Popen([binary, url], stdout=output, stderr=output)
        def stop():
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=10)
            output.close()
        self.addCleanup(stop)
        return process, log

    def fingerprint(self, process, log):
        for _ in range(50):
            self.assertIsNone(process.poll(), log.read_text())
            match = re.search(r"(?:CERT_SHA256\||fingerprint:\s*)([0-9a-fA-f]{64})", log.read_text())
            if match:
                return match.group(1).lower()
            time.sleep(0.1)
        self.fail(log.read_text())

    def test_real_nw2_and_nw3_connections(self):
        for version, binary_name in (("v2.2.1", "NW2_BINARY"), ("v3.0.0", "NW3_BINARY")):
            with self.subTest(version=version):
                config = self.directory / "nowhere.env"
                config.unlink(missing_ok=True)
                binary = os.environ[binary_name]
                tcp, udp = self.unused_port(), self.unused_port()
                common = dict(TEST_BINARY=binary, TEST_VERSION=version, TEST_KEY=KEY,
                              TEST_TCP=str(tcp), TEST_UDP=str(udp))
                portal_url = self.shell('''NOWHERE_VERSION="$TEST_VERSION"; NOWHERE_KEY="$TEST_KEY"
NOWHERE_LISTEN_HOST=127.0.0.1; NOWHERE_PUBLIC_HOST=127.0.0.1
NOWHERE_TCP_PORT="$TEST_TCP"; NOWHERE_UDP_PORT="$TEST_UDP"; NOWHERE_MORPH=1
[[ "$NOWHERE_VERSION" != v3.0.0 ]] || NOWHERE_OUT=egress
configure_values; save_config; printf '%s' "$NOWHERE_SERVICE_URL"
''', **common)
                portal, portal_log = self.start(binary, portal_url)
                pin = self.fingerprint(portal, portal_log)
                common["TEST_LOG"] = str(portal_log)
                live_pin = self.shell("load_config; current_local_tls_fingerprint", **common)
                self.assertEqual(live_pin, pin)
                if version == "v3.0.0":
                    udp_pin = self.shell("load_config; NOWHERE_TCP_CARRIER_VALUE=none; current_local_tls_fingerprint",
                                         **common)
                    self.assertEqual(udp_pin, pin)
                    egress_url = self.shell('''NOWHERE_VERSION=v3.0.0; NOWHERE_ROLE=egress
NOWHERE_EGRESS_PORTAL_HOST=127.0.0.1; NOWHERE_EGRESS_PORTAL_UDP_PORT="$TEST_UDP"
NOWHERE_EGRESS_PIN="$TEST_PIN"; configure_values; printf '%s' "$NOWHERE_SERVICE_URL"
''', TEST_PIN=pin, **common)
                    egress, egress_log = self.start(binary, egress_url)
                listener = socket.socket()
                listener.bind(("127.0.0.1", 0))
                listener.listen(16)
                self.addCleanup(listener.close)
                target = f"127.0.0.1:{listener.getsockname()[1]}"
                for carrier in ("tcp", "udp"):
                    vector = self.shell('''load_config
NOWHERE_VECTOR_UP_VALUE="$TEST_CARRIER"; NOWHERE_VECTOR_DOWN_VALUE="$TEST_CARRIER"
[[ "$TEST_CARRIER" != udp ]] || write_config_assignment NOWHERE_TCP_CARRIER_VALUE none
build_probe_vector_url
''', TEST_CARRIER=carrier, **common)
                    for _ in range(5):
                        probe = subprocess.run([binary, "probe", vector, target], capture_output=True,
                                               text=True, timeout=15)
                        if probe.returncode == 0:
                            break
                        time.sleep(0.2)
                    self.assertEqual(probe.returncode, 0, probe.stderr + portal_log.read_text())
                if version == "v3.0.0":
                    self.assertIsNone(egress.poll(), egress_log.read_text())
                    auth_port = self.unused_port()
                    auth_url = self.shell('''NOWHERE_VERSION=v3.0.0; NOWHERE_ROLE=portal
NOWHERE_TCP_PORT="$TEST_AUTH_PORT"; NOWHERE_UDP_CARRIER=none; NOWHERE_OUT=socks
NOWHERE_TCP_CARRIER=tcp
NOWHERE_OUT_SOCKS='alice:p@ss:word@127.0.0.1:1080'
configure_values; printf '%s' "$NOWHERE_SERVICE_URL"
''', TEST_AUTH_PORT=str(auth_port), **common)
                    authenticated, log = self.start(binary, auth_url)
                    self.fingerprint(authenticated, log)
                    vector_url = self.shell('''load_config
NOWHERE_VECTOR_SOCKS_VALUE="alice:p@ss:word@127.0.0.1:$TEST_IN_PORT"
printf 'vector://%s@127.0.0.1/tcp:%s?%s' "$TEST_KEY" "$TEST_TCP" "$(build_vector_query)"
''', TEST_IN_PORT=str(self.unused_port()), **common)
                    vector_process, vector_log = self.start(binary, vector_url)
                    time.sleep(0.2)
                    self.assertIsNone(vector_process.poll(), vector_log.read_text())


if __name__ == "__main__":
    unittest.main()
