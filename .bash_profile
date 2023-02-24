# Executed by bash(1) for login shells.
# Ensures that .bashrc is always used.

if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
