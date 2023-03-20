# ~/scripts/utils-encryption.sh: executed by bash(1) for all shells (via .bash_functions).
# Manipulate (create, open, close, and back up) encrypted disk images files.


# Credits ----------------------------------------------------------------------


# Functions creatd(), opend(), and closed() are an attempt to automate and
# generalize steps of sections Encrypting WSL2 disks of Guide 2 WSL written
# by Tom Christie (https://www.guide2wsl.com/luks/).

# Multiple disks can be used simultaneously. Mapping is fully automated. There
# is no need to know which loop devices are available or not. Features are
# safer by design.

# Function backd() pushes backups to a cloud remote via rclone by default. Use
# flag --local to create a local backup in $diskImagesMainDir. Else, set global
# variables $diskBackupRemoteName and $diskBackupRemoteMainDir below.


# Globals ----------------------------------------------------------------------


# Examples of standard variables used below.
#   - diskName=test
#   - diskSizeMb=20
#   - diskBlocksCount=5120
#   - diskImagesMainDir=~/enc/
#   - diskMountMainDir=~/dec/
#   - diskImagePath=~/enc/test.img
#   - diskMountDir=~/dec/test/
#   - diskLoopDevicePath=/dev/loop0
#   - diskBackupName=test-2023-01-01.img.xz
#   - diskBackupPath=~/enc/test-2023-01-01.img.xz
#   - diskBackupRemoteName=gdrive:
#   - diskBackupRemoteMainDir=Backups/luks/
#   - diskBackupRemotePath=gdrive:Backups/luks/test-2023-01-01.img.xz


declare diskImagesMainDir=~/enc/
declare diskMountMainDir=~/dec/
declare diskBackupRemoteName=gdrive:
declare diskBackupRemoteMainDir=Backups/luks/


# Functions --------------------------------------------------------------------


