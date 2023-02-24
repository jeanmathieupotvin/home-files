# ~/.bashrc: executed by bash(1) for non-login shells and subshells.
# Set all default and custom options.


# If not running interactively, don't do anything.
case $- in
    *i*) ;;
      *) return;;
esac


# Constants -------------------------------------------------------------------


# Set GPG prompt to enter passphrase on WSL2.
export GPG_TTY=$(tty)


# Default settings ------------------------------------------------------------


# Check the window size after each command and,
# if necessary, update values of LINES and COLUMNS.
shopt -s checkwinsize

# Make less more friendly for non-text input files.
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"


# Default prompt --------------------------------------------------------------


# Set variable identifying the chroot
# you work in (used in prompt below).
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Set prompt to user@host:dir and color it.
color_prompt=yes

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

unset color_prompt


# Add further colors ----------------------------------------------------------


# Add colors to ls outputs.
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# Colored GCC warnings and errors.
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'


# Custom settings -------------------------------------------------------------


# Always use aliases file.
# Use standard ~/.bash_aliases file and load it.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Always use home directory.
# Use the home directory if a new bash shell spawns in a /mnt/* directory.
echo "${PWD}" | grep -q '^/mnt/' && cd ~

# Disable bash history entirely and permanently (JMP).
shopt -s histappend

HISTCONTROL=ignoredups:ignorespace
HISTSIZE=10     # Max number of lines that can be stored in memory.
HISTFILESIZE=5  # Max number of lines that can be written to .bash_history.


# Load custom functions ------------------------------------------------------


if [ -f ~/.bash_functions ]; then
    . ~/.bash_functions
fi
