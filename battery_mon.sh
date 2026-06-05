#!/bin/bash

# ==========================================
# 纯 Wayland 极简电池监测脚本 (针对老旧硬件优化)
# ==========================================

# 1. 定义你的电池设备名称（HP 笔记本通常为 BAT0）
BATTERY="BAT0"
SYS_PATH="/sys/class/power_supply/$BATTERY"

# 2. 设置报警阈值
LOW_LIMIT=20      # 低电量报警线
CRITICAL_LIMIT=10 # 严重低电量报警线（会持续提醒）

# 确保电池设备存在
if [ ! -d "$SYS_PATH" ]; then
    echo "未找到电池设备 $BATTERY，请检查 /sys/class/power_supply/"
    exit 1
fi

while true; do
    # 读取当前电量和充电状态
    CAPACITY=$(cat "$SYS_PATH/capacity")
    STATUS=$(cat "$SYS_PATH/status")

    # 如果是放电状态（未插电源），则进行检查
    if [ "$STATUS" = "Discharging" ]; then
        
        # 严重低电量：每 30 秒发出紧急通知
        if [ "$CAPACITY" -le "$CRITICAL_LIMIT" ]; then
            if command -v notify-send &> /dev/null; then
                notify-send -u critical "🚨 电池电量极低!" "当前电量仅剩 ${CAPACITY}%，请立即连接充电器！"
            else
                echo "🚨 CRITICAL BATTERY: ${CAPACITY}%" >&2
            fi
            sleep 30
            continue
        
        # 普通低电量：发出一次警告，然后等待 2 分钟
        elif [ "$CAPACITY" -le "$LOW_LIMIT" ]; then
            if command -v notify-send &> /dev/null; then
                notify-send -u normal "🔋 电池电量低" "当前电量为 ${CAPACITY}%，建议连接电源。"
            else
                echo "⚠️ LOW BATTERY: ${CAPACITY}%"
            fi
            sleep 120
            continue
        fi
    fi

    # 正常状态或充电中，每 5 分钟（300秒）检查一次，最大化省电
    sleep 300
done
