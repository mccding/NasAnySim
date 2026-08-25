# DuckDNS：证书与动态公网 IP

当前发布的 `deploy/deploy.sh` 与 ARM64、amd64 最后成功部署脚本字节完全一致。它已经实测两项 DuckDNS 能力：

1. **DNS-01 证书**：公网 80 端口不可用于 HTTP-01 时，使用 DuckDNS token 申请 Let's Encrypt 证书；
2. **动态 IP 更新**：部署完成后生成 updater，并安装每 5 分钟执行一次的 cron。

## 提供 token

交互式终端会在需要时提示输入 token。SSH、CI 或无 TTY 环境应在私有部署目录创建 `.env`：

```bash
umask 077
printf '%s\n' 'NASANY_DUCKDNS_TOKEN=[REDACTED]' > .env
chmod 600 .env
bash deploy.sh <DuckDNS域名> <邮箱> <TTY>
```

只在客户机本地将 `[REDACTED]` 替换成真实 token。不要提交 `.env`。

## 双端实测行为

当脚本同时收到非空域名和 `NASANY_DUCKDNS_TOKEN` 时，它会：

- 生成当前部署目录的 `duckdns-update.sh`；
- 使用 `chmod +x` 将文件标记为可执行；
- 默认向 DuckDNS 请求 `ip=`，由 DuckDNS 根据请求源地址识别公网 IP；
- 如果设置 `NASANY_PUBLIC_IP`，则使用明确指定的地址；
- 安装 `*/5 * * * *` crontab；
- 将返回结果追加到 `/var/log/duckdns-update.log`。

双端验收主机均具备 `crontab`。当前已验证脚本没有“缺少 crontab 时继续”的兼容分支，因此新客户机应先确认：

```bash
command -v crontab
```

检查安装结果：

```bash
ls -l duckdns-update.sh
crontab -l | grep duckdns-update
./duckdns-update.sh
```

## 适用边界

- 只把 `NASANY_DUCKDNS_TOKEN` 与 `*.duckdns.org` 域名一起使用；
- 非 DuckDNS 域名不要向该脚本传入 DuckDNS token，改用对应 DNS 服务商的 DDNS；
- 当前实测脚本使用 `chmod +x`，没有承诺 updater 必然是 `700`；实际权限取决于部署目录和系统 `umask`；
- 双端清洁验收均以 root 在私有部署目录运行；
- `NASANY_PUBLIC_IP` 通常留空，只有代理/TUN 造成源地址识别错误时才显式设置；
- `.env`、`duckdns-update.sh`、证书和私钥均包含敏感信息，不得上传或粘贴到公开 issue；
- token 曾暴露时应立即在 DuckDNS 控制台轮换。

## 已验证脚本指纹

```text
SHA-256 bd9f02a8ff7d5cd6871467f394d45967e446978e770a31c9c5a32b2b9ec104de
```

任何对脚本的后续改动，包括权限强化、无 crontab 兼容、额外参数或自动检测，都必须重新做 ARM64 与 amd64 清洁部署后，才能继续沿用“双端已验证”声明。
