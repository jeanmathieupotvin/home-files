# ~/.bash_logout: executed by bash(1) when login shell exits.

# Clear console after leaving it.
if [ "$SHLVL" = 1 ]; then
    [ -x /usr/bin/clear_console ] && /usr/bin/clear_console -q
fi
