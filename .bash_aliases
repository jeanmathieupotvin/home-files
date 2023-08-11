# ~/.bash_aliases: executed by bash(1) for all shells (via .bashrc).
# Collection of useful aliases.

alias codev="code *.code-workspace"
alias ll="ls -alF"
alias ls="ls --color=auto"
alias dir="dir --color=auto"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias isync='rsync --recursive --verbose "$HOME/images" /mnt/d/backups --log-file="/mnt/d/backups/images/logs/$(date +"%Y-%m-%d").log"'
alias R="R --no-save"
alias lnssh='ln -s "$secretsDir/.ssh" .ssh'
alias lngnupg='ln -s "$secretsDir/.gnupg" .gnupg'
alias lnrclone='ln -s "$secretsDir/.config/rclone" ~/.config/rclone'
