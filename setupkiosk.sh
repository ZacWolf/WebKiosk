#!/bin/bash

check_deb-multimedia() {
	if [ ! -f /etc/apt/trusted.gpg.d/deb-multimedia-keyring.gpg ]; then
		apt-get install -y --force-yes deb-multimedia-keyring
		apt-get update
	fi
}

board_info() {
	BOARD=`cat /proc/cpuinfo | grep Hardware | awk '{print $3}'`
	case $BOARD in
		ODROID-U2/U3|ODROID-X|ODROID-X2)
			board="exynos4"
			;;
		ODROID-C2)
			board="odroidc2"
			;;
		ODROIDC)
			board="odroidc1"
			;;
		ODROID-XU3|ODROID-XU)
			board="exynos5"
			;;
		*)
			board="not-supported"
			;;
	esac
}

msgbox() {	# $1 is the msg
	whiptail --backtitle "$TITLE" --msgbox "$1" 0 0 0
}

change_hostname(){
	msgbox "Change the hostname for your kiosk.
The RFC requires that the hostname contains only:
letters 'a' to 'z'
numbers '0' to '9'
and hyphen (-)
Note that a hostname cannot begin or end with a hyphen.

No other char/symbol/punctuation or white-spaces are allowed." 0 0 0

	CH=`cat /etc/hostname | tr -d " \t\n\r"`
	NH=$(whiptail --backtitle "$TITLE" --inputbox "Hostname" 0 40 "$CH" 3>&1 1>&2 2>&3)

	if [ $? -eq 0 ]; then
		echo $NH > /etc/hostname
		cat /etc/hosts | sed s/"$CH"/"$NH"/g > /tmp/hosts
		mv /tmp/hosts /etc/hosts
	fi
}

fix_c2_audio(){
	if [ -f /etc/pulse/default.pa ] && [ "x$board" == "xodroidc2" ]; then
		if [ `grep "set-default-sink alsa_output.platform-odroid_hdmi.37.analog-stereo" /etc/pulse/default.pa | wc -l` -lt 1 ]; then
				echo "set-default-sink alsa_output.platform-odroid_hdmi.37.analog-stereo" >> /etc/pulse/default.pa
		fi
	fi
}

odroid_dac(){
	if [ $board == "odroidc2" ]; then
		if [ `cat /etc/modules | grep ^snd-soc-odroid-dac | wc -l` -lt 1 ]; then
				echo "snd-soc-odroid-dac" >> /etc/modules
		fi
		if [ `cat /etc/modules | grep ^snd-soc-pcm5102 | wc -l` -lt 1 ]; then
				echo "snd-soc-pcm5102" >> /etc/modules
		fi
		if [ `grep "^set-default-sink alsa_output.platform-odroid_sound_card.5.analog-stereo" /etc/pulse/default.pa | wc -l` -lt 1 ]; then
			echo "set-default-sink alsa_output.platform-odroid_sound_card.5.analog-stereo
suspend-sink alsa_output.platform-odroid_sound_card.5.analog-stereo 1" >> /etc/pulse/default.pa
        fi
		msgbox "ODROID DAC support enabled"
		echo "pcm.!default {
	type hw;
	card 1;
}
ctl.!default {
	type hw;
	card 1;
}" > /etc/asound.conf
	elif [ $board == "odroidc1" ]; then
		# TODO: untested -> requires ODROID C1+
		msgbox "Please note, that this procedure is untested, since I do not own a ODROID C1+ only a ODROID C1, without the I2S headers.\nPlease report in the forums, if you encounter any issues."
		if [ `grep "# setenv enabledac \"enabledac\"" /boot/boot.ini | wc -l` -eq 1 ]; then
			sed -i "s/# setenv enabledac \"enabledac\"/setenv enabledac \"enabledac\"/" /boot/boot.ini
		fi
		if [ `grep "^set-default-sink alsa_output.platform-odroid_sound_card.5.analog-stereo" /etc/pulse/default.pa | wc -l` -lt 1 ]; then
			echo "set-default-sink alsa_output.platform-odroid_sound_card.5.analog-stereo
suspend-sink alsa_output.platform-odroid_sound_card.5.analog-stereo 1" >> /etc/pulse/default.pa
        fi
	else
		msgbox "You shouldn't get here, please report on forums!"
		exit 1
	fi
}

