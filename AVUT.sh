#!/data/data/com.termux/files/usr/bin/bash

versions=("14.04.1" "14.04.2" "14.04.3" "14.04.4" "14.04.5" "14.04.6" "14.04"
    "16.04.1" "16.04.2" "16.04.3" "16.04.4" "16.04.5" "16.04.6" "16.04"
    "18.04.1" "18.04.2" "18.04.3" "18.04.4" "18.04.5" "18.04"
    "20.04.1" "20.04.2" "20.04.3" "20.04.4" "20.04.5" "20.04"
    "22.04.1" "22.04.2" "22.04.3" "22.04.4" "22.04"
    "23.10"
    "24.04")

echo "Choose a version:"
for ((i=0; i<${#versions[@]}; i++)); do
    echo "$((i+1)). ${versions[i]}"
done

read -p "Enter the number of your choice: " choice

if (( choice < 1 || choice > ${#versions[@]} )); then
    echo "Invalid choice. Please enter a number between 1 and ${#versions[@]}"
    exit 1
fi

UBUNTU_VERSION=${versions[choice-1]}
echo "You chose version $UBUNTU_VERSION"

folder=ubuntu-fs
if [ -d "$folder" ]; then
    first=1
    echo "skipping downloading"
fi
tarball="ubuntu-rootfs.tar.gz"
if [ "$first" != 1 ];then
    if [ ! -f $tarball ]; then
        echo "Download Rootfs, this may take a while base on your internet speed."
        
        echo "Choose which version to install:"
        echo "1. Normal"
        echo "2. x86_64"
        echo "3. i386"
        read -p "Enter your choice (1/2/3): " choice

        case "$choice" in
            1)
                # Set 1: Normal
                case "$(dpkg --print-architecture)" in
                    aarch64)
                        archurl="arm64" ;;
                    arm)
                        archurl="armhf" ;;
                    amd64)
                        archurl="amd64" ;;
                    x86_64)
                        archurl="amd64" ;;    
                    i*86)
                        archurl="i386" ;;
                    x86)
                        archurl="i386" ;;
                    *)
                        echo "unknown architecture"; exit 1 ;;
                esac
                ;;
            2)
                # Set 2: x86_64
                case "$(dpkg --print-architecture)" in
                    aarch64)
                        archurl="amd64";
                        wget https://github.com/AllPlatform/Termux-UbuntuX86_64/raw/master/arm64/qemu-x86_64-static;
                        chmod 777 qemu-x86_64-static;
                        mv qemu-x86_64-static ~/../usr/bin ;;
                    arm)
                        archurl="amd64";
                        wget https://github.com/AllPlatform/Termux-UbuntuX86_64/raw/master/arm/qemu-x86_64-static;
                        chmod 777 qemu-x86_64-static;
                        mv qemu-x86_64-static ~/../usr/bin/ ;;
                    amd64)
                        archurl="amd64" ;;
                    x86_64)
                        archurl="amd64" ;;    
                    i*86)
                        archurl="i386" ;;
                    x86)
                        archurl="i386" ;;
                    *)
                        echo "unknown architecture"; exit 1 ;;
                esac
                ;;
            3)
                # Set 3: i386
                case "$(dpkg --print-architecture)" in
                    aarch64)
                        archurl="i386";
                        wget https://github.com/AllPlatform/Termux-UbuntuX86_64/raw/master/arm64/qemu-i386-static;
                        chmod 777 qemu-i386-static;
                        mv qemu-i386-static ~/../usr/bin ;;
                    arm)
                        archurl="i386";
                        wget https://github.com/AllPlatform/Termux-UbuntuX86_64/raw/master/arm/qemu-i386-static;
                        chmod 777 qemu-i386-static;
                        mv qemu-i386-static ~/../usr/bin/ ;;
                    amd64)
                        archurl="amd64" ;;
                    x86_64)
                        archurl="amd64" ;;    
                    i*86)
                        archurl="i386" ;;
                    x86)
                        archurl="i386" ;;
                    *)
                        echo "unknown architecture"; exit 1 ;;
                esac
                ;;
            *)
                echo "Invalid choice. Exiting."; exit 1 ;;
        esac

        wget "https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${archurl}.tar.gz" -O $tarball
    fi
    cur=`pwd`
    mkdir -p "$folder"
    cd "$folder"
    echo "Decompressing Rootfs, please be patient."
    proot --link2symlink tar -zxf ${cur}/${tarball}||:
    cd "$cur"
fi
mkdir -p ubuntu-binds
bin=start-ubuntu.sh
echo "writing launch script"
cat > $bin <<- EOM
#!/bin/bash
cd \$(dirname \$0)
pulseaudio --start
## For rooted user: pulseaudio --start --system
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $folder"
if [ -n "\$(ls -A ubuntu-binds)" ]; then
    for f in ubuntu-binds/* ;do
      . \$f
    done
fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b ubuntu-fs/root:/dev/shm"
## uncomment the following line to have access to the home directory of termux
#command+=" -b /data/data/com.termux/files/home:/root"
## uncomment the following line to mount /sdcard directly to / 
#command+=" -b /sdcard"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

echo "Setting up pulseaudio so you can have music in distro."

pkg install pulseaudio -y

if grep -q "anonymous" ~/../usr/etc/pulse/default.pa;then
    echo "module already present"
else
    echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >> ~/../usr/etc/pulse/default.pa
fi

echo "exit-idle-time = -1" >> ~/../usr/etc/pulse/daemon.conf
echo "Modified pulseaudio timeout to infinite"
echo "autospawn = no" >> ~/../usr/etc/pulse/client.conf
echo "Disabled pulseaudio autospawn"
echo "export PULSE_SERVER=127.0.0.1" >> ubuntu-fs/etc/profile
echo "Setting Pulseaudio server to 127.0.0.1"

echo "fixing shebang of $bin"
termux-fix-shebang $bin
echo "making $bin executable"
chmod +x $bin
echo "removing image for some space"
rm $tarball
echo "You can now launch Ubuntu with the ./${bin} script"
