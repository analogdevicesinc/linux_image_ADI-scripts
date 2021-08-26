#!/bin/bash

# Copyright (c) 2021 Analog Devices, Inc. All Rights Reserved.
# This software is proprietary to Analog Devices, Inc. and its licensors.
# By using this software you agree to the terms of the associated 
# Analog Devices Software License Agreement.

# Manages USB OtG configuration in devicetree for supported platforms


check_platform() {
	# Most ARM systems will fill /sys/firmware.
	MODEL="/sys/firmware/devicetree/base/model"
	if [ -f "${MODEL}" ] ; then
		BASE=$(tr -d '\0' < $MODEL)
		echo "Board=$BASE"
	else
		echo "[ERROR] No Model information in devicetree"
		exit 1
	fi

	if [ "$BASE" = "Xilinx Zynq ZED" ] ; then
		echo "USB_OTG_Supported=Yes"
	else 
		# All other platform are not supported
		echo "USB_OTG_Supported=No"
		exit 1
	fi
}

show_status() {
	echo "USB_OTG_Status=" $(fdtget -t s /boot/devicetree.dtb /amba/usb@e0002000 dr_mode)
}

case "$1" in
enable)
	check_platform	
	fdtput -t s /boot/devicetree.dtb /amba/usb@e0002000 dr_mode otg
	show_status
	;;

disable)
	check_platform
	fdtput -t s /boot/devicetree.dtb /amba/usb@e0002000 dr_mode host
	show_status
	;;

status)
	check_platform
	show_status
	;;

*)
	echo "Usage: $0 {enable|disable|status}"
	exit 1
	;;
esac