enable_ir() {
	# setup modules
	if [ $board == "exynos5" ]; then
		msgbox "Please note, that this option was made for ODROID XU4 Cloudshell and may not work with other setups."
		options="options gpioplug_ir_recv gpio_nr=24 active_low=1"
		if [ `cat /etc/modprobe.d/odroid-cloudshell.conf | grep -ci -m1 "^$options"` -eq 0 ]; then
				echo "$options" >> /etc/modprobe.d/odroid-cloudshell.conf
		fi
		module="gpio-ir-recv"
		if [ `cat /etc/modules | grep -ci -m1 "^$module"` -eq 0 ]; then
				echo "$module" >> /etc/modules
				modprobe $module
		fi
	elif [ $board == "odroidc2" ] || [ $board == "odroidc1" ]; then
		if [ `cat /etc/modules | grep -ci -m1 '^meson_ir'` -eq 0 ]; then
			echo -e "meson_ir" >> /etc/modules
			modprobe meson_ir
		fi
	fi
	# install lirc
	[ `dpkg --get-selections | grep -ci -m1 '^lirc'` -eq 0 ] && apt-get install -y lirc

	#Stop complaints during startup since not using the Kodi remote
	mv /etc/lirc/lircd.conf.d/devinput.lircd.conf ~
	
	# install systemd script for IR
	cat <<_EOF_>> /etc/systemd/system/odroid-ir.service
[Unit]
Description=Odroid IR

[Service]
Type=forking
ExecStartPre=/bin/bash -c 'mkdir -p /var/run/lirc'
ExecStart=/usr/sbin/lircd --output=/run/lirc/lircd --driver=default --device=/dev/lirc0 --uinput

[Install]
WantedBy=multi-user.target
_EOF_
	systemctl daemon-reload
	msgbox "ODROID IR configured systemd script \"odroid-ir\"."
	systemctl enable odroid-ir.service
	systemctl start odroid-ir.service

}

install_xorg() {
	cat <<_EOT_>> /root/.xsession
#!/bin/bash
export DISPLAY=:0
xset +dpms
xset dpms 30 60 300
xset s off
xterm
_EOT_
	apt-get install xserver-xorg xinit x11-xserver-utils xterm -y
	case $board in
		exynos4|exynos5)
			cp /usr/local/share/setup-odroid/xorg/exynos/xorg.conf /etc/X11/
			;;
		odroidc1)
			cp /usr/local/share/setup-odroid/xorg/c1/xorg.conf /etc/X11/
			;;
		odroidc2)
			cp /usr/local/share/setup-odroid/xorg/c2/mali/xorg.conf /etc/X11/
			;;
		*)
			# nothing to do
			msgbox "Your board is not (yet) supported! Please ask in Forums for help."
			exit 0
			;;
	esac
}

install_gpu() {
	case $board in
		exynos4)
			apt-get install -y mali400-odroid
			msgbox "Installed mali400-odroid driver"
			;;
		exynos5)
			apt-get install -y malit628-odroid
			msgbox "Installed malit628-odroid driver"
			;;
		odroidc1|odroidc2)
			if [ ! -z $fbdev ]; then
					apt-get install -y mali450-fbdev-odroid
					msgbox "Installed mali450-fbdev-odroid driver"
			else
					apt-get install -y mali450-odroid
					msgbox "Installed mali450-odroid driver"
			fi
			;;
		*)
			# nothing to do / not supported
			msgbox "Your board is not (yet) supported! Please ask in Forums for help."
			exit 0
			;;
	esac
}

install_ddx() {
	case $board in
		odroidc1)
			if [ ! -z $fbdev ]; then
				# nothing here yet
				continue
			else
				apt-get install -y xf86-video-mali-odroid libump-odroid
				"Installed xf86-video-mali-odroid driver"
			fi
			;;
		odroidc2)
			if [ ! -z $fbdev ]; then
				# nothing here yet
				continue
			else
				apt-get install -y xf86-video-fbturbo-odroid libump-odroid
				cp /usr/local/share/setup-odroid/xorg/c2/fbturbo/xorg.conf /etc/X11
				msgbox "Installed xf86-video-fbturbo-odroid driver"
			fi
			;;
		exynos4|exynos5)
			apt-get install -y xf86-video-armsoc-odroid
			msgbox "Installed xf86-video-armsoc-odroid driver"
			;;
		*)
			# nothing to do / not supported
			msgbox "Your board is not (yet) supported! Please ask in Forums for help."
			exit 0
			;;
	esac
}

