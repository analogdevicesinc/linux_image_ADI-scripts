#!/bin/bash

# Copyright (c) 2021 Analog Devices, Inc. All Rights Reserved.
# This software is proprietary to Analog Devices, Inc. and its licensors.
# By using this software you agree to the terms of the associated
# Analog Devices Software License Agreement.

# Manages USB OtG configuration in devicetree for supported platforms


is_compatible() {
	echo $COMP | grep -q $1
	return $?
}

check_platform() {
	# Most ARM systems will fill /sys/firmware.
	COMPATIBLE="/proc/device-tree/compatible"
	if [ -f "${COMPATIBLE}" ] ; then
		COMP=$(strings /proc/device-tree/compatible)
		echo "Compatible=$COMP"
	else
		echo "[ERROR] No Model information in devicetree"
		exit 1
	fi

	if $(is_compatible "xlnx,zynq-7000"); then
		echo "USB_OTG_Supported=Yes"
		fdtget -p /boot/devicetree.dtb /axi > /dev/null 2>&1 && USB="/axi/usb@e0002000" || USB="/amba/usb@e0002000"
		DTB="/boot/devicetree.dtb"
	elif $(is_compatible "xlnx,zynqmp"); then
		echo "USB_OTG_Supported=Yes"
		fdtget -p /boot/devicetree.dtb /axi > /dev/null 2>&1 && USB="/axi/usb0@ff9d0000/dwc3@fe200000" || USB="/amba/usb0@ff9d0000/dwc3@fe200000"
		DTB="/boot/system.dtb"
	else
		# All other platform are not supported
		echo "USB_OTG_Supported=No"
		exit 1
	fi
}

show_status() {
	echo "USB_OTG_Status=" $(fdtget -t s $DTB $USB dr_mode)
}

case "$1" in
enable)
	check_platform
	fdtput -t s $DTB $USB dr_mode otg
	show_status
	;;

disable)
	check_platform
	fdtput -t s $DTB $USB dr_mode host
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

