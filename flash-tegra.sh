#!/bin/bash
##
## Rheinemtall Defence Flashing tool
##
## This script is an interactive installer for the Jetson NX and AGX Evaluation 
## boards. It is provided for refferance only and comes with absolutly no warrenty 
## or support. 
##
## Please use the production SDK for official L4T developemnt and support.
##

# Uncomment the line below for the runtime libraries for production system
#INSTALL_TYPE=RUNTIME
INSTALL_TYPE=DEVELOPER

export TEGRA_KERNEL_OUT=build

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"
LC_ALL="C.UTF-8"
SELF=$0
SECONDS=0
TIMEOUT=30
DEBOOT=false
DATE=$(date "+%s")
CORES=$(nproc --all)
USER=rnt
PASSWORD=welcome1
BOARD=jetson-tx2
RELEASE="unknown";
UBUNTU_RELEASE=bionic
UBUNTU_RELEASE_VERSION=18.04
MENU_TITLE="Jetson - System Setup"
OS="Ubuntu Base 16.04.2"
UBUNTU_BASE=" - Ubuntu Base 18.04"
PREPARE="Preparing Filesystem..."
CONFIGURE="Configuring Filesystem..."
DOCUMENTATION="https://wiki.ubuntu.com/Base"
PROGRESS_HEIGHT=7
ROOT=$PWD
PACKAGES_FILENAME=packages.cfg
KERNEL=kernel/kernel-4.4
KERNEL_PATH=kernel/kernel-4.4/build/arch/arm64/boot
KERNEL_IMAGE=kernel/kernel-4.4/build/arch/arm64/boot/Image
HOSTNAME=tx2
DEFAULT_IP=192.168.1.1


wait()
{
  ## Remove comment below to see output after dialogues.
  # read -p "Press enter to continue"
  0
}

select_release()
{
  REL=$1

  case $REL in
  R27_1)
    RELEASE="R27.1";
    JETPACK_VERSION="3.1"
    NVIDIA_PATH=developer2.download.nvidia.com/embedded/L4T/r27_Release_v1.0
    SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_R27.1.0_aarch64.tbz2
    L4T_RELEASE_PACKAGE=Tegra186_Linux_R27.1.0_aarch64.tbz2
    L4T_SOURCES=r27.1.0_sources.tbz2
    L4T_COMPILER=gcc-4.8.5-aarch64.tgz
    L4T_DOCS=Tegra_Linux_Driver_Package_Documents_R27.1.tar
    KERNEL_SOURCES_DIR=""
    KERNEL_SOURCES=kernel_src.tbz2
    SAMPLE_BASE_FS_PACKAGE=ubuntu-base-16.04.2-base-arm64.tar.gz
    ;;
  R28_1)
    # http://developer2.download.nvidia.com/embedded/L4T/r28_Release_v1.0/BSP/source_release.tbz2
    RELEASE="R28.1";
    JETPACK_VERSION="3.1"
    NVIDIA_PATH=developer2.download.nvidia.com/embedded/L4T/r28_Release_v1.0
    SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_R28.1.0_aarch64.tbz2
    L4T_RELEASE_PACKAGE=Tegra186_Linux_R28.1.0_aarch64.tbz2 
    L4T_SOURCES=source_release.tbz2
    L4T_COMPILER=gcc-4.8.5-aarch64.tgz
    L4T_DOCS=NVIDIA_Tegra_Linux_Driver_Package.tar
    KERNEL_SOURCES_DIR=sources
    KERNEL_SOURCES=kernel_src-tx2.tbz2
    SAMPLE_BASE_FS_PACKAGE=ubuntu-base-16.04.2-base-arm64.tar.gz
    ;;
  R28_2) # TODO: NOT YET TESTED
    # http://developer2.download.nvidia.com/embedded/L4T/r28_Release_v2.0/BSP/source_release.tbz2
    RELEASE="R28.2";
    NVIDIA_PATH=developer2.download.nvidia.com/embedded/L4T/r28_Release_v2.0
    SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_R28.2.0_aarch64.tbz2
    JETPACK_VERSION="3.2"
    L4T_RELEASE_PACKAGE=Tegra186_Linux_R28.2.0_aarch64.tbz2 
    L4T_SOURCES=source_release.tbz2
    L4T_COMPILER=gcc-4.8.5-aarch64.tgz
    L4T_DOCS=NVIDIA_Tegra_Linux_Driver_Package.tar
    KERNEL_SOURCES_DIR=sources
    KERNEL_SOURCES=kernel_src-tx2.tbz2
    SAMPLE_BASE_FS_PACKAGE=ubuntu-base-16.04.2-base-arm64.tar.gz
    ;;
  R32_4_4) # TODO: NOT YET TESTED
    # http://developer.download.nvidia.com/embedded/L4T/r32_Release_v4.4/r32_Release_v4.4-GMC3/T186/source_release.tbz2
    RELEASE="R32.4.4";
    NVIDIA_PATH=developer.download.nvidia.com/embedded/L4T/r32_Release_v4.4/r32_Release_v4.4-GMC3/T186/
    SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_R32.4.4_aarch64.tbz2
    JETPACK_VERSION="4.4.1"
    L4T_RELEASE_PACKAGE=Tegra186_Linux_R32.4.4_aarch64.tbz2
    L4T_SOURCES=source_release.tbz2
    L4T_COMPILER=gcc-4.8.5-aarch64.tgz
    L4T_DOCS=NVIDIA_Tegra_Linux_Driver_Package.tar
    KERNEL_SOURCES_DIR=sources
    KERNEL_SOURCES=kernel_src-tx2.tbz2
    SAMPLE_BASE_FS_PACKAGE=ubuntu-base-18.04.5-base-amd64.tar.gz
    ;;
  esac

  # Common downloads  
  PACKLUNCH_FILENAME="packlunch-${RELEASE}.cfg"
}

cleanup() {
  rm -f /tmp/menu.sh* &>> install.log
  rm -f /tmp/build.txt &>> install.log
  rm -f /tmp/file.txt &>> install.log
}

abort() {
  dialog --backtitle "${MENU_TITLE}${VERSION}" --title "Abort" \
    --msgbox "Board not flashed please run this script again!!!" 6 60
  cleanup
  clear
}

check_connected() {
  lsusb | grep -i nvidia  &>> install.log
  NVIDIA_READY=$?
  if ((${NVIDIA_READY} > 0)); then
    NVIDIA_READY="\Z1WARNING: Could not find nVidia device on USB. Please run 'lsusb' and make sure your device is connected to the host before continuing.\Z0\n"
  else
    NVIDIA_READY="\Z2Found nVidia device on USB ready to flash.\Z0\n"
  fi

  dialog --colors --backtitle "${MENU_TITLE}"  \
    --msgbox "Target check:\n\n${NVIDIA_READY}\n" 9 60
}

clean() {
  cd ${ROOT}/Linux_for_Tegra/rootfs &>> install.log
  chroot . /bin/bash -c "apt-get clean &>> install.log"
  chroot . /bin/bash -c "rm -rf /var/lib/apt/lists/*"
  chroot . /bin/bash -c "rm -f /usr/bin/qemu-aarch64-static"
  cd - &>> install.log
}

