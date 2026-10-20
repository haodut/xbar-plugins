#!/bin/bash

# ==========================================
# 1. 路径配置
# ==========================================
SDK_DIR="$HOME/Library/Android/sdk"
EMULATOR_CMD="$SDK_DIR/emulator/emulator"
ADB_CMD="$SDK_DIR/platform-tools/adb"

# ==========================================
# 2. 动作处理
# ==========================================
ACTION=$1
AVD_NAME=$2

# ▶️ 启动
if [ "$ACTION" = "start" ]; then
  nohup "$EMULATOR_CMD" -avd "$AVD_NAME" > /dev/null 2>&1 &
  sleep 2
  exit 0
fi

# ⏹ 关闭 (核心优化：彻底切断输出通道，实现真正的异步与秒刷新)
if [ "$ACTION" = "stop" ]; then
  # 1. 写入正在关闭的标记
  touch "/tmp/avd_closing_$AVD_NAME"
  
  # 2. 括号内的关机逻辑完全不变
  (
    for dev in $("$ADB_CMD" devices 2>/dev/null | grep 'emulator-' | awk '{print $1}'); do
      avd=$("$ADB_CMD" -s $dev emu avd name | head -n 1 | tr -d '\r')
      if [ "$avd" = "$AVD_NAME" ]; then
        "$ADB_CMD" -s $dev emu kill
      fi
    done
    
    # 智能轮询等待最多 10 秒
    for i in {1..10}; do
      sleep 1
      PID_CHECK=$(ps aux | grep "[q]emu-system" | grep "\-avd $AVD_NAME" | awk '{print $2}')
      if [ -z "$PID_CHECK" ]; then break; fi
    done
    
    # 兜底强杀
    PID=$(ps aux | grep "[q]emu-system" | grep "\-avd $AVD_NAME" | awk '{print $2}')
    if [ -n "$PID" ]; then kill -9 "$PID" 2>/dev/null; fi
    
    # 清理标记
    rm -f "/tmp/avd_closing_$AVD_NAME"
    
  # 【关键修改】在这里切断 stdin、stdout 和 stderr，让 xbar 立刻放行
  ) </dev/null >/dev/null 2>&1 &
  
  # 3. 主脚本光速退出
  exit 0
fi

# 🪟 显示窗口
if [ "$ACTION" = "focus" ]; then
  PID=$(ps aux | grep "[q]emu-system" | grep "\-avd $AVD_NAME" | awk '{print $2}')
  if [ -n "$PID" ]; then
    osascript -e "tell application \"System Events\" to set frontmost of the first process whose unix id is $PID to true"
  fi
  exit 0
fi

# ==========================================
# 3. xbar 菜单 UI 渲染
# ==========================================
echo "📱 AVD"
echo "---"

ALL_AVDS=$("$EMULATOR_CMD" -list-avds)

if [ -z "$ALL_AVDS" ]; then
  echo "未检测到模拟器 | color=gray"
  exit 0
fi

for avd in $ALL_AVDS; do
  PID=$(ps aux | grep "[q]emu-system" | grep "\-avd $avd" | awk '{print $2}')
  
  # UI 逻辑：如果进程存在，并且【不存在】关闭标记，才显示为运行中
  if [ -n "$PID" ] && [ ! -f "/tmp/avd_closing_$avd" ]; then
    echo "🟢 $avd"
    echo "-- 🪟 显示窗口 | bash=\"$0\" param1=focus param2=$avd terminal=false"
    echo "-- ⏹ 关闭模拟器 | bash=\"$0\" param1=stop param2=$avd terminal=false refresh=true color=red"
  else
    # 容错机制：如果进程真的已经消失了，顺手清理一下残留的标记文件
    if [ -z "$PID" ]; then rm -f "/tmp/avd_closing_$avd"; fi
    
    echo "⚪ $avd"
    echo "-- ▶️ 启动模拟器 | bash=\"$0\" param1=start param2=$avd terminal=false refresh=true"
  fi
done
