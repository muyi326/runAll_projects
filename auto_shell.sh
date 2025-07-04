#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# 项目一键启动脚本 (交互优化版)
# 版本：2.2.3

set -o errexit
set -o pipefail

# ==================== 配置区 ====================
VERSION="2.2.3"
LOG_DIR="${HOME}/.runall_logs"

# 项目配置
PROJECT_NAMES=("rl-swarm" "wai-run" "nexus-node")
PROJECT_CMDS=(
  "bash <(curl -fsSL https://gist.githubusercontent.com/muyi326/fa9f15d54e315cf64dc48b8e802b184c/raw/e66cbccc57338a185b4c5960dac99ad0df5b88c9/auto_n.sh)"
  "wai run"
   "bash <(curl -fsSL https://gist.githubusercontent.com/muyi326/197b7ac663e588433e6446a7055cb7b9/raw/53ef6da8d74b6224e308b856528ebacf0186f821/auto_exus.sh)"
)

# ==================== 主逻辑 ====================
main() {
  init_system
  show_banner
  run_projects
  show_success
}

# ==================== 初始化模块 ====================
init_system() {
  setup_directories
  force_clean_environment
  setup_logging
  check_dependencies
}

setup_directories() {
  mkdir -p "${LOG_DIR}"
}

force_clean_environment() {
  log "🔧 初始化系统环境..."
  close_all_terminals
  pkill -f "Terminal" || true
}

close_all_terminals() {
  log "🔄 关闭所有终端窗口..."
  osascript <<'EOF'
    tell application "Terminal"
      activate
      close every window saving no
      delay 1
      if (count of windows) is 0 then
        do script ""
        close front window saving no
      end if
    end tell
EOF
  sleep 5
}

# ==================== 项目运行模块 ====================
run_projects() {
  log "🚀 开始启动项目集群..."
  
  # 首先启动Docker
  start_docker
  
  # 等待Docker完全启动
  wait_for_docker
  
  # 然后启动依赖Docker的项目(rl-swarm)
  launch_project "rl-swarm" "${PROJECT_CMDS[0]}"
  sleep 1
  
  # 启动其他普通项目
  for ((i=1; i<${#PROJECT_NAMES[@]}; i++)); do
    if [[ "${PROJECT_NAMES[i]}" != "nexus-node" ]]; then
      launch_project "${PROJECT_NAMES[i]}" "${PROJECT_CMDS[i]}"
      sleep 1
    fi
  done

  # 特殊处理nexus-node
  launch_nexus_node

  # 最后进行窗口布局
  arrange_windows
}

launch_project() {
  local title=$1 cmd=$2
  osascript <<EOF
    tell application "Terminal"
      activate
      do script "${cmd}"
      set currentWindow to front window
      set currentTab to first tab of currentWindow
      set custom title of currentTab to "${title}"
    end tell
EOF
}

launch_nexus_node() {
    log "🚀 启动Nexus节点(终极可靠版)..."

    # 配置参数
    local SCRIPT_URL="https://gist.githubusercontent.com/muyi326/34985781263b4ae39567041d69fa25b5/raw/37e8b5337664c65baa53b9a50cf8363330f8bf77/auto_nexus.sh"
    local SCRIPT_PATH="${LOG_DIR}/nexus_node_install.sh"
    local TITLE="nexus-node"

    # 下载脚本
    for ((retry=1; retry<=3; retry++)); do
        if curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH" && [[ -s "$SCRIPT_PATH" ]]; then
            chmod +x "$SCRIPT_PATH"
            break
        elif (( retry == 3 )); then
            die "下载脚本失败"
        fi
        sleep 2
    done

    # 创建专用应答脚本
    local RESPONDER="${LOG_DIR}/nexus_responder.exp"
    cat > "$RESPONDER" <<'EOF'
#!/usr/bin/expect -f
set timeout 60
spawn bash [lindex $argv 0]
expect {
    "请输入您的选择*" { 
        send "2\r"
        exp_continue 
    }
    "*是否使用当前*" { 
        send "y\r" 
    }
    timeout {
        send_user "\n错误：等待超时\n"
        exit 1
    }
}
expect eof
EOF
    chmod +x "$RESPONDER"

    # 在新终端中启动
    osascript <<EOF
tell application "Terminal"
    activate
    do script "expect -f \\"$RESPONDER\\" \\"$SCRIPT_PATH\\""
    set currentWindow to front window
    set currentTab to first tab of currentWindow
    set custom title of currentTab to "$TITLE"
end tell
EOF

    log "✅ Nexus节点已在独立终端中启动"
}

wait_for_docker() {
  log "⏳ 等待Docker完全启动..."
  local retry=0
  while ! docker info &>/dev/null && (( retry++ < 30 )); do
    sleep 2
    log "⏳ Docker启动中...尝试 ${retry}/30"
  done
  if (( retry >= 30 )); then
    die "Docker启动超时，请检查Docker服务"
  fi
  log "✅ Docker已完全启动"
}

# ==================== 窗口管理模块 ====================
arrange_windows() {
  log "🖥️ 开始智能窗口布局..."
  
  local geometry=($(get_screen_geometry))
  local width=${geometry[2]} height=${geometry[3]}

  set_window_geometry "rl-swarm" 0 0 $((width/2)) $((height/2))
  set_window_geometry "docker" $((width/2)) 0 ${width} $((height/2))
  set_window_geometry "wai-run" 0 $((height/2)) $((width/3)) ${height}
  set_window_geometry "nexus-node" $((width/3)) $((height/2)) $((width*2/3)) ${height}
 
}

get_screen_geometry() {
  osascript -e 'tell application "Finder" to get bounds of window of desktop' | tr ',' ' '
}

set_window_geometry() {
  local title=$1 x=$2 y=$3 w=$4 h=$5
  osascript <<EOF
    tell application "Terminal"
      set targetWindows to (every window whose name contains "${title}")
      if (count of targetWindows) > 0 then
        set bounds of (item 1 of targetWindows) to {${x}, ${y}, ${w}, ${h}}
      end if
    end tell
EOF
}

# ==================== 系统服务模块 ====================
start_docker() {
  if ! docker info &>/dev/null; then
    log "🐳 启动Docker服务..."
    open -a Docker --background
  fi
}

check_dependencies() {
  local required=("docker" "osascript" "curl")
  for cmd in "${required[@]}"; do
    if ! command -v "${cmd}" >/dev/null; then
      die "缺少依赖: ${cmd}"
    fi
  done
}

# ==================== 日志模块 ====================
setup_logging() {
  exec > >(tee -a "${LOG_DIR}/runall_$(date +%Y%m%d).log") 2>&1
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
  log "❌ 严重错误: $*"
  exit 1
}

# ==================== UI模块 ====================
show_banner() {
  clear
  cat <<'EOF'

  ███╗   ███╗██╗   ██╗██╗   ██╗██╗
  ████╗ ████║██║   ██║╚██╗ ██╔╝██║
  ██╔████╔██║██║   ██║ ╚████╔╝ ██║
  ██║╚██╔╝██║██║   ██║  ╚██╔╝  ██║
  ██║ ╚═╝ ██║╚██████╔╝   ██║   ██║
  ╚═╝     ╚═╝ ╚═════╝    ╚═╝   ╚═╝
EOF
  echo "                          v${VERSION}"
}

show_success() {
  log "✅ 所有项目已启动完成！"
  log "💡 提示：可以按Command+Tab键查看窗口布局"
}

# ==================== 执行入口 ====================
main "$@"
