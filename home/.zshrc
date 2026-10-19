# 代理配置
# clash
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890
# v2ray
#export https_proxy=http://127.0.0.1:1087
#export http_proxy=http://127.0.0.1:1087
#export all_proxy=socks5://127.0.0.1:1080

# Go 环境变量
# $GOPATH/bin 目录是 Go 第三方工具的安装位置，将其配置为环境变量，
# 能够使 OS 自动找到这些第三方工具的命令，无需输入完整路径
export PATH=$PATH:$(go env GOPATH)/bin

# Java 环境变量，方便命令行全局使用
# 有些软件的运行需要 JAVA_HOME，例如 JMeter
export JAVA_HOME="/opt/homebrew/opt/openjdk@25"
export PATH="$JAVA_HOME/bin:$PATH" # :$PATH 是什么东西？

# 终端前缀
PS1="yoimiya %1~ %# "

source <(fzf --zsh)

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

google() {
    open "https://www.google.com/search?q=${*// /+}"
}

