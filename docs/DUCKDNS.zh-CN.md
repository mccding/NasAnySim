# DuckDNS：证书与动态公网 IP

一键脚本内置两项 DuckDNS 能力：

1. **DNS-01 证书**：公网 80 端口不可达时，使用 DuckDNS token 申请 Let's Encrypt 证书；
2. **动态 IP 更新**：部署完成后自动生成 updater，并安装每 5 分钟执行一次的 cron。

用户不需要另外下载 DuckDNS updater，也不需要手工写 cron。

## 提供 token

交互式终端可以直接运行：

```bash
bash deploy.sh <域名> <邮箱> <TTY>
```

没有用户证书时，脚本会提示输入 token。SSH、CI 或其他没有 TTY 的环境请在部署目录创建 `.env`：

```bash
umask 077
printf '%s\n' 'NASANY_DUCKDNS_TOKEN=[REDACTED]' > .env
chmod 600 .env
bash deploy.sh <域名> <邮箱> <TTY>
```

只在本机将 `[REDACTED]` 替换成真实 token。不要把 `.env` 上传到 GitHub。

## 自动更新机制

只有域名属于 `*.duckdns.org` 且部署时提供 token，脚本才会启用内置 updater。它会：

- 生成当前目录的 `duckdns-update.sh`；
- 设置文件权限为 `700`；
- 默认向 DuckDNS 请求 `ip=`，让 DuckDNS 根据请求源地址识别当前公网 IP；
- 如果设置 `NASANY_PUBLIC_IP`，则固定使用该值；
- 安装 `*/5 * * * *` cron；
- 将返回结果追加到 `/var/log/duckdns-update.log`。

检查：

```bash
ls -l duckdns-update.sh
crontab -l | grep duckdns-update
./duckdns-update.sh
```

如果系统没有 `crontab`，脚本会保留 owner-only updater 并给出警告；此时需要使用系统已有的调度器调用该文件。

## 安全注意

updater 文件中的 URL 包含 token，因此：

- 不要把 `duckdns-update.sh` 贴到 issue、群聊或日志中；
- 不要改变 `700` 权限；
- `.env`、证书、私钥和 updater 都应保留在部署目录；
- token 曾经暴露时，应在 DuckDNS 控制台轮换；
- 非 DuckDNS 域名不会安装这个 updater，应使用自己的 DNS 服务商 DDNS 功能。

## 固定公网 IP

一般不需要设置 `NASANY_PUBLIC_IP`。只有在代理、TUN 或特殊出口导致 DuckDNS 看到的源地址不正确时，才在本机环境中设置：

```bash
NASANY_PUBLIC_IP=<你的公网IP> bash deploy.sh <域名> <邮箱> <TTY>
```

不要把真实公网 IP 和 token 写入公开文档或提交记录。
