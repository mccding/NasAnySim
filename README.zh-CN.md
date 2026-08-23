<p align="center">
  <img src="docs/brand/icon.svg" width="112" alt="NasAnySim 图标">
</p>

<h1 align="center">NasAnySim</h1>

<p align="center"><strong>把插在 NAS 上的 4G 模块变成你的私人电话与短信网关——任何浏览器都能访问。</strong></p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="#部署">部署</a> ·
  <a href="#登录认证">登录认证</a> ·
  <a href="#许可证与分发">许可证与分发</a>
</p>

---

## 项目简介

NasAnySim 是一个**自托管蜂窝网关**，运行在 ARM Linux NAS 上（fnOS / OpenMediaVault / Debian 均可）。插入**DJI/百旺（BAIWANG）4G 模块**（兼容高通 AT 指令）和一张 SIM 卡，网关就把这张 SIM 变成一台私人电话 + 短信服务，任何现代浏览器（iOS PWA、Android、桌面）都能访问。

**功能特性**

- 📱 **短信收发** — 完整会话界面、持久化存储、多端同步
- 📞 **语音通话** — 基于 WebRTC 的呼入/呼出，带 TURN 中继穿透 NAT
- 🔔 **后台通知** — 来电、来短信的 Web Push，即使关闭 PWA 也能收到
- 🎙 **通话录音** — 在 NAS 上录制，PWA 内可播放/删除
- 🔐 **持久化 Cookie 认证** — 兼容 Caddy 等任何 forward_auth 反代
- 🐳 **单容器 ARM64 镜像** — ARM NAS 上 `docker compose up` 即用

---

## 许可证与分发

> **闭源，仅提供镜像分发。**

本项目以**预编译的 ARM64 Docker 镜像**形式发布。**源码不公开**；镜像**仅供个人免费使用，禁止商用倒卖或再分发**。

闭源的原因来自上游协议的约束：

