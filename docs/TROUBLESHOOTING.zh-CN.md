# 故障排查

## 先收集基础信息

```bash
bash deploy.sh --detect-tty
uname -m
docker ps -a --filter name=nasany
ss -lntup | grep -E ':(5037|5349|7576|7577|7578)\b'
```

不要先删除数据目录；先保留 `docker compose` 输出和相关日志。

## 网页打不开

1. 确认域名 A 记录指向当前公网 IP；
2. 确认路由器转发 `7577/TCP`；
3. 检查 `nasany-caddy`：

```bash
docker logs --tail=200 nasany-caddy
docker ps --filter name=nasany-caddy
```

如果宿主机已有代理占用 `7577`，使用：

```bash
NASANY_SKIP_CADDY=1 bash deploy.sh <域名> <邮箱> <TTY>
```

然后将生成的 `caddy/Caddyfile` 整合到已有代理。

## 网页能打开，但提示无法连接公网中继

依次确认：

- `3478/UDP` 已转发；
- `49160-49167/UDP` 整段已转发；
- 证书存在时 `5349/TCP` 已转发；
- `nasany-turn` 没有证书权限错误：

```bash
docker logs --tail=200 nasany-turn
ls -ld coturn
ls -l coturn/turnserver.conf coturn/fullchain.pem coturn/privkey.pem
```

脚本会自动将 coturn 目录设为 `755`，配置设为 `644`，并为容器内 `nobody` 准备可读证书副本。用户不需要手工修复这些权限。

## 证书申请失败

- 家庭宽带不要反复尝试 HTTP-01；
- 为 `*.duckdns.org` 域名提供 DuckDNS token，走 DNS-01；
- 非交互环境必须通过 `.env` 或环境变量提供 token；
- 检查本机时间、DNS 和 `/tmp/acme-*.log`；
- 不要把旧证书复制进清洁验收环境来代替真实签发。

## 找不到模块串口

```bash
bash deploy.sh --detect-tty
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

多串口模块不要只看编号；使用检测输出的 VID:PID 和 `ID_PATH` 判断，并将实际 AT 口作为第三个参数。

## ADB 错误

脚本会安装 Android platform tools（在支持的 apt/dnf 主机上）、创建 `nasany-adb-server.service`，并只监听 `localhost:5037`：

```bash
systemctl status nasany-adb-server.service --no-pager
adb -L tcp:localhost:5037 devices -l
ss -lnt | grep ':5037'
```

如果看到 `0.0.0.0:5037` 或 `[::]:5037`，先停止暴露的 ADB，再重新运行脚本。不要将 ADB 暴露公网。

## 模块被其他服务占用

脚本会停用 ModemManager。如果发行版没有 systemd，检查是否有其他进程打开串口：

```bash
fuser -v /dev/ttyUSB2
lsof /dev/ttyUSB2 2>/dev/null
```

## DuckDNS 没有自动更新

```bash
ls -l duckdns-update.sh
crontab -l | grep duckdns-update
./duckdns-update.sh
cat /var/log/duckdns-update.log
```

只有 `*.duckdns.org` 域名且部署时提供 token 才会生成 updater。自有域名不会安装 DuckDNS updater。若 token 曾暴露，先轮换 token，再重新生成本地 `.env` 和部署目录。