created() {
    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                declare diskName="$2"
                shift # go past argument
                shift # go past value
                ;;
            -s|--size)
                declare -i diskSizeMb="$2"
                shift # go past argument
                shift # go past value
                ;;
            -h|--help)
                echo "Syntax: created --name <string> --size <integer>"
                echo ""
                echo "Create an LUKS2 encrypted EXT4 disk image file."
                echo "Images are stored in $diskImagesMainDir."
                echo "Disks are mounted in $diskMountMainDir."
                echo ""
                echo "Arguments:"
                echo " -n, --name  name of the disk file"
                echo " -s, --size  desired size of the disk file in MB (20 MB minimum)"
                echo " -h, --help  show this help message"
                echo ""
                echo "See related commands opend, closed, and backd."
                return 1
                ;;
            *|-*|--*)
                echo "Unknown argument $1. See created --help."
                return 1
                ;;
        esac
    done

    # Check if all variables (arguments) are set.
    # Source: https://stackoverflow.com/a/13864829
    if [[ -z ${diskName+x} ]] || [[ -z ${diskSizeMb+x} ]]; then
        echo "Arguments --name and --size are both required. See created --help."
        return 1
    fi

    if [[ $diskSizeMb -lt 20 ]]; then
        echo "Size must be greater than 20 MB to allocate enough space for LUKS header."
        return 1
    fi

    # Number of blocks is equal to SIZE_IN_MB * (1024 KB/MB) / (4 KB/BLOCK).
    # This is because EXT4 filesystems typically uses blocks of size 4KB.
    declare diskImagePath="$diskImagesMainDir$diskName.img"
    declare diskMountDir="$diskMountMainDir$diskName"
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
    declare diskLoopDevicePath=$(sudo losetup --show --find "$diskImagePath") || {
        echo "Loopback device could not be set."
        return 1
    }

    declare diskLoopDeviceName=$(basename "$diskLoopDevicePath")
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
    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                declare diskName="$2"
                shift # go past argument
                shift # go past value
                ;;
            -h|--help)
                echo "Syntax: opend --name <string>"
                echo ""
                echo "Set, decrypt, and mount an encrypted EXT4 disk image file."
                echo "Images must be stored in $diskImagesMainDir."
                echo "Disks are mounted in $diskMountMainDir."
                echo ""
                echo "Arguments:"
                echo " -n, --name  name of the disk file"
                echo " -h, --help  show this help message"
                echo ""
                echo "See related commands created, closed, and backd."
                return 1
                ;;
            *|-*|--*)
                echo "Unknown argument $1. See opend --help."
                return 1
                ;;
        esac
    done

    # Check if all variables (arguments) are set.
    # Source: https://stackoverflow.com/a/13864829
    if [[ -z ${diskName+x} ]]; then
        echo "Argument --name is required. See opend --help."
        return 1
    fi

    declare diskImagePath="$diskImagesMainDir$diskName.img"
    declare diskMountDir="$diskMountMainDir$diskName"

    # We assume $diskMountDir is properly configured.
    if [[ ! -f "$diskImagePath" ]]; then
       echo "Disk $diskImagePath does not exist. Exiting."
       return 1
    fi

    echo "Opening disk $diskName."

    # Set the loopback device.
    # Find next available one and record both its path and its name.
    declare diskLoopDevicePath=$(sudo losetup --show --find "$diskImagePath") || {
        echo "Loopback device could not be set."
        return 1
    }

    declare diskLoopDeviceName=$(basename "$diskLoopDevicePath")
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
    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                declare diskName="$2"
                shift # go past argument
                shift # go past value
                ;;
            -h|--help)
                echo "Syntax: closed --name <string>"
                echo ""
                echo "Unmount, close, and remove an encrypted EXT4 disk image file set as a loop device."
                echo "Disks must be mounted in $diskMountMainDir."
                echo ""
                echo "Arguments:"
                echo " -n, --name  name of the disk file"
                echo " -h, --help  show this help message"
                echo ""
                echo "See related commands created, closed, and backd."
                return 1
                ;;
            *|-*|--*)
                echo "Unknown argument $1. See closed --help."
                return 1
                ;;
        esac
    done

    # Check if all variables (arguments) are set.
    # Source: https://stackoverflow.com/a/13864829
    if [[ -z ${diskName+x} ]]; then
        echo "Argument --name is required. See closed --help."
        return 1
    fi

    declare diskImagePath="$diskImagesMainDir$diskName.img"
    declare diskMountDir="$diskMountMainDir$diskName"
    declare diskLoopDevicePath=$(losetup -j "$diskImagePath" | grep --only-matching --perl-regexp "^(.*?)(?=: \[\]:)")
    declare diskLoopDeviceName=$(basename "$diskLoopDevicePath")

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
    # Parse arguments.
    # Source: https://stackoverflow.com/a/14203146.
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                declare diskName="$2"
                shift # go past argument
                shift # go past value
                ;;
            -h|--help)
                echo "Syntax: backd [--local] --name <string>"
                echo ""
                echo "Back up an EXT4 disk image file with XZ."
                echo "Push it to "$diskBackupRemoteName$diskBackupRemoteMainDir" via rclone."
                echo "Disks must be stored in $diskImagesMainDir."
                echo ""
                echo "Arguments:"
                echo " -n, --name   name of the disk file"
                echo " -l, --local  keep local back up and do not push it to $diskBackupRemoteName with rclone"
                echo " -h, --help   show this help message"
                echo ""
                echo "See related commands created, opend, and closed."
                echo ""
                echo "Tips:"
                echo " - To back up a disk containing an rclone profile,"
                echo "   close it first. Then, reopen it and call backd."
                return 1
                ;;
            *|-*|--*)
                echo "Unknown argument $1. See backd --help."
                return 1
                ;;
        esac
    done

    # Check if all variables (arguments) are set.
    # Source: https://stackoverflow.com/a/13864829
    if [[ -z ${diskName+x} ]]; then
        echo "Argument --name is required. See backd --help."
        return 1
    fi

    declare todayDate=$(date +"%Y-%m-%d")
    declare diskImagePath="$diskImagesMainDir$diskName.img"
    declare diskBackupName="$diskName-$todayDate.img.xz"
    declare diskBackupPath="$diskImagesMainDir$diskBackupName"
    declare diskBackupRemotePath="$diskBackupRemoteName$diskBackupRemoteMainDir$diskBackupName"

    if [[ ! -f "$diskImagePath" ]]; then
       echo "Disk $diskImagePath does not exist. Exiting."
       return 1
    fi

    # Compress image with XZ. Maximize compression.
    # By default, XZ reuses file names and appends .xz to them.
    xz --compress --keep --format=xz --check=sha256 -9 --extreme --threads=0 --verbose "$diskImagePath"
    mv "$diskImagePath.xz" "$diskBackupPath"
    echo "Disk $diskName succesfully backed up to $diskBackupPath."

    # Push backup to remote using rclone.
    if [[ -z ${localFlag+x} && $(command -v rclone) ]]; then
        rclone moveto "$diskBackupPath" "$diskBackupRemotePath" --progress
        echo "Disk $diskName succesfully pushed up to Google Drive ($diskBackupPath was removed)."
    fi
}

listd() {
    echo "Listing encrypted disks of $USER."
    echo "  Opened disks:"
    losetup -a | sed \
        -e 's,\[\]: ,,g' \
        -e 's,[()],,g'   \
        -e 's,\.img$,,g' \
        -e "s,$diskImagesMainDir,,g" \
        -e 's,\: , -> ,g' \
        -e 's,^,    - ,g'

    echo "  Available disks stored in $diskImagesMainDir:"
    ls -1 enc | sed \
        -e 's,\.img$,,g' \
        -e 's,^,    - ,g'
}
