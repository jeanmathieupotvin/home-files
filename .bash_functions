# ~/.bash_functions: executed by bash(1) for all shells (via .bashrc).
# Collection of user-level functions.

declare utilsEncryptionPath=~/scripts/utils-encryption.sh

if [ -f "$utilsEncryptionPath" ]; then
    . "$utilsEncryptionPath"
fi
