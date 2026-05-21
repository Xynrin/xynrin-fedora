# xynrin-fedora 命令速查

所有命令装在 `~/.local/bin/`，fish 和 bash 都能直接调。

> 本文件是 `xf-help` TUI 的数据源，每个二级标题（`## xxx`）对应一条命令，
> 修改这里 `xf-help` 显示同步更新。新增命令在文末加一段，按字母序保持有序。

## 目录

- [TUI 主入口 xynrin](#xynrin)
- [系统更新 up](#up)
- [自更新 xf-self-update](#xf-self-update)
- [进阶更新 xf-update](#xf-update)
- [清理空间 xf-clean](#xf-clean)
- [系统状态 xf-info](#xf-info)
- [切换主题 xf-theme](#xf-theme)
- [命令速查 xf-help](#xf-help)

---

## xynrin

**作用**：打开 xynrin-fedora 主 TUI（fzf 驱动，左列菜单 / 右列说明）。

**用法**

```bash
xynrin
```

**菜单项**

| 项 | 作用 |
|---|---|
| 系统更新 | 调用 `up` |
| 软件安装 | 重跑 `apps` 模块（fzf 多选） |
| 美化切换 | 重跑 `kde-theme` 模块（3 套方案） |
| 美化卸载 | 卸载主题包，恢复 Breeze |
| 恢复初始 | 还原 `~/.config/.xynrin-backup/plasma-*.tar.gz` |
| 系统信息 | 调用 `xf-info` |
| 命令速查 | 调用 `xf-help` |

横幅由 [oh-my-logo](https://github.com/shinshin86/oh-my-logo) 在安装时缓存到
`~/.config/xynrin-fedora/banner.ansi`，无 npx 时回落 ASCII 图形。

---

## up

**作用**：一键全面更新系统（小白友好彩色 UI）。

**用法**

```bash
up
```

**做了什么**

| 步骤 | 命令 |
|---|---|
| 1 | `sudo dnf upgrade --refresh -y` |
| 2 | `flatpak update -y`（若装了） |
| 3 | `sudo dnf autoremove -y` |
| 4 | `sudo dnf clean all` |
| 5 | `sudo fwupdmgr refresh`（若装了，仅刷元数据） |

每步会打印彩色进度，失败的步骤继续走下一步而非整体退出。

---

## xf-self-update

**作用**：拉取 xynrin-fedora 最新仓库并重新部署 dotfiles 与 `xf-*` 工具。

**用法**

```bash
xf-self-update                          # 拉 main，重跑 terminal+kde-theme+fonts-cjk
xf-self-update --all                    # 拉 main，全量重跑所有模块
xf-self-update --only terminal          # 只重跑指定模块
xf-self-update --branch dev             # 切到其他分支
xf-self-update --dry-run                # 只看会改什么，不动文件
```

**说明**

- 默认只重跑 dotfiles 相关模块（terminal / kde-theme / fonts-cjk）
- 仓库缓存在 `/tmp/xynrin-fedora/`，有 `.git` 时走 `git pull` 增量更新
- 拉取后会显示版本号变化：`1.0.0 → 1.0.1`
- dotfiles 强刷前会备份到 `~/.config/.xynrin-backup/`

---

## xf-update

**作用**：进阶版系统更新（带固件）。

**用法**

```bash
xf-update              # dnf upgrade + flatpak update + fwupdmgr update
xf-update --no-fwupd   # 跳过固件更新
```

`up` 是简化版，只刷固件元数据；`xf-update` 会真正应用固件升级（可能需要重启）。

---

## xf-clean

**作用**：深度清理。

**用法**

```bash
xf-clean              # 真清
xf-clean --dry-run    # 只看会清什么
```

| 项 | 说明 |
|---|---|
| `dnf autoremove` | 卸载没人依赖的孤立包 |
| `dnf clean all` | 清 dnf 元数据缓存 |
| `journalctl --vacuum-size=200M` | 系统日志只留最近 200M |
| `flatpak uninstall --unused` | 删未引用的 runtime |
| `~/.cache` 大文件提示 | 大于 100M 列出来不自动删 |

---

## xf-info

**作用**：一眼看系统状态。

```bash
xf-info
```

输出 OS / 内核 / Plasma / GPU / 包数量 / 失败安装 / 最近日志，适合贴 issue。

---

## xf-theme

**作用**：命令行切 KDE + GTK 主题。

```bash
xf-theme dark    # Breeze Dark + Papirus-Dark + GTK prefer-dark
xf-theme light   # Breeze + Papirus-Light + GTK 默认
```

会优先调 `plasma-apply-*`，找不到就回落到 `kwriteconfig6`，并 `qdbus org.kde.KWin /KWin reconfigure` 让标题栏立刻变色。

---

## xf-help

**作用**：本速查的 TUI 版本。

```bash
xf-help              # 弹 TUI（左列表 / 右说明）
xf-help xynrin       # 直接打印某个命令的说明
xf-help --list       # 纯文本列出所有命令
```

数据源是 `~/.config/xynrin-fedora/COMMANDS.md`（即本文件的部署副本）。

---

## 安装入口（参考）

### bootstrap.sh

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/bootstrap.sh)
```

下载仓库到 `/tmp/xynrin-fedora` → exec install.sh。**严格检测 Fedora**，非 Fedora 立即退出。

### install.sh

```bash
./install.sh                # 弹 fzf 模块菜单
./install.sh --all          # 跳菜单，全装
./install.sh --only apps    # 只跑某个模块
./install.sh --dry-run      # 只预览
```

---

## 故障排查

| 现象 | 处理 |
|---|---|
| fish 装上但没图标 | 终端字体改 Nerd Font；`fc-list \| grep -i nerd` 看是否装上 |
| KDE 主题没换 | `xynrin` → 美化切换；或 `setsid plasmashell --replace &` |
| Ctrl+Space 不切换中英 | `pgrep fcitx5`；没跑：`setsid fcitx5 -d &`；跑了不切：注销重登 |
| 安装日志在哪 | `/tmp/xynrin-fedora-install.log` |
| 失败软件在哪看 | `~/Documents/xynrin-fedora-install-failed.txt` |
| 想回滚 dotfiles | `xynrin` → 恢复初始 |

不能解决：贴 `xf-info` 输出到 [GitHub Issues](https://github.com/Xynrin/xynrin-fedora/issues)。