flash_filesystem() {
  cd ${ROOT}/Linux_for_Tegra  &>> install.log

  FLASH_OK=false;
  while [ $FLASH_OK = false ]; do
    lsusb | grep -i nvidia &>> install.log

    NVIDIA_READY=$?
    if [ ${NVIDIA_READY} -gt 0 ]; then
      NVIDIA_READY="\Z1CAUTION: Could not find nVidia device on USB. Please run 'lsusb' and make sure your device is connected to the host before continuing.\Z0\n"
    else
      NVIDIA_READY="\Z2NOTE: Found nVidia device on USB ready to flash.\Z0\n"
    fi

    dialog --colors --backtitle "${MENU_TITLE}"  \
      --help-button --help-label "Re-check" --yesno "Are you ready to flash the filesystem?\n\n${NVIDIA_READY}\n" 9 60

    response=$?
    case $response in
       0) clean; # Last thing we do is clean the filesystem
          sudo ./flash.sh $1 ${BOARD} mmcblk0p1 2&>> install.log | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for flashing to complete\Z0" --exit-label 'Exit when flash completes' --programbox "Flashing target..." 25 85 2&>> install.log; FLASH_OK=true;;
       1) abort; clear; exit -1;;
       255) echo "[ESC] key pressed.";;
    esac
   done
  cd - &>> install.log
}

