#!/bin/bash -e

if [[ ! -d "/usr/share/X11/xorg.conf.d/" ]]; then
	mkdir -p "/usr/share/X11/xorg.conf.d"
fi

echo 'Section "Device"
    Identifier  "Configured Video Device"
    Driver      "dummy"
EndSection

Section "Monitor"
    Identifier  "Configured Monitor"
    HorizSync 31.5-48.5
    VertRefresh 50-70
EndSection

Section "Screen"
    Identifier  "Default Screen"
    Monitor     "Configured Monitor"
    Device      "Configured Video Device"
    DefaultDepth 24
    SubSection "Display"
    Depth 24
    Modes "1280x720"
    EndSubSection
EndSection' > /usr/share/X11/xorg.conf.d/xorg.conf
