# Node / nvm

`install.sh --only node`:

1. Installs [nvm.fish](https://github.com/jorgebucaran/nvm.fish) via fisher if missing
2. Installs the latest LTS and sets it active
3. Installs every package in `npm-globals.txt` globally

Defaults:
- LTS pinned via `nvm_default_version` (optional, commented in config.fish)
