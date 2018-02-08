#!/bin/bash
#Setup script

echo Set a new ROOT password:
passwd

echo "set paste\nset mouse=r" > .vimrc

apt-get install net-tools dbus d-feet less curl bzip2 lsb-compat lsb-release fortune fortunes -y

wget -O .bashrc https://raw.githubusercontent.com/ZacWolf/WebKiosk/master/.bashrc

wget -O .touchscreen.sh https://raw.githubusercontent.com/ZacWolf/WebKiosk/master/touchscreen.sh
chmod 700 .\touchscreen.sh && .\touchscreen.sh

wget -O setupkiosk.sh https://raw.githubusercontent.com/ZacWolf/WebKiosk/master/setupkiosk.sh
chmod 700 .\setupkiosk.sh

read -p "The system will shutdown after you press [ENTER].\nIf you chose a touchscreen monitor, unplug the regular monitor, and plugin the touchscreen monitor after the system shuts down."

shutdown -h now