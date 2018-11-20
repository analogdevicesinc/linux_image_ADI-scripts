#!/bin/sh

grep -qi "ZCU102" /sys/firmware/devicetree/base/model && \
printf "Section \"Device\"\n  Identifier \"myfb\"\n  Driver \"fbdev\"\n  Option \"fbdev\" \"/dev/fb0\"\nEndSection\n" > /etc/X11/xorg.conf || \
rm  /etc/X11/xorg.conf
