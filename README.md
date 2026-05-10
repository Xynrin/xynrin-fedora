# Xynrin-Fedora 🚀

<p align="center">
  <img src="./image/xynrin-fedora-logo.png" alt="logo" width="150">
</p>

我的 **Fedora KDE 工作站一键配置仓库**。新机从零到可用，只需一条命令即可完成环境搭建。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/Xynrin/xynrin-fedora)](https://github.com/Xynrin/xynrin-fedora/releases)
[![Fedora Package](https://img.shields.io/badge/Fedora-ready-brightgreen.svg)](#)

---

## 一键引导（新机推荐）

**bash / zsh**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/bootstrap.sh)
```

**fish**

```fish
curl -fsSL https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/bootstrap.sh | bash
```

`bootstrap.sh` 做三件事：装 git、克隆仓库到 `~/xynrin-fedora`、打印下一步命令。真正的安装 `install.sh` 需要 sudo，必须手动跑（不在管道里）：

```sh
cd ~/xynrin-fedora
./install.sh            # 全量
./install.sh --dry-run  # 或先预览
```

## 手动克隆

```sh
git clone https://github.com/Xynrin/xynrin-fedora.git ~/xynrin-fedora
cd ~/xynrin-fedora
./install.sh
```

所有步骤幂等，先查状态再只改需要改的，中断随时可重跑。**全程只会输入一次 sudo 密码**，之后后台续期直到脚本结束。

## 布局

```
xynrin-fedora/
├── install.sh               # 瘦身入口（banner + 一次 sudo + 调度）
├── install-config/          # 每个步骤一个 install-*.sh
│   ├── common.sh            # 日志 / run / link_into / need_sudo
│   ├── install-mirrors.sh
│   ├── install-repos.sh
│   ├── install-dnf.sh
│   ├── install-flatpak.sh
│   ├── install-fish.sh
│   ├── install-fisher.sh
│   ├── install-vscode.sh
│   ├── install-node.sh
│   ├── install-systemd.sh
│   └── install-scripts.sh
├── bootstrap.sh             # 在线引导（curl raw 入口）
├── mirrors/                 # 镜像切换器
├── repos/                   # 第三方 .repo + COPR 清单
├── packages/                # dnf / flatpak 清单
├── fish/                    # config.fish / plugins / 函数 / universal 变量
├── vscode/                  # settings.json + 扩展清单
├── kde/                     # Plasma 双向同步
├── systemd/                 # 要启用的系统/用户服务
├── node/                    # npm 全局包
├── scripts/                 # 自定义命令行工具（自动 symlink）
└── docs/                    # 中文维护手册
```

## 步骤

按 `install.sh` 顺序：

| # | 步骤 | 做什么 |
|---|------|-------|
| 1 | mirrors | 按 `mirrors/preferred.txt` 切到国内镜像（装 nvidia 必备） |
| 2 | repos | RPM Fusion free/nonfree + 第三方 .repo + COPR |
| 3 | dnf | `packages/dnf.txt` 里所有包 |
| 4 | flatpak | `packages/flatpak.txt` 里的应用 |
| 5 | fish | symlink config.fish / functions / conf.d，应用 universal_vars.fish |
| 6 | fisher | bootstrap fisher + 按 `fish_plugins` 装插件 |
| 7 | vscode | symlink settings.json + 装扩展 |
| 8 | node | nvm LTS + `node/npm-globals.txt`（oh-my-logo 等） |
| 9 | systemd | 启用 `systemd/{system,user}.txt` 里的服务 |
| 10 | scripts | `scripts/*.sh` → symlink 到 `~/.local/bin/<name>`（脱后缀） |

KDE 配置不自动部署，单独跑：

```sh
./kde/push.sh
# 然后注销重登，或 kquitapp6 plasmashell && kstart plasmashell
```

## 使用

```sh
./install.sh                  # 全量
./install.sh --only fish      # 只跑 fish 步骤
./install.sh --only dnf       # 只装包
./install.sh --dry-run        # 预览不执行
```

**只有包含 `mirrors / repos / dnf / systemd / node` 的步骤会提升权限**；纯 fish/vscode/scripts 不问 sudo。

## 加新内容的流程

- **fish 函数**：丢到 `fish/functions/xxx.fish` → `./install.sh --only fish`
- **命令行工具**：丢到 `scripts/xxx.sh` → `./install.sh --only scripts` → `~/.local/bin/xxx`
- **新包**：追加到 `packages/dnf.txt` → `./install.sh --only dnf`
- **新扩展**：追加到 `vscode/extensions.txt` → `./install.sh --only vscode`
- **KDE 外观调整**：`./kde/pull.sh` 回仓库，`git commit`
- **新增安装模块**：在 `install-config/` 加 `install-xxx.sh`，在 `install.sh` 顶部 `steps=(...)` 列表加名字即可

## 更新系统

```sh
up                       # fish 函数：dnf + flatpak
fisher update            # 手动跑，注意 GitHub 匿名 API 每小时 60 次限制
```

## 同步当前机器状态回仓库

```sh
# tide 颜色 / fish_color_* 等 universal 变量
fish ~/xynrin-fedora/scripts/dump-fish-vars.fish

# KDE Plasma 配置
~/xynrin-fedora/kde/pull.sh

# 提交
cd ~/xynrin-fedora && git add -A && git commit -m "..." && git push
```

## 完整文档

见 [`docs/维护手册.md`](./docs/维护手册.md)。

## 已知 Caveat

- **COPR `lukenukem/asus-linux`** 仅 ASUS 笔记本需要；非 ASUS 机器把 `repos/copr.txt` 和 `packages/dnf.txt` 里的 `asusctl` / `supergfxctl` 删掉。
- **akmod-nvidia** 在 nvidia 新机上首次编译内核模块需要几分钟，完成后要重启，才会接管显卡。
- **fcitx5 用户词库**、`~/.ssh/`、`~/.gitconfig` 等敏感配置**不纳管**，按需另行备份。
