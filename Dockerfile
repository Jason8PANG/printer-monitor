FROM node:20-alpine

# 安装 CUPS 和必要的系统工具
RUN apk add --no-cache \
    cups \
    cups-client \
    cups-libs \
    dbus \
    ping \
    && rm -rf /var/cache/apk/*

# 创建工作目录
WORKDIR /app

# 复制 package.json
COPY package.json ./

# 安装依赖
RUN npm install --production

# 复制应用代码
COPY server.js ./
COPY public/ ./public/

# 创建 cups 配置目录
RUN mkdir -p /var/run/cups /var/log/cups /etc/cups

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# 启动脚本
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["node", "server.js"]
