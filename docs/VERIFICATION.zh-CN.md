# 双架构验收记录

## 验收范围

本记录只覆盖已经实际执行并回读的发布候选验收，不代表对所有 4G 模块、所有路由器或所有运营商的无条件兼容承诺。

## 结果

| 平台 | 镜像来源 | 清洁目录部署 | HTTPS/DNS-01 | TURN TLS 5349 | ADB/模块运行时 | 电话/短信闭环 |
|---|---|:---:|:---:|:---:|:---:|:---:|
| Linux amd64 / x86_64 | Docker Hub `:amd64` | 通过 | 通过 | 通过 | 通过 | 通过 |
| Linux arm64 / AArch64 | Docker Hub `:arm64` / `:latest` | 通过 | 通过 | 通过 | 通过 | 通过 |

## 已验证项目

- 客户机从清理后的环境开始，不依赖旧容器、旧镜像、旧 ADB server 或旧证书；
- 客户机只接收公开部署脚本和 Docker 镜像，不接收源码、`.git`、Go cache 或构建上下文；
- 脚本根据主机架构选择镜像；
- `host ADB` 仅监听 `localhost:5037`，并具备 systemd 持久化；
- 模块 bootstrap 首次可能返回 not-ready，脚本会自动重试并要求 `Ready=true`；
- coturn 目录、配置和 `nobody` 可读证书权限由脚本自动处理；
- Caddy HTTPS、Let's Encrypt DNS-01 和 TURN TLS 5349 已回读；
- ARM64 和 amd64 的模块语音运行时、ALSA helper、ADB/UAC 拓扑已验证；
- 手机端真实拨号、接听、双向听感、短信收发和挂断状态已通过本轮实测；
- `AT+CLCC` 挂断后无残留通话状态。

## 发布前复核命令

```bash
bash deploy/deploy_contract_test.sh
bash -n deploy/deploy.sh
git diff --check
```

同时检查公开提交没有 `.env`、证书、私钥、`duckdns-update.sh`、客户机地址、SSH 信息或 token。镜像 tag 和 digest 应在 Docker Hub 端回读确认。

## 边界

- `ttyUSB` 编号随 USB 拓扑变化，首次使用必须运行 `--detect-tty`；
- 家庭宽带的 HTTP-01 可用性不能假定，推荐 DuckDNS DNS-01；
- 通话依赖路由器正确转发 TURN 端口段；
- `7576`、`7578`、`5037` 不属于公网服务；
- 本项目闭源运行时通过预编译镜像分发，公开仓库不包含运行时源码。
