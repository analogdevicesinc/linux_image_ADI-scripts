#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
#
# kuiper2.0 - Embedded Linux for Analog Devices Products
#
# Copyright (c) 2024 Analog Devices, Inc.
# Author: Larisa Radu <larisa.radu@analog.com>

show_help() {

cat << EOF
Usage:
  sudo $(basename "$0") [OPTIONS] <eval-board> <carrier> [bootloader-dev]

Description:
  Script that prepares Kuiper image to boot on a carrier board.

Arguments:
  eval-board            Name of the project
  carrier               Carrier board name
  bootloader-dev        Bootloader device (default: /dev/mmcblk0p3)

Options:
  -b, --boot-partition PATH     Path to boot partition (default: /boot)
  -h, --help                    Show this help message

Notes:
  - Options must be specified before positional arguments.
  - The -b option affects which projects are listed by --help. To see projects
    on an attached SD card, use: sudo $(basename "$0") -b /media/\$USER/BOOT --help

Examples:
  # Running directly on the board:
  sudo $(basename "$0") ad4003 zed
  sudo $(basename "$0") --help

  # Configuring SD card from PC:
  sudo $(basename "$0") -b /media/\$USER/BOOT ad4003 zed
  sudo $(basename "$0") -b /media/\$USER/BOOT --help
  sudo $(basename "$0") -b /media/\$USER/BOOT <eval-board> <intel-carrier> /dev/sdb3
EOF

	echo -e "\n\nAvailable projects in your Kuiper image:\n"

	{
		# Print header
		echo -e "ADI Eval Board\tCarrier"

		# Print projects and boards
		find ${BOOT_PARTITION} -type f -name "*.json" 2>/dev/null | while read -r file; do
			jq -r '
			.projects[]?
			| select(has("name") and has("board"))
			| [.name, .board]
			| @tsv
			' "$file"
		done
	} | column -t -s $'\t'
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ] ; then
	echo "This script must be run as root"
	exit 1
fi

BOOT_PARTITION="/boot"

# Parse optional flags and their arguments, stopping at the first positional argument
while [[ $# -gt 0 ]]; do
	case $1 in
		-h|--help)
			show_help
			exit 0
			;;
		-b|--boot-partition)
			if [[ -z "$2" || "$2" == -* ]]; then
				echo "Error: --boot-partition requires a path argument" >&2
				exit 2
			fi
			BOOT_PARTITION="$2"
			shift 2
			;;
		-*)
			echo "Error: Unknown option $1" >&2
			show_help
			exit 2
			;;
		*)
			break
			;;
	esac
done

# Validate positional arguments
if [[ $# -lt 2 ]]; then
	echo -e "Error: Missing required arguments.\n" >&2
	show_help
	exit 2
fi

ADI_EVAL_BOARD=${1}
CARRIER=${2}
BOOTLOADER_DEV=${3:-"/dev/mmcblk0p3"}

if [[ ! -z "${ADI_EVAL_BOARD}"  && ! -z "${CARRIER}" ]]; then

	# Extract project description from .json by selecting the project set in the configuration file
	PROJECT_DESCRIPTION=$(find ${BOOT_PARTITION} -type f -name "*.json" \
		-exec jq -c '.projects[]? | select(.name=="'${ADI_EVAL_BOARD}'" and .board=="'${CARRIER}'")' {} + \
		| head -n 1)

	# Check if project exists
	if [[ -z "${PROJECT_DESCRIPTION}" ]]; then
		echo "Cannot find project ${ADI_EVAL_BOARD} for board ${CARRIER}. Setup not configured."
	else
		# Extract kernel path from the project description and adjust for boot partition location
		kernel=$(echo "$PROJECT_DESCRIPTION" | jq -r '.kernel' | sed "s|^/boot|${BOOT_PARTITION}|")

		# Copy kernel to Kuiper boot directory
		cp -v ${kernel} ${BOOT_PARTITION}
		if [ $? -ne 0 ]; then
			echo "Something went wrong while copying the kernel. Boot partition can't be configured."
			exit
		fi

		# Extract paths with boot files from the project description and adjust for boot partition location
		paths=$(echo "$PROJECT_DESCRIPTION" | jq -r '.files[].path' | sed "s|^/boot|${BOOT_PARTITION}|")

		# Add the correct prefix for all paths and copy them to Kuiper boot directory
		cp -v $paths ${BOOT_PARTITION}
		if [ $? -ne 0 ]; then
			echo "Something went wrong while copying boot files. Boot partition can't be configured."
			exit
		fi

		# Check if project platform is Intel
		if [[ ! -z $(echo "$PROJECT_DESCRIPTION" | jq 'select(.platform == "intel")') ]]; then

			# Create folder if it doesn't exist and move copied extlinux.conf to extlinux folder
			mkdir -p ${BOOT_PARTITION}/extlinux/ && mv -v ${BOOT_PARTITION}/extlinux.conf ${BOOT_PARTITION}/extlinux/

			# Extract preloader file from the project description and adjust for boot partition location
			preloader=$(echo "$PROJECT_DESCRIPTION" | jq -r '.preloader' | sed "s|^/boot|${BOOT_PARTITION}|")

			# Write preloader file to corresponding image partition
			dd if=${preloader} of=${BOOTLOADER_DEV} status=progress
			if [ $? -ne 0 ]; then
				echo "Something went wrong while copying the preloader. Boot partition can't be configured."
				exit
			fi

		# Remove leftover extlinux configuration for other platforms
		else
			if [[ -d "${BOOT_PARTITION}/extlinux" ]]; then
				rm -rfv ${BOOT_PARTITION}/extlinux/
			fi
		fi
		echo "Successfully prepared boot partition for running project ${ADI_EVAL_BOARD} on ${CARRIER}."
	fi
else
	echo "Setup won't be configured because setup variables are null."
fi
