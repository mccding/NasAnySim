# 更新记录

## 1.0.0-rc.5 — 2026-08-25

- 完成 Linux amd64 与 ARM64 清洁环境一键部署验收；
- 增加 `bash deploy.sh --detect-tty`，首次部署先检查架构、串口、USB、ALSA 和 ADB；
- 固化 host ADB loopback、启动等待和 bootstrap 自动重试；
- 固化 coturn `nobody` 权限、TURN TLS 5349 和配置变更后的强制重建；
- 非交互 SSH/CI 不再因 DuckDNS/acme.sh 询问导致异常退出；
- 内置 DuckDNS DNS-01 证书与动态公网 IP 更新：生成 owner-only updater，并安装 5 分钟 cron；
- 明确公网端口、内部端口、路由器转发和安全边界；
- 重排中英文 README，补充端口、DuckDNS、故障排查和双架构验收文档；
- 公开仓库保持文档/部署资源边界，不包含源码、证书、token、私钥或客户机运行数据。
