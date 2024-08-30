#!/bin/bash

if [ ! $(grep -qi -e "ZCU102" -e "ADRV9009-ZU" -e "Jupiter SDR" /sys/firmware/devicetree/base/model) ]; then
	# modify audio default sampling rate
	sed -i '/default-sample-rate/c\default-sample-rate = 48000' /etc/pulse/daemon.conf
fi
