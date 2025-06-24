#!/bin/bash

# 1. 关闭所有Terminal窗口
osascript -e 'tell application "Terminal" to quit'
sleep 1

# 2. 获取屏幕尺寸
read -r screen_width screen_height <<< $(osascript -e 'tell application "Finder" to get bounds of window of desktop' | awk '{print $3, $4}')

# 3. 计算各窗口位置和尺寸（精确到像素）
# 左上角(rl-swarm): 占左半屏的上半部分
rlswarm_width=$((screen_width/2))
rlswarm_height=$((screen_height/2))
rlswarm_pos="0, 0, $rlswarm_width, $rlswarm_height"

# 右上角(Docker): 占右半屏的上半部分 
docker_width=$((screen_width/2))
docker_height=$((screen_height/2))
docker_pos="$rlswarm_width, 0, $screen_width, $rlswarm_height"

# 左下角(wai run): 占左半屏的下半部分
wai_width=$((screen_width/3))
wai_height=$((screen_height/2))
wai_pos="0, $rlswarm_height, $wai_width, $screen_height"

# 下中间(Nexus): 在左下和右下之间
nexus_width=$((screen_width/3))
nexus_height=$((screen_height/2))
nexus_pos="$wai_width, $rlswarm_height, $((wai_width*2)), $screen_height"

# 右下角(quickq): 占右1/3的下半部分
quickq_width=$((screen_width/3))
quickq_height=$((screen_height/2))
quickq_pos="$((wai_width*2)), $rlswarm_height, $screen_width, $screen_height"

# 4. 启动各项目并精确定位

# rl-swarm (左上)
osascript <<EOF
tell application "Terminal"
    activate
    do script "cd ~/rl-swarm && source .venv/bin/activate && ./auto_run.sh"
    set bounds of front window to {$rlswarm_pos}
end tell
EOF

# Docker状态检查 (右上)
osascript <<EOF
tell application "Terminal"
    activate
    do script "echo 'Docker状态检查...' && docker ps"
    set bounds of front window to {$docker_pos}
end tell
EOF
if ! docker info &>/dev/null; then
    open -a Docker
    sleep 15
fi

# wai run (左下)
osascript <<EOF
tell application "Terminal"
    activate
    do script "wai run"
    set bounds of front window to {$wai_pos}
end tell
EOF

# Nexus节点 (下中)
osascript <<EOF
tell application "Terminal"
    activate
    do script "bash <(curl -fsSL https://gist.githubusercontent.com/readyName/4f8c8a5554852904d45bfcd2586fe9dd/raw/run_nexus_node.sh)"
    set bounds of front window to {$nexus_pos}
    delay 5
    tell application "System Events"
        keystroke "2"
        keystroke return
        delay 1
        keystroke "y"
        keystroke return
    end tell
end tell
EOF

# quickq_auto_run.sh (右下)
osascript <<EOF
tell application "Terminal"
    activate
    do script "~/rl-swarm/quickq_auto_run.sh"
    set bounds of front window to {$quickq_pos}
end tell
EOF

echo "所有项目已启动完成！窗口布局如下："
echo "┌───────────────┬───────────────┐"
echo "│   rl-swarm    │    Docker     │"
echo "├───────┬───────┼───────┬───────┤"
echo "│ wai   │ Nexus │       │QuickQ │"
echo "│ run   │ 节点  │       │       │"
echo "└───────┴───────┴───────┴───────┘"