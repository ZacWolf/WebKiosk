#!/bin/bash

apt-get install lirc -y

mv /etc/lirc/lircd.conf.d/devinput.lircd.conf /etc/lirc/lircd.conf.d/devinput.lircd.dist

echo -e "#/etc/modprobe.d/lirc.conf\noptions lirc_odroid gpio_out_pin=249 softcarrier=1 invert=1\n" > /etc/modprobe.d/lirc.conf

echo -e "# 1 wire\nblacklist w1_gpio\nblacklist wire" > /etc/modprobe.d/blacklist-odroid.conf

cat <<_EOT_>> /etc/lirc/hardware.conf
# /etc/lirc/hardware.conf
#
#Chosen Remote Control
REMOTE="None"
REMOTE_MODULES=""
REMOTE_DRIVER=""
REMOTE_DEVICE=""
REMOTE_SOCKET=""
REMOTE_LIRCD_CONF=""
REMOTE_LIRCD_ARGS=""

#Chosen Remote Control
REMOTE="None"
REMOTE_MODULES="meson-ir"
REMOTE_DRIVER=""
REMOTE_DEVICE="/dev/lirc0"
REMOTE_SOCKET=""
REMOTE_LIRCD_CONF=""
REMOTE_LIRCD_ARGS="--uinput"

#Chosen IR Transmitter
TRANSMITTER="Home-brew (odroid gpio)"
TRANSMITTER_MODULES="lirc_odroid lirc_dev"
TRANSMITTER_DRIVER=""
TRANSMITTER_DEVICE="/dev/lirc1"
TRANSMITTER_SOCKET=""
TRANSMITTER_LIRCD_CONF=""
TRANSMITTER_LIRCD_ARGS=""

#Disable kernel support.
#Typically, lirc will disable in-kernel support for ir devices in order to
#handle them internally.  Set to false to prevent lirc from disabling this
#in-kernel support.
#DISABLE_KERNEL_SUPPORT="true"

#Enable lircd
START_LIRCD="true"

#Don't start lircmd even if there seems to be a good config file
#START_LIRCMD="false"

#Try to load appropriate kernel modules
LOAD_MODULES="true"

# Default configuration files for your hardware if any
LIRCMD_CONF=""

#Forcing noninteractive reconfiguration
#If lirc is to be reconfigured by an external application
#that doesn't have a debconf frontend available, the noninteractive
#frontend can be invoked and set to parse REMOTE and TRANSMITTER
#It will then populate all other variables without any user input
#If you would like to configure lirc via standard methods, be sure
#to leave this set to "false"
FORCE_NONINTERACTIVE_RECONFIGURATION="false"
START_LIRCMD=""
_EOT_

if [ `cat /etc/modules | grep -ci -m1 '^meson_ir'` -eq 0 ]; then
	echo -e "meson_ir" >> /etc/modules
fi
if [ `cat /etc/modules | grep -ci -m1 '^lirc_odroid'` -eq 0 ]; then
	echo -e "lirc_odroid" >> /etc/modules
fi

systemctl daemon-reload
systemctl enable lircd.service

clear
read -p "The system needs to be restarted, press [ENTER]."
reboot




