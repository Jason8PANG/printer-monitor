# 🐧 AlmaLinux 9 Docker 部署指南

适用于 AlmaLinux 9 / Rocky Linux 9 / RHEL 9 服务器，使用 Docker 容器部署打印机监控服务。

---

## 📋 前置要求

| 项目 | 要求 |
|------|------|
| 操作系统 | AlmaLinux 9 / Rocky Linux 9 / RHEL 9 |
| Docker | 20.10+ |
| Docker Compose | 2.0+ (可选) |
| 内存 | 最低 512MB |
| 磁盘 | 最低 1GB |
| 端口 | 3000 (Web), 631 (CUPS) |

---

## 🚀 快速部署（推荐）

### 步骤 1：安装 Docker

```bash
# 卸载旧版本（如果有）
sudo dnf remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine

# 安装 yum 工具包
sudo dnf install -y yum-utils

# 添加 Docker 仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装 Docker Engine
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
docker compose version
```

### 步骤 2：克隆项目

```bash
# 克隆仓库
git clone https://github.com/Jason8PANG/printer-monitor.git
cd printer-monitor

# 或者只下载必要文件
mkdir -p /opt/printer-monitor
cd /opt/printer-monitor
wget https://raw.githubusercontent.com/Jason8PANG/printer-monitor/main/docker-compose.yml
wget https://raw.githubusercontent.com/Jason8PANG/printer-monitor/main/Dockerfile.centos
wget https://raw.githubusercontent.com/Jason8PANG/printer-monitor/main/docker-entrypoint.centos.sh
chmod +x docker-entrypoint.centos.sh
```

### 步骤 3：构建并启动容器

```bash
# 方式 A：使用 Docker Compose（推荐）
docker compose -f docker-compose.centos.yml up -d --build

# 方式 B：使用 Docker 命令
docker build -f Dockerfile.centos -t printer-monitor:centos .

docker run -d \
  --name printer-monitor \
  --privileged \
  --restart unless-stopped \
  -p 3000:6000 \
  -p 631:631 \
  -v printer-data:/var/log/cups \
  -v printer-config:/etc/cups \
  -e TZ=Asia/Shanghai \
  -e PORT=6000 \
  printer-monitor:centos
```

### 步骤 4：验证部署

```bash
# 查看容器状态
docker ps | grep printer-monitor

# 查看日志
docker logs printer-monitor

# 测试 Web 界面
curl http://localhost:6000

# 检查端口
ss -tlnp | grep -E '3000|631'
```

---

## 📁 完整部署脚本

创建 `deploy-centos.sh`：

```bash
#!/bin/bash
set -e

echo "=========================================="
echo "  🖨️  打印机监控 - AlmaLinux Docker 部署"
echo "=========================================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，开始安装..."
    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl start docker
    systemctl enable docker
fi

echo "✅ Docker 版本：$(docker --version)"

# 进入项目目录
cd /opt/printer-monitor 2>/dev/null || {
    echo "📁 创建部署目录..."
    mkdir -p /opt/printer-monitor
    cd /opt/printer-monitor
}

# 下载必要文件（如果不存在）
for file in docker-compose.centos.yml Dockerfile.centos docker-entrypoint.centos.sh; do
    if [ ! -f "$file" ]; then
        echo "📥 下载 $file..."
        curl -sSL "https://raw.githubusercontent.com/Jason8PANG/printer-monitor/main/$file" -o "$file"
    fi
done

chmod +x docker-entrypoint.centos.sh 2>/dev/null || true

# 构建镜像
echo "🔨 构建 Docker 镜像..."
docker build -f Dockerfile.centos -t printer-monitor:centos .

# 停止旧容器
docker stop printer-monitor 2>/dev/null || true
docker rm printer-monitor 2>/dev/null || true

# 启动新容器
echo "🚀 启动容器..."
docker run -d \
  --name printer-monitor \
  --privileged \
  --restart unless-stopped \
  -p 3000:6000 \
  -p 631:631 \
  -v printer-data:/var/log/cups \
  -v printer-config:/etc/cups \
  -e TZ=Asia/Shanghai \
  -e PORT=6000 \
  printer-monitor:centos

# 等待启动
sleep 3

# 验证
if docker ps | grep -q printer-monitor; then
    echo ""
    echo "=========================================="
    echo "  ✅ 部署成功!"
    echo "=========================================="
    echo ""
    echo "🌐 访问地址:"
    echo "   监控面板：http://$(hostname -i 2>/dev/null || echo 'localhost'):6000"
    echo "   CUPS 管理：http://$(hostname -i 2>/dev/null || echo 'localhost'):631"
    echo ""
    echo "📋 常用命令:"
    echo "   查看状态：docker ps | grep printer-monitor"
    echo "   查看日志：docker logs printer-monitor"
    echo "   重启服务：docker restart printer-monitor"
    echo "   停止服务：docker stop printer-monitor"
    echo ""
else
    echo "❌ 容器启动失败，查看日志："
    docker logs printer-monitor
    exit 1
fi
```

使用：
```bash
curl -sSL https://raw.githubusercontent.com/Jason8PANG/printer-monitor/main/deploy-centos.sh | bash
```

---

## 🔧 Docker Compose 配置

创建 `docker-compose.centos.yml`：

