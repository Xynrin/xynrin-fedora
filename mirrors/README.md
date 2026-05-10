# Mirror switcher

Fedora 默认走 metalink，国内新机第一次 `dnf install akmod-nvidia` 大概率慢或超时。
`mirrors/switch-mirror.sh` 会把 fedora + rpmfusion 的 baseurl 改成国内镜像，同时**保留 vscode / charm 等第三方 repo 不动**（它们自己有 CDN）。

## 使用

```sh
# 安装时走 preferred.txt 里写的镜像
./install.sh --only mirrors

# 临时切
sudo ~/fedora-setup/mirrors/switch-mirror.sh tuna      # 清华
sudo ~/fedora-setup/mirrors/switch-mirror.sh ustc      # 中科大
sudo ~/fedora-setup/mirrors/switch-mirror.sh aliyun    # 阿里云
sudo ~/fedora-setup/mirrors/switch-mirror.sh official  # 恢复官方
```

首次切换会把 `/etc/yum.repos.d/*.repo` 备份到 `/etc/yum.repos.d/.mirror-backup/`，之后切换都是从备份重建，不会累积 sed 的副作用。恢复 `official` 会直接从备份还原。
