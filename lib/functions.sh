#! /bin/bash

#variables
SERVER='159.65.88.73'
LIBDIR=/usr/share/manjaro-arm-tools/lib
BUILDDIR=/var/lib/manjaro-arm-tools/pkg
PACKAGER=$(cat /etc/makepkg.conf | grep PACKAGER)
PKGDIR=/var/cache/manjaro-arm-tools/pkg
ROOTFS_IMG=/var/lib/manjaro-arm-tools/img
TMPDIR=/var/lib/manjaro-arm-tools/tmp
IMGDIR=/var/cache/manjaro-arm-tools/img
IMGNAME=Manjaro-ARM-$EDITION-$DEVICE-$VERSION
PROFILES=/usr/share/manjaro-arm-tools/profiles
NSPAWN='systemd-nspawn -q --resolv-conf=copy-host --timezone=off -D'
OSDN='storage.osdn.net:/storage/groups/m/ma/manjaro-arm/'
VERSION=$(date +'%y'.'%m')
FLASHVERSION=$(date +'%y'.'%m')
ARCH='aarch64'
DEVICE='rpi3'
EDITION='minimal'
USER='manjaro'
PASSWORD='manjaro'

#import conf file
source /etc/manjaro-arm-tools/manjaro-arm-tools.conf 


usage_deploy_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = aarch64. Options = any or aarch64]"
    echo "    -p <pkg>           Package to upload"
    echo '    -r <repo>          Repository package belongs to. [Options = core, extra or community]'
    echo "    -k <gpg key ID>    Email address associated with the GPG key to use for signing"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_deploy_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -i <image>         Image to upload. Should be a .zip file."
    echo "    -d <device>        Device the image is for. [Default = rpi3. Options = rpi3, oc2, on2, rock64, rockpro64, rockpi4, sopine and pinebook]"
    echo '    -e <edition>       Edition of the image. [Default = minimal. Options = minimal, lxqt, kde, cubocore, mate and server]'
    echo "    -v <version>       Version of the image. [Default = Current YY.MM]"
    echo "    -k <gpg key ID>    Email address associated with the GPG key to use for signing"
    echo "    -t                 Create a torrent of the image"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = aarch64. Options = any or aarch64]"
    echo "    -p <pkg>           Package to build"
    echo "    -k                 Keep the previous rootfs for this build"
    echo "    -i <package>       Install local package into image rootfs."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device the image is for. [Default = rpi3. Options = rpi3, oc2, on2, rock64, rockpro64, rockpi4, sopine and pinebook]"
    echo '    -e <edition>       Edition of the image. [Default = minimal. Options = minimal, lxqt, kde, cubocore, mate and server]'
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo "    -u <user>          Username for default user. [Default = manjaro]"
    echo "    -p <password>      Password of default user. [Default = manjaro]"
    echo "    -i <package>       Install local package into image rootfs."
    echo "    -n                 Force download of new rootfs."
    echo "    -x                 Don't compress the image."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_oem() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device the image is for. [Default = rpi3. Options = rpi3, oc2, on2, rock64, rockpro64, rockpi4, sopine and pinebook]"
    echo '    -e <edition>       Edition of the image. [Default = minimal. Options = minimal, lxqt, kde, cubocore, mate and server]'
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo "    -i <package>       Install local package into image rootfs."
    echo "    -n                 Force download of new rootfs."
    echo "    -x                 Don't compress the image."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_eemcflasher() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device the image is for. [Default = rpi3. Options = rpi3, oc2, on2, rock64, rockpro64, rockpi4, sopine and pinebook]"
    echo '    -e <edition>       Edition of the image to download. [Default = minimal. Options = minimal, lxqt, kde, cubocore, mate and server]'
    echo "    -v <version>       Define the version of the release to download. [Default is current YY.MM]"
    echo "    -f <flash version> Version of the eMMC flasher image it self. [Default is current YY.MM]"
    echo "    -i <package>       Install local package into image rootfs."
    echo "    -n                 Force download of new rootfs."
    echo "    -x                 Don't compress the image."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_getarmprofiles() {
    echo "Usage: ${0##*/} [options]"
    echo '    -f                 Force download of current profiles from the git repository'
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
      local mesg=$1; shift
      printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }
 
info() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    BLUE="${BOLD}\e[1;34m"
      local mesg=$1; shift
      printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }
 
