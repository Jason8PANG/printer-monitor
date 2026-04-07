#!/bin/bash

set -e

# ============================================
# 打印机监控 - 服务器自动部署脚本
# ============================================

# 配置
SERVER_HOST="${SERVER_HOST:-suzweb02}"
SERVER_USER="${SERVER_USER:-root}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/printer-monitor}"
PROJECT_NAME="printer-monitor"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查参数
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "用法：$0 [选项]"
    echo ""
    echo "选项:"
    echo "  --host HOST      服务器主机名或 IP (默认：suzweb02)"
    echo "  --user USER      SSH 用户名 (默认：root)"
    echo "  --dir DIR        部署目录 (默认：/opt/printer-monitor)"
    echo "  --rollback       回滚到上一个版本"
    echo "  --status         查看部署状态"
    echo "  --logs           查看服务日志"
    echo "  --restart        重启服务"
    echo "  --stop           停止服务"
    echo "  --uninstall      卸载服务"
    echo ""
    echo "环境变量:"
    echo "  SERVER_HOST      服务器主机名"
    echo "  SERVER_USER      SSH 用户名"
    echo "  DEPLOY_DIR       部署目录"
    echo ""
    echo "示例:"
    echo "  $0                          # 使用默认配置部署"
    echo "  $0 --host 192.168.1.100    # 部署到指定 IP"
    echo "  $0 --user admin            # 使用指定用户"
    echo "  $0 --status                # 查看状态"
    exit 0
fi

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            SERVER_HOST="$2"
            shift 2
            ;;
        --user)
            SERVER_USER="$2"
            shift 2
            ;;
        --dir)
            DEPLOY_DIR="$2"
            shift 2
            ;;
        --rollback)
            ACTION="rollback"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        --logs)
            ACTION="logs"
            shift
            ;;
        --restart)
            ACTION="restart"
            shift
            ;;
        --stop)
            ACTION="stop"
            shift
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        *)
            log_error "未知参数：$1"
            exit 1
            ;;
    esac
done

# SSH 命令封装
ssh_cmd() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${SERVER_USER}@${SERVER_HOST}" "$@"
}

scp_cmd() {
    scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@"
}

# 测试连接
test_connection() {
    log_info "测试连接到 ${SERVER_USER}@${SERVER_HOST}..."
    if ! ssh_cmd "echo '连接成功'" > /dev/null 2>&1; then
        log_error "无法连接到服务器，请检查:"
        echo "  1. 服务器主机名/IP 是否正确"
        echo "  2. SSH 服务是否运行"
        echo "  3. SSH key 是否已配置"
        echo ""
        echo "配置 SSH key:"
        echo "  ssh-copy-id ${SERVER_USER}@${SERVER_HOST}"
        exit 1
    fi
    log_success "服务器连接成功"
}

