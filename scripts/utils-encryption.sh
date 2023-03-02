# ~/scripts/utils-encryption.sh: executed by bash(1) for all shells (via .bash_functions).
# Manipulate (create, open, close, and back up) encrypted disk images files.


# Credits ----------------------------------------------------------------------


# Functions creatd(), opend(), and closed() are an attempt to automate and
# generalize steps of sections Encrypting WSL2 disks of Guide 2 WSL written
# by Tom Christie (https://www.guide2wsl.com/luks/).

# Multiple disks can be used simultaneously. Mapping is fully automated. There
# is no need to know which loop devices are available or not. Features are
# safer by design. You can set the following aliases to list all disks and
# those that are opened:
#
# alias listd="find $diskImagesMainDir -maxdepth 1 -mindepth 1"
# alias listod="losetup -a"


# Globals ----------------------------------------------------------------------


# Examples of standard variables used below.
#   - diskImagesMainDir=~/enc/
#   - diskMountMainDir=~/dec/
#   - diskName=test
#   - diskSizeMb=20
#   - diskImagePath=~/enc/test.img
#   - diskMountDir=~/dec/test/
#   - diskBlocksCount=5120
#   - diskLoopDevicePath=/dev/loop0


declare -l diskImagesMainDir=~/enc/
declare -l diskMountMainDir=~/dec/


# Functions --------------------------------------------------------------------


