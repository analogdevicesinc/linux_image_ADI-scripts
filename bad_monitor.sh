#!/bin/sh

echo "\ndmesg\n=======" > ~/bad.monitor
dmesg >> ~/bad.monitor
echo "\ndpms\n=======" >> ~/bad.monitor
cat /sys/class/drm/card0-HDMI-A-1/dpms >> ~/bad.monitor
echo "\nstatus\n=======" >> ~/bad.monitor
cat /sys/class/drm/card0-HDMI-A-1/status >> ~/bad.monitor
echo "\nenabled\n=======" >> ~/bad.monitor
cat /sys/class/drm/card0-HDMI-A-1/enabled >> ~/bad.monitor
echo "\nmodes\n=======" >> ~/bad.monitor
cat /sys/class/drm/card0-HDMI-A-1/modes >> ~/bad.monitor
echo "\nregmap\n" >> ~/bad.monitor
cat /sys/kernel/debug/regmap/*/registers >> ~/bad.monitor
echo "\nedid\n=======" >> ~/bad.monitor
hexdump -C /sys/class/drm/card0-HDMI-A-1/edid >> ~/bad.monitor
gzip ~/bad.monitor