get_timer(){
    echo $(date +%s)
}

# $1: start timer
elapsed_time(){
    echo $(echo $1 $(get_timer) | awk '{ printf "%0.2f",($2-$1)/60 }')
}

show_elapsed_time(){
    msg "Time %s: %s minutes..." "$1" "$(elapsed_time $2)"
}
 
sign_pkg() {
    info "Signing [$PACKAGE] with GPG key belonging to $GPGMAIL..."
    gpg --detach-sign -u $GPGMAIL "$PACKAGE"
}

create_torrent() {
    info "Creating torrent of $IMAGE..."
    cd $IMGDIR/
    mktorrent -v -w https://osdn.net/projects/manjaro-arm/storage/$DEVICE/$EDITION/$VERSION/$IMAGE -o $IMAGE.torrent $IMAGE
}

checksum_img() {
    # Create checksums for the image
    info "Creating checksums for [$IMAGE]..."
    cd $IMGDIR/
    sha1sum $IMAGE > $IMAGE.sha1
    sha256sum $IMAGE > $IMAGE.sha256
    info "Creating signature for [$IMAGE]..."
    gpg --detach-sign -u $GPGMAIL "$IMAGE"
}

pkg_upload() {
    msg "Uploading package to server..."
    info "Please use your server login details..."
    scp $PACKAGE* $SERVER:/opt/repo/mirror/stable/$ARCH/$REPO/
    #msg "Adding [$PACKAGE] to repo..."
    #info "Please use your server login details..."
    #ssh $SERVER 'bash -s' < $LIBDIR/repo-add.sh "$@"
}

img_upload() {
    # Upload image + checksums to image server
    msg "Uploading image and checksums to server..."
    info "Please use your server login details..."
    rsync -raP $IMAGE* $OSDN/$DEVICE/$EDITION/$VERSION/
}

remove_local_pkg() {
    # remove local packages if remote packages exists, eg, if upload worked
    if ssh $SERVER "[ -f /opt/repo/mirror/stable/$ARCH/$REPO/$PACKAGE ]"; then
    msg "Removing local files..."
    rm $PACKAGE*
    else
    info "Package did not get uploaded correctly! Files not removed..."
    fi
}

create_rootfs_pkg() {
    msg "Building $PACKAGE for $ARCH..."
    # Remove old rootfs if it exists
    if [ -d $BUILDDIR/$ARCH ]; then
    info "Removing old rootfs..."
    rm -rf $BUILDDIR/$ARCH
    fi
    msg "Creating rootfs..."
    # backup host mirrorlist
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-orig

    # Create arm mirrorlist
    echo "Server = http://manjaro-arm.moson.eu/stable/\$arch/\$repo/" > mirrorlist
    mv mirrorlist /etc/pacman.d/mirrorlist

    # cd to root_fs
    mkdir -p $BUILDDIR/$ARCH

    # basescrap the rootfs filesystem
    basestrap -G -C $LIBDIR/pacman.conf.$ARCH $BUILDDIR/$ARCH base-devel manjaro-arm-keyring

    # Enable cross architecture Chrooting
    cp /usr/bin/qemu-aarch64-static $BUILDDIR/$ARCH/usr/bin/
    
    # restore original mirrorlist to host system
    mv /etc/pacman.d/mirrorlist-orig /etc/pacman.d/mirrorlist
    pacman -Syy

   msg "Configuring rootfs for building..."
    $NSPAWN $BUILDDIR/$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $BUILDDIR/$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    cp $LIBDIR/makepkg $BUILDDIR/$ARCH/usr/bin/
    $NSPAWN $BUILDDIR/$ARCH chmod +x /usr/bin/makepkg 1> /dev/null 2>&1
    rm -f $BUILDDIR/$ARCH/etc/ssl/certs/ca-certificates.crt
    rm -f $BUILDDIR/$ARCH/etc/ca-certificates/extracted/tls-ca-bundle.pem
    cp -a /etc/ssl/certs/ca-certificates.crt $BUILDDIR/$ARCH/etc/ssl/certs/
    cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $BUILDDIR/$ARCH/etc/ca-certificates/extracted/
    sed -i s/'#PACKAGER="John Doe <john@doe.com>"'/"$PACKAGER"/ $BUILDDIR/$ARCH/etc/makepkg.conf
    sed -i s/'#MAKEFLAGS="-j2"'/'MAKEFLAGS=-"j$(nproc)"'/ $BUILDDIR/$ARCH/etc/makepkg.conf
     if [[ ! -z "$ADD_PACKAGE" ]]; then
    info "Installing local package {$ADD_PACKAGE} to rootfs..."
    cp -ap $ADD_PACKAGE $BUILDDIR/$ARCH/var/cache/pacman/pkg/$ADD_PACKAGE
    $NSPAWN $BUILDDIR/$ARCH pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm
    fi
}