created() {
    if [[ ! $# -eq 4 ]]; then
        echo "Syntax: created [--name <string>] [--size <integer>]"
        echo ""
        echo "Create an LUKS2 encrypted EXT4 disk image file."
        echo "Images are stored in $diskImagesMainDir."
        echo "Disks are mounted in $diskMountMainDir."
        echo ""
        echo "Arguments:"
        echo " -n, --name  name of the disk file"
        echo " -s, --size  desired size of the disk file in MB (20 MB minimum)"
        echo ""
        echo "See related commands opend, closed, and backd."
        return 1
    fi

    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
            declare -l diskName="$2"
            shift # go past argument
            shift # go past value
            ;;
            -s|--size)
            declare -i diskSizeMb="$2"
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
    if [[ -z ${diskName+x} ]] || [[ -z ${diskSizeMb+x} ]]; then
        echo "Arguments --name and --size are both required."
        return 1
    fi

    if [[ $diskSizeMb -lt 20 ]]; then
        echo "Size must be greater than 20 MB to allocate enough space for LUKS header."
        return 1
    fi

    # Number of blocks is equal to SIZE_IN_MB * (1024 KB/MB) / (4 KB/BLOCK).
    # This is because EXT4 filesystems typically uses blocks of size 4KB.
    declare -l diskImagePath="$diskImagesMainDir$diskName.img"
    declare -l diskMountDir="$diskMountMainDir$diskName"
    declare -i diskBlocksCount="$diskSizeMb"*1024/4

    # Create future mount directory if it does not exist.
    if [[ ! -d "$diskMountDir" ]]; then
        echo "Creating $diskMountDir."
        mkdir "$diskMountDir"
    fi

    # Create disk image file.
    echo "Creating disk $diskName of $diskSizeMb MB ($diskBlocksCount blocks)."
    dd if=/dev/zero of="$diskImagePath" bs=4k count=$diskBlocksCount

    # Set the loopback device.
    # Find next available one and record both its path and its name.
    echo "Setting loopback device."
    declare -l diskLoopDevicePath=$(sudo losetup --show --find "$diskImagePath") || {
        echo "Loopback device could not be set."
        return 1
    }

    declare -l diskLoopDeviceName=$(basename "$diskLoopDevicePath")
    echo "Using loopback device $diskLoopDeviceName ($diskLoopDevicePath)."

    # Initialize a LUKS partition on device and set initial passphrase.
    # When cryptsetup > 2.4.0 is used, these arguments are used via luksFormat:
    #  --type luks2             : use latest version of Linux Unified Key System
    #  --cipher aes-xts-plain64 : use same cipher as VirtualBox
    #  --hash sha256            : hashing algorithm used to derive key from passphrase
    #  --iter-time 2000         : time to spend with PBKDF2 passphrase processing (milliseconds)
    #  --key-size 256           : bit size of XTS ciphers; split in half so AES-XTS256-PLAIN64 is used in practice
    #  --pbkdf argon2id         : set Password-Based Key Derivation Function algorithm for LUKS keyslot
    #  --use-urandom            : RNG to use
    # Source: https://wiki.archlinux.org/title/dm-crypt/Device_encryption
    echo "Setting disk encryption using LUKS2."
    sudo cryptsetup luksFormat --batch-mode --verify-passphrase "$diskLoopDevicePath" || {
        echo "LUKS headers could not be set for device $diskLoopDevicePath."
        return 1
    }

    # Decrypt device and map it to loop device.
    echo "Opening encrypted disk $diskName."
    sudo cryptsetup open "$diskLoopDevicePath" "$diskLoopDeviceName"

    # Format decrypted device as an EXT4 filesystem.
    echo "Formatting disk $diskName."
    sudo mkfs.ext4 "/dev/mapper/$diskLoopDeviceName" || {
        echo "Device could not be formatted."
        return 1
    }

    # Mount device in dedicated mount directory.
    echo "Mounting device in $diskMountDir."
    sudo mount "/dev/mapper/$diskLoopDeviceName" "$diskMountDir" || {
        echo "Disk could not be mounted."
        return 1
    }

    # Give permissions of mount location to user.
    sudo chown "$USER:$USER" "$diskMountDir"

    closed --name "$diskName" > /dev/null
    echo "Disk $diskName succesfully created. Open it with opend."
}

opend() {
    if [[ ! $# -eq 2 ]]; then
        echo "Syntax: opend [--name <string>]"
        echo ""
        echo "Set, decrypt, and mount an encrypted EXT4 disk image file."
        echo "Images must be stored in $diskImagesMainDir."
        echo "Disks are mounted in $diskMountMainDir."
        echo ""
        echo "Arguments:"
        echo " -n, --name  name of the disk file"
        echo ""
        echo "See related commands created, closed, and backd."
        return 1
    fi

    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
            declare -l diskName="$2"
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
    if [[ -z ${diskName+x} ]]; then
        echo "Argument --name is required."
        return 1
    fi

    declare -l diskImagePath="$diskImagesMainDir$diskName.img"
    declare -l diskMountDir="$diskMountMainDir$diskName"

    # We assume $diskMountDir is properly configured.
    if [[ ! -f "$diskImagePath" ]]; then
       echo "Disk $diskImagePath does not exist. Exiting."
       return 1
    fi

    echo "Opening disk $diskName."

    # Set the loopback device.
    # Find next available one and record both its path and its name.
    declare -l diskLoopDevicePath=$(sudo losetup --show --find "$diskImagePath") || {
        echo "Loopback device could not be set."
        return 1
    }

    declare -l diskLoopDeviceName=$(basename "$diskLoopDevicePath")
    echo "Using loopback device $diskLoopDeviceName ($diskLoopDevicePath)."

    # Decrypt device and map it to loop device.
    sudo cryptsetup open "$diskLoopDevicePath" "$diskLoopDeviceName" || {
        echo "Disk could not be decrypted."
        return 1
    }

    # Mount device in dedicated mount directory.
    sudo mount "/dev/mapper/$diskLoopDeviceName" "$diskMountDir" || {
        echo "Disk could not be mounted."
        return 1
    }

    echo "Disk $diskImagePath succesfully opened. Close it with closed."
    echo "Current directory set to $diskMountDir."
    cd "$diskMountDir"
}

closed() {
    if [[ ! $# -eq 2 ]]; then
        echo "Syntax: closed [--name <string>]"
        echo ""
        echo "Unmount, close, and remove an encrypted EXT4 disk image file set as a loop device."
        echo "Disks must be mounted in $diskMountMainDir."
        echo ""
        echo "Arguments:"
        echo " -n, --name  name of the disk file"
        echo ""
        echo "See related commands created, closed, and backd."
        return 1
    fi

    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
            declare -l diskName="$2"
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
    if [[ -z ${diskName+x} ]]; then
        echo "Argument --name is required."
        return 1
    fi

    declare -l diskImagePath="$diskImagesMainDir$diskName.img"
    declare -l diskMountDir="$diskMountMainDir$diskName"
    declare -l diskLoopDevicePath=$(losetup -j "$diskImagePath" | grep --only-matching --perl-regexp "^(.*?)(?=: \[\]:)")
    declare -l diskLoopDeviceName=$(basename "$diskLoopDevicePath")

    cd ~

    # Unmount device.
    sudo umount "$diskMountDir" || {
        echo "Disk could not be unmounted."
        return 1
    }

    # Close and encrypt loopback device.
    sudo cryptsetup close "$diskLoopDeviceName" || {
        echo "Disk could not be encrypted."
        return 1
    }

    # Remove loopback device.
    sudo losetup -d "$diskLoopDevicePath" || {
        echo "Loopback device could not be removed."
        return 1
    }

    echo "Disk $diskName succesfully closed."
}

backd() {
    if [[ ! $# -eq 2 ]]; then
        echo "Syntax: backd [--name <string>]"
        echo ""
        echo "Back up an EXT4 disk image file with XZ."
        echo "Disks must be stored in $diskImagesMainDir."
        echo ""
        echo "Arguments:"
        echo " -n, --name  name of the disk file"
        echo ""
        echo "See related commands created, opend, and closed."
        return 1
    fi

    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
            declare -l diskName="$2"
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
    if [[ -z ${diskName+x} ]]; then
        echo "Argument --name is required."
        return 1
    fi

    declare -l todayDate=$(date +"%Y-%m-%d")
    declare -l diskImagePath="$diskImagesMainDir$diskName.img"
    declare -l diskBackupPath="$diskImagesMainDir$diskName-$todayDate.img.xz"

    if [[ ! -f "$diskImagePath" ]]; then
       echo "Disk $diskImagePath does not exist. Exiting."
       return 1
    fi

    # Compress image with XZ. Maximize compression.
    # By default, XZ reuses file names and appends .xz to them.
    xz --compress --keep --format=xz --check=sha256 -9 --extreme --threads=0 --verbose "$diskImagePath"
    mv "$diskImagePath.xz" "$diskBackupPath"
    echo "Disk $diskName succesfully backed up to $diskBackupPath."
}
