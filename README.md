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
| **terminal** | fish + starship + eza/bat/zoxide/fzf/fastfetch；conf.d/functions 拆分；注册 `~/.local/bin` 工具脚本 |
| **apps** | FZF 多选面板装浏览器/音视频/办公/通讯等（dnf + flatpak） |
| **cleanup** | 隐藏用不到的开发工具 `.desktop` 图标，桌面丢一份使用说明 |

## 顺手的命令（装在 `~/.local/bin`，fish/bash 都能用）

| 命令 | 作用 |
|------|------|
| `xf-update` | 一把梭：`dnf + flatpak + fwupdmgr` |
| `xf-clean`  | 清理：autoremove + journal + flatpak 未用 runtime |
| `xf-theme dark\|light` | 命令行切 KDE + GTK 主题 |
| `xf-info` | 系统状态摘要：内核 / DE / GPU / 包数量 / 失败记录 |

## 命令参考

```bash
./install.sh              # 弹 FZF 菜单
./install.sh --all        # 跳菜单，全装
./install.sh --only apps  # 只装某个模块（逗号分隔可多个）
./install.sh --dry-run    # 只预览不真装
```

## 要求

- Fedora 41+（已在 Fedora 44 KDE Spin 测试，Plasma 6.6 + dnf5）
- 其他 Spin 也能跑，KDE 模块对非 KDE 桌面会跳过
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
- 改 fish 行为 → `kde-dotfiles/.config/fish/conf.d/*.fish`（别名/缩写/环境变量分文件）
- 加 fish 自定义函数 → `kde-dotfiles/.config/fish/functions/<name>.fish`（按需加载）
- 改 starship 提示符 → `kde-dotfiles/.config/starship.toml`
- 加 `~/.local/bin` 工具 → `kde-dotfiles/.local/bin/<name>`，会自动 chmod +x 部署
- 加模块 → `scripts/NN-xxx.sh` + `install.sh` 的 `MODULES` 数组里加一行

## License

MIT
