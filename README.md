# nowhere-sh

[简体中文](README.zh-CN.md)

An interactive deployment and management script for a Linux VPS running
[Nowhere](https://github.com/NodePassProject/Nowhere) Portal.

## Scope

New installs use `v3.1.0` by default. The release picker offers NW3 releases
and the fixed NW2 LTS baseline `v2.2.1`. GitHub prereleases are labelled `(pre)`
and can be selected by number. Pressing Enter during an update selects the
newest formal release on the current protocol line. The
script generates `nowhere://` links for Anywhere and `vector://` URLs for the
native Vector client. Existing stable NW2 installations remain recognized for
upgrade, while only the LTS baseline is offered as an NW2 install target.

## Features

- Interactive wizard: press Enter at every prompt for sensible defaults.
- Downloads a selected release and manages one systemd or OpenRC service as an NW2/NW3
  Portal or an NW3 Egress.
- Endpoint forms: shared TCP/UDP port, independent ports, TCP-only,
  UDP-only, and `tcp4`/`tcp6`/`udp4`/`udp6` address-family restrictions.
- NW2 LTS Portal configuration at the `v2.2.1` baseline, including SOCKS5 and
  native `next`, separate carriers, Morph settings, SNI, certificate pins, and
  dual-stack source binding.
- NW3 Portal and Egress configuration, including direct/SOCKS5/Egress exits,
  Egress registration, exact 32-character shared keys, and Morph.
- Anywhere and Native Vector links for NW2/NW3, with QR output and automatic
  certificate pinning for available self-signed Portal fingerprints.
- Shared-key generation, remote certificate inspection, logs, service lifecycle
  commands, instance status, and TCP Flow probes. The TUI is available on NW2.

## Quick Start

Requirements: Linux with systemd or Alpine with OpenRC, Bash, `curl`, `tar`,
and an `x86_64` or `aarch64` VPS. Python is not required. Without `jq`,
the picker shows built-in versions; use `--version` to select another release.
Install `jq` to see the live GitHub release list.

The install wizard offers `jq` and, for Anywhere links, `qrencode` separately.
Press Enter to install each missing tool, or answer `n` to skip it. Quick
install and `--yes` accept the defaults; add `--skip-jq --skip-qrencode` for
a minimal unattended install. Showing links never installs packages.

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

### Alpine and Low-Memory LXC

On an Alpine VPS or LXC booted with OpenRC, run as root:

```bash
apk add --no-cache bash curl ca-certificates
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
bash nowhere-vps.sh
```

The script uses Alpine's BusyBox utilities and installs the musl build. New
OpenRC configurations default to the `memory` transport profile; upgrades
preserve the saved profile. For an existing installation, select `memory` in
the configuration wizard or pass `configure --transport-memory-profile memory`.
On Alpine the QR tool is packaged as `libqrencode-tools` in the community
repository. Skipping it still produces text import links. The memory profile
is not a hard RAM limit; actual usage depends on traffic and concurrent connections.

On the first interactive run, choose English or Simplified Chinese. The choice
is saved and can later be changed from menu item `21`, or selected explicitly
with `--lang en` or `--lang zh`.

The default install creates an NW3 Portal with TCP and UDP on port `2077`,
Morph enabled, a self-signed certificate, and Anywhere links. Open TCP and UDP
`2077` in both the VPS firewall and cloud security group.

The main menu shows service status and a configuration summary, with grouped
actions and descriptions. Narrow terminals hide the description column. After
an action, press Enter to return; enter `q` or `0` to exit.

Opening the interactive menu checks for a newer deployment script once, with
a three-second timeout. When available, a notice points to item `22`. Network
failures are ignored. The check never installs updates or changes the service.

```text
1) Install/Reinstall Portal (Anywhere)
2) Install/Reinstall Portal (Native Vector)
3) Install/Reinstall NW3 Egress
4) Quick default install (Anywhere)
5) Reconfigure
6) Select a Release and install
7) Update Nowhere binary
8) Start service
9) Stop service
10) Restart service
11) Show Nowhere instance status
12) Probe TCP connectivity
13) Show service status
14) Open Terminal UI (NW2 only)
15) Follow logs
16) Print client links / QR code
17) Show certificate SHA-256
18) Generate shared key
19) Inspect remote certificate fingerprint
20) Uninstall
21) Switch language
22) Update deployment script
```

For non-interactive defaults:

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install --yes
```

## Endpoints

The wizard accepts a TCP carrier (`tcp`, `tcp4`, `tcp6`, or `none`) and a UDP
carrier (`udp`, `udp4`, `udp6`, or `none`), each with its own port. Equivalent
CLI options are `--tcp-carrier`, `--tcp-port`, `--udp-carrier`, and
`--udp-port`.

When unrestricted TCP and UDP use one port, Portal uses the compact endpoint:

```text
portal://key@*:2077?tls=1&morph=0
```

Different ports produce an explicit endpoint:

```text
portal://key@*/tcp:443/udp:8443?tls=1&morph=1
```

`tcp4` and `udp6` restrict a carrier to IPv4 or IPv6. These advanced carrier
suffixes are retained in native Vector URLs. Anywhere links use ordinary TCP
and UDP routes.

Portal outbound source binding supports either the single-address `dial` mode
or the `dial4`/`dial6` mode. The modes are mutually exclusive;
`dial4` and `dial6` may be configured independently or together. Use bare local
IP addresses, without brackets or ports:

```bash
sudo bash nowhere-vps.sh configure --dial4 192.0.2.10 --dial6 2001:db8::10
```

These options affect Portal outbound connections, including direct, SOCKS5,
and NW2 native `next` paths. They do not change inbound listeners or standalone
Vector/probe source selection. Explicit bindings do not silently fall back to
automatic source selection.

## Portal Outbound Paths

NW2 Portal can connect to targets directly, through an outbound SOCKS5 proxy,
or via a native next-hop Portal. The wizard offers one of `direct`, `socks`, or
`next`; SOCKS and `next` are mutually exclusive.

Use `--next key@host:port` or an explicit carrier endpoint to configure an NW2
next-hop Portal. Its route policy and TLS settings are available through
`--next-up`, `--next-down`, `--next-mux`, `--next-sni`, and `--next-pin`.

NW3 Portal selects one fixed target path: `direct`, `socks`, or `egress`. The
`egress` path requires a separately deployed NW3 Egress that connects outbound
to the Portal. NW3 does not use the NW2 `next` option.

### Egress Deployment

First install or reconfigure the public Portal with `out=egress`. QUIC/UDP
is the default and requires a Portal UDP listener. To use TLS/TCP, first
select `v3.3.0` or newer on both hosts and enable a Portal TCP listener.
Then deploy Egress on the exit VPS with the matching carrier and port.
In the menu, use item `6` (Install a selected release) to select `v3.3.0`,
then choose the appropriate role on each host.
Egress connects outbound, so it needs no inbound firewall port. Both peers
must use the same 32-character shared key and Morph setting.

```bash
sudo bash nowhere-vps.sh install-egress \
  --version v3.3.0 \
  --egress-portal-host portal.example.com \
  --egress-portal-carrier tcp \
  --egress-portal-port 2077 \
  --key 0123456789abcdef0123456789abcdef
```

Use `udp` for QUIC. Existing QUIC configurations and the old
`--egress-portal-udp-*` flags still work. Before downgrading below v3.3.0,
switch Egress back to QUIC and ensure a UDP listener is enabled on Portal.

For a self-signed Portal certificate, get its SHA-256 fingerprint on the Portal
VPS and pass it as `--egress-pin`. If the certificate is trusted by the system,
leave the pin as `none`; set `--egress-sni` when its certificate name differs
from the Portal address. An Egress route has no direct fallback when the Egress
is offline.

To bind target connections to a source address, set `--dial`, `--dial4`, or
`--dial6` on the Egress. These options affect Egress-to-target connections, not
its connection to Portal. Portal `out=egress` cannot use Portal-side dial
bindings.

## Morph and Upgrades

On `v3.4.0+`, the Portal and Egress wizards offer `chacha` (default) or
`aes` when Morph is enabled. Use menu item `6` to select the release, or
set `--cipher aes` when installing or reconfiguring a compatible version.
Portal, Vector/Anywhere, and Egress must use the same cipher. Only choose
`aes` if all peers support it, then reimport the updated client links.
Switch back to `chacha` before downgrading below v3.4.0.

NW2 is maintained at the `v2.2.1` LTS baseline. It accepts 32–64-character
lowercase hexadecimal Portal and native `next` keys; newly generated keys are
32 characters, and existing valid 64-character keys are preserved. NW2 also
verifies certificate chains and names for Native Vector, `probe`, and native
`next` connections. A self-signed certificate requires its exact SHA-256 pin.

NW3 is the default protocol line and enables Morph by default. NW2 and NW3 use
incompatible wire protocols, so switching between them requires a coordinated
client and server migration. The script asks for explicit confirmation before
the cutover; non-interactive updates require `--allow-protocol-breaking-upgrade`.
Releases within the NW3 line do not require the cross-line migration prompt.
However, Portal v3.2.0+ requires authenticated preludes for Morph TCP. Before
upgrading across this boundary, update native Vector clients to v3.1.0+ and
verify support in Anywhere or other clients. The script asks for confirmation
on affected installs, reinstalls and updates; non-interactive runs require
`--allow-prelude-breaking-upgrade`. QUIC and non-Morph TLS are unaffected.
Shared keys, certificates and share-link formats do not need migration.

For TCP Morph connections initiated by the local Nowhere process, choose the
client-side prelude mode with `--morph-tcp-prelude fade|low7|full8`. New NW3
v3.0.1+ configurations default to `fade`; NW2 LTS and NW3 v3.0.0 use `full8`.
Existing explicit settings are preserved. This affects NW2 native `next` and
NW3 native TLS connections and is not included in Anywhere import links.
Selecting `low7` or `full8` does not disable authenticated preludes.

## Client Output

Anywhere links are generated separately for TCP and UDP, so they stay within
its supported fixed-route model. Native Vector supports the full policy set:

For NW2, Anywhere SNI defaults to the public host in the link. Set
`--anywhere-sni` when the client-facing address differs from the certificate's
DNS name; the script adds an encoded `sni` parameter to the Anywhere links. The
interactive wizard also offers this setting when Anywhere output is enabled.
For example:

```bash
sudo bash nowhere-vps.sh configure \
  --public-host 203.0.113.10 --anywhere-sni proxy.example.com
```

SNI does not replace trusting a self-signed certificate fingerprint in Anywhere.

```bash
sudo bash nowhere-vps.sh install-vector \
  --vector-up mix --vector-down mix --mux 1
```

The Vector options are `--vector-up`, `--vector-down`, `--mux`,
`--vector-socks`, `--sni`, `--pin`, `--vector-rate`, `--vector-etar`, and
`--vector-log`. `mix` requires both carriers.

## TLS

The fingerprint command prints the SHA-256 fingerprint for the certificate
loaded by Portal, whether it is self-signed (`tls=1`) or supplied as PEM
(`tls=2`). It inspects the local TCP endpoint with Nowhere first, then falls back
to the current service invocation's journal. UDP-only deployments use the
journal. A self-signed fingerprint changes after
every service restart; a PEM fingerprint changes when that certificate is renewed.

```bash
sudo bash nowhere-vps.sh fingerprint
```

Native Vector links include a current self-signed certificate pin
when the fingerprint is available. Anywhere `nowhere://` links do not carry a
pin parameter; add the displayed SHA-256 fingerprint to Anywhere's Trusted
Certificates when using a self-signed certificate. The in-memory certificate
is regenerated after every service restart, so its trusted fingerprint must
then be refreshed. For a self-signed PEM certificate, set `--pin` for Native
Vector or `--next-pin` for a native Portal chain.

Generate a key or inspect a remote Portal certificate with the supported
Nowhere utilities:

```bash
sudo bash nowhere-vps.sh generate-key
sudo bash nowhere-vps.sh fingerprint 'nowhere://key@proxy.example.com:2077?morph=1'
```

Remote fingerprint inspection sends no Portal authentication or application
traffic. Verify the reported value through a trusted channel before pinning it.
These wrapper commands are available for the NW2 LTS baseline and NW3.

For a supplied certificate use absolute paths:

```bash
sudo NOWHERE_TLS=2 \
  NOWHERE_CRT=/etc/letsencrypt/live/proxy.example.com/fullchain.pem \
  NOWHERE_TLS_KEY=/etc/letsencrypt/live/proxy.example.com/privkey.pem \
  NOWHERE_PUBLIC_HOST=proxy.example.com \
  bash nowhere-vps.sh install --yes
```

## Commands

```bash
sudo bash nowhere-vps.sh configure
sudo bash nowhere-vps.sh versions
sudo bash nowhere-vps.sh update
sudo bash nowhere-vps.sh update-script
sudo bash nowhere-vps.sh start
sudo bash nowhere-vps.sh stop
sudo bash nowhere-vps.sh restart
sudo bash nowhere-vps.sh status
sudo bash nowhere-vps.sh telemetry
sudo bash nowhere-vps.sh probe example.com:443
sudo bash nowhere-vps.sh tui
sudo bash nowhere-vps.sh logs
sudo bash nowhere-vps.sh link
sudo bash nowhere-vps.sh fingerprint
sudo bash nowhere-vps.sh fingerprint 'nowhere://key@host:2077'
sudo bash nowhere-vps.sh generate-key
sudo bash nowhere-vps.sh uninstall
```

Run `bash nowhere-vps.sh --help` for the complete option list.

Existing scripts can download this version through their **Update deployment
script** option or `update-script` command. Exit and rerun the script after the
download to load the new menu. Script updates preserve the saved configuration,
keys and running service; upgrading the Nowhere binary is a separate action.

`status` reports the service state; `telemetry` runs Nowhere's local
read-only instance snapshot. `probe` builds a temporary Vector URL from the
saved server settings and tests one TCP Flow to the requested target without
printing the shared key or sending application payload. All three commands are
available on the NW2 LTS baseline and NW3.

## Files

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

On OpenRC, the service file is `/etc/init.d/nowhere`. The helper at
`/etc/nowhere/run` replaces `/etc/nowhere/nowhere.log` each time the process
starts. Use the `logs` command to follow the current log.

Uninstalling keeps `/etc/nowhere` so configuration and keys are not removed by
accident.
