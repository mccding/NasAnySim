<div align="center">

<img src="brand/icon.png" width="96" alt="NasAnySim 图标">

# NasAnySim

**把插在 NAS 上的 4G 模块，变成你的私人电话与短信网关**

[简体中文](README.md) · [English](README.en.md)

![License](https://img.shields.io/badge/License-PolyForm%20Noncommercial-blue.svg)
![Platform](https://img.shields.io/badge/Platform-ARM64%20%2F%20x86_64-green.svg)
![Version](https://img.shields.io/badge/Version-1.0.0--rc.4-lightgrey.svg)

</div>

## ✨ 项目简介

NasAnySim 是一个**自托管蜂窝网关**，运行在 ARM Linux NAS 上（fnOS / OpenMediaVault / Debian 均可）。

插入 **DJI / 百旺（BAIWANG）4G 模块**（兼容高通 AT 指令）和一张 SIM 卡，网关就把这张 SIM 变成：

> 📱 **私人电话** · 💬 **短信收发** · 🔔 **来电/短信通知** · 🎙 **通话录音**

任何现代浏览器（iOS PWA、Android、桌面）都能访问，无需随身携带第二台手机。

<div align="center">

![NasAnySim 架构](brand/architecture.svg)

*架构总览：手机 → NAS 网关 → 4G 模块与 SIM*

</div>

---

## 🚀 功能特性

| 功能 | 说明 |
|------|------|
| 📱 短信收发 | 完整会话界面，持久化存储，多端同步 |
| 📞 语音通话 | WebRTC 呼入/呼出，TURN 中继穿透 NAT |
| 🔔 后台通知 | 来电/短信 Web Push，关闭 PWA 也能收到 |
| 🎙 通话录音 | NAS 本地录制，PWA 内播放/删除 |
| 🔐 安全认证 | 持久化 Cookie 认证，兼容 Caddy 反代 |
| 🐳 一键部署 | 单容器镜像（ARM64 / x86_64），`docker compose up` 即用 |

---

## ⚖️ 许可证与分发

> **闭源 · 仅镜像分发 · 免费自用 · 禁止商用**

本项目以**预编译的 Docker 镜像**形式发布（ARM64 / x86_64）。**源码不公开**；镜像**仅供个人免费使用，禁止商用倒卖或再分发**。

闭源原因：项目早期 USB/AT/eSIM/模块管理基础衍生自 **VoHive/DJOneHub**（[github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)），受其 **"Changes and New Works License"** 约束；UAC 探测与 QDC507 音频路径参考了 **MaVo**（[github.com/moluncn/mavo](https://github.com/moluncn/mavo)，MIT）等公开项目。这些上游协议限制了衍生作品的再分发方式。

完整声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

**使用条款：** 免费供个人自托管使用；**禁止商用倒卖、禁止改皮转卖、禁止再分发镜像及其内容。**

---

## 📦 快速部署

### 你只需要准备 3 样东西

| # | 你要做的 | 说明 |
|---|---------|------|
| 1 | 🖥 **一台 NAS**（ARM64 或 x86_64） | 已装 Docker（fnOS / rk35xx 已验证） |
| 2 | 📶 **4G 模块 + SIM 卡** | 插在 NAS 上，枚举为 `/dev/ttyUSB2` |
| 3 | 🌐 **一个域名** | 解析到你家宽公网 IP（DDNS 也行） |

> ⚠️ **系统设置**：必须**禁用 ModemManager**（否则它抢占模块串口）。

### 一键部署（推荐）

**不用改任何脚本**——下载脚本，把域名和邮箱填在命令里就行：

```bash
# 1. 下载部署脚本
curl -fsSL https://raw.githubusercontent.com/mccding/NasAnySim/main/deploy/deploy.sh -o deploy.sh

# 2. 一键部署（把"你的域名"换成你的域名，"你的邮箱"用于自动申请 HTTPS 证书）
bash deploy.sh 你的域名 your@email.com
```

脚本会自动：创建数据目录、生成密钥、配置 Caddy 反代 + HTTPS 证书、启动网关和 TURN 中继。**唯一要你在路由器上做的**是转发两个端口（见下表）。

完成后打开：

```
https://你的域名:7577/remote/     # 默认账号 admin / admin
```

> ⚠️ **首次登录后请立即修改默认密码。**

### 路由器需要转发的端口

| 端口 | 协议 | 用途 | 必须转发 |
|------|------|------|---------|
| `7577` | TCP | HTTPS PWA 访问 | ✅ 必须 |
| `3478` | UDP | TURN 语音中继 | ✅ 必须 |
| `5349` | TCP | TURN TLS（检测到证书时启用） | 视情况 |

### 常见情况

**已有 Caddy/Nginx 反代？** 无需任何操作——脚本会自动检测到 7577 被占用，跳过自带 Caddy，你的反代不受影响。生成的 `./caddy/Caddyfile` 里有现成的站点配置，复制到你的反代即可复用。

**用 DuckDNS 免费域名 + 自动申请 HTTPS 证书？**（家庭宽带有公网 IP 但 80 端口被运营商封时推荐）

> **为什么需要 DuckDNS？** 家庭宽带公网 IP 是动态的（会变），需要一个免费域名 + 自动更新 IP 才能稳定访问你的 NAS。DuckDNS 完全免费、无需备案。

#### 第 1 步：注册 DuckDNS 域名

1. 打开 https://www.duckdns.org
2. 用 **GitHub / Google / Twitter 账号**登录（都行）
3. 在 "domains" 里输入你想要的子域名（比如 `mynas`），点 **add domain**
4. 页面会显示你的 **token**（一串字符，粘贴保存好，相当于密钥）

#### 第 2 步：一键脚本帮你搞定剩下的一切

部署时把 DuckDNS 的 token 交给脚本。**两种方式任选**：

**方式 ①：把 token 写在命令最前面**（照抄格式，只改 `你的token`）：

```bash
NASANY_DUCKDNS_TOKEN=你的token bash deploy.sh mynas.duckdns.org your@email.com
```
简单记：`NASANY_DUCKDNS_TOKEN=` 后面跟你的 token（空格隔开），再照常写 `bash deploy.sh 域名 邮箱`。

**方式 ②：写进 `.env` 文件**（更不容易抄错）：

```bash
# 用任意编辑器在本目录建一个 .env 文件，写上这一行：
NASANY_DUCKDNS_TOKEN=你的token

# 然后正常执行（脚本会自动读 .env）：
bash deploy.sh mynas.duckdns.org your@email.com
```

**执行时到底填什么（对照着填）**：

| 命令里的位置 | 填什么 | 例子 |
|------------|--------|------|
| `NASANY_DUCKDNS_TOKEN=` | 你在 duckdns.org 页面看到的 token（一串字符，像 `3d4507b3-5b2a-45e3-...`） | `NASANY_DUCKDNS_TOKEN=3d4507b3...` |
| `mynas.duckdns.org` | 你注册的**完整域名**（注意要带 `.duckdns.org`） | `mynas.duckdns.org` |
| `your@email.com` | 你自己的邮箱（用于申请 HTTPS 证书） | `you@example.com` |

> **token 在哪看**：登录 https://www.duckdns.org 后，页面 "Token" 一栏就是（一串 36 位左右的字符，形如 `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`）。复制它，粘贴到命令里或 `.env` 文件里。

两种方式效果完全一样。脚本会自动：
- 🎫 用 **acme.sh + DuckDNS DNS-01** 申请**真 HTTPS 证书**（不依赖 80 端口，家庭宽带可用）
- 🔄 生成 `duckdns-update.sh`（调用 DuckDNS 官方接口更新你的公网 IP）
- ⏰ 安装 **5 分钟一次的定时任务**，IP 变了自动更新域名解析

#### 第 3 步：没有 token 时怎么办

- 只填域名 + 邮箱 → 用 **Let's Encrypt**（需要 80 端口开放，云服务器/企业宽带可用）
- 都不填 → 用**自签证书**（开箱即用，但浏览器会提示不安全，PWA 需手动信任）

**模块不在 `/dev/ttyUSB2`？**（大多数用户不需要管这条）

只有当你运行脚本时看到 `WARN: /dev/ttyUSB2 not found`（模块串口没找到）才需要处理。先查一下你的模块实际在哪个串口：

```bash
ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

看到的是 `/dev/ttyUSB2`（默认）就不用管；如果是别的（比如 `/dev/ttyACM0`），把串口告诉脚本：

```bash
bash deploy.sh 你的域名 your@email.com /dev/ttyACM0
```

---

## 🔌 端口映射

| 端口 | 绑定 | 服务 | 用途 |
|------|------|------|------|
| `7577` | 公网 (Caddy) | HTTPS PWA | `https://你的域名:7577/remote/` |
| `7578` | 127.0.0.1 | 远程网关 | 反代目标，不对外 |
| `7576` | 127.0.0.1 | 本地控制台 | 本机诊断 |
| `3478` | 公网 (TURN) | TURN UDP/TCP | WebRTC 语音中继（通话必需） |
| `5349` | 公网 (TURN) | TURN TLS | WebRTC 语音中继（加密） |

---

## 🔐 登录认证

### 首次登录

新部署的默认凭据为 **`admin` / `admin`**。

> ⚠️ **首次登录后请立即修改密码**，切勿在公网部署上保留默认凭据。

### 修改密码（终端）

SSH 到 NAS 后执行：

```bash
# 重置登录密码
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-password "你的新密码" \
  -remote-reset-password-file /var/lib/nasany/auth/password-hash

# 重置登录用户名
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-username "你的新用户名" \
  -remote-reset-username-file /var/lib/nasany/auth/username
```

> ⚠️ 重置后**重启容器**（`docker compose restart nasany-sms`）让新凭据生效。

---

## ⚙️ 模块配置

连接模块后，网关**自动完成模块配置**，无需手动敲 AT 命令：

- ✅ **仅 CLCC mode 0** — 只跟踪真实语音通话
- ✅ **禁用 ModemManager** — 模块串口由网关独占
- ✅ **USB 组合查询** — `AT+QCFG="USBCFG"` 验证语音 USB profile
- ✅ **PCM/DAI 语音路由** — `AT+QPCMV` / `AT+QDAI` 校验音频链路
- ✅ **UAC + QDC507 音频** — 重启后 ADB 推送模块侧运行时，自动建立语音路由

**模块侧必备：** 模块枚举为 `/dev/ttyUSB2` · ModemManager 已禁用 · SIM 已注册 · TURN 中继可达

---

## 📱 手机安装

1. Safari 打开 `https://你的域名:7577/remote/`
2. 登录
3. 分享 → **添加到主屏幕**
4. 以独立 PWA 全屏运行

---

## ❓ 常见问题

<details>
<summary><b>为什么闭源？</b></summary>

上游协议约束（VoHive 的 "Changes and New Works License"、libusb LGPL、MaVo 参考）限制了衍生作品的再分发方式；我们只分发镜像。
</details>

<details>
<summary><b>支持 x86_64 吗？</b></summary>

支持。提供 **ARM64** 和 **x86_64** 两种镜像，一键脚本会自动检测 NAS 架构并拉取对应版本。
</details>

<details>
<summary><b>支持哪些模块？</b></summary>

DJI / 百旺模块（QDC507 语音路径，兼容高通 AT）。网关通过 USB AT 或 `/dev/ttyUSB2` 自动识别。
</details>

<details>
<summary><b>可以拿去卖吗？</b></summary>

不可以。镜像仅供个人自托管免费使用，禁止商用与再分发。
</details>

---

## 🙏 致谢

- **MacCellular**（[github.com/yuexiazhuojiu-byte/MacCellular](https://github.com/yuexiazhuojiu-byte/MacCellular)）— 本项目的前身，最早的 Mac 端 SMS + 电话网关开源实现，感谢作者的出色工作
- **VoHive / DJOneHub**（[github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)）— 早期 USB/AT、eSIM 与模块管理基础。`Required Notice: Copyright iniwex5`
- **MaVo**（[github.com/moluncn/mavo](https://github.com/moluncn/mavo)，MIT）— UAC 探测与 QDC507 音频路径参考
- **Celldock** 等公开项目 — 技术参考
- **Pion WebRTC**（MIT）、**libusb**（LGPL-2.1）、**coturn** — 运行时依赖

完整声明：[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

---

## 💖 支持本项目

如果本项目对你有帮助，欢迎支持它的开发：

<div align="center">

![支持本项目](brand/support-qr.png)

*微信扫码支持 · Scan to support*

</div>