check_for_kernel_update() {
  cd ${ROOT}/Linux_for_Tegra  &>> install.log
  if [ -f ../$KERNEL_PATH/Image ]; then
    d=$(stat -c%y ../$KERNEL_PATH/Image | cut -d'.' -f1)
    dialog --colors --backtitle "${MENU_TITLE}${VERSION}"  \
      --yesno "Rebuilt kernel image detected, would copy this into the filesystem?\n\n           KERNEL BUILT : \Z6$d\Zn" 9 60

    response=$?
    case $response in
       0) cp $ROOT/$KERNEL_PATH/Image ./kernel/Image &>> install.log
          cp $ROOT/$KERNEL_PATH/zImage ./kernel/zImage &>> install.log
          cp $ROOT/$KERNEL/$TEGRA_KERNEL_OUT/modules/kernel_supplements.tbz2 ./kernel/kernel_supplements.tbz2 &>> install.log
          cp $ROOT/$KERNEL/$TEGRA_KERNEL_OUT/arch/arm64/boot/dts/* ./kernel/dtb &>> install.log
          ;;
    esac
  fi

  cd - &>> install.log
}

choices=""

create_packages() {
  PACKAGES=${ROOT}/$1
  if [ ! -f $PACKAGES ]; then
    echo 'autofs "Automatic file system mounting" off' > $PACKAGES
    echo 'ethtool "ethernet tool" on' >> $PACKAGES
    echo 'hwinfo "Hardware probing" off' >> $PACKAGES
    echo 'isc-dhcp-client "DHCP Client" on' >> $PACKAGES
    echo 'lxde "Minimal Desktop" off' >> $PACKAGES
    echo 'nano "text editor" on' >> $PACKAGES
    echo 'net-tools "Provides ifconfig" on' >> $PACKAGES
    echo 'openssh-server "Secure ssh server" off' >> $PACKAGES
    echo 'pciutils "lspci command" on' >> $PACKAGES
    echo 'sudo "superuser do" on' >> $PACKAGES
    echo 'udev "dynamic device naming" on' >> $PACKAGES
    echo 'vim "vi text editor" off' >> $PACKAGES
    echo 'xfce4 "Minimal Desktop" off' >> $PACKAGES
    echo 'xorg "X server" off' >> $PACKAGES
  fi
}

select_packages() {
  PACKAGES=${ROOT}/$1

  create_packages $1

  pkglist=""
  n=1

  while read pkgs;
  do
    pkglist="$pkglist $pkgs"
    n=$[n+1]
  done < $PACKAGES

  cmd="dialog --stdout --backtitle \"${MENU_TITLE}${VERSION}\" --checklist 'Items read from file ./$1:' 21 60 20 $pkglist"

  choices=`eval $cmd`
}

install_packages() {
  progress=40;

  # Front end for post install scripts.
  chroot . /bin/bash -c "apt-get -qqy install --no-install-recommends dialog" &>> install.log

  for choice in $choices
  do
    progress=$(($progress + 1))
    echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "Installing $choice package..." ${PROGRESS_HEIGHT} 70 
    chroot . /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -qqy install --no-install-recommends $choice" &>> de
  done

  progress=$(($progress + 1))
  echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "Cleaning apt cache..." ${PROGRESS_HEIGHT} 70 
}

install_pack={}

select_packlunch() {
  PACKAGES2=${ROOT}/$1

  if [ ! -f "$PACKAGES2" ]; then
    return
  fi

  pkglist=""
  n=1
  declare -a array

  while read pkg2;
  do
    array=($pkg2)
    desc=$(echo "\"${pkg2#*\"}")
    pkglist="$pkglist ${array[0]} $desc  ${array[4]}"
    install_pack[$n]=$pkg2
    n=$[n+1]
  done < $PACKAGES2

  cmd="dialog --stdout --backtitle \"${MENU_TITLE}${VERSION}\" --checklist 'Install packages read from file ./$1:' 20 60 20 $pkglist"

  export choices2=`eval $cmd`
}

remote_sudo() {
  expect -c "
  set timeout 500
  spawn  sudo -u $SUDO_USER ssh -t ${SSH_USER}@${SSH_IP} $1
  expect -exact \"password:\"
  send \"$SSH_PASSWORD\n\"
  expect -exact \"closed.\"
" 
}

remote_check() {
  expect -c "
  set timeout 1
  spawn  sudo -u $SUDO_USER ssh -t ${SSH_USER}@${SSH_IP} 
  expect -exact \"Are you sure you want to continue connecting (yes/no)?\"
  send \"yes\n\"
  expect -exact \"password:\"
  send \"$SSH_PASSWORD\n\"
  expect -exact \"$\"
  send \"exit\n\"
  expect -exact \"closed.\"
" &>> install.log
}

myscp() {
echo "sudo -u $SUDO_USER scp $1 $2"
  expect -c "
  set timeout 120
  spawn  sudo -u $SUDO_USER scp $1 $2
  expect -exact \"password:\"
  send \"$SSH_PASSWORD\n\"
  expect -exact \"closed.\"
" &>> install.log
}

post_install_packlunch() {
  if [ ${INSTALL_TYPE} == "RUNTIME" ]; then
    INST_APT[0]="cuda-cudart-8-0"
    INST_APT[1]="tensorrt-2.1.0"
    INST_APT[2]="libvisionworks"
    INST_APT[3]="libopencv4tegra"
    INST_APT[4]="libvisionworks-samples"
    INST_APT[5]="tbc"
    SETUP_TYPE="runtime"
  else
    INST_APT[0]="cuda-samples-8-0"
    INST_APT[1]="tensorrt-2.1.0"
    INST_APT[2]="libvisionworks-dev"
    INST_APT[3]="libopencv4tegra-dev"
    INST_APT[4]="libvisionworks-samples"
    INST_APT[5]="tbc"
    SETUP_TYPE=""
  fi

  for choice in $choices2
  do
    echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "Setting up $choice2 package..." ${PROGRESS_HEIGHT} 70 
    
    if [ $1 -eq 0 ]; then
      case $choice in
        CUDA_Toolkit )
            chroot . /bin/bash -c "apt-get -qqy install --no-install-recommends ${INST_APT[0]}" >> install.log
            ;;
        TensorRT )
            chroot . /bin/bash -c "apt-get -qqy install --no-install-recommends ${INST_APT[1]}" >> install.log
            ;;
        VisionWorks )
            chroot . /bin/bash -c "apt-get -qqy install --no-install-recommends ${INST_APT[2]}" >> install.log
            ;;
        OpenCV4Tegra )
            chroot . /bin/bash -c "apt-get -qqy install --no-install-recommends ${INST_APT[3]}" >> install.log
            ;;
        VisionWorksSFM )
            chroot . /bin/bash -c "apt-get -qqy install --no-install-recommends ${INST_APT[4]}" >> install.log
            ;;
        cuDNN )
            ;;
      esac
    else

      case $choice in
        CUDA_Toolkit )
            remote_sudo "sudo apt-get -qqy install --no-install-recommends ${INST_APT[0]}" 
            ;;
        TensorRT )
            remote_sudo "sudo apt-get -qqy install --no-install-recommends ${INST_APT[1]}"
            ;;
        VisionWorks )
            remote_sudo "sudo apt-get -qqy install --no-install-recommends ${INST_APT[2]}"
            ;;
        OpenCV4Tegra )
            remote_sudo "sudo apt-get -qqy install --no-install-recommends ${INST_APT[3]}" 
            ;;
        VisionWorksSFM )
            remote_sudo "sudo apt-get -qqy install --no-install-recommends ${INST_APT[4]}"
            ;;
        cuDNN )
            ;;
      esac
    fi
    progress=$(($progress + 1))
  done
}

install_packlunch() {
  if [ "$choices2" == "" ];then
    return
  fi
  n=0
  if [ $1 -eq 0 ]
  then
    cd ${ROOT}/Linux_for_Tegra/rootfs
    ADDER=1
    KEEP_PATH=../..
  else
    cd ${ROOT}
    ADDER=2
    KEEP_PATH=.
  fi

  if [ $1 -eq 1 ]; then
    VERSION=" - Installing remote libraries"
    SSH_IP="192.168.0.0"
    SSH_USER="ubuntu"
    SSH_PASSWORD="ubuntu"
    TARGET_OK=false;
    
    # need expect to be interactive
    apt-get -qqy install expect

    while [ $TARGET_OK = false ]; do
      wait
      dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --form "Please enter ssh login details for TX2 target machine below. Please make sure you have exchanged keys with your target prior to attempting remote installation.:" 14 50 0 \
  "IP"       1 1  "$SSH_IP" 1 10 16 0 \
  "username" 2 1  "$SSH_USER" 2 10 20 0 \
  "password" 3 1  "$SSH_PASSWORD" 3 10 20 0 2> /tmp/ip.txt 

      response=$?
      case $response in
         255) clear;echo "[ESC] key pressed.";exit;;
      esac

      SSH_IP=$(sed -n '1p' /tmp/ip.txt)  
      SSH_USER=$(sed -n '2p' /tmp/ip.txt)
      SSH_PASSWORD=$(sed -n '3p' /tmp/ip.txt)

      ping $SSH_IP -c 1 -w 1 &>> install.log
      ALIVE=$?

      if [ ! $ALIVE -eq 0 ]; then
        dialog --colors --backtitle "${MENU_TITLE}${VERSION}" \
          --yes-label "Continue" --no-label "Re-check" --yesno "\Z1WARNING: Target device $SSH_IP is not reachable!" 6 60
      fi

      response=$?
      case $response in
         0) TARGET_OK=true;;
         255) clear;echo "[ESC] key pressed.";exit;;
      esac
    done
  fi

  # Test remote connection (setup for first use)
  remote_check

  # Download the packages first
  for choice2 in $choices2
  do
    progress=$(($progress + $ADDER))
    echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "Downloading $choice2 package..." ${PROGRESS_HEIGHT} 70 
    index=0
    line=(${install_pack[$n]})
    c=0
    # Find the line matching the choice
    for i in "${install_pack[@]}"
    do
      : 
    tmp=${install_pack[$c]}
    tmp2=($tmp)
      if [ "${tmp2[0]}" == "$choice2" ];then
        index=$c
      fi
      c=$[c+1]      
    done
    line=(${install_pack[$index]})

    # Keep downloaded files in the root directory so they persist if the filesystem is rebuilt
    wget -nc -P$KEEP_PATH ${line[1]}/${line[2]} &>> install.log

    if [ $1 -eq 0 ]
    then
      progress=$(($progress + $ADDER))
      wait
      echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "Copying $choice2 into filesystem..." ${PROGRESS_HEIGHT} 70 
      cp ../../${line[2]} ./opt/. 

      progress=$(($progress + $ADDER))
      wait
      echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "Dpkg installing $choice2..." ${PROGRESS_HEIGHT} 70 
      chroot . /bin/bash -c "cd /opt; dpkg -i ${line[2]}" >> install.log
      # Remove that package now its installed (free up the disk space)
      chroot . /bin/bash -c "rm /opt/${line[2]}" >> install.log
    else
      progress=$(($progress + $ADDER))
      wait
      echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "Scp $choice2 into filesystem..." ${PROGRESS_HEIGHT} 70 
      myscp ${line[2]} ${SSH_USER}@${SSH_IP}:.

      progress=$(($progress + $ADDER))
      wait
      echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "Dpkg installing $choice2..." ${PROGRESS_HEIGHT} 70 
      remote_sudo "sudo dpkg -i ${line[2]}"

      # Remove that package now its installed (free up the disk space)
      remote_sudo "sudo rm ./${line[2]}"
    fi
    n=$[n+1]
  done

  progress=$(($progress + $ADDER))
  wait
  echo $progress | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge "apt-get update new sources..." ${PROGRESS_HEIGHT} 70
  if [ $1 -eq 0 ]
  then
    # Now update 
    chroot . /bin/bash -c "apt-get update" &>> install.log
  else
    # Now update 
    remote_sudo "sudo apt-get update"
  fi

  post_install_packlunch $1
  cd -
}

ask_open_shell() {
  cd ${ROOT}$1 &>> install.log
  dialog --defaultno --colors --backtitle "${MENU_TITLE}${VERSION}"  \
    --yesno "Do you want to open a filesystem terminal?\n\nNOTE: This can be usefull for manually configuring your filesystem prior to flashing. $2\Zn\n" 10 60

  response=$?
  case $response in
     0) cd ${ROOT}$1 &>> install.log;gnome-terminal -- bash -c "printf 'QEMU shell for $OS\nPlease make any modifications then type 'exit' to finish:\n\n';chroot . /bin/bash" &>> install.log
        cd ..
        wait
        dialog --backtitle "${MENU_TITLE}${VERSION}" --title "QEMU filesystem shell open..." --msgbox "Press OK when you have finished modifying the filesystem." 5 70
        ;;
  esac
  cd - &>> install.log
}

#
# https://developer.nvidia.com/embedded/linux-tegra (Stable)
#
setup_l4t () {
  OS="Ubuntu 16.04 LTS (L4T ${RELEASE})"
  USER=nvidia
  PASSWORD=nvidia
  VERSION=" - $OS"
  OPEN_CUSTOM=false
  DOWNLOAD_PATH=github.com/Abaco-Systems/tx2-sample-filesystems/releases/download/R28_1;

  cmd="dialog --backtitle \"${MENU_TITLE}\"  \
--title \"Select your filesystem\" \
--no-cancel \
--menu \"You can use the UP/DOWN arrow keys, the first letter of the choice as a hot key.\" 16 65 6 \
nvidia \"L4T R28.1 Full Unity Desktop\" \
xfce4 \"Xfce4 Desktop Environment (with networking)\" \
lxde \"Lxde Desktop Environment (with networking)\" \
cmdline \"Minimal command line (with networking)\" \
custom \"Open custom filesystem\" \
Exit \"Exit to the shell\"  2> \"${INPUT}\""

  eval $cmd

  menuitem=$(cat ${INPUT})

  # make decsion 
  case $menuitem in
    cmdline) SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_Debootstrap_cmdline_aarch64.tbz2;
             VERSION=" - Github Debootstrap command line Ubuntu (xenial)"
             USER=abaco;PASSWORD=abaco;
             ;;
    xfce4) SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_Debootstrap_xfce4_aarch64.tbz2;
           VERSION=" - Github Debootstrap Xfce4 line Ubuntu (xenial)"
           USER=abaco;PASSWORD=abaco;
           ;;
    lxde) SAMPLE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_Debootstrap_lxde_aarch64.tbz2;
          VERSION=" - Github Debootstrap Lxdes line Ubuntu (xenial)"
          USER=abaco;PASSWORD=abaco;
          ;;
    nvidia) DOWNLOAD_PATH=${NVIDIA_PATH}/BSP; 
          ;;
    custom) OPEN_CUSTOM=true;
          ;;
    Exit) abort;exit;;
  esac

  if $OPEN_CUSTOM; then
    if [ -d $ROOT/fs ]; then
       FS_PATH=$ROOT/fs
     else
       FS_PATH=$ROOT
     fi
     eval "dialog --backtitle \"${MENU_TITLE}${VERSION}\" --title \"Please choose alternative filesystem\" --fselect $FS_PATH/ 14 70" 2> /tmp/file.txt
          SAMPLE_FS_PACKAGE=$(cat /tmp/file.txt)
          OS="Custom Filsystem"
          if [ -d "Linux_for_Tegra" ]; then
            echo '15' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title 'Removing old files...' --gauge 'Removing old Files.' ${PROGRESS_HEIGHT} 75 0
            rm -rf Linux_for_Tegra/ &>> install.log
          fi
  else
        if [ -d "Linux_for_Tegra" ]; then
          echo '15' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title 'Removing old files...' --gauge 'Removing old Files.' ${PROGRESS_HEIGHT} 75 0
          rm -rf Linux_for_Tegra/ &>> install.log
        fi

        echo '20' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" \
          --gauge "wget ${SAMPLE_FS_PACKAGE}" 6 75 0
        wget -nc -q http://${DOWNLOAD_PATH}/${SAMPLE_FS_PACKAGE}
        SAMPLE_FS_PACKAGE=${ROOT}/${SAMPLE_FS_PACKAGE}
  fi

  echo '40' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge "wget ${L4T_RELEASE_PACKAGE}" ${PROGRESS_HEIGHT} 75 0
  wget -nc -q http://${NVIDIA_PATH}/BSP/${L4T_RELEASE_PACKAGE}

  echo '60' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge "Expanding ${L4T_RELEASE_PACKAGE}" ${PROGRESS_HEIGHT} 75 0
  tar xpf ${L4T_RELEASE_PACKAGE} 

  cd $ROOT/Linux_for_Tegra/rootfs/ &>> install.log
  TMP=${SAMPLE_FS_PACKAGE##*/} 
  echo '80' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge "Expanding ${TMP}" ${PROGRESS_HEIGHT} 75 0
  tar xpf ${SAMPLE_FS_PACKAGE}

  cd ..
  echo '90' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Applying binaries...' ${PROGRESS_HEIGHT} 75 
  ./apply_binaries.sh &>> install.log
  echo '95' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Setting up QEMU emulator...' ${PROGRESS_HEIGHT} 75 
  cp /usr/bin/qemu-aarch64-static ./rootfs/usr/bin/. &>> install.log

  ## Preload the nVidia librarys Packlunch
  select_packlunch $PACKLUNCH_FILENAME

  # If the kernel has been rebuilt offer to copy the Image in
  check_for_kernel_update
  
  cd $ROOT/Linux_for_Tegra/rootfs &>> install.log
  echo '10' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Enabling other sources...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "sed -i 's/# deb http/deb http/g' /etc/apt/sources.list"
  echo '20' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Updating apt-get...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "apt-get update > install.log"
  echo '30' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Installing packages...' ${PROGRESS_HEIGHT} 70 
  install_packlunch 0
    
  # Offer to open a QEMU chroot shell for manual probing of filesystem
  ask_open_shell /Linux_for_Tegra/rootfs 

  # Now flash the target
  flash_filesystem

  # Basic usage info (anonymous)
  wget -T 1 -O /dev/null "http://dweet.io/dweet/for/abaco-l4t-setup?OS=Linux4Tegra&Version=17.01Setup_Time=$SECONDS&Date=$DATE"  &&>> install.log

  dialog --backtitle "${MENU_TITLE}${VERSION}" \
  --colors \
  --title "Target system should be rebooting now..." \
  --msgbox "\n
