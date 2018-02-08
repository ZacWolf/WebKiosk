#!/bin/bash

check_deb-multimedia() {
	if [ ! -f /etc/apt/trusted.gpg.d/deb-multimedia-keyring.gpg ]; then
		apt-get install -y --force-yes deb-multimedia-keyring
		apt-get update
	fi
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
}

install_gpu() {
	if [ ! -z $fbdev ]; then
			apt-get install -y mali450-fbdev-odroid
			msgbox "Installed mali450-fbdev-odroid driver"
	else
			apt-get install -y mali450-odroid
			msgbox "Installed mali450-odroid driver"
	fi
}

install_ddx() {
	if [ ! -z $fbdev ]; then
		# nothing here yet
		continue
	else
		apt-get install -y xf86-video-fbturbo-odroid libump-odroid
		cp -f /usr/local/share/setup-odroid/xorg/c2/fbturbo/xorg.conf /etc/X11
		msgbox "Installed xf86-video-fbturbo-odroid driver"
	fi
}

install_backlightpwm(){ # currently unsupported
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
	echo -e "$CHROMIMUM &" >> /home/$USERNAME/.xsession
	tee -a /home/$USERNAME/.xsession  <<_EOT_
backlight_stat = "On"	
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
}


config_xsession(){
	cat <<_EOT_>> /home/$USERNAME/.xsession
#!/bin/bash
export DISPLAY=:0
xset +dpms
xset dpms 30 60 120
xset s off
rm -f /home/chrome/.cache/chromium/Default/Cache/*
_EOT_
	echo $CHROMIMUM >> /home/$USERNAME/.xsession
	chown $USERNAME:$USERNAME /home/$USERNAME/.xsession
	chmod 755 /home/$USERNAME/.xsession
}


install_tomcat(){
	apt-get install default-jdk tomcat8 -y
	sed -i s/localhost/http:\/\/localhost:8080/g /home/$USERNAME/.xsession
	cat <<_EOT_>> /var/lib/tomcat8/webapps/ROOT/index.html
<html>
<head></head>
<body>
<table width="100%">
	<tr>
		<td nowrap><h1>Tomcat8:</h1>
			Tomcat installed at: <br />
			<code>/usr/share/tomcat8</code> <br />
			Conf:<br />
			<code>/etc/tomcat8</code> <br />
			Doc root:<br />
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
		<td nowrap><h1>ngix:</h1>
			ngix doc root at: <br />
			<code>/var/www/nginx-default/</code>
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
		msgbox "Installed nginx as basic webserver"
}

kiosk_URL_setother(){

	CU=http://www.google.com
	NU=$(whiptail --backtitle "Set the the default URL for your kiosk:" --inputbox "Default URL" 0 40 "$CU" 3>&1 1>&2 2>&3)

	if [ $? -eq 0 ]; then
		sed -i -e "s/http:\/\/localhost/http:\/$NU/g" /home/$USERNAME/.xsession
	fi
}

kiosk_URL(){
CC=$(whiptail --backtitle "Default Kiosk URL" --menu "WebServer Menu" 0 0 1 --nocancel --ok-button "Select one..." \
                "1" "Install Tomcat (Java Server)" \
                "2" "Install nGIX (Basic webserver)" \
                "3" "Set a specific URL" \
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
CHROMIUM="/usr/bin/chromium --kiosk --no-first-run --disable-translate --disable-infobars --use-gl=egl --ignore-gpu-blacklist --num-raster-threads=4 --enable-zero-copy --enable-floating-virtual-keyboard http://localhost"

check_deb-multimedia

apt-get install console-setup keyboard-configuration pulseaudio -y
dpkg-reconfigure keyboard-configuration
dpkg-reconfigure locales
dpkg-reconfigure tzdata

change_hostname
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

apt autoremove -y
	
reboot