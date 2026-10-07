# nowhere-sh

[English](README.md)

[NodePassProject/Nowhere](https://github.com/NodePassProject/Nowhere) Portal
的 Linux VPS 一键部署与管理脚本。

## 支持范围

脚本默认安装 `v2.2.1`。指定版本列表会展示受支持的 Nowhere Release，并排除 V1；
升级时直接回车会选择列表中的最新版本。脚本输出
Anywhere 的 `nowhere://` 链接和 Native Vector 的 `vector://` URL。

## 功能

- 交互式向导，每一项均有默认值，连续回车即可完成部署。
- 下载指定受支持 Release，并通过一个 systemd Portal 服务管理。
- 支持共享/独立 TCP、UDP 端口，TCP-only、UDP-only，以及
  `tcp4`、`tcp6`、`udp4`、`udp6` 地址族限制。
- 支持 Portal TLS、`morph`、TCP Morph 前导模式、限速、出站 SOCKS5、原生
  `next` Portal 链路、Mux、SNI、证书 Pin、日志与传输环境参数。
- 支持 Nowhere 2.2 共享密钥校验与迁移、32 位密钥生成、独立 `dial4/dial6`
  出站源地址绑定，以及远端证书指纹查询。
- 支持 Native Vector 固定路由或 `mix`、Mux、SNI、Pin、限速、日志和本地
  SOCKS5 监听。
- 输出 Anywhere 的 TCP、UDP 导入链接，并为优先可用链路生成终端二维码。
- 提供 Terminal UI、日志、服务启停与 TLS 证书 SHA-256 查询。
- 提供只读实例状态和 TCP Flow 连通性探测（Nowhere `v2.1.2` 及之后版本）。

## 快速开始

系统需要 Linux、systemd、`curl`、`tar`，支持 `x86_64` 与 `aarch64` VPS。

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

首次交互运行时可选择 English 或简体中文，选择会保存下来；之后可在菜单第 `20`
项切换，也可用 `--lang en` 或 `--lang zh` 显式指定语言。

默认安装会在 `2077` 同时启用无限制 TCP 和 UDP carrier，使用临时自签证书，
并输出 Anywhere 链接。VPS 防火墙与云厂商安全组均需放行同一个 TCP、UDP 端口。

```text
1) 安装/重装（Anywhere）
2) 安装/重装（Native Vector）
3) 快速默认安装（Anywhere）
4) 修改配置
5) 指定 Release 安装
6) 更新 Nowhere 二进制
7) 启动服务
8) 停止服务
9) 重启服务
10) 查看 Nowhere 实例状态（2.1.2+）
11) 测试 TCP 连通性（2.1.2+）
12) 查看 systemd 服务状态
13) 打开 Terminal UI
14) 查看日志
15) 打印客户端链接 / 二维码
16) 查看证书 SHA-256
17) 生成共享密钥（2.2.0+）
18) 查询远端证书指纹（2.2.0+）
19) 卸载服务
20) 切换语言
21) 更新部署脚本
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

Portal 出站源地址支持两种互斥模式：旧的单地址 `dial`，或 Nowhere 2.2 新增的
`dial4/dial6`。后者可分别设置，也可同时设置。请填写本机 IP 字面值，不要加方括号
或端口：

```bash
sudo bash nowhere-vps.sh configure --dial4 192.0.2.10 --dial6 2001:db8::10
```

这些参数影响 Portal 对外建立的连接，包括直连、SOCKS5 和原生 `next`；不改变入站
监听地址，也不控制独立运行的 Vector 或连通性探测。指定源地址绑定失败时不会静默
回退到系统自动选择。

## Portal 出站路径

Portal 可直连目标、经由出站 SOCKS5，或连接下一个原生 Portal。向导中选择
`direct`、`socks`、`next` 之一；SOCKS 与 `next` 不能同时使用。

使用 `--next key@host:port` 或显式 carrier 端点配置下一跳 Portal；其路由和 TLS
参数分别为 `--next-up`、`--next-down`、`--next-mux`、`--next-sni`、`--next-pin`。

## Morph 与升级

默认 `morph=0`。启用 `morph=1` 后，Nowhere `v2.1.0` 更改了 Morph 协议格式，
无法与 `v2.0.x` 的 Morph 对端通信。因此，将已启用 Morph 的 Portal 从 `v2.0.x`
升级到 `v2.1.0` 或更高版本前，需要同步升级受影响的 Anywhere 客户端、原生
Vector 节点和原生 `next` 跳板。

交互式更新在这个兼容性边界会要求输入 `UPGRADE` 才继续。非交互式自动化会被
拒绝；只有已完成协同升级时，才应额外传入
`--allow-morph-breaking-upgrade`。

Nowhere `v2.1.1` 移除了 `event` 日志级别。更新或重配到 `v2.1.1` 及之后版本时，
脚本会自动将已保存的 `event` 改为 `info`；选择较早版本时仍允许使用 `event`。

Nowhere `v2.2.1` 要求 Portal 监听密钥和启用的原生 `next` 密钥必须是 32–64 位小写
十六进制。新安装会生成 32 位密钥（16 个随机字节）；已有的 64 位密钥仍然有效并会保留。
更新旧安装时，如果当前监听密钥不兼容，脚本会询问是否轮换；接受后旧客户端链接会失效，
需要重新导入。若 `next` 密钥不合规，脚本会在替换二进制前停止更新。存在 Portal 链路时，
请先为每一跳确定新密钥，并在链路两端配置完全相同的值，再升级对应节点。

2.2 默认对 Native Vector、`probe` 和原生 `next` 校验证书链与名称；`sni=none` 不会
关闭校验。自签证书必须提供准确的 SHA-256 pin。默认的内存自签证书在服务每次重启后
都会变化；若能取得当前指纹，脚本会将 pin 自动写入生成的 Vector 链接。希望链接稳定
时建议使用受信任 CA 签发的 PEM 证书。

本机 Nowhere 进程主动发起的 TCP Morph 连接可用
`--morph-tcp-prelude low7|full8` 选择前导模式；Nowhere 2.2 默认 `full8`，仍可选择
`low7`。它影响原生 `next` 等出站连接，不会写入 Anywhere 导入链接。

## 客户端链接

Anywhere 会分别生成 TCP 与 UDP 链接，保持在其支持的固定路由范围内。Native
Vector 支持完整路由策略，例如：

Anywhere 链接默认使用链接中的公网主机名作为 SNI。若分享地址是 IP、证书签发给
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

指纹命令会输出 Portal 实际加载证书的 SHA-256，适用于自签证书（`tls=1`）和
PEM 证书（`tls=2`）。脚本优先探测本机 TCP 当前呈现的证书；探测不可用时再从
Nowhere 日志读取，因此 PEM 证书热重载后也能显示当前指纹。自签证书指纹每次重启
都会变化；PEM 证书指纹会在证书续期后变化：

```bash
sudo bash nowhere-vps.sh fingerprint
```

Nowhere 2.2 下，脚本会在可取得当前指纹时把自签证书 pin 加入 Native Vector 链接。
Anywhere 的 `nowhere://` 链接不支持携带 pin 参数；使用自签证书时，请把上面显示的
SHA-256 指纹添加到 Anywhere 的 Trusted Certificates。内存证书每次重启都会重新生成，
届时需要更新受信任指纹。自签 PEM 证书则需分别通过 `--pin` 设置 Vector pin，或通过
`--next-pin` 设置原生 Portal 链路的 pin。

可使用 Nowhere 2.2 工具生成密钥或查看远端 Portal 证书指纹：

```bash
sudo bash nowhere-vps.sh generate-key
sudo bash nowhere-vps.sh fingerprint 'nowhere://key@proxy.example.com:2077?morph=1'
```

远端指纹查询不会发送 Portal 身份验证或应用数据。固定证书前，应通过可信渠道核对
查询结果。
这两个封装命令要求本机已安装 Nowhere `v2.2.0` 或更新版本。

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

`status` 查看 systemd 服务状态；`telemetry` 调用 Nowhere 的只读实例状态快照。
`probe` 会根据已保存的服务配置临时生成 Vector URL，测试到目标地址的一次 TCP
Flow，不会显示共享密钥，也不会发送应用数据。这两个命令要求已安装 Nowhere
`v2.1.2` 或更新版本；较旧版本请先从菜单更新二进制。

## 文件位置

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

卸载会保留 `/etc/nowhere`，避免误删配置与 Shared Key。
