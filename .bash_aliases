# ~/.bash_aliases: executed by bash(1) for all shells (via .bashrc).
# Collection of useful aliases.

alias ll="ls -alF"
alias ls="ls --color=auto"
alias dir="dir --color=auto"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias R="R --no-save"
alias link-ssh='ln -s "$diskMountMainDir/keys/.ssh" .ssh'
alias link-gnupg='ln -s "$diskMountMainDir/keys/.gnupg" .gnupg'
alias link-rclone='ln -s "$diskMountMainDir/keys/.config/rclone" ~/.config/rclone'
