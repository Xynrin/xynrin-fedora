# KDE Plasma 配置

KDE 的 `rc` 文件会被 Plasma 频繁改写（调个面板大小、改张壁纸都会触发），如果用 symlink 的话仓库工作区会一直有 diff。所以这里用**快照双向同步**：

- `pull.sh` — 把当前机器的 KDE 配置采集到 `kde/config/` 和 `kde/konsole/`
- `push.sh` — 把仓库里的快照部署回当前机器（会先备份现有文件到 `.kde-backup-<stamp>/`）

## 采集当前机器（日常用）

调完 Plasma 外观想保存：

```sh
~/fedora-setup/kde/pull.sh
cd ~/fedora-setup && git diff kde/
```

Diff 看着对就 commit。

## 部署到新机

```sh
~/fedora-setup/kde/push.sh
# 注销重登，或者：
kquitapp6 plasmashell && kstart plasmashell
```

## 纳管范围

见 `files.txt` 和 `konsole-files.txt`。要加新文件直接改列表就行——列表里的路径用的是相对 `~/.config/` 的路径。

## 注意

- `install.sh` 不会自动跑 `push.sh`，因为部署 KDE 配置是一个需要重登生效的破坏性操作，交给你手动触发更安全
- 如果某些 Plasma 布局和硬件强相关（多屏、屏幕分辨率），换机可能显示异常，回退方法：`~/.config/.kde-backup-<stamp>/` 里有旧文件
