# ~/fedora-setup

My Fedora bootstrap — one command to rebuild this machine from scratch.

## 一键配置新机

```sh
git clone https://github.com/Xynrin/fedora-setup.git ~/fedora-setup
cd ~/fedora-setup
./install.sh
```

首次执行会按顺序跑 10 个步骤。全部幂等：每步都是"先查状态，再只改需要改的"，随时可以中断再重跑。

## 布局

```
fedora-setup/
├── install.sh             # 入口（支持 --only STEP / --dry-run）
├── mirrors/
│   ├── preferred.txt      # 优先镜像 (tuna/ustc/aliyun/official)
│   └── switch-mirror.sh   # 切换器（可单独调用）
├── repos/
│   ├── *.repo             # 第三方 dnf repo 文件（vscode、charm...）
│   └── copr.txt           # 要启用的 COPR
├── packages/
│   ├── dnf.txt            # 要装的 rpm 包（分类有注释）
│   └── flatpak.txt        # flatpak 应用 id
├── fish/
│   ├── config.fish        # 主配置（symlink 到 ~/.config/fish/）
│   ├── fish_plugins       # fisher 插件列表
│   ├── universal_vars.fish # tide 颜色、fish_color_* 全量还原
│   ├── functions/         # 手写 fish 函数（serve、mkcd、killport...）
│   └── conf.d/
├── vscode/
│   ├── settings.json      # symlink 到 ~/.config/Code/User/
│   └── extensions.txt     # 扩展 id 列表
├── systemd/
│   ├── system.txt         # 系统级启用的服务
│   └── user.txt           # 用户级启用的服务
├── node/
│   └── npm-globals.txt    # 全局 npm 包
└── scripts/
    ├── opt.sh             # 性能/续航切换
    └── dump-fish-vars.fish # 重新导出 universal_vars
```

## 步骤

按 `install.sh` 里写死的顺序：

1. **mirrors** — 按 `mirrors/preferred.txt` 切到国内镜像（装 nvidia 必备）
2. **repos** — RPM Fusion free/nonfree + 第三方 .repo + COPR
3. **dnf** — `packages/dnf.txt` 里所有包
4. **flatpak** — `packages/flatpak.txt` 里的应用
5. **fish** — symlink config.fish / functions / conf.d，应用 universal_vars.fish（还原 tide 外观）
6. **fisher** — bootstrap fisher + 按 `fish_plugins` 装插件
7. **vscode** — symlink settings.json + 装扩展
8. **node** — 通过 nvm.fish 装 LTS，按列表装全局 npm 包
9. **systemd** — 启用 `systemd/{system,user}.txt` 里的服务
10. **scripts** — `scripts/*.sh` → symlink 到 `~/.local/bin/<name>`（脱后缀）

## 使用

```sh
./install.sh                  # 全量
./install.sh --only fish      # 只跑 fish
./install.sh --only dnf       # 只装包
./install.sh --dry-run        # 预览不执行
```

## 加新脚本的流程

- **fish 函数**：丢到 `fish/functions/xxx.fish` → `./install.sh --only fish`
- **命令行工具**：丢到 `scripts/xxx.sh` → `./install.sh --only scripts` → `~/.local/bin/xxx`
- **新包**：追加到 `packages/dnf.txt` → `./install.sh --only dnf`
- **新扩展**：追加到 `vscode/extensions.txt` → `./install.sh --only vscode`

## 更新系统

```sh
up                       # fish 函数：dnf + flatpak
fisher update            # 手动跑，注意 GitHub 匿名 API 每小时 60 次限制
```

## 同步当前机器的状态回 repo

如果在当前机器上临时改了 tide 配色或 fisher 插件列表，跑一次：

```sh
fish ~/fedora-setup/scripts/dump-fish-vars.fish   # 把 tide/fish_color_* 变量存盘
```

然后 `git commit` 提交。

## 已知 Caveat

- **不包括**：KDE Plasma 外观设置（壁纸、Dolphin、Konsole 色板等）、fcitx5 用户词库、tmux/vim 配置、`~/.ssh/`。这些东西要么太杂要么含敏感信息，需要可以单独建子目录再纳管。
- **COPR `lukenukem/asus-linux`** 仅 ASUS 笔记本需要；非 ASUS 机器把 `repos/copr.txt` 和 `packages/dnf.txt` 里的 `asusctl` / `supergfxctl` 删掉。
- **akmod-nvidia** 在 nvidia 新机上首次编译内核模块需要几分钟，完成后要重启，才会接管显卡。
