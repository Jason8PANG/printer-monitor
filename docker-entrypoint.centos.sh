#!/bin/bash
set -e

echo "=========================================="
echo "  🖨️  打印机监控服务 (CentOS 版)"
echo "=========================================="
echo ""

# 时区设置
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime 2>/dev/null || true
echo $TZ > /etc/timezone 2>/dev/null || true

# 启动 D-Bus (CUPS 需要)
echo "📋 启动 D-Bus..."
if [ ! -S /var/run/dbus/system_bus_socket ]; then
    mkdir -p /var/run/dbus
    chmod 755 /var/run/dbus
    dbus-daemon --system --fork 2>/dev/null || true
    sleep 2
fi
echo "✅ D-Bus 已启动"

# 启动 CUPS 服务
echo "📋 启动 CUPS 服务..."
if ! pgrep cupsd > /dev/null 2>&1; then
    # 创建 CUPS 配置
    if [ ! -f /etc/cups/cupsd.conf ]; then
        echo "⚙️  创建 CUPS 配置..."
        cat > /etc/cups/cupsd.conf << 'EOF'
# CUPS 配置 - CentOS Docker 环境
Listen 631
Listen localhost:631
ServerAdmin root
ServerRoot /etc/cups
TempDirectory /tmp

# 访问控制
<Location />
  Order allow,deny
  Allow all
</Location>

<Location /admin>
  Order allow,deny
  Allow all
</Location>

<Location /admin/conf>
  Order allow,deny
  Allow all
</Location>

# 日志
AccessLog /var/log/cups/access_log
ErrorLog /var/log/cups/error_log
LogLevel warn

# 安全设置
MaxLogSize 0
EOF
    fi
    
    # 启动 cupsd
    cupsd 2>/dev/null || true
    sleep 2
fi

# 验证 CUPS 是否运行
if pgrep cupsd > /dev/null 2>&1; then
    echo "✅ CUPS 服务已启动 (端口 631)"
else
    echo "⚠️  CUPS 服务启动失败，继续运行应用..."
fi

# 确保日志目录存在
mkdir -p /var/log/cups
touch /var/log/cups/access_log /var/log/cups/error_log 2>/dev/null || true

# 设置权限
chmod 644 /etc/cups/cupsd.conf 2>/dev/null || true
chmod 755 /var/log/cups 2>/dev/null || true

echo ""
echo "=========================================="
echo "  ✅ 初始化完成"
echo "=========================================="
echo ""
echo "🌐 监控面板：http://localhost:${PORT:-6000}"
echo "📋 CUPS 管理：http://localhost:631"
echo ""
echo "📝 日志目录：/var/log/cups"
echo "⚙️  配置目录：/etc/cups"
echo ""

# 执行主命令
exec "$@"
