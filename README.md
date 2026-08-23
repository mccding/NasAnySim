<div align="center">

# 📡 NasAnySim

**把插在 NAS 上的 4G 模块，变成你的私人电话与短信网关**

[简体中文](README.md) · [English](README.en.md)

![License](https://img.shields.io/badge/License-PolyForm%20Noncommercial-blue.svg)
![Platform](https://img.shields.io/badge/Platform-ARM64%20Linux-green.svg)
![Version](https://img.shields.io/badge/Version-1.0.0--rc.4-lightgrey.svg)

---

</div>

## ✨ 项目简介 / Overview

NasAnySim 是一个**自托管蜂窝网关**，运行在 ARM Linux NAS 上（fnOS / OpenMediaVault / Debian 均可）。

插入 **DJI / 百旺（BAIWANG）4G 模块**（兼容高通 AT 指令）和一张 SIM 卡，网关就把这张 SIM 变成：

> 📱 **私人电话** · 💬 **短信收发** · 🔔 **来电/短信通知** · 🎙 **通话录音**

任何现代浏览器（iOS PWA、Android、桌面）都能访问，无需随身携带第二台手机。

---

## 🚀 功能特性 / Features

| 功能 | 说明 |
|------|------|
| 📱 短信收发 | 完整会话界面，持久化存储，多端同步 |
| 📞 语音通话 | WebRTC 呼入/呼出，TURN 中继穿透 NAT |
| 🔔 后台通知 | 来电/短信 Web Push，关闭 PWA 也能收到 |
| 🎙 通话录音 | NAS 本地录制，PWA 内播放/删除 |
| 🔐 安全认证 | 持久化 Cookie 认证，兼容 Caddy 反代 |
| 🐳 一键部署 | 单容器 ARM64 镜像，`docker compose up` 即用 |

---

## ⚖️ 许可证与分发 / Licensing & Distribution

> **闭源 · 仅镜像分发 · 免费自用 · 禁止商用**

本项目以**预编译的 ARM64 Docker 镜像**形式发布。**源码不公开**；镜像**仅供个人免费使用，禁止商用倒卖或再分发**。

闭源原因：项目早期 USB/AT/eSIM/模块管理基础衍生自 **VoHive/DJOneHub**（[github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)），受其 **"Changes and New Works License"** 约束；UAC 探测与 QDC507 音频路径参考了 **MaVo**（[github.com/moluncn/mavo](https://github.com/moluncn/mavo)，MIT）等公开项目。这些上游协议限制了衍生作品的再分发方式。

完整声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

**使用条款：** 免费供个人自托管使用；**禁止商用倒卖、禁止改皮转卖、禁止再分发镜像及其内容。**

---

## 📦 快速部署 / Deployment

### 需要准备什么？

| 项目 | 要求 |
|------|------|
| 🖥 NAS | ARM64 Linux + Docker（fnOS / rk35xx 已验证） |
| 📶 4G 模块 | DJI / 百旺模块，带 SIM 卡，枚举为 `/dev/ttyUSB2` |
| ⚙️ 系统设置 | **必须禁用 ModemManager**（避免抢占串口） |
| 🌐 网络 | 一个域名 + HTTPS（Caddy 反代）+ TURN 中继（语音必需） |

### 第一步：创建工作目录

```bash
mkdir -p /mnt/docker-compose/maccellular && cd /mnt/docker-compose/maccellular
```

### 第二步：生成会话密钥

```bash
openssl rand -base64 48 > data/auth/session-secret
chmod 600 data/auth/session-secret
```

### 第三步：保存 compose 配置

把下面的内容保存为 `compose.yaml`（点击右侧 📋 复制）：

<details>
<summary>📄 点击展开完整 docker-compose.yaml</summary>

```yaml
services:
  nasany-sms:
    image: ghcr.io/你的账号/nasany-sms:latest   # ARM64 镜像
    container_name: nasany-sms
    restart: unless-stopped
    network_mode: host
    devices:
      - /dev/ttyUSB2:/dev/ttyUSB2       # 4G 模块 AT 串口
      - /dev/snd:/dev/snd               # 模块语音(UAC)的 ALSA PCM
    volumes:
      - ./data:/var/lib/maccellular     # 持久化:短信/认证/录音
      - ./turn-secret:/run/secrets/turn-secret:ro
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    command:
      - -listen
      - 127.0.0.1:7576
      - -port
      - /dev/ttyUSB2
      - -phone-relay-runtime
      - -sms-store
      - /var/lib/maccellular
      - -call-history-store
      - /var/lib/maccellular/call-history.json
      - -remote-listen
      - 127.0.0.1:7578
      - -remote-host
      - localhost
      - -remote-control
      - -remote-allow-loopback
      - -remote-recordings-dir
      - /var/lib/maccellular/call-recordings
      - -remote-cookie-auth
      - -remote-cookie-auth-password-hash-file
      - /var/lib/maccellular/auth/password-hash
      - -remote-cookie-auth-username-file
      - /var/lib/maccellular/auth/username
      - -remote-cookie-auth-initialized-file
      - /var/lib/maccellular/auth/initialized
      - -remote-cookie-auth-secret-file
      - /var/lib/maccellular/auth/session-secret
      - -remote-media-turn-host
      - 你的域名.example.com
      - -remote-media-turn-secret-file
      - /run/secrets/turn-secret
      - -remote-media-turn-udp-port
      - "3478"
      - -remote-incoming-answer
      - -remote-rescue-hangup
      - -remote-push
      - -remote-push-vapid-private-key-file
      - /var/lib/maccellular/vapid-private-key
      - -remote-push-vapid-subject
      - mailto:你@example.com
      - -remote-push-subscriptions-file
      - /var/lib/maccellular/push/subscriptions.json
      - -web-console

  nasany-turn:
    image: coturn/coturn:latest
    container_name: nasany-turn
    restart: unless-stopped
    network_mode: host
    command:
      - -n
      - --realm=你的域名.example.com
      - --listening-port=3478
      - --tls-listening-port=5349
      - --fingerprint
      - --lt-cred-mech
      - --use-auth-secret
      - --static-auth-secret-file=/run/secrets/turn-secret
      - --cert=/etc/coturn/tls/fullchain.pem
      - --pkey=/etc/coturn/tls/privkey.pem
```

</details>

### 第四步：启动

```bash
docker compose up -d
```

### 第五步：打开 PWA

```
https://你的域名:7577/remote/
```

---

## 🔌 端口映射 / Ports

| 端口 | 绑定 | 服务 | 用途 |
|------|------|------|------|
| `7577` | 公网 (Caddy) | HTTPS PWA | `https://你的域名:7577/remote/` |
| `7578` | 127.0.0.1 | 远程网关 | 反代目标，不对外 |
| `7576` | 127.0.0.1 | 本地控制台 | 本机诊断 |
| `3478` | 公网 (TURN) | TURN UDP/TCP | WebRTC 语音中继（通话必需） |
| `5349` | 公网 (TURN) | TURN TLS | WebRTC 语音中继（加密） |

---

## 🔐 登录认证 / Authentication

### 首次登录

新部署的默认凭据为 **`admin` / `admin`**。

> ⚠️ **首次登录后请立即修改密码**，切勿在公网部署上保留默认凭据。

### 修改密码（终端）

SSH 到 NAS 后执行：

```bash
# 重置登录密码
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-password "你的新密码" \
  -remote-reset-password-file /var/lib/maccellular/auth/password-hash

# 重置登录用户名
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-username "你的新用户名" \
  -remote-reset-username-file /var/lib/maccellular/auth/username
```

> ⚠️ 重置后**重启容器**（`docker compose restart nasany-sms`）让新凭据生效。

---

## ⚙️ 模块配置 / Module Setup

连接模块后，网关**自动完成模块配置**，无需手动敲 AT 命令：

- ✅ **仅 CLCC mode 0** — 只跟踪真实语音通话
- ✅ **禁用 ModemManager** — 模块串口由网关独占
- ✅ **USB 组合查询** — `AT+QCFG="USBCFG"` 验证语音 USB profile
- ✅ **PCM/DAI 语音路由** — `AT+QPCMV` / `AT+QDAI` 校验音频链路
- ✅ **UAC + QDC507 音频** — 重启后 ADB 推送模块侧运行时，自动建立语音路由

**模块侧必备：** 模块枚举为 `/dev/ttyUSB2` · ModemManager 已禁用 · SIM 已注册 · TURN 中继可达

---

## 📱 手机安装（iOS PWA）

1. Safari 打开 `https://你的域名:7577/remote/`
2. 登录
3. 分享 → **添加到主屏幕**
4. 以独立 PWA 全屏运行

---

## ❓ 常见问题 / FAQ

<details>
<summary><b>为什么闭源？</b></summary>

上游协议约束（VoHive 的 "Changes and New Works License"、libusb LGPL、MaVo 参考）限制了衍生作品的再分发方式；我们只分发镜像。
</details>

<details>
<summary><b>支持 x86_64 吗？</b></summary>

目前镜像为 **ARM64**（rk35xx NAS）。x86_64 构建后续可能加入。
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

## 🙏 致谢 / Acknowledgements

- **VoHive / DJOneHub**（[github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)）— 早期 USB/AT、eSIM 与模块管理基础。`Required Notice: Copyright iniwex5`
- **MaVo**（[github.com/moluncn/mavo](https://github.com/moluncn/mavo)，MIT）— UAC 探测与 QDC507 音频路径参考
- **Celldock** 等公开项目 — 技术参考
- **Pion WebRTC**（MIT）、**libusb**（LGPL-2.1）、**coturn** — 运行时依赖

完整声明：[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

---

## 💖 支持本项目 / Support

如果本项目对你有帮助，欢迎支持它的开发：

<div align="center">

![支持 / Support](brand/support-qr.png)

*微信扫码支持 · Scan to support*

</div>
