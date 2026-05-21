# xynrin-fedora 命令速查

所有命令装在 `~/.local/bin/`，fish 和 bash 都能直接调。

> 本文件是 `xf-help` TUI 的数据源，每个二级标题（`## xxx`）对应一条命令，
> 修改这里 `xf-help` 显示同步更新。新增命令在文末加一段，按字母序保持有序。

## 目录

- [安装与升级](#xf-self-update)
- [日常维护](#xf-update)
- [清理空间](#xf-clean)
- [系统状态](#xf-info)
- [切换主题](#xf-theme)
- [命令速查](#xf-help)

---

## xf-self-update

**作用**：拉取 xynrin-fedora 最新仓库并重新部署 dotfiles 与 `xf-*` 工具。

**用法**

```bash
xf-self-update                          # 拉 main，重跑 terminal+kde-theme+fonts-cjk
xf-self-update --all                    # 拉 main，全量重跑所有模块（含软件安装）
xf-self-update --only terminal         # 只重跑指定模块
xf-self-update --branch dev            # 切到其他分支
xf-self-update --dry-run               # 只看会改什么，不动文件
```

**说明**

- 默认只重跑 dotfiles 相关模块（terminal / kde-theme / fonts-cjk），避免每次更新都重装一遍软件
- 仓库缓存在 `/tmp/xynrin-fedora/`，有 `.git` 时走 `git pull` 增量更新
- 拉取后会显示版本号变化：`0.2.0 → 0.3.0`
- dotfiles 强刷前会备份到 `~/.config/.xynrin-backup/<ts>.bak`

**首次安装走 bootstrap.sh，后续维护用 xf-self-update。**

---

## xf-update

**作用**：一把梭更新系统。

**用法**

```bash
xf-update              # dnf upgrade + flatpak update + fwupdmgr update
xf-update --no-fwupd   # 跳过固件更新（笔电外出别折腾）
```

**说明**

- 用当前的 dnf（dnf5 优先），自动 `--refresh`
- flatpak 走的是当前 remote（如果 15-cn-mirror 切了 SJTU 就用 SJTU）
- fwupdmgr 是固件升级工具，会先 refresh 再 update，期间可能要重启

---

## xf-clean

**作用**：清理冗余。

**用法**

```bash
xf-clean              # 真清
xf-clean --dry-run    # 只看会清什么
```

**清的东西**

| 项 | 说明 |
|---|---|
| `dnf autoremove` | 卸载没人依赖的孤立包 |
| `dnf clean all` | 清 dnf 元数据缓存 |
| `journalctl --vacuum-size=200M` | 系统日志只留最近 200M |
| `flatpak uninstall --unused` | 删掉没被任何应用引用的 runtime |
| `~/.cache` 大文件提示 | 大于 100M 的缓存目录列出来，**不自动删**，要你看着办 |

---

## xf-info

**作用**：一眼看系统状态。

**用法**

```bash
xf-info
```

**输出内容**

- **OS**：发行版 + 内核版本
- **Plasma / DE**：当前桌面环境 + Wayland/X11 + plasmashell 版本
- **GPU**：lspci 识别的所有显卡
- **包数量**：rpm + flatpak 已装数
- **失败的安装记录**：`~/Documents/xynrin-fedora-install-failed.txt` 末尾 20 行
- **最近一次安装日志**：`/tmp/xynrin-fedora-install.log` 末尾 10 行

适合贴 issue 时一并提交。

---

## xf-theme

**作用**：命令行切 KDE + GTK 主题（不用翻系统设置）。

**用法**

```bash
xf-theme dark    # Breeze Dark + Papirus-Dark + GTK prefer-dark
xf-theme light   # Breeze + Papirus-Light + GTK 默认
```

**做了什么**

1. 优先调 `plasma-apply-colorscheme` / `plasma-apply-lookandfeel` / `plasma-apply-cursortheme`
   （这些命令同时写 `kdeglobals` + `kdedefaults/`，并通知 plasmashell 立即重绘）
2. 找不到 plasma-apply-\* 才回落到 `kwriteconfig6` 直写两个层级
3. GTK：`gsettings set org.gnome.desktop.interface color-scheme prefer-dark` + 改 `~/.config/gtk-{3,4}.0/settings.ini`
4. `qdbus org.kde.KWin /KWin reconfigure` 让窗口标题栏立刻变色

**生效范围**：当前会话立即可见，新打开的 GTK 应用走新主题（已开窗口需重启）。

---

## xf-help

**作用**：本速查的 TUI 版本，fzf 驱动，搜索 + 预览即用。

**用法**

```bash
xf-help              # 弹 TUI（左列表 / 右说明）
xf-help xf-update    # 直接打印某个命令的说明
xf-help --list       # 纯文本列出所有命令
```

**TUI 操作**

| 按键 | 作用 |
|---|---|
| 上下 / `Ctrl-J` `Ctrl-K` | 移动 |
| 直接输入 | 实时搜索命令名 |
| `Enter` | 在终端里执行该命令（先确认） |
| `Ctrl-Y` | 复制命令名到剪贴板（需 wl-copy / xclip） |
| `Esc` / `Ctrl-C` | 退出 |

数据源是仓库里的 `docs/COMMANDS.md`，新增命令直接编辑 markdown 即可。

---

## 安装入口（参考）

这些不在 `~/.local/bin`，是仓库里的脚本，安装/升级时用：

### bootstrap.sh

**首次在线安装**（小白）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/bootstrap.sh)
```

下载仓库到 `/tmp/xynrin-fedora` → exec install.sh。

### install.sh

**仓库内主入口**：

```bash
./install.sh                # 弹 fzf 模块菜单（默认全选）
./install.sh --all          # 跳菜单，全装，所有 confirm 走默认
./install.sh --only apps    # 只跑某个模块（逗号分隔可多个）
./install.sh --dry-run      # 只预览，不真动
```

**环境变量**

| 变量 | 默认 | 作用 |
|---|---|---|
| `XF_DOTFILES_FORCE` | `1` | dotfiles 强刷+备份；设 `0` 保留宿主机已有配置 |
| `XF_BACKUP_DIR` | `~/.config/.xynrin-backup` | 备份目录 |
| `XF_SKIP_CN_MIRROR` | `0` | 设 `1` 跳过 TUNA 镜像切换 |
| `XF_NONINTERACTIVE` | `0`（`--all` 自动设 `1`） | 跳过所有 confirm 提示 |
| `XF_LOG_FILE` | `/tmp/xynrin-fedora-install.log` | 日志路径 |

---

## 故障排查

| 现象 | 处理 |
|---|---|
| fish 装上但没颜色 | `cat ~/.config/starship.toml \| head` 看 palette 是否在顶层；不在就 `xf-self-update` |
| KDE 主题没换 | 重新跑 `xf-theme dark`；面板没刷新 `setsid plasmashell --replace &` |
| Ctrl+Space 不切换中英 | `pgrep fcitx5` 看是否在跑；没跑：`setsid fcitx5 -d &`；跑了不切：注销重登 |
| 安装日志在哪 | `/tmp/xynrin-fedora-install.log`；失败软件：`~/Documents/xynrin-fedora-install-failed.txt` |
| 想回滚 dotfiles | `ls ~/.config/.xynrin-backup/` 找时间戳，`cp -a` 拷回去 |

不能解决就贴 `xf-info` 输出到 [GitHub Issues](https://github.com/Xynrin/xynrin-fedora/issues)。