install_backlightpwm(){ # currently unsupported
	cp /etc/rc.local ~
	case $board in
		odroidc1)
			sed -i "s/exit\ 0//g" /etc/rc.local
			tee -a /etc/rc.local <<_EOT_
echo 97 | tee /sys/class/gpio/export
echo out | tee /sys/class/gpio/gpio97/direction
echo 0 | tee /sys/class/gpio/gpio97/value
chown  $USERNAME:$USERNAME /sys/class/gpio/gpio97/value
echo 108 | tee /sys/class/gpio/export
echo out | tee /sys/class/gpio/gpio108/direction
echo 0 | tee /sys/class/gpio/gpio108/value
chown  $USERNAME:$USERNAME /sys/class/gpio/gpio108/value
exit 0
_EOT_
			echo -e "$CHROMIMUM $DEFAULT_URL &" >> /home/$USERNAME/.xsession
			tee -a /home/$USERNAME/.xsession << _EOT_
while true
do
sleep 1
stat=$(xset -q|sed -ne 's/^[ ]*Monitor is //p')
if [ "$stat" == "Off" -a "$cur_stat" == "On" ]; then
        echo "monitor goes to Off"
        echo 1 | tee /sys/class/gpio/gpio97/value
        echo 1 | tee /sys/class/gpio/gpio108/value
        cur_stat=$stat
elif [ "$stat" == "On" -a "$cur_stat" == "Off" ]; then
        echo "monitor turns back On"
        echo 0 | tee /sys/class/gpio/gpio108/value
        echo 0 | tee /sys/class/gpio/gpio97/value
        cur_stat=$stat
fi
done
_EOT_
			;;
		odroidc2)
			sed -i "s/exit\ 0//g" /etc/rc.local
			tee -a /etc/rc.local.new << _EOT_
echo 234 | tee export
echo out | tee /sys/class/gpio/gpio234/direction
echo 0 | tee /sys/class/gpio/gpio234/value
chown  $USERNAME:$USERNAME /sys/class/gpio/gpio234/value
echo 214 | tee export
echo out | tee /sys/class/gpio/gpio214/direction
echo 0 | tee /sys/class/gpio/gpio214/value
chown  $USERNAME:$USERNAME /sys/class/gpio/gpio214/value
exit 0
_EOT_
			echo -e "$CHROMIMUM  $DEFAULT_URL &" >> /home/$USERNAME/.xsession
			tee -a /home/$USERNAME/.xsession  <<_EOT_
while true
do
sleep 1
stat=$(xset -q|sed -ne 's/^[ ]*Monitor is //p')
if [ "$stat" == "Off" -a "$cur_stat" == "On" ]; then
        echo "monitor goes to Off"
        # backlight off first 
        echo 1 | tee /sys/class/gpio/gpio214/value
        echo 1 | tee /sys/class/gpio/gpio234/value
        cur_stat=$stat
elif [ "$stat" == "On" -a "$cur_stat" == "Off" ]; then
        echo "monitor turns back On"
        echo 0 | tee /sys/class/gpio/gpio234/value
        echo 0 | tee /sys/class/gpio/gpio214/value
        cur_stat=$stat
fi
done
_EOT_
			;;
		*)
			# nothing to do / not supported
			msgbox "Backlight Control for your board is not (yet) supported! Please ask in Forums for help."
			;;
    esac
}


