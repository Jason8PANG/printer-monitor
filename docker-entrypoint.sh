#!/bin/sh
set -e

echo "🖨️  启动打印机监控服务..."

# 启动 D-Bus (CUPS 需要)
if [ ! -S /var/run/dbus/system_bus_socket ]; then
  mkdir -p /var/run/dbus
  dbus-daemon --system --fork || true
  sleep 1
fi

# 启动 CUPS 服务
if ! pgrep cupsd > /dev/null; then
  echo "📋 启动 CUPS 服务..."
  cupsd || true
  sleep 2
fi

# 检查 CUPS 配置
if [ ! -f /etc/cups/cupsd.conf ]; then
  echo "⚙️  创建默认 CUPS 配置..."
  mkdir -p /etc/cups
  cat > /etc/cups/cupsd.conf << 'EOF'
# CUPS 配置 - Docker 环境
Listen 631
Listen localhost:631
ServerAdmin root
ServerRoot /etc/cups

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

# 临时文件
TempDirectory /tmp
EOF
fi

# 确保日志目录存在
mkdir -p /var/log/cups
touch /var/log/cups/access_log /var/log/cups/error_log

# 设置权限
chmod 644 /etc/cups/cupsd.conf 2>/dev/null || true

echo "✅ 初始化完成"
echo "🌐 Web 界面：http://localhost:3000"
echo "📋 CUPS Web: http://localhost:631"

exec "$@"
