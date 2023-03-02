# ~/.bash_aliases: executed by bash(1) for all shells (via .bashrc).
# Collection of useful aliases.

alias ll="ls -alF"
alias ls="ls --color=auto"
alias dir="dir --color=auto"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias R="R --no-save"
alias listd="find $diskImagesMainDir -maxdepth 1 -mindepth 1"
alias listod="losetup -a"
alias link-keys="opend keys;ln -s $diskMountMainDir/keys/.ssh .ssh;ln -s $diskMountMainDir/keys/.gnupg .gnupg;"
