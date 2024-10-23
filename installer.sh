#!/data/data/com.termux/files/usr/bin/bash

# Function to prompt user to choose Ubuntu version
choose_ubuntu_version() {
    echo "Choose your Ubuntu version:"
    echo "1) Trusty Tahr (14.04)"
    echo "2) Xenial Xerus (16.04)"
    echo "3) Bionic Beaver (18.04)"
    echo "4) Focal Fossa (20.04)"
    echo "5) Jammy Jellyfish (22.04)"
    echo "6) Mantic Minotaur (23.10)"
    echo "7) Abort The Installation"
    read -p "Enter the number of your Ubuntu version: " selected_version_index

    case "$selected_version_index" in
        1) ubuntu_version="trusty" ;;
        2) ubuntu_version="xenial" ;;
        3) ubuntu_version="bionic" ;;
        4) ubuntu_version="focal" ;;
        5) ubuntu_version="jammy" ;;
        6) ubuntu_version="mantic" ;;
        7) exit ;;
        *) echo "Invalid option"; choose_ubuntu_version ;;
    esac
}

# Function to prompt user to choose architecture
choose_userarch() {
    echo "Choose your architecture:"
    echo "1) armhf"
    echo "2) arm64"
    echo "3) Abort"
    read -p "Enter your choice (1/2/3): " choice

    case "$choice" in
        1) userarch="armhf" ;;
        2) userarch="arm64" ;;
        3) exit ;;
        *) echo "Invalid option"; exit 1 ;;
    esac
}

# Function to validate architecture
validate_userarch() {
    qemu=""
    if [[ "$userarch" =~ ^arm ]]; then
        qemu=""
    else
        devarch=$(dpkg --print-architecture)
        case $devarch in
            arm)
                case $userarch in
                    armhf) qemu="arm-qemu-i386-static" ;;
                    arm64) qemu="arm-qemu-x86_64-static" ;;
                    *) echo "Unsupported userarch for devarch arm"; exit 1 ;;
                esac
                ;;
            aarch64)
                case $userarch in
                    armhf) qemu="aarch64-qemu-i386-static" ;;
                    arm64) qemu="aarch64-qemu-x86_64-static" ;;
                    *) echo "Unsupported userarch for devarch aarch64"; exit 1 ;;
                esac
                ;;
            *)
                echo "Unsupported devarch"; exit 1 ;;
        esac
    fi
}

# Function to set up Ubuntu filesystem
setup_ubuntu_fs() {
    folder="ubuntu-fs-$userarch"
    if [ -d "$folder" ]; then
        echo "Skipping downloading."
        return
    fi

    tarball="ubuntu-rootfs.tar.gz"
    if [ ! -f "$tarball" ]; then
        echo "Downloading Rootfs, this may take a while based on your internet speed."
        wget "https://partner-images.canonical.com/core/${ubuntu_version}/current/ubuntu-${ubuntu_version}-core-cloudimg-${userarch}-root.tar.gz" -O "$tarball"
    fi

    mkdir -p "$folder"
    echo "Decompressing Rootfs, please be patient."
    proot --link2symlink tar -zxf "$tarball" -C "$folder" || :
}

# Function to create start-ubuntu script
create_start_ubuntu_script() {
    mkdir -p ubuntu-binds
    bin="start-ubuntu-$userarch.sh"
    echo "Writing launch script"
    cat > "$bin" <<- EOM
#!/bin/bash
cd \$(dirname \$0)
pulseaudio --start
unset LD_PRELOAD
command="proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $folder $qemu"
command+=" -b /dev"
command+=" -b /proc"
command+=" -b ubuntu-fs-$userarch/root:/dev/shm"
command+=" -b /sys"
command+=" -b /data"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ]; then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

    echo "Fixing shebang of $bin"
    termux-fix-shebang "$bin"
    echo "Making $bin executable"
    chmod +x "$bin"
}

# Function to setup PulseAudio
setup_pulseaudio() {
    echo "Setting up PulseAudio so you can have music in the distro."
    pkg install pulseaudio -y 

    if ! grep -q "auth-anonymous=1" ~/../usr/etc/pulse/default.pa; then
        echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >> ~/../usr/etc/pulse/default.pa
    fi

    echo "exit-idle-time = -1" >> ~/../usr/etc/pulse/daemon.conf
    echo "autospawn = no" >> ~/../usr/etc/pulse/client.conf
    echo "export PULSE_SERVER=127.0.0.1" >> "ubuntu-fs-$userarch/etc/profile"
}

# Main script
choose_ubuntu_version
choose_userarch
validate_userarch
setup_ubuntu_fs
create_start_ubuntu_script
setup_pulseaudio

(echo "nameserver 8.8.8.8"; echo "nameserver 1.1.1.1") | tee ubuntu-fs-$userarch/etc/resolv.conf
echo "Removing image for some space"
rm "ubuntu-rootfs.tar.gz"
echo "You can now launch Ubuntu with the ./${bin} script"
