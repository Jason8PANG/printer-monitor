#!/bin/bash
set -e

# ============================================
# AlmaLinux Docker 一键部署脚本
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=========================================="
echo "  🖨️  打印机监控 - CentOS Docker 部署"
echo "=========================================="
echo ""

# 检查是否 root
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 root 用户运行此脚本"
    echo "  sudo $0"
    exit 1
fi

# 检查 Docker
install_docker() {
    log_info "Docker 未安装，开始安装..."
    
    # 卸载旧版本
    yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    
    # 安装 yum 工具
    yum install -y yum-utils
    
    # 添加 Docker 仓库
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || {
        # 如果官方源失败，使用阿里云镜像
        yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    }
    
    # 安装 Docker
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 启动 Docker
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker 安装完成"
}

if ! command -v docker &> /dev/null; then
    install_docker
else
    log_success "Docker 已安装：$(docker --version)"
fi

# 创建部署目录
DEPLOY_DIR="/opt/printer-monitor"
log_info "创建部署目录：$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# 下载必要文件
download_files() {
    log_info "下载项目文件..."
    
    files=(
        "docker-compose.centos.yml"
        "Dockerfile.centos"
        "docker-entrypoint.centos.sh"
    )
    
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            log_info "下载 $file..."
            curl -sSL "https://raw.githubusercontent.com/Jason8PANG/printer-monitor/main/$file" -o "$file"
        else
            log_info "$file 已存在，跳过"
        fi
    done
    
    chmod +x docker-entrypoint.centos.sh
}

# 检查是否从 GitHub 克隆
if [ -f "docker-compose.centos.yml" ]; then
    log_info "使用本地项目文件"
else
    download_files
fi

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --add-port=6000/tcp --permanent 2>/dev/null || true
        firewall-cmd --add-port=631/tcp --permanent 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        log_success "firewalld: 端口 6000, 631 已开放"
    fi
    
    # SELinux
    if command -v getenforce &> /dev/null; then
        SELINUX=$(getenforce 2>/dev/null || echo "Unknown")
        if [ "$SELINUX" == "Enforcing" ]; then
            log_warn "SELinux 处于 Enforcing 模式，可能需要调整策略"
            setsebool -P httpd_can_network_connect 1 2>/dev/null || true
        fi
    fi
}

configure_firewall

# 构建镜像
log_info "构建 Docker 镜像..."
docker build -f Dockerfile.centos -t printer-monitor:centos .

# 停止旧容器
log_info "清理旧容器..."
docker stop printer-monitor 2>/dev/null || true
docker rm printer-monitor 2>/dev/null || true

# 启动容器
log_info "启动容器..."
docker run -d \
  --name printer-monitor \
  --privileged \
  --restart unless-stopped \
  -p 6000:6000 \
  -p 631:631 \
  -v printer-data:/var/log/cups \
  -v printer-config:/etc/cups \
  -e TZ=Asia/Shanghai \
  -e PORT=6000 \
  printer-monitor:centos

# 等待启动
log_info "等待服务启动..."
sleep 5

# 验证
if docker ps | grep -q printer-monitor; then
    # 获取服务器 IP
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo ""
    echo "=========================================="
    log_success "部署成功!"
    echo "=========================================="
    echo ""
    echo "🌐 访问地址:"
    echo "   监控面板：http://${SERVER_IP}:6000"
    echo "   CUPS 管理：http://${SERVER_IP}:631"
    echo ""
    echo "📋 容器信息:"
    docker ps | grep printer-monitor
    echo ""
    echo "📝 常用命令:"
    echo "   查看状态：docker ps | grep printer-monitor"
    echo "   查看日志：docker logs printer-monitor"
    echo "   实时日志：docker logs -f printer-monitor"
    echo "   重启服务：docker restart printer-monitor"
    echo "   停止服务：docker stop printer-monitor"
    echo "   进入容器：docker exec -it printer-monitor /bin/bash"
    echo ""
    echo "📁 部署目录：$DEPLOY_DIR"
    echo "💾 数据卷：printer-data, printer-config"
    echo ""
else
    log_error "容器启动失败!"
    echo ""
    echo "查看日志："
    docker logs printer-monitor
    exit 1
fi
