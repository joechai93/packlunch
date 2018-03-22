# Packlunch the Jetpack replacement
Nvidia TX2 replacement for Jetpack installer. Bash scritp for remote install and setup of Nvidia Jetson TX2 cards with additional kernel build and debootstrap options for minimal install.

![Jetson TX2 Module](https://developer.nvidia.com/sites/default/files/akamai/embedded/images/jetsontx2/JetsonTX2Module_300px_v3.png)
# Setup
There is a minimal requirement for the host system to support the bash scripting environment and have the apt-get package manager. For missing dependancies the script will attempt to install the required packages.

# Execution
As this script will install additional depencancies superuser password is requested.
```
sudo flash-tegra.sh
```
There is also a flashing only tool with a cutdown interface called ezflash. To run this:
```
sudo ezflash.sh
```
This uses binary file systems that have been pre-built to save time for quick tests see images [here](https://github.com/Abaco-Systems/jetson-tx2-sample-filesystems). 

## Screenshots
![Welcome Screen](/images/packlunch-shot01.png)
**Welcome screen where you can select the distribution you wish to work with**

![Select install type](/images/packlunch-shot02.png)
**Select required function**

List of possible actions:
* base - install Ubuntu Base
* l4t - install standard L4T
* kernel - rebuild the kernel from source and optionaly run menuconfig
* [debootstrap](https://wiki.debian.org/Debootstrap) - build minimal binary file system
* packlunch - Download and install Jetpack libraries
* Exit - abandon install

![Packlunch selection screen](/images/packlunch-shot03.png)
**Packlunch - Select required packages**

![Packlunch login screen](/images/packlunch-shot04.png)
**Packlunch - Select target ssh login**


