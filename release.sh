#!/bin/bash

set -e

# ============================================
# 自动发布脚本
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
echo "  🚀 Printer Monitor - 自动发布工具"
echo "=========================================="
echo ""

# 检查参数
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "用法：$0 <版本号> [选项]"
    echo ""
    echo "版本号格式：v1.0.0 (遵循 SemVer)"
    echo ""
    echo "选项:"
    echo "  --dry-run    预演，不实际推送"
    echo "  --skip-test  跳过测试"
    echo ""
    echo "示例:"
    echo "  $0 v1.0.0           # 发布 v1.0.0"
    echo "  $0 v1.0.0 --dry-run # 预演发布"
    echo "  $0 v1.0.1           # 发布补丁版本"
    echo ""
    exit 0
fi

# 检查版本号
VERSION=$1
if [ -z "$VERSION" ]; then
    log_error "请提供版本号"
    echo "示例：$0 v1.0.0"
    exit 1
fi

# 验证版本号格式
if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "版本号格式错误，应该是 v1.0.0 格式"
    exit 1
fi

DRY_RUN=false
SKIP_TEST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-test)
            SKIP_TEST=true
            shift
            ;;
        *)
            log_error "未知参数：$1"
            exit 1
            ;;
    esac
done

# 检查 Git 状态
log_info "检查 Git 状态..."
if [ -n "$(git status --porcelain)" ]; then
    log_warn "有未提交的更改"
    git status --short
    read -p "是否继续？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "取消发布"
        exit 0
    fi
fi

# 检查是否在 main 分支
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
    log_warn "当前不在 main 分支，当前分支：$BRANCH"
    read -p "是否切换到 main 分支？(y/N): " confirm
    if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
        git checkout main
        git pull origin main
    else
        log_info "取消发布"
        exit 0
    fi
fi

# 更新版本号
log_info "更新版本号到 $VERSION..."

# 更新 package.json
if [ -f package.json ]; then
    node -e "
    const pkg = require('./package.json');
    pkg.version = '$VERSION';
    console.log(JSON.stringify(pkg, null, 2));
    " > package.json.tmp && mv package.json.tmp package.json
    log_success "package.json 已更新"
fi

# 提交更改
log_info "提交版本更改..."
git add package.json
git commit -m "chore: release version $VERSION" || echo "No changes to commit"

# 打标签
log_info "创建 Git 标签 $VERSION..."
if [ "$DRY_RUN" == "true" ]; then
    log_warn "[预演] git tag -a $VERSION -m \"Release $VERSION\""
else
    git tag -a $VERSION -m "Release $VERSION"
fi

# 推送
log_info "推送到 GitHub..."
if [ "$DRY_RUN" == "true" ]; then
    log_warn "[预演] git push origin main"
    log_warn "[预演] git push origin $VERSION"
    echo ""
    log_success "预演完成！实际发布请去掉 --dry-run 参数"
else
    git push origin main
    git push origin $VERSION
    echo ""
    log_success "发布成功！"
    echo ""
    echo "=========================================="
    echo "  ✅ 版本 $VERSION 已发布"
    echo "=========================================="
    echo ""
    echo "📦 GitHub Actions 将自动:"
    echo "  1. 构建 Docker 镜像 (Alpine & AlmaLinux)"
    echo "  2. 推送到 Docker Hub"
    echo "  3. 创建 GitHub Release"
    echo ""
    echo "🔗 查看进度:"
    echo "   https://github.com/Jason8PANG/printer-monitor/actions"
    echo ""
    echo "📦 Docker 镜像:"
    echo "   docker pull jason8pang/printer-monitor:$VERSION"
    echo "   docker pull jason8pang/printer-monitor-almalinux:$VERSION"
    echo ""
fi
