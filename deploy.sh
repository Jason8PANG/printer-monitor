#!/bin/bash

set -e

echo "🖨️  打印机监控面板 - 快速部署脚本"
echo "=================================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查 Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose 未安装"
    exit 1
fi

echo "✅ Docker 环境检测通过"

# 构建
echo ""
echo "🔨 构建镜像..."
$COMPOSE_CMD build

# 启动
echo ""
echo "🚀 启动服务..."
$COMPOSE_CMD up -d

# 等待服务就绪
echo ""
echo "⏳ 等待服务启动..."
sleep 5

# 检查状态
echo ""
echo "📊 服务状态:"
$COMPOSE_CMD ps

echo ""
echo "✅ 部署完成!"
echo ""
echo "🌐 访问地址:"
echo "   监控面板：http://localhost:3000"
echo "   CUPS 管理：http://localhost:631"
echo ""
echo "📋 常用命令:"
echo "   查看日志：$COMPOSE_CMD logs -f"
echo "   停止服务：$COMPOSE_CMD down"
echo "   重启服务：$COMPOSE_CMD restart"
echo ""
