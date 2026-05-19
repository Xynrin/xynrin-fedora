==========================================
  xynrin-fedora — Fedora KDE 使用速查
==========================================

✨ 你刚刚装了什么
  • RPM Fusion free/nonfree 源 + Flathub
  • 你选中的：KDE 主题 / 中文字体+输入法 / 终端美化 / 常用软件

🎨 KDE 主题
  系统设置 → 全局主题 / 颜色 / 图标 随时切换
  壁纸：桌面右键 → 配置桌面和壁纸

⌨️ 输入法（fcitx5）
  Ctrl + Space   中 / 英切换
  Ctrl + Shift   切换多个输入法
  右下角托盘 → 配置 可调候选词数、皮肤、输入偏好
  如果不生效：注销重登 / 或重启

💻 终端（fish + starship）
  cd 目录 → 现在支持 zoxide 智能跳（输入部分路径关键字）
  ll / la  看详细列表（eza 增强版 ls）
  cat      已替换为 bat（带语法高亮）
  abbr     git / docker / systemctl 等常用命令的缩写，按空格展开
  换回 bash： chsh -s /bin/bash

📦 装更多软件
  再跑一次： cd /tmp/xynrin-fedora && ./install.sh --only apps
  或手动：   sudo dnf install XXX   /  flatpak install flathub XXX

🐛 出问题了
  日志在： /tmp/xynrin-fedora-install.log
  没装成功的软件：~/Documents/xynrin-fedora-install-failed.txt
  GitHub Issues： https://github.com/Xynrin/xynrin-fedora/issues

📌 Fedora 44 小提示
  • 默认包管理器是 dnf5（dnf 命令仍可用，是 dnf5 的别名）
  • 默认显示管理器从 SDDM 换成了 Plasma Login Manager
  • Plasma 6.6 引入了首次启动向导（Plasma Setup）

记得：大部分主题/字体/输入法的改动，需要 **注销重登或重启** 才完全生效。
