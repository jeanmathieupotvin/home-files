# ~/.bash_functions: executed by bash(1) for all shells (via .bashrc).
# Collection of useful utility functions.


# Create, open, and close LUKS encrypted disk images files ---------------------


# Functions creatd(), opend(), and close() are an attempt to automate steps
# of sections Encrypting WSL2 disks of Guide 2 WSL written by Tom Christie.
# See https://www.guide2wsl.com/luks/ for more information. All credits goes
# to him.


declare -l DISKDIR=~/disks
declare -l DISKMNT=~/projects

created() {
    if [[ ! $# -eq 4 ]]; then
        echo "Syntax: created [--name <string>] [--size <integer>]"
        echo ""
        echo "Create an EXT4 disk image file encrypted with LUKS."
        echo "Disks are stored  in $DISKDIR."
        echo "Disks are mounted in $DISKMNT."
        echo ""
        echo "Arguments:"
        echo " -n, --name  name of the disk file"
        echo " -s, --size  desired size of the disk file in GB"
        echo ""
        echo "See related commands opend and closed."
        return 1
    fi

    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
            declare -l DISKNAME="$2"
            shift # go past argument
            shift # go past value
            ;;
            -s|--size)
            declare -i DISKSIZE="$2"
            shift # go past argument
            shift # go past value
            ;;
            -*|--*)
            echo "Unknown argument $1."
            return 1
            ;;
        esac
    done

    # Check if all variables (arguments) are set.
    # Source: https://stackoverflow.com/a/13864829
    if [[ -z ${DISKNAME+x} ]] || [[ -z ${DISKSIZE+x} ]]; then
        echo "Arguments --name and --size are both required."
        return 1
    fi

    declare -l DISKPATH="$DISKDIR/$DISKNAME.img"
    declare -l DISKDEST="$DISKMNT/$DISKNAME"
    declare -i DISKBLOCKS=$DISKSIZE*1024*1024/4

    # Create mount directory if it does not exist.
    if [[ ! -d "$DISKDEST" ]]; then
        echo "Creating $DISKDEST."
        mkdir "$DISKDEST"
    fi

    echo "Creating disk $DISKNAME of $DISKSIZE GB ($DISKBLOCKS blocks)."

    # Create disk image file.
    dd if=/dev/zero of="$DISKPATH" bs=4k count=$DISKBLOCKS

    # Set up disk image as a loopback device.
    sudo losetup /dev/loop0 "$DISKPATH"

    # Initialize a LUKS partition on device and set initial passphrase.
    # When cryptsetup > 2.4.0 is used, these arguments are used:
    #  --type luks2             : use latest version of Linux Unified Key System
    #  --cipher aes-xts-plain64 : use same cipher as VirtualBox
    #  --hash sha256            : hashing algorithm used to derive key from passphrase
    #  --iter-time 2000         : time to spend with PBKDF2 passphrase processing (milliseconds)
    #  --key-size 256           : bit size of XTS ciphers; split in half so AES-XTS256-PLAIN64 is used in practice
    #  --pbkdf argon2id         : set Password-Based Key Derivation Function algorithm for LUKS keyslot
    #  --use-urandom            : RNG to use
    #  --verify-passphrase      : passphrase has to be typed twice
    # Source: https://wiki.archlinux.org/title/dm-crypt/Device_encryption
    sudo cryptsetup luksFormat -q -y /dev/loop0 || {
        echo "LUKS headers could not be created for device."
        return 1
    }

    # Set up decrypted device as new loopback device.
    sudo cryptsetup open /dev/loop0 loop0

    # Format decrypted device.
    sudo mkfs.ext4 /dev/mapper/loop0 || {
        echo "Device could not be formatted."
        return 1
    }

    # Mount device in dedicated matching directory.
    sudo mount /dev/mapper/loop0 "$DISKDEST" || {
        echo "Disk could not be mounted."
        return 1
    }

    # Give permissions of mount location to user.
    sudo chown "$USER:$USER" "$DISKDEST"

    closed --name "$DISKNAME" > /dev/null
    echo "Disk $DISKNAME succesfully created. Open it with opend."
}

# Set up a disk, decrypt it, and mount it automatically.
# Source: https://www.guide2wsl.com/luks/
opend() {
    if [[ ! $# -eq 2 ]]; then
        echo "Syntax: opend [--name <string>]"
        echo ""
        echo "Decrypt and mount an EXT4 disk image file encrypted with LUKS."
        echo "Disks must be stored in $DISKDIR."
        echo "Disks are mounted in $DISKMNT."
        echo ""
        echo "Arguments:"
        echo " -n, --name  name of the disk file"
        echo ""
        echo "See related commands created and closed."
        return 1
    fi

    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
            declare -l DISKNAME="$2"
            shift # go past argument
            shift # go past value
            ;;
            -*|--*)
            echo "Unknown argument $1."
            return 1
            ;;
        esac
    done

    # Check if all variables (arguments) are set.
    # Source: https://stackoverflow.com/a/13864829
    if [[ -z ${DISKNAME+x} ]]; then
        echo "Argument --name is required."
        return 1
    fi

    declare -l DISKPATH="$DISKDIR/$DISKNAME.img"
    declare -l DISKDEST="$DISKMNT/$DISKNAME"

    # We assume $DISKDEST is properly configured.
    if [[ ! -f "$DISKPATH" ]]; then
       echo "Disk $DISKPATH does not exist. Exiting."
       return 1
    fi

    echo "Opening disk $DISKNAME."

    # Setup the loopback device.
    sudo losetup /dev/loop0 "$DISKPATH" || {
        echo "Loopback device could not be installed."
        return 1
    }

    # Setup and decrypt device.
    sudo cryptsetup open /dev/loop0 loop0 || {
        echo "Disk could not be decrypted."
        return 1
    }

    # Mount device in dedicated matching directory.
    sudo mount /dev/mapper/loop0 "$DISKDEST" || {
        echo "Disk could not be mounted."
        return 1
    }

    echo "Disk $DISKPATH succesfully opened. Close it with closed."
    echo "Current directory set to $DISKDEST."

    cd "$DISKDEST"
}

# Unmount a disk, encrypt it, and remove it.
# This function is the equivalent inverse of opend().
# Source: https://www.guide2wsl.com/luks/
closed() {
    if [[ ! $# -eq 2 ]]; then
        echo "Syntax: closed [--name <string>]"
        echo ""
        echo "Unmount, close, and remove an opened EXT4 disk image file encrypted with LUKS."
        echo "Disks must be mounted in $DISKMNT."
        echo ""
        echo "Arguments:"
        echo " -n, --name  name of the disk file"
        echo ""
        echo "See related commands created and closed."
        return 1
    fi

    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
            declare -l DISKNAME="$2"
            shift # go past argument
            shift # go past value
            ;;
            -*|--*)
            echo "Unknown argument $1."
            return 1
            ;;
        esac
    done

    # Check if all variables (arguments) are set.
    # Source: https://stackoverflow.com/a/13864829
    if [[ -z ${DISKNAME+x} ]]; then
        echo "Argument --name is required."
        return 1
    fi

    declare -l DISKDEST="$DISKMNT/$DISKNAME"

    cd ~

    # Unmount device.
    sudo umount "$DISKDEST" || {
        echo "Disk could not be unmounted."
        return 1
    }

    # Close and encrypt loopback device.
    sudo cryptsetup close loop0 || {
        echo "Disk could not be encrypted."
        return 1
    }

    # Remove loopback device.
    sudo losetup -d /dev/loop0 || {
        echo "Loopback device could not be removed."
        return 1
    }

    echo "Disk $DISKNAME succesfully closed."
}
