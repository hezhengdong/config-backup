# config-backup

macOS 常用配置的自动备份，变更后自动推送到 GitHub。

## 内容

| 路径 | 来源 |
|---|---|
| `home/.zshrc` | `~/.zshrc` |
| `home/.vimrc` | `~/.vimrc` |
| `home/.config/clash.meta/remove_hk.sh` | `~/.config/clash.meta/remove_hk.sh` |
| `inventory/brew-leaves.txt` | `brew leaves \| sort` |
| `inventory/brew-casks.txt` | `brew list --cask \| sort` |

不含任何密钥。`backup.sh` 在提交前会扫描高置信度密钥特征，命中即中止。

## 自动运行

LaunchAgent `com.hezhengdong.config-backup`，每天 12:30 执行一次，登录时补跑一次。

```bash
launchctl print gui/$(id -u)/com.hezhengdong.config-backup   # 查看状态
tail -f ~/Library/Logs/config-backup.log                      # 查看日志
```

手动执行：

```bash
~/config-backup/backup.sh
```

## 恢复

```bash
git clone git@github.com:hezhengdong/config-backup.git
cd config-backup
rsync -av home/ ~/
brew install $(cat inventory/brew-leaves.txt)
brew install --cask $(cat inventory/brew-casks.txt)
```

单文件回滚：

```bash
git log --oneline -- home/.zshrc
git show <commit>:home/.zshrc > ~/.zshrc
```

## 新增备份文件

编辑 `backup.sh`，在“拷贝配置文件”一节加一行：

```bash
copy_file "$HOME/.gitconfig" "home/.gitconfig"
```
