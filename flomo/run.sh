#!/usr/bin/env bash
# ============================================================
# flomo 风格前端项目 —— 一键构建/预览脚本（Git Bash 用）
# 用法:
#   bash run.sh install   # 安装依赖（首次运行）
#   bash run.sh build     # 生产构建，输出到 dist/
#   bash run.sh dev       # 启动开发服务器（默认 3000 端口）
#   bash run.sh dev 3100  # 指定端口启动
# ============================================================
set -e

# Kimi 自带的 Node.js 运行目录（本机实测路径）
NODE_DIR="/c/Users/huawei/AppData/Local/Programs/kimi-desktop/resources/resources/runtime/node"

# Git Bash 里 npm 是 npm.cmd，需要包装成 shell 脚本才能直接调用
mkdir -p /tmp/nodebin
cat > /tmp/nodebin/npm <<'EOF'
#!/usr/bin/env bash
exec cmd //c "$(dirname "$(which node)")\\npm.cmd" "$@"
EOF
cat > /tmp/nodebin/npx <<'EOF'
#!/usr/bin/env bash
exec cmd //c "$(dirname "$(which node)")\\npx.cmd" "$@"
EOF
chmod +x /tmp/nodebin/npm /tmp/nodebin/npx

export PATH="/tmp/nodebin:$NODE_DIR:$PATH"

cd "$(dirname "$0")"

case "${1:-build}" in
  install)
    npm install --no-audit --no-fund
    ;;
  build)
    npm run build
    ;;
  dev)
    PORT="${2:-3000}"
    npm run dev -- --port "$PORT"
    ;;
  *)
    echo "未知命令: $1（可用: install / build / dev [端口]）"
    exit 1
    ;;
esac
