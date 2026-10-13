# nowhere-sh

[English](README.md)

[NodePassProject/Nowhere](https://github.com/NodePassProject/Nowhere) Portal
的 Linux VPS 一键部署与管理脚本。

## 支持范围

脚本新装默认使用 `v3.0.0`。版本列表提供稳定版 NW3 Release，以及固定的
NW2 LTS 基线 `v2.2.1`。升级时直接回车会选择当前协议线中最新的受支持版本。
脚本输出 Anywhere 的 `nowhere://` 链接和 Native Vector 的 `vector://` URL。现有稳定版
NW2 安装仍可识别并升级，但 NW2 的新安装目标只提供 LTS 基线。

## 功能

- 交互式向导，每一项均有默认值，连续回车即可完成部署。
- 下载指定受支持 Release，并通过一个 systemd 服务管理 NW2/NW3 Portal 或 NW3 Egress。
- 支持共享/独立 TCP、UDP 端口，TCP-only、UDP-only，以及
  `tcp4`、`tcp6`、`udp4`、`udp6` 地址族限制。
- NW2 LTS 按 `v2.2.1` 存量基线管理，支持 SOCKS5、原生 `next`、Mux、SNI、
  证书 Pin、Morph 与双栈出站源地址绑定。
- NW3 Portal 支持直连、SOCKS5、Egress 出口、32 位共享密钥和 Morph；NW3
  Egress 可作为独立 systemd 服务部署。
- 支持 Anywhere 和 Native Vector 链接；输出 Anywhere TCP/UDP 导入链接及二维码，
  并在可用时为 Native Vector 自动添加自签证书 Pin。
- 提供共享密钥生成、远端证书指纹查询、日志、服务启停、实例状态和 TCP Flow 探测。
  Terminal UI 仅适用于 NW2。

## 快速开始

系统需要 Linux、systemd、`curl`、`tar`，支持 `x86_64` 与 `aarch64` VPS。

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

首次交互运行时可选择 English 或简体中文，选择会保存下来；之后可在菜单第 `21`
项切换，也可用 `--lang en` 或 `--lang zh` 显式指定语言。

默认安装会在 `2077` 同时启用 TCP 和 UDP carrier，开启 Morph，使用自签证书，
并输出 Anywhere 链接。VPS 防火墙与云厂商安全组均需放行 TCP、UDP `2077`。

主菜单顶部显示服务状态与配置摘要，操作按功能分组并附有简短说明；窄终端会隐藏说明列。
执行操作后按回车返回菜单，输入 `q` 或 `0` 退出。

```text
1) 安装/重装（Anywhere）
2) 安装/重装（Native Vector）
3) 安装/重装（NW3 Egress）
4) 快速默认安装（Anywhere）
5) 修改配置
6) 指定 Release 安装
7) 更新 Nowhere 二进制
8) 启动服务
9) 停止服务
10) 重启服务
11) 查看 Nowhere 实例状态
12) 测试 TCP 连通性
13) 查看 systemd 服务状态
14) 打开终端界面（仅 NW2）
15) 查看实时日志
16) 打印客户端链接 / 二维码
17) 查看证书 SHA-256
18) 生成共享密钥
19) 查询远端证书指纹
20) 卸载服务
21) 切换语言
22) 更新部署脚本
```

非交互默认安装：

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install --yes
```

## Carrier

向导分别配置 TCP carrier（`tcp`、`tcp4`、`tcp6` 或 `none`）和 UDP carrier
（`udp`、`udp4`、`udp6` 或 `none`），两个 carrier 可以使用独立端口。命令行参数为
`--tcp-carrier`、`--tcp-port`、`--udp-carrier`、`--udp-port`。

不限地址族的 TCP、UDP 共用一个端口时，会生成紧凑端点：

```text
portal://key@*:2077?tls=1&morph=0
```

分别使用端口时，会生成显式端点：

```text
portal://key@*/tcp:443/udp:8443?tls=1&morph=1
```

`tcp4`、`udp6` 用于把对应 carrier 限制为 IPv4 或 IPv6。Native Vector URL 会保留
这些高级限制；Anywhere 链接使用普通 TCP、UDP 固定路由。

Portal 出站源地址支持两种互斥模式：单地址 `dial`，或 `dial4/dial6`。后者
可分别设置，也可同时设置。请填写本机 IP 字面值，不要加方括号
或端口：

```bash
sudo bash nowhere-vps.sh configure --dial4 192.0.2.10 --dial6 2001:db8::10
```

这些参数影响 Portal 对外建立的连接，包括直连、SOCKS5 和 NW2 原生 `next`；不改变入站
监听地址，也不控制独立运行的 Vector 或连通性探测。指定源地址绑定失败时不会静默
回退到系统自动选择。

## Portal 出站路径

NW2 Portal 可直连目标、经由出站 SOCKS5，或连接下一个原生 Portal。向导中选择
`direct`、`socks`、`next` 之一；SOCKS 与 `next` 不能同时使用。

使用 `--next key@host:port` 或显式 carrier 端点配置 NW2 下一跳 Portal；其路由和 TLS
参数分别为 `--next-up`、`--next-down`、`--next-mux`、`--next-sni`、`--next-pin`。

NW3 Portal 需要选择一个固定出口：`direct`、`socks` 或 `egress`。选择 `egress` 时，Portal
必须启用 UDP carrier，并另外部署一个主动连接 Portal 的 NW3 Egress；NW3 不再使用
NW2 的 `next` 配置。

### 部署 Egress

先在公网入口机安装或重配 NW3 Portal，选择 `out=egress` 并启用 UDP carrier。然后在
出口 VPS 通过菜单第 `3` 项或 `install-egress` 部署 NW3 Egress。填写 Portal 的 UDP
地址和端口、与 Portal 完全相同的 32 位共享密钥，以及需要时使用的 SNI 或证书 Pin。
Egress 会主动发起 QUIC 连接，因此出口 VPS 不需要开放入站端口。Portal 与 Egress 的
共享密钥和 Morph 设置必须一致。

```bash
sudo bash nowhere-vps.sh install-egress \
  --egress-portal-host portal.example.com \
  --egress-portal-udp-port 2077 \
  --key 0123456789abcdef0123456789abcdef
```

Portal 使用自签证书时，在入口机查询 SHA-256 指纹并作为 `--egress-pin` 传入。证书
受系统信任时 Pin 可留为 `none`；证书域名与 Portal 地址不同时，设置 `--egress-sni`。
Egress 离线时，Portal 不会自动回退为直连。

如需绑定目标连接的源地址，在 Egress 上设置 `--dial`、`--dial4` 或 `--dial6`。
这些设置只影响 Egress 到目标地址的连接，不影响 Egress 到 Portal 的 QUIC 连接。Portal
使用 `out=egress` 时不能配置 Portal 侧的 dial 绑定。

## Morph 与升级

NW2 按 `v2.2.1` LTS 基线维护。Portal 和原生 `next` 密钥接受 32–64 位小写
十六进制；新生成的密钥为 32 位，已有的合规 64 位密钥会保留。Native Vector、`probe`
和原生 `next` 会校验证书链与名称；自签证书需要准确的 SHA-256 Pin。

NW3 是默认协议线，默认开启 Morph。NW2 与 NW3 的 wire protocol 不兼容，切换协议线前
需要协调升级客户端和服务端。脚本会在切换时要求明确确认；非交互更新需传入
`--allow-protocol-breaking-upgrade`。NW3 协议线内的稳定 Release 可直接选择升级，不会
触发跨协议线迁移确认。

本机 Nowhere 的 TCP Morph 出站连接可通过 `--morph-tcp-prelude low7|full8` 设置前导模式，
默认是 `full8`。该设置影响 NW2 原生 `next` 和 NW3 原生 TLS 连接，不会写入 Anywhere
导入链接。

## 客户端链接

Anywhere 会分别生成 TCP 与 UDP 链接，保持在其支持的固定路由范围内。Native
Vector 支持完整路由策略，例如：

NW2 的 Anywhere 链接默认使用链接中的公网主机名作为 SNI。若分享地址是 IP、证书签发给
另一个域名，可通过 `--anywhere-sni` 指定证书域名，脚本会将其编码后加入 Anywhere
链接。交互向导在启用 Anywhere 输出时也会询问此项。示例：

```bash
sudo bash nowhere-vps.sh configure \
  --public-host 203.0.113.10 --anywhere-sni proxy.example.com
```

SNI 不能代替在 Anywhere 中信任自签证书指纹。

```bash
sudo bash nowhere-vps.sh install-vector \
  --vector-up mix --vector-down mix --mux 1
```

Vector 相关参数是 `--vector-up`、`--vector-down`、`--mux`、`--vector-socks`、
`--sni`、`--pin`、`--vector-rate`、`--vector-etar`、`--vector-log`。使用 `mix`
必须同时启用 TCP 与 UDP carrier。

## TLS

指纹命令会输出 Portal 证书的 SHA-256，适用于自签证书（`tls=1`）和 PEM 证书
（`tls=2`）。脚本优先使用 Nowhere 探测本机 TCP 证书，失败时读取当前服务进程的日志；
UDP-only 部署使用日志中的指纹。
自签证书指纹每次重启都会变化；PEM 证书指纹会在证书续期后变化：

```bash
sudo bash nowhere-vps.sh fingerprint
```

脚本会在可取得当前指纹时把自签证书 Pin 加入 Native Vector 链接。
Anywhere 的 `nowhere://` 链接不支持携带 pin 参数；使用自签证书时，请把上面显示的
SHA-256 指纹添加到 Anywhere 的 Trusted Certificates。内存证书每次重启都会重新生成，
届时需要更新受信任指纹。自签 PEM 证书则需分别通过 `--pin` 设置 Vector pin，或通过
`--next-pin` 设置原生 Portal 链路的 pin。

可使用脚本封装命令生成密钥或查看远端 Portal 证书指纹：

```bash
sudo bash nowhere-vps.sh generate-key
sudo bash nowhere-vps.sh fingerprint 'nowhere://key@proxy.example.com:2077?morph=1'
```

远端指纹查询不会发送 Portal 身份验证或应用数据。固定证书前，应通过可信渠道核对
查询结果。
NW2 LTS 基线和 NW3 均支持这两个命令。

使用自有 PEM 证书时填写绝对路径：

```bash
sudo NOWHERE_TLS=2 \
  NOWHERE_CRT=/etc/letsencrypt/live/proxy.example.com/fullchain.pem \
  NOWHERE_TLS_KEY=/etc/letsencrypt/live/proxy.example.com/privkey.pem \
  NOWHERE_PUBLIC_HOST=proxy.example.com \
  bash nowhere-vps.sh install --yes
```

## 管理命令

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

完整参数请执行：

```bash
bash nowhere-vps.sh --help
```

旧脚本可继续通过“更新部署脚本”选项或 `update-script` 命令下载新版。下载完成后，
退出并重新运行脚本以加载新菜单。更新脚本会保留已保存的配置、密钥和正在运行的服务，
不会自动升级 Nowhere 二进制；二进制升级需要单独选择。

`status` 查看 systemd 服务状态；`telemetry` 调用 Nowhere 的只读实例状态快照。
`probe` 会根据已保存的服务配置临时生成 Vector URL，测试到目标地址的一次 TCP
Flow，不会显示共享密钥，也不会发送应用数据。NW2 LTS 基线和 NW3 均支持这些命令。

## 文件位置

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

卸载会保留 `/etc/nowhere`，避免误删配置与 Shared Key。
