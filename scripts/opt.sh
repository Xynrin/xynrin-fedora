#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 获取当前状态并翻译
gpu_raw=$(supergfxctl -g)
case $gpu_raw in
    "Hybrid") current_gpu="混合模式" ;;
    "Integrated") current_gpu="仅核显(最省电)" ;;
    "dGpu") current_gpu="仅独显(高性能)" ;;
    "AsusMuxDgpu") current_gpu="独显直连(最高性能)" ;;
    *) current_gpu=$gpu_raw ;;
esac

# 获取所有活跃屏幕的刷新率
current_refresh=$(kscreen-doctor -o | grep -o '[0-9.]*\*' | cut -d'*' -f1 | cut -d'.' -f1 | xargs echo | sed 's/ /Hz, /g')Hz

profile_raw=$(tuned-adm active | awk '{print $NF}')
case $profile_raw in
    "balanced") current_profile="平衡模式" ;;
    "throughput-performance") current_profile="高性能模式" ;;
    "power-saver") current_profile="省电模式" ;;
    *) current_profile=$profile_raw ;;
esac

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   Fedora 44 高性能笔记本管理工具      ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e " 当前状态: "
echo -e "   显卡模式: ${YELLOW}$current_gpu${NC}"
echo -e "   屏幕刷新: ${YELLOW}$current_refresh${NC}"
echo -e "   性能模式: ${YELLOW}$current_profile${NC}"
echo -e "${BLUE}---------------------------------------${NC}"
echo -e "1. ${RED}[狂暴模式]${NC} - 独显直连 + 180Hz + 高性能调度"
echo -e "2. ${GREEN}[均衡模式]${NC} - 混合显卡 + 180Hz + 自动调度"
echo -e "3. ${YELLOW}[续航模式]${NC} - 彻底关独显 + 60Hz + 节能模式"
echo -e "4. ${BLUE}[状态监控]${NC} - 查看实时显卡占用与温度"
echo -e "q. 退出"
echo -e "${BLUE}---------------------------------------${NC}"
read -p "请选择模式 (1-4): " choice

case $choice in
    1)
        echo -e "${RED}正在切换至狂暴模式...${NC}"
        sudo supergfxctl -m AsusMuxDgpu 2>/dev/null || sudo supergfxctl -m dGpu 2>/dev/null || sudo supergfxctl -m Hybrid
        kscreen-doctor output.eDP-1.mode.2 output.HDMI-A-1.mode.4 2>/dev/null
        sudo tuned-adm profile throughput-performance
        echo -e "${GREEN}完成！建议注销并重新登录以应用显卡更改。${NC}"
        ;;
    2)
        echo -e "${GREEN}正在切换至均衡模式...${NC}"
        sudo supergfxctl -m Hybrid
        kscreen-doctor output.eDP-1.mode.2 output.HDMI-A-1.mode.4 2>/dev/null
        sudo tuned-adm profile balanced
        echo -e "${GREEN}完成！${NC}"
        ;;
    3)
        echo -e "${YELLOW}正在切换至续航模式...${NC}"
        sudo supergfxctl -m Integrated
        kscreen-doctor output.eDP-1.mode.1 output.HDMI-A-1.mode.3 2>/dev/null
        sudo tuned-adm profile power-saver
        echo -e "${GREEN}完成！独显已切断电源，刷新率已降至 60Hz。${NC}"
        ;;
    4)
        nvtop
        ;;
    q)
        exit 0
        ;;
    *)
        echo "无效选项"
        ;;
esac