Filesystem setup complete you can now login using:\n
   username:\Zb\Z0${USER}\Zn\n
   password:\Zb\Z0${PASSWORD}\Zn\n\n
If the network device is not working you will need to rebuild\n
the kernel to include your device.\n
\n\n"  16 70
  clear
}

#
# https://wiki.ubuntu.com/Base (Working)
#
setup_ubuntu_base () {
  username=/tmp/user
  password=/tmp/password

  if [ -d "Linux_for_Tegra" ]; then
    echo '15' | dialog --backtitle "${MENU_TITLE}${VERSION}"  --title 'Removing old files...' --gauge 'Removing old Files, Linux_for_Tegra.' ${PROGRESS_HEIGHT} 70 0
    rm -rf Linux_for_Tegra/
  fi

  wait
  if [ "$DEBOOT" = false ]; then
    echo '20' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge "wget ${SAMPLE_BASE_FS_PACKAGE}" ${PROGRESS_HEIGHT} 70 0
    wget -nc -q http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/${SAMPLE_BASE_FS_PACKAGE} &>> install.log
    echo "http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/${SAMPLE_BASE_FS_PACKAGE}"
  fi

  wait
  echo '40' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge "wget ${L4T_RELEASE_PACKAGE}" ${PROGRESS_HEIGHT} 70 0
  wget -nc -q http://${NVIDIA_PATH}/${L4T_RELEASE_PACKAGE}
  if [[ ! -e "/usr/bin/qemu-aarch64-static" ]]
  then
    wait
    echo '50' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge 'Installing qemu-user-static' ${PROGRESS_HEIGHT} 70 0
    apt-get -qqy install qemu-user-static &>> install.log
  fi

  wait
  echo '60' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge "Expanding ${L4T_RELEASE_PACKAGE}" ${PROGRESS_HEIGHT} 70 0
  sudo tar xpf ${L4T_RELEASE_PACKAGE} &>> install.log
  cd Linux_for_Tegra/rootfs/  &>> install.log

  wait
  echo '80' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge "Expanding ${SAMPLE_BASE_FS_PACKAGE}" ${PROGRESS_HEIGHT} 70 0
  tar xpf ../../${SAMPLE_BASE_FS_PACKAGE} &>> install.log

  wait
  # Setup networking
  echo '95' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge 'Setting up the networking' ${PROGRESS_HEIGHT} 70 0

  echo "[Match]" > ./etc/systemd/network/50-wired.network
  echo "Name=eth*" >> ./etc/systemd/network/50-wired.network
  echo "" >> ./etc/systemd/network/50-wired.network
  echo "[Network]" >> ./etc/systemd/network/50-wired.network
  echo "DHCP=ipv4" >> ./etc/systemd/network/50-wired.network
  echo "nameserver 8.8.8.8" > ./etc/resolv.conf

  echo "127.0.0.1  localhost.localdomain localhost $HOSTNAME" > ./etc/hosts
  echo "$HOSTNAME" > ./etc/hostname

  wait

  # Update welcome message
  echo '100' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${PREPARE}" --gauge 'Setting up banner messages..' ${PROGRESS_HEIGHT} 70 0

  echo "#!/bin/bash" > ./etc/update-motd.d/10-help-text
  echo "printf \"\n\"" >> ./etc/update-motd.d/10-help-text
  echo "printf \" * Documentation:       ${DOCUMENTATION}\n\"" >> ./etc/update-motd.d/10-help-text
  echo "printf \" * nVidia:              https://developer.nvidia.com/embedded/linux-tegra\n\"" >> ./etc/update-motd.d/10-help-text
  echo "printf \" * Community Support:   https://github.com/ross-newman/packlunch\n\"" >> ./etc/update-motd.d/10-help-text
  echo "printf \" * Created by:          ross@rossnewman.com\n\"" >> ./etc/update-motd.d/10-help-text
  echo "$OS \n \l" > ./etc/issue
  echo "DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=$UBUNTU_RELEASE_VERSION
DISTRIB_CODENAME=bionic 
DISTRIB_DESCRIPTION=\"$OS\"" > ./etc/lsb-release

  # Get the user password
  # show an inputbox
  dialog --title "Create default user" \
  --backtitle "${MENU_TITLE}${VERSION}" \
  --no-cancel \
  --inputbox "Enter the account username " 8 60 2>$username

  # get data stored in $username using input redirection
  USER=$(cat $username)

  dialog --title "Create default password" \
  --backtitle "${MENU_TITLE}${VERSION}" \
  --no-cancel \
  --clear \
  --insecure \
  --passwordbox "Enter the account password " 8 60 2>$password

  select_packages $PACKAGES_FILENAME
  select_packlunch $PACKLUNCH_FILENAME

  # If the kernel has been rebuilt offer to copy the Image files into the filesystem
  check_for_kernel_update

  # get data stored in $OUPUT using input redirection
  PASSWORD=$(cat $password)

  # Setup chroot environment
  echo '5' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Setting up QEMU emulator...' ${PROGRESS_HEIGHT} 70 
  cp /usr/bin/qemu-aarch64-static ./usr/bin/. &>> install.log
  echo '10' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Setting up locale...' ${PROGRESS_HEIGHT} 70 
#  chroot . /bin/bash -c "apt-get -qqy install language-pack-en &>> install.log; sudo -u ${USER} locale-gen ${LANG} &>> install.log"
  echo '15' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Enabling other sources...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "sed -i 's/# deb http/deb http/g' /etc/apt/sources.list"
  echo '20' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Updating apt-get...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "apt-get update &>> install.log"
  echo '40' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Installing packages...' ${PROGRESS_HEIGHT} 70 
  install_packages 
  install_packlunch 0
  echo '70' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Creating user...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "useradd -m -s /bin/bash ${USER} &>> install.log"
  echo '75' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Adding user to groups...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "usermod -a -G sudo,adm,tty,video ${USER} &>> install.log"
  echo '80' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Changing password...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "echo \"${USER}:${PASSWORD}\" | chpasswd &>> install.log"

  # Cleanup password files
  rm $username &>> install.log
  rm $password &>> install.log

  # Add eth0 startup script
  echo '85' | dialog --backtitle "${MENU_TITLE}${UBUNTU_BASE}" --title "${CONFIGURE}" --gauge 'Configuring DHCP...' ${PROGRESS_HEIGHT} 70 
  echo "#!/bin/bash" > ./home/${USER}/eth0.sh
  echo "if [ \"\$EUID\" -ne 0 ]" >> ./home/${USER}/eth0.sh
  echo "  then echo \"Please run as root\"" >> ./home/${USER}/eth0.sh
  echo "  exit -1" >> ./home/${USER}/eth0.sh
  echo "fi" >> ./home/${USER}/eth0.sh
  echo "ifconfig eth0 up" >> ./home/${USER}/eth0.sh
  echo "dhclient eth0" >> ./home/${USER}/eth0.sh
  chmod +x ./home/${USER}/eth0.sh &>> install.log

  # Add complete desktop install script
  echo '#!/bin/bash 
if [ "$EUID" -ne 0 ] 
then 
  echo "Please run as root" 
  exit -1 
fi 
echo "Completing desktop install (Xorg)..." 
# Cache will be empty so we need to run update first
apt-get update
DEBIAN_FRONTEND=noninteractive  apt-get -qy install --no-install-recommends xorg xserver-xorg-legacy slim
echo "Fixing libglx and libGL..." 
sudo rm /usr/lib/xorg/modules/extensions/libglx.so 
sudo ln -s /usr/lib/aarch64-linux-gnu/tegra/libglx.so /usr/lib/xorg/modules/extensions/libglx.so 
sudo ln -s /usr/lib/aarch64-linux-gnu/tegra/libGL.so /usr/lib/aarch64-linux-gnu/libGL.so 

echo "#!/bin/bash" > .xinitrc

# Xfce4 setup...
cp /usr/share/backgrounds/xfce/xfce-teal.jpg /usr/share/slim/themes/debian-lines/background.png
apt-get -qy install --no-install-recommends greybird-gtk-theme tango-icon-theme xubuntu-icon-theme

# Lxde Setup...
apt-get -qy install policykit-1

echo "# Disaple screen blank (causes the xserver to stop responding)" >> .xinitrc
echo "xset -dpms; xset s off" >> .xinitrc
echo "exec startxfce4" >> .xinitrc
echo "#exec startlxde" >> .xinitrc
echo "#!/bin/bash" > .xsessionrc
echo "xset -dpms; xset s off" >> .xsessionrc
echo "Completed setup" 
echo "Type the following to start your desktop:" 
echo "    startxfce4 | startlxde"' > ./home/${USER}/complete_desktop_install.sh
  chmod +x ./home/${USER}/complete_desktop_install.sh &>> install.log

  echo '#!/bin/bash 
if [ "$EUID" -ne 0 ] 
then 
  echo "Please run as root" 
  exit -1 
fi 
echo "Removing repos..."
rm -rf /var/libopencv4tegra-repo
rm -rf /var/cuda-repo-8-0-local
rm -rf /var/nv-gie-repo-rc-cuda8.0*
rm -rf /var/visionworks-repo
rm -rf /var/visionworks-sfm-repo
rm -f /etc/apt/sources.list.d/cuda-8-0-local.list
rm -f /etc/apt/sources.list.d/libopencv4tegra-repo.list
rm -f /etc/apt/sources.list.d/nv-gie-rc-cuda8.0*.list
rm -f /etc/apt/sources.list.d/visionworks-repo.list
rm -f /etc/apt/sources.list.d/visionworks-sfm-repo.list
echo "Removing install logfile..."
rm /install.log
apt-get update
echo "Done..."
' > ./home/${USER}/remove_repos.sh
  chmod +x ./home/${USER}/remove_repos.sh

  cd $ROOT/Linux_for_Tegra/rootfs  &>> install.log
  
  echo '85' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Modifying .bashrc...' ${PROGRESS_HEIGHT} 70 
  echo "
export PATH=$PATH:/usr/local/cuda-8.0/bin
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/cuda-8.0/lib64:/usr/local/lib64
" >> ./home/${USER}/.bashrc 

  echo '90' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Updating networking...' ${PROGRESS_HEIGHT} 70 
  mkdir ./etc/network &>> install.log
  echo "auto lo
iface lo inet loopback
 
allow-hotplug eth0
iface eth0 inet dhcp
 
allow-hotplug eth1
iface eth1 inet dhcp
 
allow-hotplug eth2
iface eth2 inet dhcp" > ./etc/network/interface
  
  echo '92' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Tidyup...' ${PROGRESS_HEIGHT} 70 
  chroot . /bin/bash -c "mkdir /usr/local/cuda"
  chroot . /bin/bash -c "ln -s /usr/local/cuda-8.0/targets/aarch64-linux/include /usr/local/cuda/include"
  chroot . /bin/bash -c "ln -s /usr/local/cuda-8.0/bin /usr/local/cuda/bin"
  chroot . /bin/bash -c "ln -s /usr/local/cuda-8.0/lib64 /usr/local/cuda/lib64"
  cd ..  &>> install.log

    # Offer to open a QEMU chroot shell for manual probing of filesystem
  ask_open_shell /Linux_for_Tegra/rootfs

  cd $ROOT/Linux_for_Tegra &>> install.log
  echo '95' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${CONFIGURE}" --gauge 'Applying binaries...' ${PROGRESS_HEIGHT} 70 
  ./apply_binaries.sh &>> install.log
  cd $ROOT/Linux_for_Tegra/rootfs &>> install.log
  chroot . /bin/bash -c "mv /home/nvidia/* /home/${USER}/.;rm -rf /home/nvidia;rm -rf /home/ubuntu"
  # fix file permissions
  chroot . /bin/bash -c "chown -R ${USER}:${USER} /home/${USER}/*"
  cd $ROOT/Linux_for_Tegra &>> install.log

  # Now flash the target
  flash_filesystem

  # Basic usage info (anonymous)
  wget -T 1 -O /dev/null "http://dweet.io/dweet/for/abaco-base-setup?OS=Ubuntu_Base&Version=16.04&Setup_Time=$SECONDS&Date=$DATE"  &>> install.log

  dialog --backtitle "${MENU_TITLE}${VERSION}" \
  --title "Target system should be rebooting now..." \
  --colors \
  --msgbox "\n
Filesystem $OS setup complete you can now login using:\n
   username:\Zb\Z0${USER}\Zn\n
   password:\Zb\Z0${PASSWORD}\Zn\n
\n
If the network device is not working you will need to rebuild\n
the kernel to include your device.\n
\n
To make the system more usable the following packages were added:\n
    \Z6${choices}\Zn\n
\n
When running setup the DHCP network:\n
   ifconfig eth0 up\n
   dhclient eth0\n\n"  20 70
  cleanup
  clear
}