# 部署操作
do_deploy() {
    log_info "开始部署到 ${SERVER_HOST}..."
    log_info "部署目录：${DEPLOY_DIR}"
    
    # 1. 创建部署目录
    log_info "创建部署目录..."
    ssh_cmd "mkdir -p ${DEPLOY_DIR}"
    
    # 2. 备份当前版本（如果存在）
    if ssh_cmd "[ -d ${DEPLOY_DIR}/current ]" 2>/dev/null; then
        log_info "备份当前版本..."
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        ssh_cmd "cp -r ${DEPLOY_DIR}/current ${DEPLOY_DIR}/backup_${TIMESTAMP}"
        ssh_cmd "rm -rf ${DEPLOY_DIR}/previous && mv ${DEPLOY_DIR}/current ${DEPLOY_DIR}/previous" || true
    fi
    
    # 3. 上传文件
    log_info "上传项目文件..."
    scp_cmd -r \
        server.js \
        package.json \
        Dockerfile \
        docker-compose.yml \
        docker-entrypoint.sh \
        deploy.sh \
        README.md \
        .dockerignore \
        public/ \
        "${SERVER_USER}@${SERVER_HOST}:${DEPLOY_DIR}/current"
    
    # 4. 创建 systemd 服务文件
    log_info "配置 systemd 服务..."
    ssh_cmd "cat > /etc/systemd/system/${PROJECT_NAME}.service << 'EOF'
[Unit]
Description=Printer Monitor Service
After=network.target cups.service
Requires=cups.service

[Service]
Type=simple
User=root
WorkingDirectory=${DEPLOY_DIR}/current
Environment=PORT=3000
Environment=TZ=Asia/Shanghai
ExecStart=/usr/bin/node ${DEPLOY_DIR}/current/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${PROJECT_NAME}

# 安全设置
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
"
    
    # 5. 重新加载 systemd 并启动服务
    log_info "启动服务..."
    ssh_cmd "systemctl daemon-reload"
    ssh_cmd "systemctl enable ${PROJECT_NAME}"
    ssh_cmd "systemctl restart ${PROJECT_NAME}"
    
    # 6. 配置防火墙（如果需要）
    log_info "配置防火墙..."
    ssh_cmd "firewall-cmd --add-port=3000/tcp --permanent 2>/dev/null || true"
    ssh_cmd "firewall-cmd --reload 2>/dev/null || true"
    ssh_cmd "ufw allow 3000/tcp 2>/dev/null || true"
    
    # 7. 等待服务启动
    log_info "等待服务启动..."
    sleep 3
    
    # 8. 检查服务状态
    if ssh_cmd "systemctl is-active --quiet ${PROJECT_NAME}"; then
        log_success "部署成功！"
        echo ""
        echo "=========================================="
        echo "  🎉 打印机监控服务已部署"
        echo "=========================================="
        echo ""
        echo "  服务状态：运行中 ✅"
        echo "  访问地址：http://${SERVER_HOST}:3000"
        echo "  部署目录：${DEPLOY_DIR}"
        echo ""
        echo "常用命令:"
        echo "  查看状态：$0 --status"
        echo "  查看日志：$0 --logs"
        echo "  重启服务：$0 --restart"
        echo "  回滚版本：$0 --rollback"
        echo ""
    else
        log_error "服务启动失败，查看日志："
        echo "  $0 --logs"
        exit 1
    fi
}

# 查看状态
do_status() {
    log_info "服务状态..."
    ssh_cmd "systemctl status ${PROJECT_NAME} --no-pager"
}

# 查看日志
do_logs() {
    log_info "最近日志 (最后 50 行)..."
    ssh_cmd "journalctl -u ${PROJECT_NAME} --no-pager -n 50"
}

# 重启服务
do_restart() {
    log_info "重启服务..."
    ssh_cmd "systemctl restart ${PROJECT_NAME}"
    sleep 2
    if ssh_cmd "systemctl is-active --quiet ${PROJECT_NAME}"; then
        log_success "服务已重启"
    else
        log_error "重启失败"
        exit 1
    fi
}

# 停止服务
do_stop() {
    log_info "停止服务..."
    ssh_cmd "systemctl stop ${PROJECT_NAME}"
    log_success "服务已停止"
}

# 回滚
do_rollback() {
    log_info "回滚到上一个版本..."
    if ssh_cmd "[ -d ${DEPLOY_DIR}/previous ]" 2>/dev/null; then
        ssh_cmd "rm -rf ${DEPLOY_DIR}/current"
        ssh_cmd "cp -r ${DEPLOY_DIR}/previous ${DEPLOY_DIR}/current"
        ssh_cmd "systemctl restart ${PROJECT_NAME}"
        log_success "已回滚到上一个版本"
    else
        log_error "没有可回滚的版本"
        exit 1
    fi
}

# 卸载
do_uninstall() {
    log_warn "即将卸载服务..."
    read -p "确定要卸载吗？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "取消卸载"
        exit 0
    fi
    
    log_info "停止服务..."
    ssh_cmd "systemctl stop ${PROJECT_NAME}" || true
    ssh_cmd "systemctl disable ${PROJECT_NAME}" || true
    ssh_cmd "rm /etc/systemd/system/${PROJECT_NAME}.service" || true
    ssh_cmd "systemctl daemon-reload"
    
    log_info "删除部署目录..."
    ssh_cmd "rm -rf ${DEPLOY_DIR}"
    
    log_success "服务已卸载"
}

# 主流程
echo ""
echo "=========================================="
echo "  🖨️  打印机监控 - 自动部署工具"
echo "=========================================="
echo ""

test_connection

case ${ACTION:-deploy} in
    deploy)
        do_deploy
        ;;
    status)
        do_status
        ;;
    logs)
        do_logs
        ;;
    restart)
        do_restart
        ;;
    stop)
        do_stop
        ;;
    rollback)
        do_rollback
        ;;
    uninstall)
        do_uninstall
        ;;
    *)
        log_error "未知操作：${ACTION}"
        exit 1
        ;;
esac
