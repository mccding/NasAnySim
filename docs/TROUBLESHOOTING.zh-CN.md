# 故障排查

## 先收集基础信息

```bash
uname -m
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
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

当前双端实测脚本要求 `7577` 未被占用；`NASANY_SKIP_CADDY` 不属于双端验收接口。如果已有代理占用端口，请先停止，不要直接执行当前一键部署，代理整合需单独复测。

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
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

多串口模块不要只看编号，应确认实际 AT 口并将其作为第三个参数。当前实测脚本没有 `--detect-tty` 子命令。

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

## 忘记用户名或密码

当前镜像的网页没有常驻账号设置入口。首次部署需要停用 `admin / admin`，或后来忘记账号/密码时，都应使用容器内置的一次性重置功能：

```bash
read -r -p '新用户名：' NASANY_NEW_USERNAME
read -r -s -p '新密码（8–128 个字符）：' NASANY_NEW_PASSWORD
printf '\n'

if docker exec nasany-sms /usr/local/bin/djonehub-macos \
  -remote-reset-username "$NASANY_NEW_USERNAME" \
  -remote-reset-username-file /var/lib/nasany/auth/username \
  -remote-reset-password "$NASANY_NEW_PASSWORD" \
  -remote-reset-password-file /var/lib/nasany/auth/password-hash; then
  unset NASANY_NEW_USERNAME NASANY_NEW_PASSWORD
  docker restart nasany-sms
else
  unset NASANY_NEW_USERNAME NASANY_NEW_PASSWORD
  echo '账号或密码修改失败，容器未重启。' >&2
fi
```

重启后用新账号登录，并确认 `admin / admin` 已无法登录。一次性重置程序执行后立即退出是正常行为；如果不重启主容器，正在运行的进程仍会使用内存中的旧凭据。不要把真实密码直接写进命令、Compose、`.env` 或公开 issue；内置重置接口会在一次性进程参数中短暂接收密码，只能在可信的 NAS 管理终端执行。

## DuckDNS 没有自动更新

```bash
ls -l duckdns-update.sh
crontab -l | grep duckdns-update
./duckdns-update.sh
cat /var/log/duckdns-update.log
```

当前双端实测脚本在“域名和 token 均非空”时生成 updater，因此只应把 DuckDNS token 与 `*.duckdns.org` 域名一起使用。双端验收主机都安装了 `crontab`。若 token 曾暴露，先轮换 token，再重新生成本地 `.env` 和部署目录。
