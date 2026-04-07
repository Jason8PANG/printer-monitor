# GitHub Actions 配置说明

## 📋 工作流文件

| 文件 | 触发条件 | 功能 |
|------|---------|------|
| `ci.yml` | Push 到 main / PR | 代码测试、构建镜像、部署开发环境 |
| `release.yml` | 创建 Tag | 构建生产镜像、发布 Docker Hub、创建 GitHub Release |

---

## 🔐 配置 Secrets

在 GitHub 仓库设置中添加以下 Secrets：

进入：https://github.com/Jason8PANG/printer-monitor/settings/secrets/actions

### Docker Hub (必需)

| Secret 名称 | 值 | 说明 |
|-----------|-----|------|
| `DOCKER_USERNAME` | `jason8pang` | Docker Hub 用户名 |
| `DOCKER_PASSWORD` | `<access token>` | Docker Hub 访问令牌 |

### 获取 Docker Hub Access Token

1. 登录 https://hub.docker.com
2. 进入 Account Settings → Security
3. 点击 "New Access Token"
4. 填写描述，选择读写权限
5. 复制生成的 token，添加到 Secrets

### 开发服务器部署 (可选)

| Secret 名称 | 值 | 说明 |
|-----------|-----|------|
| `DEV_SERVER_HOST` | `suzvweb02` | 开发服务器主机名 |
| `DEV_SERVER_USER` | `root` | SSH 用户名 |
| `SSH_PRIVATE_KEY` | `<private key>` | SSH 私钥 |

---

## 🚀 发布流程

### 1. 准备发布

```bash
# 确保在 main 分支
git checkout main
git pull origin main

# 运行测试
docker compose up -d --build
docker compose ps
```

### 2. 执行发布

```bash
# 使用发布脚本（推荐）
./release.sh v1.0.0

# 或手动创建标签
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### 3. 自动构建

推送标签后，GitHub Actions 会自动：

1. ✅ 构建 Alpine 镜像 → `jason8pang/printer-monitor:v1.0.0`
2. ✅ 构建 AlmaLinux 镜像 → `jason8pang/printer-monitor-almalinux:v1.0.0`
3. ✅ 推送到 Docker Hub
4. ✅ 创建 GitHub Release

### 4. 查看进度

https://github.com/Jason8PANG/printer-monitor/actions

---

## 📦 版本命名

遵循 [SemVer](https://semver.org/) 规范：

- `v1.0.0` - 主版本。重大变更，可能不向后兼容
- `v1.1.0` - 次版本。新功能，向后兼容
- `v1.0.1` - 补丁版本。Bug 修复，向后兼容

---

## 🔄 CI/CD 流程

### Push 到 main 分支

```
Push → CI 测试 → 构建镜像 → 部署开发服务器
```

### 创建 Release Tag

```
Tag → 构建生产镜像 → 推送 Docker Hub → 创建 Release
```

---

## 🛠️ 本地测试

### 测试 Docker 构建

```bash
# 测试 Alpine 镜像
docker build -t printer-monitor:test .

# 测试 AlmaLinux 镜像
docker build -f Dockerfile.centos -t printer-monitor-almalinux:test .

# 运行测试
docker run -d -p 6000:6000 --name test printer-monitor:test
curl http://localhost:6000
docker stop test && docker rm test
```

### 测试发布脚本

```bash
# 预演发布
./release.sh v1.0.0 --dry-run

# 跳过测试发布
./release.sh v1.0.0 --skip-test
```

---

## 📊 镜像标签

自动生成的标签：

- `v1.0.0` - 精确版本
- `v1.0` - 主版本。次版本
- `latest` - 最新版本

---

## 🔧 故障排查

### 构建失败

1. 检查 GitHub Actions 日志
2. 本地测试构建：`docker build -t test .`
3. 检查 Dockerfile 语法

### 推送失败

1. 检查 Docker Hub credentials
2. 验证用户名密码正确
3. 检查网络连接

### Release 未创建

1. 检查是否从 tag 触发
2. 查看 workflow 运行日志
3. 确认 GITHUB_TOKEN 权限

---

## 📝 示例

### 发布新版本

```bash
# 拉取最新代码
git pull origin main

# 运行测试
docker compose up -d --build
curl http://localhost:6000

# 发布
./release.sh v1.1.0

# 查看进度
open https://github.com/Jason8PANG/printer-monitor/actions
```

### 紧急修复

```bash
# 修复 bug 后
git add .
git commit -m "fix: critical bug fix"
git push origin main

# 发布补丁版本
./release.sh v1.0.1
```

---

## 🎯 最佳实践

1. **频繁发布** - 小步快跑，每次发布变化不要太大
2. **测试充分** - 发布前确保本地测试通过
3. **语义化版本** - 遵循 SemVer 规范
4. **更新文档** - 在 Release 中说明变更内容
5. **监控构建** - 及时查看 Actions 运行状态

---

**技术支持**: 如有问题请提交 Issue 或查看 GitHub Actions 文档
