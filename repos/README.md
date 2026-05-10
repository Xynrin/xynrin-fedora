# Third-party dnf repos

`install.sh --only repos` does three things:

1. Enables RPM Fusion free + nonfree (needed for ffmpeg, nvidia, steam)
2. Copies every `.repo` file here into `/etc/yum.repos.d/`
3. Enables required COPR repos (see `copr.txt`)

Repo files currently tracked:

- `charm.repo`      — glow / gum / etc
- `google-chrome.repo`
- `vscode.repo`     — Microsoft builds of Code
