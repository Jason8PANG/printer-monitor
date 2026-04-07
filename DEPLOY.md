# 🚀 部署指南 - suzweb02 服务器

## 📋 部署方式选择

### 方式一：一键自动部署（推荐）

```bash
# 1. 确保可以 SSH 连接到服务器
ssh root@suzweb02

# 2. 如果首次部署，先在服务器上运行初始化脚本
ssh root@suzweb02 "bash -s" < server-setup.sh

# 3. 运行部署脚本
./deploy-to-server.sh --host suzweb02 --user root
```

### 方式二：GitHub Actions 自动部署

1. 在 GitHub 仓库设置 Secrets：
   - 进入 https://github.com/Jason8PANG/printer-monitor/settings/secrets/actions
   - 添加以下 secrets：

   | Name | Value |
   |------|-------|
   | `SSH_PRIVATE_KEY` | SSH 私钥内容 (`cat ~/.ssh/id_ed25519`) |
   | `SERVER_HOST` | `suzweb02` |
   | `SERVER_USER` | `root` |
   | `DEPLOY_DIR` | `/opt/printer-monitor` (可选) |

2. 每次 push 到 main 分支自动部署

### 方式三：手动部署

```bash
# 1. SSH 到服务器
ssh root@suzweb02

# 2. 安装依赖
apt-get update && apt-get install -y nodejs npm cups cups-client

# 3. 克隆项目
git clone https://github.com/Jason8PANG/printer-monitor.git /opt/printer-monitor
cd /opt/printer-monitor

# 4. 安装 Node 依赖
npm install --production

# 5. 启动服务
npm start

# 或使用 systemd (见下方)
```

---

## 🔧 服务器初始化（首次部署）

在 `suzweb02` 上执行：

```bash
# 下载并运行初始化脚本
curl -O https://raw.githubusercontent.com/Jason8PANG/printer-monitor/main/server-setup.sh
chmod +x server-setup.sh
./server-setup.sh
```

或手动安装：

```bash
# Ubuntu/Debian
apt-get update
apt-get install -y nodejs npm cups cups-client dbus

# CentOS/RHEL
yum install -y epel-release
dnf install -y nodejs npm cups cups-client dbus

# 启动 CUPS
systemctl enable cups
systemctl start cups
```

---

## 📦 使用部署脚本

### 部署

```bash
./deploy-to-server.sh --host suzweb02 --user root
```

### 查看状态

```bash
./deploy-to-server.sh --status
```

### 查看日志

```bash
./deploy-to-server.sh --logs
```

### 重启服务

```bash
./deploy-to-server.sh --restart
```

### 回滚到上一版本

```bash
./deploy-to-server.sh --rollback
```

### 停止服务

```bash
./deploy-to-server.sh --stop
```

### 卸载

```bash
./deploy-to-server.sh --uninstall
```

---

## 🔐 SSH 免密登录配置

如果还没有配置 SSH key：

```bash
# 生成 SSH key (如果已有可跳过)
ssh-keygen -t ed25519

# 复制公钥到服务器
ssh-copy-id root@suzweb02

# 测试连接
ssh root@suzweb02
```

---

## 🛠️ Systemd 服务管理

服务名：`printer-monitor`

```bash
# 查看状态
systemctl status printer-monitor

# 启动
systemctl start printer-monitor

# 停止
systemctl stop printer-monitor

# 重启
systemctl restart printer-monitor

# 开机自启
systemctl enable printer-monitor

# 查看日志
journalctl -u printer-monitor -f
```

---

## 🔒 防火墙配置

确保以下端口开放：

| 端口 | 用途 |
|------|------|
| 3000 | Web 监控面板 |
| 631 | CUPS 打印服务 |

### Ubuntu (UFW)

```bash
ufw allow 3000/tcp
ufw allow 631/tcp
ufw reload
```

### CentOS (firewalld)

```bash
firewall-cmd --add-port=3000/tcp --permanent
firewall-cmd --add-port=631/tcp --permanent
firewall-cmd --reload
```

---

## 🌐 访问服务

部署完成后访问：

- **监控面板**: http://suzweb02:3000
- **CUPS 管理**: http://suzweb02:631

如果服务器有域名：

- http://your-domain.com:3000

---

## 🐛 故障排查

### 服务无法启动

```bash
# 查看详细日志
journalctl -u printer-monitor --no-pager -n 100

# 检查端口占用
ss -tlnp | grep 3000

# 检查 Node.js 版本
node -v  # 需要 16+
```

### CUPS 连接问题

```bash
# 检查 CUPS 状态
systemctl status cups

# 测试打印机
lpstat -p

# 查看 CUPS 日志
tail -f /var/log/cups/error_log
```

### 网络问题

```bash
# 测试服务器连接
ping suzweb02

# 测试端口
telnet suzweb02 3000

# 检查防火墙
iptables -L -n | grep 3000
```

---

## 📊 更新部署

```bash
# 拉取最新代码
git pull origin main

# 重新部署
./deploy-to-server.sh --host suzweb02

# 自动备份旧版本，可回滚
./deploy-to-server.sh --rollback
```

---

## 📝 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PORT` | 3000 | Web 服务端口 |
| `TZ` | Asia/Shanghai | 时区 |
| `DEPLOY_DIR` | /opt/printer-monitor | 部署目录 |

---

## ✅ 部署检查清单

- [ ] SSH 免密登录已配置
- [ ] 服务器依赖已安装 (Node.js, CUPS)
- [ ] 防火墙端口已开放 (3000, 631)
- [ ] 服务运行正常
- [ ] Web 界面可访问
- [ ] 打印机已配置并测试

---

**技术支持**: 如有问题请查看日志或提交 GitHub Issue
