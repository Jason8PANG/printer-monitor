# 🖨️ 打印机监控面板

基于 Node.js 的 Linux 打印机状态监控和自动修复工具，支持 Docker 部署。

## ✨ 功能特性

- **实时监控** - 查看所有打印机状态和打印队列
- **网络诊断** - 自动检测打印机网络连接状态
- **一键修复** - 自动诊断并修复常见打印问题
- **队列管理** - 清除卡住的打印任务
- **服务控制** - 重启 CUPS 服务，启用/禁用打印机
- **日志查看** - 实时查看 CUPS 系统日志
- **响应式设计** - 支持手机和桌面访问

## 📦 安装方法

### 方法一：CentOS Docker（推荐）

```bash
# 一键部署脚本
curl -sSL https://raw.githubusercontent.com/Jason8PANG/printer-monitor/main/deploy-centos.sh | sudo bash

# 或手动执行
git clone https://github.com/Jason8PANG/printer-monitor.git
cd printer-monitor
sudo ./deploy-centos.sh
```

详细文档：**[DEPLOY-CENTOS.md](DEPLOY-CENTOS.md)**

### 方法二：Docker Compose

```bash
# 1. 进入项目目录
cd printer-monitor

# 2. 构建并启动
docker-compose up -d --build

# 3. 查看日志
docker-compose logs -f

# 4. 访问 Web 界面
# http://localhost:6000
# CUPS 原生界面：http://localhost:631
```

### 方法三：Docker 直接运行

```bash
# 构建镜像
docker build -t printer-monitor .

# 运行容器
docker run -d \
  --name printer-monitor \
  --privileged \
  -p 3000:6000 \
  -p 631:631 \
  -v cups-config:/etc/cups \
  -v cups-logs:/var/log/cups \
  -e TZ=Asia/Shanghai \
  --restart unless-stopped \
  printer-monitor

# 查看日志
docker logs -f printer-monitor
```

### 方法四：本地安装（无需 Docker）

```bash
# 1. 安装系统依赖 (Debian/Ubuntu)
sudo apt-get update
sudo apt-get install -y cups cups-client dbus

# 2. 安装 Node.js 依赖
cd printer-monitor
npm install

# 3. 启动服务
npm start

# 4. 访问 http://localhost:6000
```

## 🔧 配置说明

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| PORT | 3000 | Web 服务端口 |
| TZ | Asia/Shanghai | 时区设置 |

### 端口说明

- **3000** - 监控面板 Web 界面
- **631** - CUPS 原生 Web 管理界面

### 数据持久化

Docker 卷会保存：
- `/etc/cups` - CUPS 配置文件
- `/var/log/cups` - CUPS 日志文件

## 🚀 使用指南

### 1. 查看打印机状态

打开 Web 界面后，会自动显示所有已安装的打印机：
- ✅ 绿色 = 已启用
- 🔴 红色 = 已禁用
- 🟡 黄色 = 空闲
- 🔵 蓝色 = 打印中

### 2. 网络诊断

选择打印机后点击"网络检查"：
- 自动提取打印机 URI
- Ping 测试网络连接
- 显示详细诊断结果

### 3. 自动修复

点击"一键自动修复"会执行：
1. 检查网络连接
2. 验证 CUPS 服务状态
3. 清除卡住的队列
4. 重新启用打印机

### 4. 手动操作

- **启用/禁用打印机** - 控制打印机接受任务
- **查看队列** - 显示当前等待的打印任务
- **清除队列** - 删除所有等待的任务
- **重启服务** - 重启整个 CUPS 服务
- **查看日志** - 显示最近的系统日志

## 🛠️ API 接口

```
GET  /api/printers              # 获取所有打印机状态
GET  /api/queue/:printer?       # 获取打印队列
POST /api/check-network/:printer # 检查网络连接
POST /api/clear-queue/:printer   # 清除打印队列
POST /api/restart-service        # 重启 CUPS 服务
POST /api/toggle-printer/:printer/:enable|disable
POST /api/accept-printer/:printer/:accept|reject
POST /api/auto-fix/:printer      # 自动诊断修复
GET  /api/logs                   # 获取系统日志
```

## 🔐 安全注意事项

⚠️ **重要提示：**

1. 此应用需要 **privileged 权限** 来管理系统服务
2. 建议仅在 **内网环境** 部署
3. 如需外网访问，请添加认证层（Nginx Auth、防火墙等）
4. 生产环境建议配置 HTTPS

### 添加基础认证（可选）

```bash
# 使用 Nginx 反向代理
docker run -d \
  --name nginx-auth \
  -p 80:80 \
  -v ./nginx.conf:/etc/nginx/nginx.conf \
  -v .htpasswd:/etc/nginx/.htpasswd \
  nginx:alpine
```

## 🐛 故障排查

### 容器启动失败

```bash
# 查看详细日志
docker logs printer-monitor

# 进入容器调试
docker exec -it printer-monitor /bin/sh
```

### 无法连接打印机

1. 检查打印机是否已正确安装：`lpstat -p`
2. 验证网络连接：`ping <printer-ip>`
3. 检查 CUPS 服务：`systemctl status cups`

### 权限问题

确保容器以 privileged 模式运行：
```yaml
privileged: true
```

## 📝 添加打印机

### 通过网络添加

```bash
# 进入容器
docker exec -it printer-monitor /bin/sh

# 添加 IPP 打印机
lpadmin -p Office-Printer -E -v ipp://192.168.1.100/ipp/print -m everywhere
cupsenable Office-Printer
cupsaccept Office-Printer

# 设置为默认
lpoptions -d Office-Printer
```

### 通过 USB 添加

USB 打印机需要宿主机支持，建议先在宿主机配置好打印机，然后通过 CUPS 共享。

## 🔄 更新部署

```bash
# Docker Compose
docker-compose pull
docker-compose up -d --build

# 直接 Docker
docker stop printer-monitor
docker rm printer-monitor
# 重新运行 docker run 命令
```

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**技术支持**: 如有问题请查看日志或提交 Issue
