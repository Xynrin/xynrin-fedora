==========================================
  xynrin-fedora — Fedora 44 KDE 使用速查
==========================================

✨ 你刚刚装了什么
  • RPM Fusion free/nonfree 源 + Flathub
  • 你选中的：KDE 主题 / 中文字体+输入法 / 终端美化 / 常用软件 / 显卡驱动
  • ~/.local/bin 里几个 xf-* 工具脚本

🎨 KDE 主题
  系统设置 → 全局主题 / 颜色 / 图标 随时切换
  命令行切：  xf-theme dark   xf-theme light
  GTK 应用也会跟着深/浅，新窗口生效

⌨️ 输入法（fcitx5）
  Ctrl + Space   中 / 英切换
  Ctrl + Shift   切多个输入法
  右下角托盘 → 配置（候选词数、皮肤、偏好）
  不生效：注销重登 / 或重启

💻 终端（fish + starship）
  cd 目录 → zoxide 智能跳（输入部分关键字）
  ll / la  详细列表（eza）
  cat      已替换为 bat（带高亮）
  abbr     g / gp / in / up / sc 等缩写，按空格展开
  自定义：~/.config/fish/conf.d/*.fish     函数：~/.config/fish/functions/*.fish
  换回 bash： chsh -s /bin/bash

🛠️ ~/.local/bin 常用命令
  xf-update     一把梭：dnf + flatpak + 固件
  xf-clean      清理：autoremove + journal + flatpak unused + ~/.cache 报告
  xf-info       系统状态摘要
  xf-theme      切深色 / 浅色

📦 装更多软件
  再跑一次： cd /tmp/xynrin-fedora && ./install.sh --only apps
  或手动：   sudo dnf install XXX   /  flatpak install flathub XXX

🐛 出问题了
  日志在： /tmp/xynrin-fedora-install.log
  没装成功的软件：~/Documents/xynrin-fedora-install-failed.txt
  GitHub Issues： https://github.com/Xynrin/xynrin-fedora/issues

📌 Fedora 44 小提示
  • 默认包管理器 dnf5（dnf 命令是别名）
  • 默认显示管理器从 SDDM 换成了 Plasma Login Manager
  • Plasma 6 引入了首次启动向导（Plasma Setup）

记得：大部分主题/字体/输入法的改动，**注销重登或重启**后才完全生效。
