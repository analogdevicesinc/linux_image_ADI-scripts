#!/bin/sh

if grep -qi -e "ZCU102" -e "ADRV9009-ZU" -e "Jupiter SDR" /sys/firmware/devicetree/base/model; then
	# create X11 xorg.conf
	printf "Section \"Device\"\n  Identifier \"myfb\"\n  Driver \"fbdev\"\n  Option \"fbdev\" \"/dev/fb0\"\nEndSection\n" \
		> /etc/X11/xorg.conf

	# delete xorg.conf created by enable_dummy_display if exists
	rm -f /usr/share/X11/xorg.conf.d/xorg.conf
else
	rm -f /etc/X11/xorg.conf
fi
