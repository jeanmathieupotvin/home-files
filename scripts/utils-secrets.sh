# utils-secrets.sh: executed by bash(1) for all shells via .bash_functions.
# Lock and unlock encrypted secrets. They are stored as an encrypted image file.
# This script is a simplification of ./utils-images.sh.
# See secrets::help() for usage.


# Globals ----------------------------------------------------------------------


declare -i secretsImageDefaultSizeInMb=50
declare secretsImagePath="$HOME/images/secrets.img"
declare secretsDir="$HOME/secrets/"


# Main function ----------------------------------------------------------------


secrets() {
    case $1 in
        init)
            shift # go past command
            secrets::initialize "$@"
            ;;
        unlock)
            shift # go past command
            secrets::unlock "$@"
            ;;
        lock)
            shift # go past command
            secrets::lock "$@"
            ;;
        help)
            shift # go past command
            secrets::help "$@"
            ;;
        *)
            echo "Unknown command $1. Try 'secrets help'."
            return 1
            ;;
    esac
}


# Internal functions -----------------------------------------------------------


secrets::help() {
    echo "Syntax: secrets <command>"
    echo ""
    echo "Commands:"
    echo "  init    create a new container (an image file and its mount directory)."
    echo "  unlock  decrypt and mount your secrets."
    echo "  lock    unmount and encrypt your secrets."
    echo "  help    print this help page."
    echo ""
    echo "Tips:"
    echo "  - Users can modify exported variables below to handle many containers."
    echo "  - Containers uses $secretsImageDefaultSizeInMb MB by default."
    echo ""
    echo "Current settings:"
    echo "  - secretsImagePath [path to image]  : $secretsImagePath"
    echo "  - secretsDir       [mount directory]: $secretsDir"
}

secrets::unlock() {
    # Set loopback device.
    # Find next available one.
    # Export its path and name as environment variables.
    export secretsDevicePath=$(sudo losetup --show --find "$secretsImagePath")
    export secretsDeviceName=$(basename "$secretsDevicePath")

    # Map device and decrypt its contents.
    # Mount device in dedicated directory.
    sudo cryptsetup open "$secretsDevicePath" "$secretsDeviceName"
    sudo mount "/dev/mapper/$secretsDeviceName" "$secretsDir"
}

secrets::lock() {
    # Unmount device.
    # Encrypt contents of device.
    # Remove device.
    sudo umount "$secretsDir"
    sudo cryptsetup close "$secretsDeviceName"
    sudo losetup -d "$secretsDevicePath"

    # Unset exported environment variables previously set by secrets::unlock.
    unset secretsDevicePath
    unset secretsDeviceName
}

secrets::initialize() {
    if [[ $secretsImageDefaultSizeInMb -lt 20 ]]; then
        echo "Constant secretsImageDefaultSizeInMb must be greater than 20 MB."
        echo "This is required to allocate enough space for LUKS header."
        return 1
    fi

    # Number of blocks is equal to secretsImageDefaultSizeInMb * (1024 KB/MB) / (4 KB/BLOCK).
    # EXT4 filesystems uses blocks of size 4KB.
    declare -i nBlocks=$secretsImageDefaultSizeInMb*1024/4

    # Create secretsDir if it does not exist.
    if [[ ! -d "$secretsDir" ]]; then
        mkdir "$secretsDir"
    fi

    # Create image file.
    dd if=/dev/zero of="$secretsImagePath" bs=4k count=$nBlocks

    # Set loopback device to initialize LUKS partition.
    # Find next available one. Register its path and name.
    declare secretsDevicePath=$(sudo losetup --show --find "$secretsImagePath")
    declare secretsDeviceName=$(basename "$secretsDevicePath")

    # Initialize LUKS partition on device.
    # Argument luksFormat is equivalent to the following arguments.
    # Source: https://wiki.archlinux.org/title/dm-crypt/Device_encryption.
    #  --type luks2             : use latest version of Linux Unified Key System
    #  --cipher aes-xts-plain64 : use same cipher as VirtualBox
    #  --hash sha256            : hashing algorithm used to derive key from passphrase
    #  --iter-time 2000         : time to spend with PBKDF2 passphrase processing (milliseconds)
    #  --key-size 512           : bit key size of XTS ciphers; split in half for AES-XTS256-PLAIN64
    #  --pbkdf argon2id         : set Password-Based Key Derivation Function algorithm for LUKS keyslot
    #  --use-urandom            : RNG to use
    sudo cryptsetup luksFormat --batch-mode "$secretsDevicePath"

    # Map device and decrypt its contents.
    # Format decrypted device as an EXT4 filesystem.
    # Mount device in secretsDir.
    # Cede ownership of secretsDir to current user.
    sudo cryptsetup open "$secretsDevicePath" "$secretsDeviceName"
    sudo mkfs.ext4 "/dev/mapper/$secretsDeviceName"
    sudo mount "/dev/mapper/$secretsDeviceName" "$secretsDir"
    sudo chown "$USER:$USER" "$secretsDir"

    secrets::lock
}
