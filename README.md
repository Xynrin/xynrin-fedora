# xynrin-fedora

**Fedora KDE 一键美化** — 刚装完 Fedora KDE Spin？一条命令把它变成好看、好用、带中文输入法、带常用软件。

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/bootstrap.sh)
```

脚本会引导你选要装的模块（默认全选），15 分钟内搞定。**请以普通用户运行**（不要 `sudo bash …`），脚本内部会按需申请一次 sudo 密码。

## 能做什么

| 模块 | 做什么 |
|------|------|
| **repos**（必做） | 启用 RPM Fusion free/nonfree + Flathub |
| **kde-theme** | Breeze Dark + Papirus 图标 + Fedora 壁纸 |
| **fonts-cjk** | 思源/Noto CJK + JetBrains Mono + fcitx5 拼音 |
| **terminal** | fish + starship + eza/bat/zoxide/fzf/fastfetch，默认 shell 切 fish |
| **apps** | FZF 多选面板装浏览器/音视频/办公/通讯等（dnf + flatpak） |
| **cleanup** | 隐藏用不到的开发工具 `.desktop` 图标，桌面丢一份使用说明 |

## 命令参考

```bash
./install.sh              # 弹 FZF 菜单
./install.sh --all        # 跳菜单，全装
./install.sh --only apps  # 只装某个模块（逗号分隔可多个）
./install.sh --dry-run    # 只预览不真装
```

## 要求

- Fedora 40+（KDE Spin 推荐，其他 Spin 也能跑）
- 能访问外网（脚本从 github / flathub / rpmfusion 拉资源）
- 一个普通用户（UID 1000）
- x86_64 或 aarch64

## 常见问题

**Q: 注销重登后输入法没反应？**  
A: 系统设置 → 自启动 → 添加 `fcitx5`；或重启一次。

**Q: 默认 shell 换 fish 后想换回 bash？**  
A: `chsh -s /bin/bash`

**Q: 装失败的软件在哪看？**  
A: `~/Documents/xynrin-fedora-install-failed.txt`，可以手动重试。

**Q: 安装日志？**  
A: `/tmp/xynrin-fedora-install.log`

## 自定义

- 加/减软件 → 改 `applist-kde.txt` / `applist-common.txt`
- 改 fish 配置 → `kde-dotfiles/.config/fish/config.fish`
- 改 starship 提示符 → `kde-dotfiles/.config/starship.toml`
- 加模块 → `scripts/NN-xxx.sh` + `install.sh` 的 `MODULES` 数组里加一行

## License

MIT