```yaml
version: '3.8'

services:
  printer-monitor:
    build:
      context: .
      dockerfile: Dockerfile.centos
    image: printer-monitor:centos
    container_name: printer-monitor
    privileged: true
    ports:
      - "3000:6000"
      - "631:631"
    volumes:
      - printer-data:/var/log/cups
      - printer-config:/etc/cups
    environment:
      - TZ=Asia/Shanghai
      - PORT=6000
    restart: unless-stopped
    networks:
      - printer-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

volumes:
  printer-data:
  printer-config:

networks:
  printer-net:
    driver: bridge
```

启动：
```bash
docker compose -f docker-compose.centos.yml up -d
```

---

## 🔐 防火墙配置

### firewalld (AlmaLinux 7/8)

```bash
# 开放端口
sudo firewall-cmd --add-port=6000/tcp --permanent
sudo firewall-cmd --add-port=631/tcp --permanent
sudo firewall-cmd --reload

# 验证
firewall-cmd --list-ports
```

### SELinux

```bash
# 检查 SELinux 状态
getenforce

# 如果为 Enforcing，添加规则
sudo setsebool -P httpd_can_network_connect 1
sudo semanage port -a -t http_port_t -p tcp 3000 2>/dev/null || true
```

---

## 🛠️ 容器管理命令

```bash
# 查看状态
docker ps | grep printer-monitor

# 查看日志
docker logs printer-monitor
docker logs -f printer-monitor  # 实时日志
docker logs --tail 100 printer-monitor  # 最后 100 行

# 重启容器
docker restart printer-monitor

# 停止容器
docker stop printer-monitor

# 启动容器
docker start printer-monitor

# 进入容器
docker exec -it printer-monitor /bin/bash

# 查看资源使用
docker stats printer-monitor

# 删除容器（保留数据卷）
docker stop printer-monitor
docker rm printer-monitor

# 完全删除（包括数据卷）
docker stop printer-monitor
docker rm printer-monitor
docker volume rm printer-data printer-config
```

---

## 📊 使用 systemd 管理容器

创建 `/etc/systemd/system/printer-monitor.service`：

```ini
[Unit]
Description=Printer Monitor Docker Container
After=network-online.target docker.service
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=-/usr/bin/docker stop printer-monitor
ExecStartPre=-/usr/bin/docker rm printer-monitor
ExecStart=/usr/bin/docker run -d \
  --name printer-monitor \
  --privileged \
  --restart unless-stopped \
  -p 3000:6000 \
  -p 631:631 \
  -v printer-data:/var/log/cups \
  -v printer-config:/etc/cups \
  -e TZ=Asia/Shanghai \
  printer-monitor:centos
ExecStop=/usr/bin/docker stop printer-monitor
ExecReload=/usr/bin/docker restart printer-monitor

[Install]
WantedBy=multi-user.target
```

使用：
```bash
# 重新加载 systemd
sudo systemctl daemon-reload

# 启用服务
sudo systemctl enable printer-monitor

# 启动服务
sudo systemctl start printer-monitor

# 查看状态
sudo systemctl status printer-monitor

# 查看日志
sudo journalctl -u printer-monitor -f
```

---

## 🔄 更新部署

```bash
# 进入项目目录
cd /opt/printer-monitor

# 拉取最新代码
git pull origin main

# 重新构建并启动
docker compose -f docker-compose.centos.yml up -d --build

# 或使用 Docker 命令
docker stop printer-monitor
docker rm printer-monitor
docker build -f Dockerfile.centos -t printer-monitor:centos .
docker run -d --name printer-monitor --privileged --restart unless-stopped \
  -p 3000:6000 -p 631:631 \
  -v printer-data:/var/log/cups -v printer-config:/etc/cups \
  -e TZ=Asia/Shanghai printer-monitor:centos
```

---

## 🐛 故障排查

### 容器无法启动

```bash
# 查看详细日志
docker logs printer-monitor

# 检查端口占用
ss -tlnp | grep -E '3000|631'

# 检查 Docker 状态
systemctl status docker
```

### CUPS 服务异常

```bash
# 进入容器
docker exec -it printer-monitor /bin/bash

# 检查 CUPS 状态
ps aux | grep cupsd
curl http://localhost:631

# 重启 CUPS
pkill cupsd
cupsd

# 查看 CUPS 日志
tail -f /var/log/cups/error_log
```

### 网络连接问题

```bash
# 测试容器网络
docker exec printer-monitor ping -c 3 google.com

# 检查防火墙
firewall-cmd --list-all

# 临时关闭防火墙测试
systemctl stop firewalld
```

### 权限问题

```bash
# 检查 SELinux
getenforce
setenforce 0  # 临时禁用测试

# 检查目录权限
docker exec printer-monitor ls -la /var/log/cups
docker exec printer-monitor ls -la /etc/cups
```

---

## 📝 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PORT` | 3000 | Web 服务端口 |
| `TZ` | Asia/Shanghai | 时区 |

---

## 📦 数据持久化

以下数据通过 Docker 卷持久化：

| 卷名 | 容器路径 | 说明 |
|------|----------|------|
| `printer-data` | `/var/log/cups` | CUPS 日志 |
| `printer-config` | `/etc/cups` | CUPS 配置 |

查看卷：
```bash
docker volume ls | grep printer
docker volume inspect printer-data
```

---

## ✅ 部署检查清单

- [ ] Docker 已安装并运行
- [ ] 防火墙端口已开放 (3000, 631)
- [ ] SELinux 已配置（如启用）
- [ ] 容器运行正常
- [ ] Web 界面可访问
- [ ] CUPS 服务正常
- [ ] 打印机已配置

---

**技术支持**: 如有问题请查看日志或提交 GitHub Issue
