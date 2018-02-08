#!/bin/bash
# Setup Touchscreen

setup_vu5(){
	sed -i 's/^#\ setenv\ m\ \"800x480p60hz\"/setenv\ m\ \"800x480p60hz\"/g' /boot/boot.ini
	sed -i "s/#\ setenv\ m_bpp\ \"24\"/setenv\ m_bpp\ \"24\"/" /boot/boot.ini
	sed -i 's/^#\ setenv\ vout\ \"dvi\"/setenv\ vout\ \"dvi\"/g' /boot/boot.ini
	sed -i "s/setenv\ monitor_onoff\ \"false\" # true or false/setenv\ monitor_onoff\ \"true\"\nsetenv backlight_pwm \"yes\"/" /boot/boot.ini
}

setup_vu7(){
	sed -i 's/^#\ setenv\ m\ \"1024x600p60hz\"/setenv\ m\ \"1024x600p60hz\"/g' /boot/boot.ini
	sed -i "s/#\ setenv\ m_bpp\ \"24\"/setenv\ m_bpp\ \"24\"/" /boot/boot.ini
	sed -i 's/^#\ setenv\ vout\ \"dvi\"/setenv\ vout\ \"dvi\"/g' /boot/boot.ini
	sed -i "s/setenv\ monitor_onoff\ \"false\" # true or false/setenv\ monitor_onoff\ \"true\"\nsetenv backlight_pwm \"yes\"/" /boot/boot.ini
}

setup_vu8(){
	sed -i 's/^#\ setenv\ m\ \"1024x768p60hz\"/setenv\ m\ \"1024x768p60hz\"/g' /boot/boot.ini
	sed -i "s/#\ setenv\ m_bpp\ \"32\"/setenv\ m_bpp\ \"32\"/" /boot/boot.ini
	sed -i 's/^#\ setenv\ vout\ \"dvi\"/setenv\ vout\ \"dvi\"/g' /boot/boot.ini
	sed -i "s/setenv\ monitor_onoff\ \"false\" # true or false/setenv\ monitor_onoff\ \"true\"\nsetenv backlight_pwm \"invert\"/" /boot/boot.ini
}

setup_default(){
	sed -i 's/^#setenv\ m\ \"1920x1080p60hz\"/setenv\ m\ \"1920x1080p60hz\"/g' /boot/boot.ini
	sed -i "s/#\ setenv\ m_bpp\ \"32\"/setenv\ m_bpp\ \"32\"/" /boot/boot.ini
	sed -i 's/^#\ setenv\ vout\ \"dvi\"/setenv\ vout\ \"hdmi\"/g' /boot/boot.ini
	sed -i "s/setenv\ monitor_onoff\ \"false\" # true or false/setenv\ monitor_onoff\ \"true\"\nsetenv backlight_pwm \"invert\"/" /boot/boot.ini
}

sed -i 's/^setenv\ m\ /#\ setenv\ m\ /g' /boot/boot.ini
sed -i "s/^setenv\ m_bpp\ /#\ setenv\ m_bpp\ /g" /boot/boot.ini
sed -i 's/^setenv\ vout\ /#\ setenv\ vout\ /g' /boot/boot.ini

CC=$(whiptail --backtitle "Touchscreen" --menu "Monitor Menu" 0 0 1 --nocancel -ok-button "Select one..."\
                "1" "Setup VU5/7" \
                "2" "Setup VU7+" \
                "3" "Setup VU8" \
				"4" "Setup for non-touch 1080p monitor"
                3>&1 1>&2 2>&3)
	case "$CC" in
			"1")    setup_vu5;;
			"2")    setup_vu7;;
			"3")    setup_vu8;;
			"4")    setup_default;;
			*) msgbox "Error 001. Please report on the forums" && exit 0 ;;
	esac || msgbox "I don't know how you got here! >> $CC << Report on the forums"
	