create_rootfs_img() {
    msg "Creating install image of $EDITION for $DEVICE..."
    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
    info "Removing old rootfs..."
    rm -rf $ROOTFS_IMG/rootfs_$ARCH
    fi
    mkdir -p $ROOTFS_IMG/rootfs_$ARCH
    if [[ "$KEEPROOTFS" = "false" ]]; then
    rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
    # fetch and extract rootfs
    info "Downloading latest $ARCH rootfs..."
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    #also fetch it, if it does not exist
    if [ ! -f "$ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz" ]; then
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    
    info "Extracting $ARCH rootfs..."
    bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH
    
    info "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    
    msg "Installing packages for $EDITION edition on $DEVICE..."
    mount -o bind /var/cache/manjaro-arm-tools/pkg/pkg-cache $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    # Install device and editions specific packages
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syyu base $PKG_DEVICE $PKG_EDITION --noconfirm
    if [[ "$DEVICE" = "on2" ]]; then
    if [[ "$EDITION" = "kde" ]] || [[ "$EDITION" = "cubocore" ]]; then
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -R sddm sddm-kcm --noconfirm
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -S sddm-n2 sddm-kcm --noconfirm
    elif [[ "$EDITION" = "lxqt" ]]; then
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -R sddm sddm-qt-manjaro-theme --noconfirm
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -S sddm-n2 sddm-qt-manjaro-theme --noconfirm
    fi
    fi
    if [[ ! -z "$ADD_PACKAGE" ]]; then
    info "Installing local package {$ADD_PACKAGE} to rootfs..."
    cp -ap $ADD_PACKAGE $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/$ADD_PACKAGE
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm
    fi
    
    info "Enabling services..."
    # Enable services
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable getty.target haveged.service resize-fs.service 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable $SRV_EDITION 1> /dev/null 2>&1

    info "Applying overlay for $EDITION edition..."
    cp -ap $PROFILES/arm-profiles/overlays/$EDITION/* $ROOTFS_IMG/rootfs_$ARCH/
    
    info "Setting up users..."
    #setup users
    echo "$USER" > $TMPDIR/user
    echo "$PASSWORD" >> $TMPDIR/password
    echo "$PASSWORD" >> $TMPDIR/password
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH passwd root < $LIBDIR/pass-root 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH useradd -m -g users -G wheel,storage,network,power,users -s /bin/bash $(cat $TMPDIR/user) 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH passwd $(cat $TMPDIR/user) < $TMPDIR/password 1> /dev/null 2>&1
    
    info "Enabling user services..."
    if [[ "$EDITION" = "minimal" ]] || [[ "$EDITION" = "server" ]]; then
        info "No user services for $EDITION edition"
    else
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH --user $(cat $TMPDIR/user) systemctl --user enable pulseaudio.service 1> /dev/null 2>&1
    fi

    info "Setting up system settings..."
    #system setup
    rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/ca-certificates.crt
    rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/tls-ca-bundle.pem
    cp -a /etc/ssl/certs/ca-certificates.crt $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/
    cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/
    echo "manjaro-arm" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/hostname 1> /dev/null 2>&1
    chown -R root:root $ROOTFS_IMG/rootfs_$ARCH/etc
    if [[ "$EDITION" != "minimal" && "$EDITION" != "server" ]]; then
    chown root:polkitd $ROOTFS_IMG/rootfs_$ARCH/etc/polkit-1/rules.d
    fi
    
    info "Doing device specific setups for $DEVICE..."
    if [[ "$DEVICE" = "rpi3" ]]; then
        echo "dtparam=audio=on" | tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt 1> /dev/null 2>&1
        echo "blacklist vchiq" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/modprobe.d/blacklist-vchiq.conf 1> /dev/null 2>&1
        echo "blacklist snd_bcm2835" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/modprobe.d/blacklist-vchiq.conf 1> /dev/null 2>&1
        echo "LABEL=BOOT  /boot   vfat    defaults        0       0" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/fstab 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "oc2" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable amlogic.service 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "on2" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable dhcpcd.service 1> /dev/null 2>&1
        echo "LABEL=BOOT  /boot   vfat    defaults        0       0" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/fstab 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "pinebook" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable pinebook-post-install.service 1> /dev/null 2>&1
    else
        info "No device specific setups for $DEVICE..."
    fi
    
    info "Cleaning rootfs for unwanted files..."
    umount $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    #rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/*
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/*
    rm -f $TMPDIR/user $TMPDIR/password
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/systemd-firstboot.service
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/machine-id

    msg "$DEVICE $EDITION rootfs complete"
}

create_rootfs_oem() {
    msg "Creating OEM image of $EDITION for $DEVICE..."
    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
    info "Removing old rootfs..."
    rm -rf $ROOTFS_IMG/rootfs_$ARCH
    fi
    mkdir -p $ROOTFS_IMG/rootfs_$ARCH
    if [[ "$KEEPROOTFS" = "false" ]]; then
    rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
    # fetch and extract rootfs
    info "Downloading latest $ARCH rootfs..."
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    #also fetch it, if it does not exist
    if [ ! -f "$ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz" ]; then
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    
    info "Extracting $ARCH rootfs..."
    bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH
    
    info "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    
    msg "Installing packages for $EDITION edition on $DEVICE..."
    # Install device and editions specific packages
    mount -o bind /var/cache/manjaro-arm-tools/pkg/pkg-cache $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syyu base $PKG_DEVICE $PKG_EDITION dialog manjaro-arm-oem-install --noconfirm
    if [[ "$DEVICE" = "on2" ]]; then
    if [[ "$EDITION" = "kde" ]] || [[ "$EDITION" = "cubocore" ]]; then
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -R sddm sddm-kcm --noconfirm
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -S sddm-n2 sddm-kcm --noconfirm
    elif [[ "$EDITION" = "lxqt" ]]; then
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -R sddm sddm-qt-manjaro-theme --noconfirm
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -S sddm-n2 sddm-qt-manjaro-theme --noconfirm
    fi
    fi
    if [[ ! -z "$ADD_PACKAGE" ]]; then
    info "Installing local package {$ADD_PACKAGE} to rootfs..."
    cp -ap $ADD_PACKAGE $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/$ADD_PACKAGE
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm
    fi
    
    info "Enabling services..."
    # Enable services
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable getty.target haveged.service resize-fs.service 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable $SRV_EDITION 1> /dev/null 2>&1
    
    #disabling services depending on edition
    if [[ "$EDITION" = "mate" ]] || [[ "$EDITION" = "i3" ]]; then
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable lightdm.service 1> /dev/null 2>&1
    elif [[ "$EDITION" = "gnome" ]]; then
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable gdm.service 1> /dev/null 2>&1
    elif [[ "$EDITION" = "minimal" ]] || [[ "$EDITION" = "server" ]]; then
    echo "No display manager in $EDITION..."
    else
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable sddm.service 1> /dev/null 2>&1
    fi

    info "Applying overlay for $EDITION edition..."
    cp -ap $PROFILES/arm-profiles/overlays/$EDITION/* $ROOTFS_IMG/rootfs_$ARCH/

    info "Setting up system settings..."
    #system setup
    rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/ca-certificates.crt
    rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/tls-ca-bundle.pem
    cp -a /etc/ssl/certs/ca-certificates.crt $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/
    cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/
    echo "manjaro-arm" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/hostname 1> /dev/null 2>&1
    echo "Enabling autologin for OEM setup..."
    mv $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service.bak
    cp $LIBDIR/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service
    echo "Correcting permissions from overlay..."
    chown -R root:root $ROOTFS_IMG/rootfs_$ARCH/etc
    if [[ "$EDITION" != "minimal" && "$EDITION" != "server" ]]; then
    chown root:polkitd $ROOTFS_IMG/rootfs_$ARCH/etc/polkit-1/rules.d
    fi
    
    
    info "Doing device specific setups for $DEVICE..."
    if [[ "$DEVICE" = "rpi3" ]]; then
        echo "dtparam=audio=on" | tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt 1> /dev/null 2>&1
        echo "blacklist vchiq" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/modprobe.d/blacklist-vchiq.conf 1> /dev/null 2>&1
        echo "blacklist snd_bcm2835" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/modprobe.d/blacklist-vchiq.conf 1> /dev/null 2>&1
        echo "LABEL=BOOT  /boot   vfat    defaults        0       0" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/fstab 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "oc2" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable amlogic.service 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "on2" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable dhcpcd.service 1> /dev/null 2>&1
        echo "LABEL=BOOT  /boot   vfat    defaults        0       0" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/fstab 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "pinebook" ]] || [[ "$DEVICE" = "sopine" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable pinebook-post-install.service 1> /dev/null 2>&1
    else
        echo "No device specific setups for $DEVICE..."
    fi
    
    info "Cleaning rootfs for unwanted files..."
    umount $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    #rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/*
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/*
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/*.pacnew
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/systemd-firstboot.service
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/machine-id

    msg "$DEVICE $EDITION rootfs complete"
}

create_emmc_install() {
    msg "Creating eMMC install image of $EDITION for $DEVICE..."
    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
    info "Removing old rootfs..."
    rm -rf $ROOTFS_IMG/rootfs_$ARCH
    fi
    mkdir -p $ROOTFS_IMG/rootfs_$ARCH
    if [[ "$KEEPROOTFS" = "false" ]]; then
    rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
    # fetch and extract rootfs
    info "Downloading latest $ARCH rootfs..."
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    #also fetch it, if it does not exist
    if [ ! -f "$ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz" ]; then
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    
    info "Extracting $ARCH rootfs..."
    bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH
    
    info "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    
    msg "Installing packages for eMMC installer edition of $EDITION on $DEVICE..."
    # Install device and editions specific packages
    mount -o bind /var/cache/manjaro-arm-tools/pkg/pkg-cache $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syyu base $PKG_DEVICE $PKG_EDITION manjaro-arm-emmc-flasher --noconfirm

    info "Enabling services..."
    # Enable services
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable getty.target haveged.service resize-fs.service 1> /dev/null 2>&1
    
    info "Setting up system settings..."
    # enable autologin
    mv $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service.bak
    cp $LIBDIR/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service
    
    info "Downloading $DEVICE $EDITION image..."
    cd $ROOTFS_IMG/rootfs_$ARCH/var/tmp/
    wget -q --show-progress --progress=bar:force:noscroll -O Manjaro-ARM.img.xz https://osdn.net/projects/manjaro-arm/storage/$DEVICE/$EDITION/$VERSION/Manjaro-ARM-$EDITION-$DEVICE-$VERSION.img.xz
    
    info "Cleaning rootfs for unwanted files..."
    umount $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    #rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/*
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/*
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/*.pacnew
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/systemd-firstboot.service
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/machine-id
}

create_img() {
    # Test for device input
    if [[ "$DEVICE" != "oc2" && "$DEVICE" != "on2" && "$DEVICE" != "pinebook" && "$DEVICE" != "sopine" && "$DEVICE" != "rpi3" && "$DEVICE" != "rock64" && "$DEVICE" != "rockpro64" && "$DEVICE" != "rockpi4" ]]; then
        echo 'Invalid device '$DEVICE', please choose one of the following'
        echo 'oc2
        on2
        pinebook
        sopine
        rpi3
        rock64
        rockpro64
        rockpi4'
        exit 1
    else
    msg "Finishing image for $DEVICE $EDITION edition..."
    info "Copying files to image..."
    fi

    ARCH='aarch64'

    #get size of blank image
    SIZE=$(du -s --block-size=MB $ROOTFS_IMG/rootfs_$ARCH | awk '{print $1}' | sed -e 's/MB//g')
    EXTRA_SIZE=300
    REAL_SIZE=`echo "$(($SIZE+$EXTRA_SIZE))"`
    
    #making blank .img to be used
    dd if=/dev/zero of=$IMGDIR/$IMGNAME.img bs=1M count=$REAL_SIZE 1> /dev/null 2>&1

    #probing loop into the kernel
    modprobe loop 1> /dev/null 2>&1

    #set up loop device
    LDEV=`losetup -f`
    DEV=`echo $LDEV | cut -d "/" -f 3`

    #mount image to loop device
    losetup $LDEV $IMGDIR/$IMGNAME.img 1> /dev/null 2>&1


    ## For Raspberry Pi devices
    if [[ "$DEVICE" = "rpi3" ]]; then
        #partition with boot and root
        parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        parted -s $LDEV mkpart primary fat32 0% 100M 1> /dev/null 2>&1
        START=`cat /sys/block/$DEV/${DEV}p1/start`
        SIZE=`cat /sys/block/$DEV/${DEV}p1/size`
        END_SECTOR=$(expr $START + $SIZE)
        parted -s $LDEV mkpart primary ext4 "${END_SECTOR}s" 100% 1> /dev/null 2>&1
        partprobe $LDEV 1> /dev/null 2>&1
        mkfs.vfat "${LDEV}p1" -n BOOT 1> /dev/null 2>&1
        mkfs.ext4 "${LDEV}p2" -L ROOT 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        mkdir -p $TMPDIR/boot
        mount ${LDEV}p1 $TMPDIR/boot
        mount ${LDEV}p2 $TMPDIR/root
        cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        mv $TMPDIR/root/boot/* $TMPDIR/boot

    #clean up
        umount $TMPDIR/root
        umount $TMPDIR/boot
        losetup -d $LDEV 1> /dev/null 2>&1
        rm -r $TMPDIR/root $TMPDIR/boot
        partprobe $LDEV 1> /dev/null 2>&1

    ## For Odroid devices
    elif [[ "$DEVICE" = "oc2" ]]; then
        #Clear first 8mb
        dd if=/dev/zero of=${LDEV} bs=1M count=8 1> /dev/null 2>&1
	
    #partition with a single root partition
        parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        parted -s $LDEV mkpart primary ext4 0% 100% 1> /dev/null 2>&1
        partprobe $LDEV 1> /dev/null 2>&1
        mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 -L ROOT 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        chmod 777 -R $TMPDIR/root
        mount ${LDEV}p1 $TMPDIR/root
        cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/

    #flash bootloader
        cd $TMPDIR/root/boot/
        ./sd_fusing.sh $LDEV 1> /dev/null 2>&1
        cd ~

    #clean up
        umount $TMPDIR/root
        losetup -d $LDEV 1> /dev/null 2>&1
        rm -r $TMPDIR/root
        partprobe $LDEV 1> /dev/null 2>&1
        
    elif [[ "$DEVICE" = "on2" ]]; then
        #Clear first 8 mb
        dd if=/dev/zero of=${LDEV} bs=1M count=8 1> /dev/null 2>&1
        
    #partition with 2 partitions
        parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        parted -s $LDEV mkpart primary fat32 0% 256M 1> /dev/null 2>&1
        START=`cat /sys/block/$DEV/${DEV}p1/start`
        SIZE=`cat /sys/block/$DEV/${DEV}p1/size`
        END_SECTOR=$(expr $START + $SIZE)
        parted -s $LDEV mkpart primary ext4 "${END_SECTOR}s" 100% 1> /dev/null 2>&1
        partprobe $LDEV 1> /dev/null 2>&1
        mkfs.vfat "${LDEV}p1" -n BOOT 1>/dev/null 2>&1
        mkfs.ext4 "${LDEV}p2" -L ROOT 1> /dev/null 2>&1
        
    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        mkdir -p $TMPDIR/boot
        mount ${LDEV}p1 $TMPDIR/boot
        mount ${LDEV}p2 $TMPDIR/root
        cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        mv $TMPDIR/root/boot/* $TMPDIR/boot
        
    #flash bootloader
        dd if=$TMPDIR/boot/u-boot.bin of=${LDEV} conv=fsync,notrunc bs=512 seek=1 1> /dev/null 2>&1
        
    #clean up
        umount $TMPDIR/root
        umount $TMPDIR/boot
        losetup -d $LDEV 1> /dev/null 2>&1
        rm -r $TMPDIR/root $TMPDIR/boot
        partprobe $LDEV 1> /dev/null 2>&1

    ## For pine devices
    elif [[ "$DEVICE" = "pinebook" ]] || [[ "$DEVICE" = "sopine" ]]; then

    #Clear first 8mb
        dd if=/dev/zero of=${LDEV} bs=1M count=8 1> /dev/null 2>&1
	
    #partition with a single root partition
        parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        parted -s $LDEV mkpart primary ext4 0% 100% 1> /dev/null 2>&1
        partprobe $LDEV 1> /dev/null 2>&1
        mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 -L ROOT 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        chmod 777 -R $TMPDIR/root
        mount ${LDEV}p1 $TMPDIR/root
        cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        
    #flash bootloader
        dd if=$TMPDIR/root/boot/u-boot-sunxi-with-spl-$DEVICE.bin of=${LDEV} bs=8k seek=1 1> /dev/null 2>&1

    #clean up
        umount $TMPDIR/root
        losetup -d $LDEV 1> /dev/null 2>&1
        rm -r $TMPDIR/root
        partprobe $LDEV 1> /dev/null 2>&1
        
    ## For rockchip devices
    elif [[ "$DEVICE" = "rock64" ]] || [[ "$DEVICE" = "rockpro64" ]] || [[ "$DEVICE" = "rockpi4" ]]; then

    #Clear first 32mb
        dd if=/dev/zero of=${LDEV} bs=1M count=32 1> /dev/null 2>&1
	
    #partition with a single root partition
        parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        parted -s $LDEV mkpart primary ext4 32M 100% 1> /dev/null 2>&1
        partprobe $LDEV 1> /dev/null 2>&1
        mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 -L ROOT 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        chmod 777 -R $TMPDIR/root
        mount ${LDEV}p1 $TMPDIR/root
        cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        
    #flash bootloader
        dd if=$TMPDIR/root/boot/idbloader.img of=${LDEV} seek=64 conv=notrunc 1> /dev/null 2>&1
        dd if=$TMPDIR/root/boot/uboot.img of=${LDEV} seek=16384 conv=notrunc 1> /dev/null 2>&1
        dd if=$TMPDIR/root/boot/trust.img of=${LDEV} seek=24576 conv=notrunc 1> /dev/null 2>&1
        
    #clean up
        umount $TMPDIR/root
        losetup -d $LDEV 1> /dev/null 2>&1
        rm -r $TMPDIR/root
        partprobe $LDEV 1> /dev/null 2>&1

    else
        #Not sure if this IF statement is nesssary anymore
        info "The $DEVICE has not been set up yet"
    fi
    chmod 666 $IMGDIR/$IMGNAME.img
}

create_zip() {
    info "Compressing $IMGNAME.img..."
    #zip img
    cd $IMGDIR
    xz -zv --threads=0 $IMGNAME.img
    chmod 666 $IMGDIR/$IMGNAME.img.xz

    info "Removing rootfs_$ARCH"
    rm -rf $ROOTFS_IMG/rootfs_$ARCH
}

build_pkg() {
    #cp package to rootfs
    msg "Copying build directory {$PACKAGE} to rootfs..."
    $NSPAWN $BUILDDIR/$ARCH mkdir build 1> /dev/null 2>&1
    cp -rp "$PACKAGE"/* $BUILDDIR/$ARCH/build/

    #build package
    msg "Building {$PACKAGE}..."
    $NSPAWN $BUILDDIR/$ARCH/ chmod -R 777 build/ 1> /dev/null 2>&1
    mount -o bind /var/cache/manjaro-arm-tools/pkg/pkg-cache $BUILDDIR/$ARCH/var/cache/pacman/pkg
    $NSPAWN $BUILDDIR/$ARCH/ --chdir=/build/ makepkg -sc --noconfirm
    umount $BUILDDIR/$ARCH/var/cache/pacman/pkg
}

export_and_clean() {
    if ls $BUILDDIR/$ARCH/build/*.pkg.tar.xz* 1> /dev/null 2>&1; then
        #pull package out of rootfs
        msg "Package Succeeded..."
        info "Extracting finished package out of rootfs..."
        mkdir -p $PKGDIR/$ARCH
        cp $BUILDDIR/$ARCH/build/*.pkg.tar.xz* $PKGDIR/$ARCH/
        chmod 666 $PKGDIR/$ARCH/$PACKAGE*
        msg "Package saved as {$PACKAGE} in {$PKGDIR/$ARCH}..."

        #clean up rootfs
        info "Cleaning build files from rootfs"
        rm -rf $BUILDDIR/$ARCH/build/

    else
        msg "!!!!! Package failed to build !!!!!"
        info "Cleaning build files from rootfs"
        rm -rf $BUILDDIR/$ARCH/build/
        exit 1
    fi
}

get_profiles() {
    if ls $PROFILES/arm-profiles/* 1> /dev/null 2>&1; then
        cd $PROFILES/arm-profiles
        git pull
    else
        cd $PROFILES
        git clone https://gitlab.com/Strit/arm-profiles.git
    fi
}