#
# https://wiki.ubuntu.com/ARM/RootfsFromScratch/QemuDebootstrap
#
deboot_buildfs () {
  DEBOOT=true
  OS="Debootstrap Ubuntu Minimal (L4T ${RELEASE})";
  SAMPLE_BASE_FS_PACKAGE=Tegra_Linux_Sample-Root-Filesystem_${UBUNTU_RELEASE}_aarch64.tbz2

  if [ -f $SAMPLE_BASE_FS_PACKAGE ]; then

    response=$?
    case $response in
       0) DEBOOT_EXISITS=true;
	        ;;
       255 ) abort; exit -;
          ;;
       *)
          rm -rf ./${SAMPLE_BASE_FS_PACKAGE}  &>> install.log;
          DEBOOT_EXISITS=false;
	        ;;
    esac

  else
    DEBOOT_EXISITS=false;
  fi

  if [ $DEBOOT_EXISITS == "false" ] ; then
    echo '40' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "Creating filesystem" --gauge 'Installing debootstrap...' ${PROGRESS_HEIGHT} 70 
    apt-get -qqy install debootstrap  &>> install.log
    wait
    echo '60' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "Creating filesystem" --gauge 'Removing old files...' ${PROGRESS_HEIGHT} 70 
    rm -rf ./debootstrap  &>> install.log 
    wait
    
    echo '80' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "Creating filesystem" --gauge 'Setting up...' ${PROGRESS_HEIGHT} 70 

    mkdir ./debootstrap  &>> install.log 
    export ARCH=arm64

    if [ -f /usr/bin/qemu-aarch64-static ] ; then
      wait
      echo '90' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "Setup" --gauge 'Installing QEMU for aarch64...' ${PROGRESS_HEIGHT} 70 
      apt-get install qemu-utils qemu-efi-aarch64 qemu-system-arm
    fi

  #  BOX_TYPE=--progressbox
    BOX_TYPE=--programbox
    
    wait
    # You can add additional packages, nano added as a starter
    debootstrap \
            --arch=$ARCH \
            --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg \
            --verbose \
            --foreign \
            --variant=minbase \
            --include=nano \
            $UBUNTU_RELEASE \
            ./debootstrap/rootfs | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for setup to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "debootstrap first stage ($UBUNTU_RELEASE)..."  25 85
        
    cp /usr/bin/qemu-aarch64-static ${ROOT}/debootstrap/rootfs/usr/bin &>> install.log
    cd ${ROOT}/debootstrap/rootfs  &>> install.log
    chroot . /bin/bash -c "/debootstrap/debootstrap --second-stage" | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for setup to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "debootstrap second stage ($UBUNTU_RELEASE)..."  25 85

    ask_open_shell /debootstrap/rootfs

    # When done create a filesystem archive
    tar -cvjSf $SAMPLE_BASE_FS_PACKAGE * | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for setup to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Creating archive ${SAMPLE_BASE_FS_PACKAGE} ($UBUNTU_RELEASE)..."  25 85
    mv $SAMPLE_BASE_FS_PACKAGE $ROOT/.  &>> install.log
    cd -  &>> install.log
  fi
  wait
  # Now configure and flash the image
  dialog --colors --backtitle "${MENU_TITLE}${VERSION}"  \
    --timeout $TIMEOUT --yesno "Do you want configure and flash this image now?\n" 6 60

  response=$?
  case $response in
     0 | 255) VERSION=" - Custom ${UBUNTU_RELEASE} debootstrap filesystem";
              DOCUMENTATION="https://wiki.ubuntu.com/ARM/RootfsFromScratch/QemuDebootstrap";
              cd $ROOT &>> install.log
              setup_ubuntu_base;
              ;;
  esac
  wait
  dialog --backtitle "${MENU_TITLE}${VERSION}" \
