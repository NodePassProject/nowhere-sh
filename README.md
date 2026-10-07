# nowhere-sh

[简体中文](README.zh-CN.md)

An interactive deployment and management script for a Linux VPS running
[Nowhere](https://github.com/NodePassProject/Nowhere) Portal.

## Scope

The default install version is `v2.2.1`. The release picker lists supported
Nowhere releases and omits V1; pressing Enter during update selects the latest
listed release. It generates
`nowhere://` links for Anywhere plus `vector://` URLs for the native Vector client.

## Features

- Interactive wizard: press Enter at every prompt for sensible defaults.
- Downloads a selected supported release and manages one systemd Portal service.
- Endpoint forms: shared TCP/UDP port, independent ports, TCP-only,
  UDP-only, and `tcp4`/`tcp6`/`udp4`/`udp6` address-family restrictions.
- Portal TLS modes, `morph`, rate limits, outbound SOCKS5, native `next` Portal
  chaining, Mux, SNI, certificate pinning, logs, TCP Morph prelude mode, and
  transport environment settings.
- Nowhere 2.2 shared-key validation and migration, 32-character key generation,
  independent `dial4`/`dial6` source binding, and remote certificate inspection.
- Native Vector URL generation with fixed or `mix` routes, Mux, SNI, pin,
  rate limits, logs, and local SOCKS5 listener.
- Anywhere TCP and UDP import links, plus a terminal QR code for the preferred
  available carrier.
- Terminal UI, logs, service lifecycle commands, and TLS certificate SHA-256
  fingerprint output.
- Read-only instance telemetry and one-shot TCP Flow connectivity probes
  (Nowhere `v2.1.2` and later).

## Quick Start

Requirements: Linux, systemd, `curl`, `tar`, and an `x86_64` or `aarch64` VPS.

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

On the first interactive run, choose English or Simplified Chinese. The choice
is saved and can later be changed from menu item `20`, or selected explicitly
with `--lang en` or `--lang zh`.

The default install enables both unrestricted TCP and UDP carriers on port
`2077`, creates an ephemeral self-signed certificate, and prints Anywhere
links. Open the same TCP and UDP port in both the VPS firewall and cloud security
group.

```text
1) Install/Reinstall (Anywhere)
2) Install/Reinstall (Native Vector)
3) Quick default install (Anywhere)
4) Reconfigure
5) Select a Release and install
6) Update Nowhere binary
7) Start service
8) Stop service
9) Restart service
10) Show Nowhere instance status (v2.1.2+)
11) Probe TCP connectivity (v2.1.2+)
12) Show systemd service status
13) Open Terminal UI
14) Follow logs
15) Print client links / QR code
16) Show certificate SHA-256
17) Generate shared key (v2.2.0+)
18) Inspect remote certificate fingerprint (v2.2.0+)
19) Uninstall
20) Switch language
21) Update deployment script
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

Portal outbound source binding supports either the legacy single-family `dial`
mode or the Nowhere 2.2 `dial4`/`dial6` mode. The modes are mutually exclusive;
`dial4` and `dial6` may be configured independently or together. Use bare local
IP addresses, without brackets or ports:

```bash
sudo bash nowhere-vps.sh configure --dial4 192.0.2.10 --dial6 2001:db8::10
```

These options affect Portal outbound connections, including direct, SOCKS5,
and native `next` paths. They do not change inbound listeners or standalone
Vector/probe source selection. Explicit bindings do not silently fall back to
automatic source selection.

## Portal Outbound Paths

Portal can connect to targets directly, through an outbound SOCKS5 proxy, or via
a native next-hop Portal. The wizard offers one of `direct`, `socks`, or `next`;
SOCKS and `next` are mutually exclusive.

Use `--next key@host:port` or an explicit carrier endpoint to configure a
next-hop Portal. Its route policy and TLS settings are available through
`--next-up`, `--next-down`, `--next-mux`, `--next-sni`, and `--next-pin`.

## Morph and Upgrades

`morph=0` is the default. With `morph=1`, Nowhere `v2.1.0` changes the Morph
wire format and cannot communicate with a `v2.0.x` Morph peer. Before upgrading
a Morph-enabled Portal from `v2.0.x` to `v2.1.0` or later, upgrade every
affected Anywhere client, native Vector node, and native `next` hop together.

The interactive update flow requires typing `UPGRADE` at this compatibility
boundary. Non-interactive automation is refused unless the coordinated rollout
has been completed and `--allow-morph-breaking-upgrade` is supplied.

Nowhere `v2.1.1` removes the `event` log level. When updating or reconfiguring
to `v2.1.1` or later, this script automatically changes a saved `event` level
to `info`; older selected releases continue to accept `event`.

Nowhere `v2.2.1` requires every Portal listener and enabled native `next` shared
key to be 32–64 lowercase hexadecimal characters. New installs generate a
32-character key (16 random bytes); existing 64-character keys remain valid
and are preserved. When updating an older saved installation, the script offers
to rotate an incompatible listener key; accepting invalidates its old client
links, which must be imported again. Invalid `next` keys stop the update before
replacing the binary. For a Portal chain, coordinate a fresh key for each hop
and set the identical key on both ends before upgrading that hop.
The `nw2` wire contract remains compatible with `v2.1.2`; this is a key and
certificate-trust configuration change, not a relay wire-protocol migration.

Nowhere 2.2 also verifies certificate chains and names by default for Native
Vector, `probe`, and native `next` connections. `sni=none` does not disable
verification. A self-signed certificate needs its exact SHA-256 pin. For the
default in-memory self-signed certificate, this script adds the current pin to
generated Vector URLs when available; that pin changes whenever the service
restarts. Use a stable CA-trusted PEM certificate for links that should survive
restarts.

For TCP Morph connections initiated by the local Nowhere process, choose the
client-side prelude mode with `--morph-tcp-prelude low7|full8`. `full8` is the
default in Nowhere 2.2; `low7` remains available. This setting affects native
outbound connections such as `next`; it is not included in Anywhere import
links.

## Client Output

Anywhere links are generated separately for TCP and UDP, so they stay within
its supported fixed-route model. Native Vector supports the full policy set:

Anywhere SNI defaults to the public host in the link. Set `--anywhere-sni` when
the client-facing address differs from the certificate's DNS name; the script
adds an encoded `sni` parameter to the Anywhere links. The interactive wizard
also offers this setting when Anywhere output is enabled. For example:

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
(`tls=2`). It probes the live local TCP endpoint first and falls back to the
Nowhere log when probing is unavailable, so hot-reloaded PEM certificates are
reported correctly. A self-signed fingerprint changes after every service
restart; a PEM fingerprint changes when that certificate is renewed.

```bash
sudo bash nowhere-vps.sh fingerprint
```

Nowhere 2.2 Native Vector links include a current self-signed certificate pin
when the fingerprint is available. Anywhere `nowhere://` links do not carry a
pin parameter; add the displayed SHA-256 fingerprint to Anywhere's Trusted
Certificates when using a self-signed certificate. The in-memory certificate
is regenerated after every service restart, so its trusted fingerprint must
then be refreshed. For a self-signed PEM certificate, set `--pin` for Native
Vector or `--next-pin` for a native Portal chain.

Generate a key or inspect a remote Portal certificate with the Nowhere 2.2
utilities:

```bash
sudo bash nowhere-vps.sh generate-key
sudo bash nowhere-vps.sh fingerprint 'nowhere://key@proxy.example.com:2077?morph=1'
```

Remote fingerprint inspection sends no Portal authentication or application
traffic. Verify the reported value through a trusted channel before pinning it.
These wrapper commands require the local Nowhere binary to be installed at
`v2.2.0` or later.

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

`status` reports the systemd service state; `telemetry` runs Nowhere's local
read-only instance snapshot. `probe` builds a temporary Vector URL from the
saved server settings and tests one TCP Flow to the requested target without
printing the shared key or sending application payload. These two commands
require an installed Nowhere binary `v2.1.2` or later.

## Files

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

Uninstalling keeps `/etc/nowhere` so configuration and keys are not removed by
accident.
