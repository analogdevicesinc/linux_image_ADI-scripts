#!/bin/bash
#
# Dumps the register values of an iio device to stdout.
#
# A specific device name can be passed as the first argument and the number of
# registers as the second argument. It defaults trying to dump 256 registers
# from the axi-ad6676-hpc device.
#
# reg-dump.sh [device name] [number of registers to dump]

DEV_NAME=${1:-axi-ad6676-hpc}
NUM_REG=${2:-256}
DEV_NODE=

if [[ ${UID} -ne 0 ]]; then
	echo "This script must be run as root!"
	exit 1
fi

for dev in /sys/bus/iio/devices/*; do 
	[[ $(<"${dev}/name") == "${DEV_NAME}" ]] && DEV_NODE=$(basename ${dev})
done

if [[ -z ${DEV_NODE} ]]; then
	echo "Device node not found for iio device \"${DEV_NAME}\"!"
	echo
	echo "Available iio devices:"
	echo "$(cat /sys/bus/iio/devices/*/name)"
	exit 1
fi

if [[ ! -f /sys/kernel/debug/iio/${DEV_NODE}/direct_reg_access ]]; then
	echo "${DEV_NAME} lacks direct register access debugfs support!"
	exit 1
fi

for reg in $(seq 0 $((NUM_REG-1))); do
	echo ${reg} > /sys/kernel/debug/iio/${DEV_NODE}/direct_reg_access
	hex_addr=$(printf "%x" ${reg})
	val=$(</sys/kernel/debug/iio/${DEV_NODE}/direct_reg_access)
	dec_val=$(printf "%d" ${val})
	echo "Address: 0x${hex_addr^^} (${reg}): Value ${val} (${dec_val})"
done