--title "Finished flashing, setup complete..." \
--colors \
--msgbox "The Debootstrap file system setup complete, minimal deboot image was saved:\n\n    \Z6Tegra_Linux_Sample-Root-Filesystem_${UBUNTU_RELEASE}_aarch64.tbz2\Zn" 8 70
  cleanup
  clear
  exit -1
}

check_setup() {
  if [ "$EUID" -ne 0 ]
  then 
    echo "Please run as root"
    exit -1
  fi

  # Check that we can run the menu system
  if which dialog &>> install.log
  then
    # Found so do nothing
    echo "Ok lets continue" &>> install.log
  else
    read -p "Install dialog command (y/n)?" choice
    case "$choice" in 
      y|Y ) sudo apt-get -qqy install dialog;;
      n|N ) echo "Command required quitting..."; exit;;
      * ) echo "invalid";;
    esac
  fi
}

#
# Download and rebuild the kernel source
#
rebuild_kernel() {
  export CROSS_COMPILE=$ROOT/install/bin/aarch64-unknown-linux-gnu-
  export ARCH=arm64
  CONFIG=tegra18_defconfig
  VERSION=" - Kernel-4.4"
  BUILD="Configuring host build system"

  # Get the kernel source for our board
  echo '10' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Removing old sources...' ${PROGRESS_HEIGHT} 70 
  rm -rf install
  rm -rf kernel
  rm -rf sources
  rm -rf nvl4t_docs
  rm -rf build
  rm -rf hardware
  echo '15' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Getting kernel sources...' ${PROGRESS_HEIGHT} 70 
  wget -nc -q http://${NVIDIA_PATH}/BSP/${L4T_SOURCES}
  echo '30' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Getting toolchain...' ${PROGRESS_HEIGHT} 70 
  wget -nc -q http://${NVIDIA_PATH}/BSP/${L4T_COMPILER}
  echo '50' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Getting documentation...' ${PROGRESS_HEIGHT} 70 
  wget -nc -q http://${NVIDIA_PATH}/Docs/${L4T_DOCS}
  echo '60' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Unpacking sources archive...' ${PROGRESS_HEIGHT} 70 
  case $REL in
  R27_1)
    tar xjf ${L4T_SOURCES} ${KERNEL_SOURCES}
    ;;
  R28_1)
    tar xjf ${L4T_SOURCES} ${KERNEL_SOURCES_DIR}/${KERNEL_SOURCES}
    ;;
  esac

  echo '70' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Unpacking compiler archive...' ${PROGRESS_HEIGHT} 70 
  tar xfz ${L4T_COMPILER}
  echo '80' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Unpacking documentation archive...' ${PROGRESS_HEIGHT} 70 
  tar xf ${L4T_DOCS}
  echo '90' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${BUILD}" --gauge 'Unpacking kernel archive...' ${PROGRESS_HEIGHT} 70 
  case $REL in
  R27_1)
    tar xjf ${KERNEL_SOURCES}
    ;;
  R28_1)
    tar xjf ${KERNEL_SOURCES_DIR}/${KERNEL_SOURCES}
    ;;
  esac

  if [ -f ${L4T_DOCS} ]; then
    dialog --colors --defaultno --backtitle "${MENU_TITLE}${VERSION}"  \
      --yesno "Do you want to open the kernel documentation?\n" 6 60

    response=$?
    case $response in
       0) firefox $ROOT/nvl4t_docs/index.html &>> install.log &;;
    esac
  fi

  case $REL in
  R27_1)
    cd $ROOT/$KERNEL &>> install.log
    dialog --colors --defaultno --clear --backtitle "${MENU_TITLE}${VERSION}"  \
      --yesno "Do you want to patch the kernel?\n\nNOTE: Adds in support for Intel x540 10GigE\n" 8 60 

    response=$?
    if [ $response == 0 ]; then
      cp ./arch/arm64/configs/${CONFIG}  ./arch/arm64/configs/${CONFIG}_abaco &>> install.log
      echo "# Abaco Systems x540 NIC and Multicast settings
