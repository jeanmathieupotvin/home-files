# utils-secrets.sh: executed by bash(1) for all shells via .bash_functions.
# Lock and unlock encrypted secrets. They are stored as an encrypted image file.
# This script is a simplification of ./utils-images.sh.
# See secrets::help() for usage.


# Globals ----------------------------------------------------------------------


export SECRETS_IMAGE_DEFAULT_SIZE_IN_MB=50
export SECRETS_IMAGE_PATH="$HOME/images/secrets.img"
export SECRETS_DIR="$HOME/secrets/"


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
    echo "  - Containers uses $SECRETS_IMAGE_DEFAULT_SIZE_IN_MB MB by default."
    echo ""
    echo "Current settings:"
    echo "  - SECRETS_IMAGE_PATH [path to image] : $SECRETS_IMAGE_PATH"
    echo "  - SECRETS_DIR       [mount directory]: $SECRETS_DIR"
}

secrets::unlock() {
    # Set loopback device.
    # Find next available one.
    # Export its path and name as environment variables.
    export SECRETS_DEVICE_PATH=$(sudo losetup --show --find "$SECRETS_IMAGE_PATH")
    export SECRETS_DEVICE_NAME=$(basename "$SECRETS_DEVICE_PATH")

    # Map device and decrypt its contents.
    sudo cryptsetup open "$SECRETS_DEVICE_PATH" "$SECRETS_DEVICE_NAME" || {
        sudo losetup -d "$SECRETS_DEVICE_PATH"
        unset SECRETS_DEVICE_PATH
        return 1
    }

    # Mount device in dedicated directory.
    sudo mount "/dev/mapper/$SECRETS_DEVICE_NAME" "$SECRETS_DIR" || {
        sudo cryptsetup close "$imageDeviceName"
        sudo losetup -d "$SECRETS_DEVICE_PATH"
        unset SECRETS_DEVICE_PATH
        return 1
    }
}

secrets::lock() {
    # Unmount device.
    # Encrypt contents of device.
    # Remove device.
    sudo umount "$SECRETS_DIR"
    sudo cryptsetup close "$SECRETS_DEVICE_NAME"
    sudo losetup -d "$SECRETS_DEVICE_PATH"

    # Unset exported environment variables previously set by secrets::unlock.
    unset SECRETS_DEVICE_PATH
    unset SECRETS_DEVICE_NAME
}

secrets::initialize() {
    if [[ $SECRETS_IMAGE_DEFAULT_SIZE_IN_MB -lt 20 ]]; then
        echo "Constant SECRETS_IMAGE_DEFAULT_SIZE_IN_MB must be greater than 20 MB."
        echo "This is required to allocate enough space for LUKS header."
        return 1
    fi

    # Number of blocks is equal to SECRETS_IMAGE_DEFAULT_SIZE_IN_MB * (1024 KB/MB) / (4 KB/BLOCK).
    # EXT4 filesystems uses blocks of size 4KB.
    declare -i nBlocks=$SECRETS_IMAGE_DEFAULT_SIZE_IN_MB*1024/4

    # Create SECRETS_DIR if it does not exist.
    if [[ ! -d "$SECRETS_DIR" ]]; then
        mkdir "$SECRETS_DIR"
    fi

    # Create image file.
    dd if=/dev/zero of="$SECRETS_IMAGE_PATH" bs=4k count=$nBlocks

    # Set loopback device to initialize LUKS partition.
    # Find next available one. Register its path and name.
    declare SECRETS_DEVICE_PATH=$(sudo losetup --show --find "$SECRETS_IMAGE_PATH")
    declare SECRETS_DEVICE_NAME=$(basename "$SECRETS_DEVICE_PATH")

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
    sudo cryptsetup luksFormat --batch-mode "$SECRETS_DEVICE_PATH"

    # Map device and decrypt its contents.
    # Format decrypted device as an EXT4 filesystem.
    # Mount device in SECRETS_DIR.
    # Cede ownership of SECRETS_DIR to current user.
    sudo cryptsetup open "$SECRETS_DEVICE_PATH" "$SECRETS_DEVICE_NAME"
    sudo mkfs.ext4 "/dev/mapper/$SECRETS_DEVICE_NAME"
    sudo mount "/dev/mapper/$SECRETS_DEVICE_NAME" "$SECRETS_DIR"
    sudo chown "$USER:$USER" "$SECRETS_DIR"

    secrets::lock
}