config_xsession(){
	cat <<_EOT_>> /home/$USERNAME/.xsession
#!/bin/bash
backlight_stat = "On"
export DISPLAY=:0
xset +dpms
xset dpms 30 60 120
xset s off
rm -f /home/chrome/.cache/chromium/Default/Cache/*
_EOT_
	echo -e "$CHROMIMUM $DEFAULT_URL" >> /home/$USERNAME/.xsession
	chown $USERNAME:$USERNAME /home/$USERNAME/.xsession
	chmod 755 /home/$USERNAME/.xsession
}


install_tomcat(){
		sed i s/http:\/\/localhost/http:\/\/localhost:8080/g /home/$USERNAME/.xsession
		cat <<_EOT_>> /var/lib/tomcat8/webapps/ROOT/index.html
<html>
<head></head>
<body>
<table width="100%">
	<tr>
		<td nowrap><h1>Tomcat8:</h1>
			Tomcat installed at: <br />
			<code>/usr/share/tomcat8</code> <br />
			<code>/etc/tomcat8</code> <br />
			<code>/var/lib/tomcat8/webapps/ROOT</code>
		</td>
		<td width="100%" valign="center">
			<center>
			<h2><a href="http://google.com">Google</h2>
			<h2><a href="http://www.pandora.com">Pandora</h2>
			<h2><a href="http://amazon.com">Amazon</h2>
			</center>
		</td>
	</tr>
</table>
</body>
</html>
_EOT_
		DEFAULT_URL=http://localhost:8080
		msgbox "Installed Tomcat"
}

install_ngix(){
	apt-get install nginx -y
	cat <<_EOT_>> /var/www/nginx-default/index.html
<html>
<head></head>
<body>
<table width="100%">
	<tr>
		<td nowrap><h3>ngix:</h3>
			ngix installed at: <br />
			<code>/var/www/nginx-default/</code>
		</td>
		<td width="100%" valign="center">
			<center>
			<h2><a href="http://google.com">Google</h2>
			<h2><a href="http://www.pandora.com">Pandora</h2>
			<h2><a href="http://amazon.com">Amazon</h2>
			<h2></h2>
			<h2><a href="chrome://gpu">GPU</a></h2>
			</center>
		</td>
	</tr>
</table>
</body>
</html>
_EOT_
		msgbox "Installed nginx as basic webserver"
}

kiosk_URL_setother(){

	CU=http://www.google.com
	NU=$(whiptail --backtitle "Set the the default URL for your kiosk:" --inputbox "Default URL" 0 40 "$CU" 3>&1 1>&2 2>&3)

	if [ $? -eq 0 ]; then
		DEFAULT_URL=$NU
	fi
}

kiosk_URL(){
CC=$(whiptail --backtitle "Default Kiosk URL" --menu "WebServer Menu" 0 0 1 --nocancel -ok-button "Select one..."\
                "1" "Install Tomcat (Java Server)" \
                "2" "Install nGIX (Basic webserver)" \
                "3" "Specify a default URL" \
                3>&1 1>&2 2>&3)
	case "$CC" in
			"1")    install_tomcat;;
			"2")    install_ngix;;
			"3")    kiosk_URL_setother;;
			*) msgbox "Error 001. Please report on the forums" && exit 0 ;;
	esac || msgbox "I don't know how you got here! >> $CC << Report on the forums"
}

#========================================================
# START SCRIPT
#========================================================

USERNAME=chrome
CHROMIUM=/usr/bin/chromium --kiosk --no-first-run --disable-translate --disable-infobars --use-gl=egl --ignore-gpu-blacklist --num-raster-threads=4 --enable-zero-copy --enable-floating-virtual-keyboard
DEFAULT_URL=http://localhost


board_info
check_deb-multimedia

apt-get install console-setup keyboard-configuration pulseaudio -y
dpkg-reconfigure keyboard-configuration
dpkg-reconfigure locales
dpkg-reconfigure tzdata

change_hostname
enable_ir
CC=$(whiptail --backtitle "ODROID audio device" --yesno "Will you be using an ODROID audio device (Stereo Bonnet or HiFi Shield)?" 0 0 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
		odroid_dac
	else
		fix_c2_audio
	fi	
	
install_xorg
install_gpu
install_ddx
apt-get install nodm chromium -y
ln -sf /usr/lib/aarch64-linux-gnu/libGLESv2.so /usr/lib/chromium/libGLESv2.so
ln -sf /usr/lib/aarch64-linux-gnu/libEGL.so /usr/lib/chromium/libEGL.so
useradd -m $USERNAME
echo -e "$USERNAME\n$USERNAME" | passwd $USERNAME
adduser $USERNAME video
adduser $USERNAME audio
adduser $USERNAME adm
adduser $USERNAME cdrom
adduser $USERNAME input
adduser $USERNAME tty
sed -i -e "s/root/$USERNAME/g" /etc/default/nodm
kiosk_URL
config_xsession

sed -i "s/setenv\ condev\ \"consoleblank=0\ console=ttyS0,115200n8\ console=tty0\"/setenv\ condev\ \"consoleblank=1\ console=ttyS0,115200n8\"/" /boot/boot.ini
	
reboot