CONFIG_IXGB=y
CONFIG_IXGBE=y
" >> ./arch/arm64/configs/${CONFIG}
    fi
    ;;
  R28_1)
    # IXGB Drive is a module in this release (no need to patch)
    ;;
  esac

  # create .config the offer to edit it (menuconfig)
  cd $ROOT/$KERNEL
  mkdir $TEGRA_KERNEL_OUT &>> install.log
  make mrproper 

# Change to programbox if you want to wait for the user to review each build step.
#  BOX_TYPE=--progressbox
  BOX_TYPE=--programbox

  make -j$CORES O=$TEGRA_KERNEL_OUT ${CONFIG} 2&>> install.log | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Building ${CONFIG}..."  25 85

  dialog --colors --defaultno --backtitle "${MENU_TITLE}${VERSION}"  \
    --yesno "Do you want to run menuconfig?\n" 6 60

  response=$?
  MENUCONFIG="Setting up Menuconfig"
  case $response in
     0) echo '50' | dialog --backtitle "${MENU_TITLE}${VERSION}" --title "${MENUCONFIG}" --gauge 'Installing libcursers...' ${PROGRESS_HEIGHT} 70 
        sudo apt-get -qqy install libncurses5-dev &>> install.log  # cant build menusystem without this on 16.04 LTS 
        make menuconfig KCONFIG_CONFIG=$TEGRA_KERNEL_OUT/.config 2&>> install.log
        ;;
  esac

  dialog --backtitle "${MENU_TITLE}${VERSION}" \
--title "Build Environment" \
--colors \
--ok-label "Build Kernel" \
--msgbox "CROSS_COMPILE=${CROSS_COMPILE}
TEGRA_KERNEL_OUT=$TEGRA_KERNEL_OUT\n
ARCH=$ARCH\n
CONFIG=$CONFIG\n
KERNEL=/$KERNEL\n" 10 70

  KBUILD_START=$SECONDS
  make -j$CORES O=$TEGRA_KERNEL_OUT zImage 2&>> install.log | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Building zImage..."  25 85
  make -j$CORES O=$TEGRA_KERNEL_OUT dtbs 2&>> install.log | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Building dtbs..."  25 85 
  make -j$CORES O=$TEGRA_KERNEL_OUT modules 2&>> install.log  | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Building modules..."  25 85  
  mkdir $TEGRA_KERNEL_OUT/modules
  make -j$CORES O=$TEGRA_KERNEL_OUT modules_install INSTALL_MOD_PATH=./modules | dialog --colors --backtitle "${MENU_TITLE} - \Z1Please wait for build to complete\Z0" --timeout $TIMEOUT $BOX_TYPE "Installing Modules..."  25 85
  cd $TEGRA_KERNEL_OUT/modules &>> install.log
  tar --owner root --group root -cjf kernel_supplements.tbz2 lib/modules &>> install.log
  cd - &>> install.log
  KBUILD_END=$SECONDS
  KBUILD_TIME=$(($KBUILD_END - $KBUILD_START))

  # Basic usage info (anonymous)
  wget -T 1 -O /dev/null "http://dweet.io/dweet/for/abaco-kernel-setup?OS=Ubuntu_Base&Version=16.04.2&Setup_Time=$SECONDS&Build_Time=$KBUILD_TIME&Date=$DATE"  &&>> install.log

  dialog --backtitle "${MENU_TITLE}${VERSION}" \