- 早期 USB/AT/eSIM/模块管理基础衍生自 **VoHive / DJOneHub**（[github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)），受其**"Changes and New Works License"** 约束 — `Required Notice: Copyright iniwex5`。
- UAC 探测与 QDC507 音频路径参考了 **MaVo**（[github.com/moluncn/mavo](https://github.com/moluncn/mavo)，MIT）与 **Celldock** 等公开项目。
- 运行时依赖含 **libusb**（LGPL-2.1）与 **Pion WebRTC**（MIT）。

这些上游协议限制了衍生作品的再分发方式，因此我们只分发二进制而非源码。完整保留声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

**使用条款：** 免费供个人自托管使用；**禁止商用倒卖、禁止改皮转卖、禁止再分发镜像及其内容。**

---

## 部署

### 前置条件

- 一台 **ARM64 Linux NAS**（已安装 Docker；已在 fnOS / rk35xx 上验证）
- 一个 **高通 4G 模块**（已验证 QDC507 音频路径）+ 已插入的 **SIM 卡**，枚举为 `/dev/ttyUSB2`
- **必须禁用 ModemManager**，避免系统抢占模块串口
- 一个域名 + HTTPS（推荐 Caddy 反代），以及可通的 TURN 中继（语音必需）

### 快速开始

```bash
# 1. 创建工作目录
mkdir -p /mnt/docker-compose/maccellular && cd /mnt/docker-compose/maccellular

# 2. 把下面的 compose 配置保存为 compose.yaml

# 3. 生成会话密钥（至少 32 字节随机）
openssl rand -base64 48 > data/auth/session-secret
chmod 600 data/auth/session-secret

# 4. 启动网关
docker compose up -d

# 5. 打开 PWA
#    https://你的域名:7577/remote/
```

### docker-compose.yaml

```yaml
services:
  nasany-sms:
    image: ghcr.io/你的账号/nasany-sms:latest   # ARM64 镜像
    container_name: nasany-sms
    restart: unless-stopped
    network_mode: host
    devices:
      - /dev/ttyUSB2:/dev/ttyUSB2       # 高通模块 AT 串口
      - /dev/snd:/dev/snd               # 模块语音(UAC)的 ALSA PCM 设备
    volumes:
      - ./data:/var/lib/maccellular     # 持久化:短信/认证/录音
      - ./turn-secret:/run/secrets/turn-secret:ro   # coturn REST 密钥
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
      # 远程 PWA 网关
      - -remote-listen
      - 127.0.0.1:7578
      - -remote-host
      - localhost
      - -remote-control
      - -remote-allow-loopback
      - -remote-recordings-dir
      - /var/lib/maccellular/call-recordings
      # Cookie 认证
      - -remote-cookie-auth
      - -remote-cookie-auth-password-hash-file
      - /var/lib/maccellular/auth/password-hash
      - -remote-cookie-auth-username-file
      - /var/lib/maccellular/auth/username
      - -remote-cookie-auth-initialized-file
      - /var/lib/maccellular/auth/initialized
      - -remote-cookie-auth-secret-file
      - /var/lib/maccellular/auth/session-secret
      # 语音 TURN 中继
      - -remote-media-turn-host
      - 你的域名.example.com
      - -remote-media-turn-secret-file
      - /run/secrets/turn-secret
      - -remote-media-turn-udp-port
      - "3478"
      - -remote-incoming-answer
      - -remote-rescue-hangup
      # Web Push 后台通知
      - -remote-push
      - -remote-push-vapid-private-key-file
      - /var/lib/maccellular/vapid-private-key
      - -remote-push-vapid-subject
      - mailto:你@example.com
      - -remote-push-subscriptions-file
      - /var/lib/maccellular/push/subscriptions.json
      - -web-console

  # WebRTC 语音 TURN 中继（局域网外通话必需）
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

### 反向代理（Caddy）

PWA 与 API 位于 Caddy 之后，由 forward_auth 登录网关保护：

```caddy
https://你的域名:7577 {
    tls /etc/ssl/fullchain.pem /etc/ssl/privkey.pem

    # 登录/登出无需会话
    handle /remote/auth/* {
        reverse_proxy 127.0.0.1:7578 {
            header_up Host localhost
        }
    }

    # PWA 图标无需会话（iOS "添加到主屏幕"）
    handle /remote/*.png {
        reverse_proxy 127.0.0.1:7578 { header_up Host localhost }
    }
    handle /remote/*.svg {
        reverse_proxy 127.0.0.1:7578 { header_up Host localhost }
    }
    handle /remote/manifest.webmanifest {
        reverse_proxy 127.0.0.1:7578 { header_up Host localhost }
    }

    # 其余页面/API 需要签名会话 Cookie
    handle {
        forward_auth 127.0.0.1:7578 {
            uri /api/remote/v1/auth/check
            header_up Host localhost
        }
        reverse_proxy 127.0.0.1:7578 {
            header_up Host localhost
        }
    }
}
```

---

## 端口映射

| 端口 | 绑定 | 服务 | 用途 |
|------|------|------|------|
| `7577` | 公网 (Caddy) | HTTPS PWA | `https://你的域名:7577/remote/` |
| `7578` | 127.0.0.1 (nasany-sms) | 远程网关 | 反代目标，不对外 |
| `7576` | 127.0.0.1 (nasany-sms) | 本地控制台 | 本机诊断 |
| `3478` | 公网 (nasany-turn) | TURN UDP/TCP | WebRTC 语音中继（通话必需） |
| `5349` | 公网 (nasany-turn) | TURN TLS | WebRTC 语音中继（加密） |

---

## 登录认证

### 首次登录

新部署会播种默认凭据 **`admin` / `admin`**。

> ⚠️ **首次登录后请立即修改密码。** 对公网部署，切勿保留默认凭据。

### 终端修改密码

SSH 到 NAS，在容器内执行：

```bash
# 重置登录密码
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-password "你的新密码" \
  -remote-reset-password-file /var/lib/maccellular/auth/password-hash

# 重置登录用户名
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-username "你的新用户名" \
  -remote-reset-username-file /var/lib/maccellular/auth/username

# 工厂重置:用户名=admin、密码=<值>、下次登录视为首次
docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-init-credentials "临时密码" \
  -remote-cookie-auth-password-hash-file /var/lib/maccellular/auth/password-hash \
  -remote-cookie-auth-username-file /var/lib/maccellular/auth/username \
  -remote-cookie-auth-initialized-file /var/lib/maccellular/auth/initialized
```

> 重置命令把新 hash 写入磁盘后退出；**重启容器**（`docker compose restart nasany-sms`）让运行中的进程加载新凭据。

---

## 模块配置

连接模块后，网关会**自动完成模块配置**（无需手动敲 AT 命令）：

- **仅 CLCC mode 0** — 只跟踪真实语音通话，忽略 mode-1 数据会话
- **禁用 ModemManager** — 模块串口由网关独占
- **USB 组合查询** — `AT+QCFG="USBCFG"` 验证支持语音的 USB profile
- **PCM/DAI 语音路由** — `AT+QPCMV` / `AT+QDAI` 校验，确保模块音频到达主机
- **UAC + QDC507 音频**（参考 MaVo）— 重启后经 ADB 推送模块侧语音运行时；加载 `qdc507` 内核模块；建立 PCM 桥；接听电话后自动启动语音路由

**模块侧必备环境：**
1. 模块枚举为 `/dev/ttyUSB2`
2. ModemManager 已禁用
3. SIM 已插入且注册到网络
4. TURN 中继可达（通话音频）

---

## 手机安装（iOS PWA）

1. Safari 打开 `https://你的域名:7577/remote/`
2. 登录
3. 分享 → **添加到主屏幕**
4. 应用以独立 PWA 全屏方式安装

---

## 常见问题

**为什么闭源？**
上游协议约束（VoHive 的 "Changes and New Works License"、libusb LGPL、MaVo 参考）限制了衍生作品的再分发方式；我们只分发镜像。见[许可证与分发](#许可证与分发)。

**支持 x86_64 吗？**
目前镜像为 **ARM64**（rk35xx NAS）。x86_64 构建后续可能加入。

**支持哪些模块？**
具备 QDC507 语音路径的高通模块（EC25 系列已验证）。网关通过 `/dev/ttyUSB2` 自动识别 AT 串口。

**可以拿去卖吗？**
不可以。镜像仅供个人自托管免费使用，禁止商用与再分发。

---

## 致谢

- **VoHive / DJOneHub**（[github.com/iniwex5/vohive](https://github.com/iniwex5/vohive)）— 早期 USB/AT、eSIM 与模块管理基础。`Required Notice: Copyright iniwex5`
- **MaVo**（[github.com/moluncn/mavo](https://github.com/moluncn/mavo)，MIT）— UAC 探测与 QDC507 音频路径参考
- **Celldock** 等公开项目 — 技术参考
- **Pion WebRTC**（MIT）、**libusb**（LGPL-2.1）、**coturn** — 运行时依赖

完整声明：[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

---

## 支持本项目

如果本项目对你有帮助，欢迎支持它的开发：

<div align="center">
  <img src="docs/brand/support-qr.png" width="180" alt="支持/打赏二维码">
  <p><em>支持本项目</em></p>
</div>
