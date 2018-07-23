#!/usr/bin/env bash
set -e

ROOTPASSWORD=$1
USERNAME=$2
USERPASSWORD=$3

echo "updating"
locale-gen
hwclock --systohc
pacman-key --populate archlinux
pacman-key --init
updatedb
pkgfile --update

echo "adding colour"
sed -i 's/#Color/Color/' /etc/pacman.conf

# setting up the user
echo "creating Root password"
echo -e "${ROOTPASSWORD}\n${ROOTPASSWORD}" | passwd root
useradd -m -G wheel,users -s /bin/bash ${USERNAME}
echo -e "${USERPASSWORD}\n${USERPASSWORD}" | passwd ${USERNAME}
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/10_wheel
chmod 640 /etc/sudoers.d/10_wheel

# Create any missing directories
mkdir -p /etc/pacman.d/hooks

# Change sudoers to allow nobody user access to sudo without password
echo 'nobody ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99_nobody

# Create Build Directorys and set permissions
mkdir /tmp/build
chgrp nobody /tmp/build
chmod g+ws /tmp/build
setfacl -m u::rwx,g::rwx /tmp/build
setfacl -d --set u::rwx,g::rwx,o::- /tmp/build
cd /tmp/build/

# Install Yay AUR Helper
sudo -u nobody curl -SLO https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz
sudo -u nobody tar -zxvf yay.tar.gz
cd yay
sudo -u nobody makepkg -s -i --noconfirm
cd ../..
rm -r build

# Change sudoers to allow wheel group access to sudo with password
rm /etc/sudoers.d/99_nobody