--title "Compilation Complete (${SECONDS}s)" \
--colors \
--ok-label "Quit" \
--msgbox "
Copy the kernel to your target /boot :\n\n
  \Z6./kernel/kernel-4.4/build/arch/arm64/boot/Image\Zn\n
  \Z6./kernel/kernel-4.4/build/arch/arm64/boot/zImage\Zn\n
  \Z6./kernel/kernel-4.4/build/modules/kernel_supplements.tbz2\Zn\n\n
To remove downloads type :\n
  \Z6$SELF clean\Zn\n
  \Z6$SELF kclean (remove kernel dir only)\Zn\n\n
To finish desktop installation please run ./complete_desktop_install.sh on target." 14 70
  cd - &>> install.log
  cleanup
  clear
}

backup_image() {
  cd ./Linux_for_Tegra/bootloader

  eval "dialog --backtitle \"${MENU_TITLE} - Backup\" --title \"Please choose a backup file\" --fselect $HOME/ 14 48" 2> /tmp/file.txt
  FILE=$(cat /tmp/file.txt)

  check_connected 
  
  ./tegraflash.py --bl cboot.bin --applet nvtboot_recovery.bin --chip 0x21 --cmd "read APP ${FILE}" 2&>> install.log | \
    dialog --colors --backtitle "${MENU_TITLE} - Backup" --programbox "Creating backup image ${FILE}..."  25 85
#  cd - &>> install.log
#  clear
  echo "./tegraflash.py --bl cboot.bin --applet mb1_recovery_prod.bin --chip 0x18 --cmd \"read APP ${FILE}\""
 }

restore_image() {
  cd ./Linux_for_Tegra/bootloader
  eval "dialog --backtitle \"${MENU_TITLE} - Restore\" --title \"Please choose a backup file\" --fselect $HOME/ 14 48" 2> /tmp/file.txt
  FILE=$(cat /tmp/file.txt)

  check_connected 

  sudo ./tegraflash.py --bl cboot.bin --applet mb1_recovery_prod.bin --chip 0x18 --cmd "write APP ${FILE}"  2&>> install.log | \
    dialog --colors --backtitle "${MENU_TITLE} - Restore" --programbox "Restoring backup image ${FILE}..."  25 85
  cd - &>> install.log
  clear
}

remote_install() {
  select_packlunch $PACKLUNCH_FILENAME; 
  install_packlunch 1; 
  dialog --backtitle "${MENU_TITLE}${VERSION}" \
--title "Remote packlunch install complete" \
--colors \
--ok-label "Quit" \
--msgbox "
The target system $SSH_IP has now been configured.\n\n
Successfully installed the following nVidia libraries:\n
  \Z6$choices2\Zn\n\n
You can now start using the target libraries." 12 70
  clear
  exit
}

##
## Main scripting block
##   Check filesystem choice and invoke setup. This script will:
##     * Download the neccessary files
##     * Expand the archives
##     * Do any filesystem configuration
##     * Apply nVidia binaries
##     * Flash the image to the target
##

# Check for non interactive commands

if [ "$1" = "clean" ]
then
  echo Removing file system directory...
  rm -f ${SAMPLE_FS_PACKAGE}
  rm -f ${SAMPLE_BASE_FS_PACKAGE}
  rm -f ${L4T_RELEASE_PACKAGE}
  rm -rf Linux_for_Tegra/
  rm -rf install
  rm -rf kernel
  rm -rf nvl4t_docs
  rm -rf build
  rm -rf hardware
  rm -rf debootstrap
  rm -f *.tar
  rm -f *.tgz
  rm -f *.tbz2
  rm -f *.txt
  rm -f *.html
  echo Done.
  exit -1
fi

if [ "$1" = "kclean" ]
then
  echo Removing kernel directory...
  rm -rf kernel
  echo Done.
  exit
fi

if [ "$1" = "remove" ]
then
  echo Removing install dependancies...
  apt-get -qqy remove libncurses5-dev dialog
  apt -qqy autoremove
  echo Done.
  exit
fi

if [ "$1" = "create" ]
then
  echo Creating template $PACKAGES_FILENAME...
  create_packages $PACKAGES_FILENAME
  echo Done.
  exit
fi

check_setup

dialog --backtitle "${MENU_TITLE}" \
--title "Nvidia Jetson device setup tool" \
--colors \
--yes-label "Install R32.4.4" \
--no-label "Exit" \
--yesno " \n
Jetson AGX/NX flash script \n
    ross@rossnewman.com\n
\n
Script to download and flash Jetson Tegra sample file systems.\n
   $ flash-tegra.sh (interactive setup)\n
   $ flash-tegra.sh clean (remove all temporary files)\n
   $ flash-tegra.sh kclean (remove kernel temporary file)\n
   $ flash-tegra.sh remove (remove apt-get installer packages)\n
   $ flash-tegra.sh create (create template packages file)\n
\n
Please place board into recovery mode and connect to (this) host machine.\n\n
\Z3WARNING: Computer must be connected to the internet to download required packages\Z0\n\n
\Z1NOTE: This script is provided without any warrenty or support what so ever, for refference only.\Z0\n" 23 75

response=$?

case $response in
#   0) select_release R28_1;;
#   1) abort; clear; exit -1;;
#   1) select_release R27_1;;
   0) select_release R32_4_4;;   
   1) abort; clear; echo "[ESC] key pressed."; exit -1;;   
   255) abort; clear; echo "[ESC] key pressed."; exit -1;;
esac

### display main menu ###

if [ -f ./Linux_for_Tegra/bootloader/system.img ];then
  FLASH_QUICK_MENU='"Quickly flash the last system.img"'
  FLASH_QUICK=quick
else
  FLASH_QUICK_MENU=
  FLASH_QUICK=''
fi

if [ -f ./Linux_for_Tegra/bootloader/tegraflash.py ];then
# The clone function appears to no longer work on the TX2 so removing it for now
#  BACKUP_MENU='"Create a backup image"'
#  BACKUP=backup
#  RESTORE_MENU='"Quickly flash the last system.img"'
#  RESTORE=restore
  dummy=0
fi
INPUT=/tmp/menu.sh.$$

# Not supported
# arch \"Install the latest version of archlinux (Alpha)\" \

cmd="dialog --backtitle \"${MENU_TITLE}\"  \
--title \"Select your filesystem\" \
--no-cancel \
--menu \"You can use the UP/DOWN arrow keys, the first letter of the choice as a hot key.\" 17 65 8 \
base \"Install Ubuntu Base 16.04 (approx 500 Mb)\" \
l4t \"Install Linux for Tegra ${RELEASE} (approx 3.0Gb)\" \
kernel \"Rebuild the Linux kernel\" \
debootstrap \"Create your own filesystem from scratch\" \
${FLASH_QUICK} ${FLASH_QUICK_MENU} \
${BACKUP} ${BACKUP_MENU} \
${RESTORE} ${RESTORE_MENU} \
packlunch \"Install Jetpack on target\"
Exit \"Exit to the shell\"  2> \"${INPUT}\""

eval $cmd

menuitem=$(cat ${INPUT})

# make decsion 
case $menuitem in
  base) VERSION=${UBUNTU_BASE};setup_ubuntu_base;;
#  l4t) setup_l4t;;
  kernel) rebuild_kernel;;
  debootstrap) deboot_buildfs;;
  backup) backup_image;;
  restore) restore_image;;
  quick) cd $ROOT/Linux_for_Tegra &>> install.log;flash_filesystem -r;cd ..;clear;;
  packlunch) remote_install;;
  Exit) abort;exit;;
esac

cleanup



