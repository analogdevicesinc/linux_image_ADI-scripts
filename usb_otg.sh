#!/bin/bash

# Copyright (c) 2021-22 Analog Devices, Inc. All Rights Reserved.
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
		fdtget -p /boot/devicetree.dtb /axi > /dev/null 2>&1 && USB="/axi/usb@e0002000" || USB="/amba/usb@e0002000"
		DTB="/boot/devicetree.dtb"
	elif $(is_compatible "xlnx,zynqmp"); then
		fdtget -p /boot/devicetree.dtb /axi > /dev/null 2>&1 && USB="/axi/usb0@ff9d0000/dwc3@fe200000" || USB="/amba/usb0@ff9d0000/dwc3@fe200000"
		DTB="/boot/system.dtb"
	elif $(is_compatible "altr,socfpga-cyclone5"); then
		USB="/soc/usb@ffb40000"
		DTB="/boot/socfpga.dtb"
	else
		# All other platform are not supported
		echo "USB OtG Supported=No"
		exit 1
	fi
	echo "USB OtG Supported=Yes"
}

show_status() {
	echo "USB dr_mode=" $(fdtget --default "Not Specified: per usb/generic.txt dr_mode should default to otg" --type s $DTB $USB dr_mode)
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

delete_dr_mode)
	check_platform
	fdtput -d $DTB $USB dr_mode
	show_status
	;;

status)
	check_platform
	show_status
	;;

*)
	echo "Usage: $0 {enable|disable|delete_dr_mode|status}"
	exit 1
	;;
esac

