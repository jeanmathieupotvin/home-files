# ~/user-auto-mount-points.sh: executed manually by user.
# Auto-mount partitions in custom folders when computer is booted.

# Sources:
#  - techrepublic.com/article/how-to-properly-automount-a-drive-in-ubuntu-linux


# List all mountable partitions.
sudo fdisk -l

# Partitions to mount.
# DATA (Secondary disk data) : /dev/sda2

# Get uuid of partitions.
sudo blkid

# Create a mount point.
# A mount point is a directory that can be used to access disks.
# Turns out you cannot use /dev/sdj as Linux does.
sudo mkdir /disks
sudo mkdir /disks/data

# Change mount point's directory permissions.
# We first create a group to manage who can access /disks.
# Then, we add user jmp (me) to this group.
# Then, we give ownership of /disks to this group.
sudo groupadd disks
sudo usermod -aG disks jmp
sudo chown -R :disks /disks

# Create an automount entry.
sudo nano /etc/fstab

# We add the following lines to the bottom of this file.
# Here are the options we should use.
#   1. auto        - automatically determine the file system.
#   2. nosuid      - ensures the filesystem cannot contain set userid files.
#                    This prevents root escalation and other security issues.
#   3. nodev       - ensures the filesystem cannot contain special devices.
#                    This prevents access to random device hardware.
#   4. nofail      - removes the errorcheck.
#   5. x-gvfs-show - shows mount option in the file manager.
#                    If GUI-less server, this is not necessary.
#   6. 0           - Which filesystems need to be dumped (0 is default).
#   7. 0           - Order in which filesystem checks are done at boot time
#                    (0 is default).
UUID=<uuid> /disks/data  auto nosuid,nodev,nofail,x-gvfs-show 0 0

# Test the automount entry.
# No error implies entry is correct.
sudo mount -a
