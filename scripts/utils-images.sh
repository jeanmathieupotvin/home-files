# ~/scripts/utils-images.sh: executed by bash(1) for all shells via .bash_functions.
# Manipulate image files. # See images::help() for usage.


# Credits ----------------------------------------------------------------------


# Functions images::initialize(), images::lock(), and images::unlock() are an
# attempt to automate and generalize steps of Encrypting WSL2 disks written by
# Tom Christie (https://www.guide2wsl.com/luks/). Multiple disks can be used
# simultaneously. Mapping is fully automated. There is no need to know which
# loop devices are available or not.


# Globals ----------------------------------------------------------------------


export IMAGES_DEFAULT_SIZE_IN_MB=1000
export IMAGES_LOCKED_DIR="$HOME/images/"
export IMAGES_UNLOCKED_DIR="$HOME/projects/"


# Main function ----------------------------------------------------------------


images() {
    case $1 in
        list)
            shift # go past command
            images::list "$@"
            ;;
        init)
            shift # go past command
            images::initialize "$@"
            ;;
        unlock)
            shift # go past command
            images::unlock "$@"
            ;;
        lock)
            shift # go past command
            images::lock "$@"
            ;;
        help)
            shift # go past command
            images::help "$@"
            ;;
        *)
            echo "Unknown command $1. Try 'images help'."
            return 1
            ;;
    esac
}


# Internal functions -----------------------------------------------------------


images::help() {
    echo "Syntax: images <command> <name>"
    echo ""
    echo "Commands:"
    echo "  list    list unlocked and available images stored in $IMAGES_LOCKED_DIR."
    echo "  init    create a new container (an image file and its mount directory)."
    echo "  unlock  decrypt and mount your image as a device."
    echo "  lock    unmount and encrypt your image."
    echo "  help    print this help page."
    echo ""
    echo "Arguments:"
    echo "  name    image's name to initialize, lock, or unlock."
    echo ""
    echo "Tips:"
    echo "  - Containers uses $IMAGES_DEFAULT_SIZE_IN_MB MB by default."
    echo "  - Modify environment variables below to change commands' behavior."
    echo ""
    echo "Current settings:"
    echo "  - IMAGES_DEFAULT_SIZE_IN_MB [default size (MB)]   : $IMAGES_DEFAULT_SIZE_IN_MB"
    echo "  - IMAGES_LOCKED_DIR         [images' directory]   : $IMAGES_LOCKED_DIR"
    echo "  - IMAGES_UNLOCKED_DIR       [main mount directory]: $IMAGES_UNLOCKED_DIR"
}

images::list() {
    echo "Listing all images of $USER."
    echo "Unlocked images:"

    # sed expressions below do the
    # following operations in order.
    #   - delete line of $SECRETS_IMAGE_PATH
    #   - remove useless/empty "[]:" strings
    #   - remove parentheses from paths
    #   - remove file extensions
    #   - keep basenames only
    #   - replace : by ->
    #   - add indentation
    losetup -a | sed \
        -e "/$(basename $SECRETS_IMAGE_PATH)/d" \
        -e 's,\[\]: ,,g' \
        -e 's,[()],,g'   \
        -e 's,\.img$,,g' \
        -e 's,"$IMAGES_LOCKED_DIR",,g' \
        -e 's,\: , -> ,g' \
        -e 's,^,  - ,g'

    echo "Available images in $IMAGES_LOCKED_DIR:"

    # sed expressions below do the
    # following operations in order.
    #   - delete line of $SECRETS_IMAGE_PATH
    #   - remove file extensions
    #   - add indentation
    ls -1 "$IMAGES_LOCKED_DIR" | sed \
        -e "/$(basename $SECRETS_IMAGE_PATH)/d" \
        -e 's,\.img$,,g' \
        -e 's,^,  - ,g'
}

images::unlock() {
    declare imageName="$1"
    declare imagePath="$IMAGES_LOCKED_DIR$imageName.img"
    declare imageDir="$IMAGES_UNLOCKED_DIR$imageName"

    # Set loopback device.
    # Find next available one.
    # Export its path and name as environment variables.
    declare imageDevicePath=$(sudo losetup --show --find "$imagePath")
    declare imageDeviceName=$(basename "$imageDevicePath")

    # Map device and decrypt its contents.
    sudo cryptsetup open "$imageDevicePath" "$imageDeviceName" || {
        sudo losetup -d "$imageDevicePath"
        return 1
    }

    # Mount device in dedicated directory.
    sudo mount "/dev/mapper/$imageDeviceName" "$imageDir" || {
        sudo cryptsetup close "$imageDeviceName"
        sudo losetup -d "$imageDevicePath"
        return 1
    }
}

images::lock() {
    declare imageName="$1"
    declare imagePath="$IMAGES_LOCKED_DIR$imageName.img"
    declare imageDir="$IMAGES_UNLOCKED_DIR$imageName"

    # Find device mapped to imageName.
    declare imageDevicePath=$(losetup -j "$imagePath" | \
        grep --only-matching --perl-regexp "^(.*?)(?=: \[\]:)")
    declare imageDeviceName=$(basename "$imageDevicePath")

    # Unmount device.
    # Encrypt contents of device.
    # Remove device.
    sudo umount "$imageDir"
    sudo cryptsetup close "$imageDeviceName"
    sudo losetup -d "$imageDevicePath"
}

images::initialize() {
    if [[ $IMAGES_DEFAULT_SIZE_IN_MB -lt 20 ]]; then
        echo "Constant IMAGES_DEFAULT_SIZE_IN_MB must be greater than 20 MB."
        echo "This is required to allocate enough space for LUKS header."
        return 1
    fi

    declare imageName="$1"
    declare imagePath="$IMAGES_LOCKED_DIR$imageName.img"
    declare imageDir="$IMAGES_UNLOCKED_DIR$imageName"

    # Number of blocks is equal to IMAGES_DEFAULT_SIZE_IN_MB * (1024 KB/MB) / (4 KB/BLOCK).
    # This is because EXT4 filesystems typically uses blocks of size 4KB.
    declare -i nBlocks="$IMAGES_DEFAULT_SIZE_IN_MB"*1024/4

    # Create imageDir if it does not exist.
    if [[ ! -d "$imageDir" ]]; then
        mkdir "$imageDir"
    fi

    # Create image file.
    dd if=/dev/zero of="$imagePath" bs=4k count=$nBlocks

    # Set loopback device to initialize LUKS partition.
    # Find next available one. Register its path and name.
    declare imageDevicePath=$(sudo losetup --show --find "$imagePath")
    declare imageDeviceName=$(basename "$imageDevicePath")

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
    sudo cryptsetup luksFormat --batch-mode "$imageDevicePath"

    # Map device and decrypt its contents.
    # Format decrypted device as an EXT4 filesystem.
    # Mount device in secretsDir.
    # Cede ownership of secretsDir to current user.
    sudo cryptsetup open "$imageDevicePath" "$imageDeviceName"
    sudo mkfs.ext4 "/dev/mapper/$imageDeviceName"
    sudo mount "/dev/mapper/$imageDeviceName" "$imageDir"
    sudo chown "$USER:$USER" "$imageDir"

    images::lock "$imageName"
}
