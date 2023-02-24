# ~/.bash_profile: executed by bash(1) for login shells.
# Ensures that .bashrc is always executed.

if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
