#!/bin/bash

set -e

# ============================================
# 服务器初始化脚本 - 打印机监控依赖安装
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
echo "  🖨️  打印机监控 - 服务器初始化"
echo "=========================================="
echo ""

# 检测系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    log_error "无法检测操作系统类型"
    exit 1
fi

log_info "检测到操作系统：$OS"

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                nodejs \
                npm \
                cups \
                cups-client \
                cups-daemon \
                dbus \
                curl \
                git
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y epel-release || true
            dnf install -y \
                nodejs \
                npm \
                cups \
                cups-client \
                dbus \
                curl \
                git || true
            ;;
        alpine)
            apk add --no-cache \
                nodejs \
                npm \
                cups \
                cups-client \
                dbus \
                curl \
                git
            ;;
        *)
            log_warn "未知系统类型，尝试通用安装..."
            ;;
    esac
    
    log_success "系统依赖安装完成"
}

# 配置 CUPS
configure_cups() {
    log_info "配置 CUPS 服务..."
    
    # 启动 CUPS
    systemctl enable cups
    systemctl start cups
    
    # 配置 CUPS 允许远程连接（可选）
    if [ -f /etc/cups/cupsd.conf ]; then
        cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.backup
        
        # 添加监听地址
        if ! grep -q "Listen 0.0.0.0:631" /etc/cups/cupsd.conf; then
            echo "Listen 0.0.0.0:631" >> /etc/cups/cupsd.conf
        fi
        
        # 重启 CUPS
        systemctl restart cups
    fi
    
    log_success "CUPS 配置完成"
}

# 安装 Node.js (如果版本过低)
install_nodejs() {
    NODE_VERSION=$(node -v 2>/dev/null || echo "none")
    
    if [ "$NODE_VERSION" == "none" ]; then
        log_info "安装 Node.js..."
        
        case $OS in
            ubuntu|debian)
                curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
                apt-get install -y nodejs
                ;;
            centos|rhel|fedora|rocky|almalinux)
                curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
                dnf install -y nodejs || yum install -y nodejs
                ;;
            *)
                log_warn "请手动安装 Node.js 18+"
                ;;
        esac
    else
        log_info "Node.js 已安装：$NODE_VERSION"
    fi
    
    log_success "Node.js 就绪"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # firewall-cmd (CentOS/RHEL/Fedora)
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --add-port=3000/tcp --permanent || true
        firewall-cmd --add-port=631/tcp --permanent || true
        firewall-cmd --reload || true
        log_info "firewalld: 端口 3000, 631 已开放"
    fi
    
    # ufw (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow 3000/tcp || true
        ufw allow 631/tcp || true
        log_info "ufw: 端口 3000, 631 已开放"
    fi
    
    # iptables (通用)
    if command -v iptables &> /dev/null; then
        iptables -A INPUT -p tcp --dport 3000 -j ACCEPT 2>/dev/null || true
        iptables -A INPUT -p tcp --dport 631 -j ACCEPT 2>/dev/null || true
        log_info "iptables: 端口 3000, 631 已添加规则"
    fi
    
    log_success "防火墙配置完成"
}

# 创建部署目录
create_deploy_dir() {
    log_info "创建部署目录..."
    mkdir -p /opt/printer-monitor
    chown root:root /opt/printer-monitor
    chmod 755 /opt/printer-monitor
    log_success "部署目录就绪：/opt/printer-monitor"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    echo ""
    echo "检查项目:"
    
    # Node.js
    if command -v node &> /dev/null; then
        echo "  ✅ Node.js: $(node -v)"
    else
        echo "  ❌ Node.js: 未安装"
    fi
    
    # npm
    if command -v npm &> /dev/null; then
        echo "  ✅ npm: $(npm -v)"
    else
        echo "  ❌ npm: 未安装"
    fi
    
    # CUPS
    if systemctl is-active --quiet cups; then
        echo "  ✅ CUPS: 运行中"
    else
        echo "  ⚠️  CUPS: 未运行 (尝试启动...)"
        systemctl start cups || true
    fi
    
    # 端口
    if command -v ss &> /dev/null; then
        CUPS_PORT=$(ss -tlnp | grep ':631' | wc -l)
        if [ "$CUPS_PORT" -gt 0 ]; then
            echo "  ✅ CUPS 端口 631: 监听中"
        else
            echo "  ⚠️  CUPS 端口 631: 未监听"
        fi
    fi
    
    echo ""
}

# 主流程
install_dependencies
install_nodejs
configure_cups
configure_firewall
create_deploy_dir
verify_installation

echo ""
echo "=========================================="
echo "  ✅ 服务器初始化完成!"
echo "=========================================="
echo ""
echo "下一步:"
echo "  1. 运行部署脚本:"
echo "     ./deploy-to-server.sh --host suzweb02"
echo ""
echo "  2. 或直接复制文件后手动启动:"
echo "     cd /opt/printer-monitor"
echo "     npm install"
echo "     npm start"
echo ""
echo "  3. 访问 Web 界面:"
echo "     http://suzweb02:3000"
echo ""
