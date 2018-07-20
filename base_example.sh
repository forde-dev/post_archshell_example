#!/usr/bin/env bash

set -e

# this checks if the system is uefi
if [ ! -d "/sys/firmware/efi/" ]; then
	echo "This script only works in UEFI"
	exit 1
fi
# set a root password
ROOTPASSWORD="password"

# set a username for your user
USERNAME="user"

# set a password for your user
USERPASSWORD="userpassword"

# set a hostname for the system
HOSTNAME="computer"

# set the drive to install on (more on that in a moment)
DRIVE="/dev/sda"

# set keymap for the keyboard
KEYMAP="uk"

# set up what packages need to be installed (also more on this below)
PKG="base base-devel grub wireless_tools nfs-utils ntfs-3g openssh pkgfile pacman-contrib mlocate mlocate alsa-utils bash-completion rsync"

# clocks
# this enables the time controller
echo "Setting local time"
timedatectl set-ntp true

# this syncs with the system clock
hwclock --systohc --utc

# keyboard
# this loads the keyboard depending on your country as set in the variables
echo "Loading Uk Keymap for the keyboard"
loadkeys ${KEYMAP}


# this wipes and formates the drive
echo "# Wriping Drive and segergating"
sgdisk -Z ${DRIVE}

# this optimumises the partition
sgdisk -a 2048 -o ${DRIVE}

# this makes the EFI partition
echo "Setup UEFI Boot Partition"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" ${DRIVE}

# this makes the EFI partition a vfat filesystem
mkfs.vfat ${DRIVE}1

# this create the swap partition
echo "Setup Swap"
sgdisk -n 2:0:+2G -t 2:8200 -c 2:"Swap Partition" ${DRIVE}

# this makes the ROOT partition
echo "Setup Root"
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux / Partition" ${DRIVE}

# this sets the ROOT partitions file system to ext4
mkfs.ext4 ${DRIVE}3

# this mounts the ROOT partition
echo "# Mounting Partitions"
mount ${DRIVE}3 /mnt

# this creates a /boot/efi directory
mkdir -pv /mnt/boot/efi

# this mounts the EFI
mount ${DRIVE}1 /mnt/boot/efi

# this makes the swap
echo "Enable Swap Partition"
mkswap ${DRIVE}2

# this mounts the swap
swapon ${DRIVE}2

# ths installs reflector
echo "Downloading and Install reflector installation requirements"
pacman -Sy --noconfirm --needed reflector

# this downloads and sort Mirrors List from Archlinux.org
echo "Downloading and Ranking mirrors"
reflector --verbose --protocol http --latest 200 --number 20 --sort rate --save /etc/pacman.d/mirrorlist

# this updates the database
pacman -Syy

# this installs all the packages that we have in our PKG variable
echo "# Installing Main System"
pacstrap /mnt ${PKG}


echo "# Creating Fstab Entrys"
genfstab -U /mnt >> /mnt/etc/fstab

# Core Configuration #

echo "Configuring Network"
rm /mnt/etc/resolv.conf
ln -sf "/run/systemd/resolve/stub-resolv.conf" /mnt/etc/resolv.conf
cat > /mnt/etc/systemd/network/20-wired.network <<NET_EOF
[Match]
Name=en*
[Network]
DHCP=ipv4
NET_EOF

# Set Console keymap
echo "Setting KEYMAP"
echo "KEYMAP=$KEYMAP" >> /mnt/etc/vconsole.conf

# Set Hostname
echo "Setting Hostname"
echo "${HOSTNAME}" > /mnt/etc/hostname

# set location to ireland

echo "Setting Locale to en_IE"

sed -i 's/^en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/^#en_IE.UTF-8/en_IE.UTF-8/' /etc/locale.gen
echo "LANG=en_IE.UTF-8" > /etc/locale.conf
export LANG=en_IE.UTF-8
locale-gen
echo ""

# Set Timezone
echo "Setting Timezone"
ln -sf "/usr/share/zoneinfo/Europe/Dublin" /mnt/etc/localtime

# Enable required services
echo "Setting up Systemd Services"
arch-chroot /mnt systemctl enable systemd-networkd.service systemd-resolved.service

# Finalizing #

# Execute the post configurations within chroot
cp post_example.sh /mnt/root/
arch-chroot /mnt sh /root/post_example.sh ${ROOTPASSWORD} ${USERNAME} ${USERPASSWORD}
rm /mnt/root/post_example.sh

echo "Unmounting Drive Partitions"
swapoff ${DRIVE}2
umount /mnt/boot/efi
umount /mnt

# Finsihing Note #

echo ""
echo "Finised Core Install"
echo
echo
echo
echo "After reboot login as your user"
