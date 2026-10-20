#!/bin/bash

# ==========================================
# 1. 路径与环境变量配置
# ==========================================
# 注入 Homebrew 路径，确保 xbar 能找到 scrcpy
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SDK_DIR="$HOME/Library/Android/sdk"
EMULATOR_CMD="$SDK_DIR/emulator/emulator"
ADB_CMD="$SDK_DIR/platform-tools/adb"
SCRCPY_CMD="scrcpy"

# ==========================================
# 2. 动作处理 (AVD 与 Scrcpy 逻辑分离)
# ==========================================
ACTION=$1
TARGET=$2

# ----------------- AVD 模拟器动作 -----------------
if [ "$ACTION" = "avd_start" ]; then
  nohup "$EMULATOR_CMD" -avd "$TARGET" > /dev/null 2>&1 &
  sleep 2
  exit 0
fi

if [ "$ACTION" = "avd_stop" ]; then
  touch "/tmp/avd_closing_$TARGET"
  (
    for dev in $("$ADB_CMD" devices 2>/dev/null | grep 'emulator-' | awk '{print $1}'); do
      avd=$("$ADB_CMD" -s $dev emu avd name | head -n 1 | tr -d '\r')
      if [ "$avd" = "$TARGET" ]; then "$ADB_CMD" -s $dev emu kill; fi
    done
    for i in {1..10}; do
      sleep 1
      if [ -z "$(ps aux | grep "[q]emu-system" | grep "\-avd $TARGET" | awk '{print $2}')" ]; then break; fi
    done
    PID=$(ps aux | grep "[q]emu-system" | grep "\-avd $TARGET" | awk '{print $2}')
    if [ -n "$PID" ]; then kill -9 "$PID" 2>/dev/null; fi
    rm -f "/tmp/avd_closing_$TARGET"
  ) </dev/null >/dev/null 2>&1 &
  exit 0
fi

if [ "$ACTION" = "avd_focus" ]; then
  PID=$(ps aux | grep "[q]emu-system" | grep "\-avd $TARGET" | awk '{print $2}')
  if [ -n "$PID" ]; then
    osascript -e "tell application \"System Events\" to set frontmost of the first process whose unix id is $PID to true"
  fi
  exit 0
fi

# ----------------- Scrcpy 投屏动作 -----------------
if [ "$ACTION" = "scrcpy_start" ]; then
  # 增加 --window-title 参数，给窗口强行命名为设备序列号，方便后续精准寻找
  nohup "$SCRCPY_CMD" -s "$TARGET" --window-title "$TARGET" > /dev/null 2>&1 &
  sleep 1
  exit 0
fi

if [ "$ACTION" = "scrcpy_start_stealth" ]; then
  nohup "$SCRCPY_CMD" -s "$TARGET" -S -w --keyboard=uhid --window-title "$TARGET" > /dev/null 2>&1 &
  sleep 1
  exit 0
fi

if [ "$ACTION" = "scrcpy_stop" ]; then
  # 1. 使用 pkill 优雅关闭包含该设备序列号的 scrcpy 进程
  pkill -f "scrcpy.*-s $TARGET" 2>/dev/null
  
  # 2. 等待 0.5 秒，给系统释放资源的时间
  sleep 0.5
  
  # 3. 兜底机制：如果 0.5 秒后进程卡死没退出，直接 -9 拔电源强杀
  pkill -9 -f "scrcpy.*-s $TARGET" 2>/dev/null
  
  # 4. 再等待 1 秒，确保进程死透，这样主脚本退出后 xbar 刷新就能瞬间变成 ⚪
  sleep 1
  
  exit 0
fi

if [ "$ACTION" = "scrcpy_focus" ]; then
  # 组合 AppleScript：先将所有 scrcpy 进程激活，再精准匹配窗口名字并推到最顶层
  osascript -e 'tell application "System Events"
    set frontmost of every process whose name is "scrcpy" to true
    repeat with p in (every process whose name is "scrcpy")
      try
        perform action "AXRaise" of window "'$TARGET'" of p
      end try
    end repeat
  end tell' > /dev/null 2>&1
  exit 0
fi

# ==========================================
# 3. xbar 菜单 UI 渲染
# ==========================================
echo "📱"
echo "---"

# ----------------- 模块 A: 官方 AVD 模拟器 -----------------
echo "💻 官方模拟器 (AVD) | color=#0078D7"
ALL_AVDS=$("$EMULATOR_CMD" -list-avds 2>/dev/null)

if [ -z "$ALL_AVDS" ]; then
  echo "未创建模拟器 | color=gray"
else
  for avd in $ALL_AVDS; do
    PID=$(ps aux | grep "[q]emu-system" | grep "\-avd $avd" | awk '{print $2}')
    if [ -n "$PID" ] && [ ! -f "/tmp/avd_closing_$avd" ]; then
      echo "🟢 $avd"
      echo "-- 🪟 显示窗口 | bash=\"$0\" param1=avd_focus param2=$avd terminal=false"
      echo "-- ⏹ 关闭模拟器 | bash=\"$0\" param1=avd_stop param2=$avd terminal=false refresh=true color=red"
    else
      if [ -z "$PID" ]; then rm -f "/tmp/avd_closing_$avd"; fi
      echo "⚪ $avd"
      echo "-- ▶️ 启动模拟器 | bash=\"$0\" param1=avd_start param2=$avd terminal=false refresh=true"
    fi
  done
fi

echo "---"

# ----------------- 模块 B: 真实设备 / 第三方模拟器 (Scrcpy) -----------------
echo "📱 物理设备与投屏 (Scrcpy) | color=#107C10"

# 获取所有处于 device 状态的设备，并过滤掉 emulator- (避免与上半部分重复)
ADB_DEVICES=$("$ADB_CMD" devices 2>/dev/null | tail -n +2 | grep -w "device" | awk '{print $1}' | grep -v 'emulator-')

if [ -z "$ADB_DEVICES" ]; then
  echo "未检测到已连接的设备 | color=gray"
else
  for dev in $ADB_DEVICES; do
    # 尝试通过 adb 读取手机的真实机型名称 (例如 Pixel 7)
    MODEL=$("$ADB_CMD" -s "$dev" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    # 如果读不到机型，就降级显示它的序列号
    if [ -z "$MODEL" ]; then MODEL="$dev"; fi
    
    # 检测 scrcpy 是否正在运行这个设备
    PID=$(ps aux | grep "[s]crcpy" | grep "\-s $dev" | awk '{print $2}')
    
    if [ -n "$PID" ]; then
      echo "🟢 $MODEL ($dev)"
      echo "-- 🪟 显示窗口 | bash=\"$0\" param1=scrcpy_focus param2=$dev terminal=false"
      echo "-- ⏹ 关闭投屏 | bash=\"$0\" param1=scrcpy_stop param2=$dev terminal=false refresh=true color=red"
    else
      echo "⚪ $MODEL ($dev)"
      echo "-- ▶️ 标准投屏 | bash=\"$0\" param1=scrcpy_start param2=$dev terminal=false refresh=true"
      echo "-- 🕶️ 极客投屏 (息屏+常亮+键盘) | bash=\"$0\" param1=scrcpy_start_stealth param2=$dev terminal=false refresh=true"
    fi
  done
fi
