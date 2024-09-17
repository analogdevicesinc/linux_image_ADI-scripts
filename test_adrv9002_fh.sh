#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
#
# This is a test script for testing fast frequency hopping in ADRV9002 designs.
# It depends on libiio (and tools) and realpath (which is installed by default in almost every distribution).
# The script provides some configurability but also enforces some defaults:
# * HOP signal 1 will control RX1/TX1.
# * HOP signal 2 will control RX2/TX2.
# * If HOP1 is given we default to Frequency Hopping mode: LO_RETUNE_REALTIME_PROCESS
# * If HOP2 is given we default to Frequency Hopping mode: LO_RETUNE_REALTIME_PROCESS_DUAL_HOP
# * As a consequence of the above item, the max table size is 32.
# * DGPIO_2 will be used to control the hop signal.
# * DGPIO_3 is the base for the gpio's used when the index table control is set to gpio.
# * The script only tests one port on each call and the port to test is deduced from the hop signal and --rx
#   flag parameter (eg: hop signal 1 without --rx will run the test on TX1).
set -euo pipefail

profile=""
stream=""
tbl_a=""
tbl_b=""
tbl_sz_a=0
tbl_sz_b=0
tbl_ctl="gpio"
tbl_ngpio=0
max_tbl_sz=64
# start of gpios for index table control
dgpio_3=0
rx="false"
hop=1
hop_en=0
dev_name="adrv9002-phy"
iio_dev=""
port_en=0
verbose="n"
# number of times we loop through the hopping tables
n_run=5
# false if we can't export the enable pins and the driver is in control of those
export_en_pin=y

usage() {
	printf "Usage: $0 [options] TABLE_A [TABLE_B]
Script to test fast frequency hopping for ADRV9002 devices. At least
one table must be given. The second one is optional.

Options:
  -n, --n-run		number of times we loop through the hopping tables [defaults to 5].
  -p, --profile		profile to load on the device. it takes two arguments being the
			first the stream file and the second the profile.
			[only mandatory if a FH enabled profile is not already loaded].
  -c, --table-ctl	how to control table indexing [defaults to gpio]:
	gpio		use gpios to control the indexes.
	loop		automatically increment through the indexes.
	ping-pong	automatically switch tables when the last index is reached.
  -s, --hop-signal	which hop signal to use [must be either 1 or 2]. combined
			with the --rx flag controls which port will be tested.
  -r, --rx		test on a rx port [defaults to 1].
  -d, --debug		verbose on.
  -h, --help		display this help and exit.
	\n"
	exit 2
}

error() {
	[[ ${#} -gt "0" ]] && echo "[ERROR]: "${*}
	exit 1
}

info() {
	[[ ${#} -gt "0" ]] && echo "[INFO]: "${*}

	return 0
}

debug() {
	[[ ${#} -gt "0" && ${verbose} == "y" ]] && echo "[DEBUG]: "${*}

	return 0
}

file_exists() {
	[[ ! -f ${1} ]] && error "\"${1}\" does not exist..."

	return 0
}

validate_tbl() {
	local tbl_sz=0
	local tbl_type=${2}

	file_exists "${1}"

	tbl_sz=$(cat "${1}" | egrep -v '<.*>|^#|^$' | wc -l)
	[[ ${tbl_sz} -gt ${max_tbl_sz} ]] && error "\"${1}\" has more than ${max_tbl_sz} entries(${tbl_sz})..."

	[[ ${tbl_type} == "a" ]] && tbl_sz_a=${tbl_sz} || tbl_sz_b=${tbl_sz}

	return 0
}

get_ngpios() {
	local max_gpios=6
	local i=1;
	local n=1;
	local tbl_sz=$((tbl_sz_a > tbl_sz_b ? tbl_sz_a : tbl_sz_b))

	[[ ${tbl_ctl} != "gpio" ]] && { echo 0; return 0; }

	while [[ ${i} -le ${max_gpios} ]]; do
		n=$((${n} * 2))
		if [[ ${n} -ge ${tbl_sz} ]]; then
			echo ${i}
			break
		fi

		let i+=1
	done

	return 0
}

do_set_gpio_idx() {
	local gpio=0
	local g=0
	local idx=${1}

	[[ ${tbl_ctl} != "gpio" ]] && return 0

	debug "Set gpios for idx=${idx}"
	for ((g=0; g<${tbl_ngpio}; g++)); do
		gpio=$((${dgpio_3} + ${g}))
		# unset the gpio first so we make sure we get the exact index we want
		echo 0 > "/sys/class/gpio/gpio${gpio}/value"
		if [[ "$((${idx} & $((1<<${g}))))" != 0 ]]; then
			debug "Set gpio${gpio}"
			echo 1 > "/sys/class/gpio/gpio${gpio}/value"
		fi
	done

	return 0
}

do_gpios_export() {
	local model=$(tr -d \\0 </sys/firmware/devicetree/base/model)
	local g=0
	local gpio=0
	local rx1_en=0
	# let's dynamically get the gpios offset based on the platform as this already proved
	# it can change between versions.
	local off=0
	local jupiter=n
	local port_en_sign="+"

	# gpio's as defined in ADI devicetrees/reference designs
	if  [[  ${model} =~ "ZynqMP" ||  ${model} =~ "Jupiter SDR" ]]; then
		off=$(cat /sys/kernel/debug/gpio | grep zynqmp_gpio | grep -Eo '[0-9]+-[0-9]+' | cut -d"-" -f1)
		# hop_en will use dgpio2
		hop_en=$((${off} + 112))
		dgpio_3=$((${off} + 113))
		[[ ${model} =~ "ZynqMP" ]] && rx1_en=$((${off} + 126)) || {
			rx1_en=$((${off} + 125))
			jupiter=y
			port_en_sign="-"
		}
	elif [[ ${model} =~ "Xilinx Zynq" ]]; then
		off=$(cat /sys/kernel/debug/gpio | grep zynq_gpio | grep -Eo '[0-9]+-[0-9]+' | cut -d"-" -f1)
		# zynq (also applies to ZED) platforms have a 906 offset from the value defined
		# in the devicetree
		hop_en=$((${off} + 88))
		dgpio_3=$((${off} + 89))
		rx1_en=$((${off} + 102))
	else
		error "Unknown System: \"${model}\""
	fi

	# let's point to the port we want to control.
	if [[ ${hop} == 1 ]]; then
		if [[ ${rx} == "true" ]]; then
			port_en=${rx1_en}
		else
			# tx1
			port_en=$((${rx1_en} ${port_en_sign} 2))
		fi
	else
		if [[ ${rx} == "true" ]]; then
			# rx2
			port_en=$((${rx1_en} ${port_en_sign} 1))
		else
			# tx2
			port_en=$((${rx1_en} ${port_en_sign} 3))
		fi
	fi

	# export the enable pin for the used port and make sure it's output low
	[[ ! -e /sys/class/gpio/gpio${port_en} ]] && { \
		debug "Export GPIO: ${port_en}"
		echo ${port_en} > "/sys/class/gpio/export" 2>/dev/null && {
			echo low > "/sys/class/gpio/gpio${port_en}/direction"
		} || {
			# We could redirect stderr to a file and look for "Device or resource busy". But,
			# meh, not going with that. Just assume that in case of error we can control the pin
			# over the device ensm interface. If we can't, the script will fail later on anyways.
			export_en_pin="n"
		}
	}

	# export hop pin
	[[ ! -e /sys/class/gpio/gpio${hop_en} ]] && { \
		debug "Export GPIO; ${hop_en}"
		echo ${hop_en} > "/sys/class/gpio/export"
		echo low > "/sys/class/gpio/gpio${hop_en}/direction"
	}

	# export gpios for table control
	for ((g=0; g<${tbl_ngpio}; g++)); do
		gpio=$((${dgpio_3} + ${g}))

		[[ ! -e /sys/class/gpio/gpio${gpio} ]] && {
			debug "Export GPIO; ${gpio}"
			echo ${gpio} > "/sys/class/gpio/export"
			echo low > "/sys/class/gpio/gpio${gpio}/direction"
		}
	done

	return 0
}

do_gpios_unexport() {
	local g=0
	local gpio=0

	debug "Unexporting GPIOS: ${hop_en}"
	[[ ${export_en_pin} == "y" ]] && {
		debug "Unexporting GPIOS: ${port_en}"
		echo ${port_en} > "/sys/class/gpio/unexport"
	}
	echo ${hop_en} > "/sys/class/gpio/unexport"

	for ((g=0; g<${tbl_ngpio}; g++)); do
		gpio=$((${dgpio_3} + ${g}))

		debug "Unexporting GPIOS: ${gpio}"
		echo ${gpio} > "/sys/class/gpio/unexport"
	done

	return 0
}

do_config() {
	local p
	# first we will do all static/forced configurations
	# unset all pins so there's no possibility of overlapping
	iio_attr -D ${dev_name} fh_hop1_table_select_pin_set 0 1>/dev/null
	iio_attr -D ${dev_name} fh_hop2_table_select_pin_set 0 1>/dev/null
	iio_attr -D ${dev_name} fh_hop1_pin_set 0 1>/dev/null
	iio_attr -D ${dev_name} fh_hop2_pin_set 0 1>/dev/null
	iio_attr -D ${dev_name} fh_table_index_control_npins 0 1>/dev/null
	# force hop mappings. HOP1 = [RX1 TX1], HOP2 = [RX2 TX2]
	iio_attr -D ${dev_name} fh_rx0_port_hop_signal 0 1>/dev/null
	iio_attr -D ${dev_name} fh_tx0_port_hop_signal 0 1>/dev/null
	iio_attr -D ${dev_name} fh_rx1_port_hop_signal 1 1>/dev/null
	iio_attr -D ${dev_name} fh_tx1_port_hop_signal 1 1>/dev/null
	# force it to dual hop if using hop signal 2. This also means that the
	# table size cannot be bigger than 32 entries
	[[ ${hop} == 2 ]] && iio_attr -D ${dev_name} fh_mode 3 1>/dev/null || \
		iio_attr -D ${dev_name} fh_mode 2 1>/dev/null
	# force maximum lo range
	iio_attr -D ${dev_name} fh_min_lo_freq_hz 30000000 1>/dev/null
	iio_attr -D ${dev_name} fh_max_lo_freq_hz 6000000000 1>/dev/null
	# let's do now the actual config set by the user
	# dgpio_2 for hop signal
	iio_attr -D ${dev_name} fh_hop${hop}_pin_set 3 1>/dev/null
	if [[ ${tbl_ctl} == "gpio" ]]; then
		iio_attr -D ${dev_name} fh_table_index_control_mode 2 1>/dev/null
	elif [[ ${tbl_ctl} == "ping-pong" ]]; then
		iio_attr -D ${dev_name} fh_table_index_control_mode 1 1>/dev/null
	else
		iio_attr -D ${dev_name} fh_table_index_control_mode 0 1>/dev/null
	fi

	tbl_ngpio=$(get_ngpios)
	debug "Got ngpios=${tbl_ngpio}"
	iio_attr -D ${dev_name} fh_table_index_control_npins ${tbl_ngpio} 1>/dev/null
	for p in $(seq 1 ${tbl_ngpio}); do
		# we start at dgpio3 so pin4
		iio_attr -D ${dev_name} fh_table_index_control_pin${p} $((${p} + 3)) 1>/dev/null
	done

	return 0
}

do_dev_init() {
	local fh=$(iio_attr -d ${dev_name} profile_config | grep "FH enable" | cut -d ":" -f2 | tr -d " ")

	iio_dev=$(iio_attr -c | grep ${dev_name} | cut -d"," -f1 | tr -d "\t")
	if [[ -n ${profile} ]]; then
		# if a profile is given, well, we assume FH is enabled!
		info "Loading new profile..."
		cat "${stream}" > "/sys/bus/iio/devices/${iio_dev}/stream_config"
		cat "${profile}" > "/sys/bus/iio/devices/${iio_dev}/profile_config"
	else
		[[ ${fh} == 0 ]] && error "Frequency hopping not enabled and profile not given..."
		info "Initializing the device..."
		iio_attr -D ${dev_name} initialize 1 >/dev/null 2>&1
	fi

	return 0
}

do_tbl_hop() {
	local i

	for ((i=0; i<${1}; i++)); do
		do_set_gpio_idx ${i}
		# the table index get's fetched by the device when we assert the port pin
		[[ ${export_en_pin} == "y" ]] && {
			echo 1 > "/sys/class/gpio/gpio${port_en}/value"
		} || {
			if [[ ${rx} == "true" ]]; then
				iio_attr -c ${dev_name} -i voltage$((${hop} - 1)) ensm_mode rf_enabled >/dev/null
			else
				iio_attr -c ${dev_name} -o voltage$((${hop} - 1)) ensm_mode rf_enabled >/dev/null
			fi
		}
		# trigger the hop signal. the frame should start on the next hop edge
		echo 1 > "/sys/class/gpio/gpio${hop_en}/value"
		sleep 0.1
		[[ ${export_en_pin} == "y" ]] && {
			echo 0 > "/sys/class/gpio/gpio${port_en}/value"
		} || {
			if [[ ${rx} == "true" ]]; then
				iio_attr -c ${dev_name} -i voltage$((${hop} - 1)) ensm_mode primed >/dev/null
			else
				iio_attr -c ${dev_name} -o voltage$((${hop} - 1)) ensm_mode primed >/dev/null
			fi
		}
		echo 0 > "/sys/class/gpio/gpio${hop_en}/value"
	done
}

do_hopping() {
	local i=0

	# let's load the table
	cat "${tbl_a}" >> "/sys/bus/iio/devices/${iio_dev}/frequency_hopping_hop${hop}_table_a"
	[[ -n ${tbl_b} ]] && cat "${tbl_b}" >> "/sys/bus/iio/devices/${iio_dev}/frequency_hopping_hop${hop}_table_b"
	[[ ${rx} == "true" ]] && iio_attr -c ${dev_name} -i voltage$((${hop} - 1)) port_en_mode pin 1>/dev/null || \
		iio_attr -c ${dev_name} -o voltage$((${hop} - 1)) port_en_mode pin 1>/dev/null

	info "Start hopping, tbl_ctl: ${tbl_ctl}, tbl_sz_a: ${tbl_sz_a}, tbl_sz_b: ${tbl_sz_b}, hop: ${hop}, \
										rx: ${rx}, repetitions: ${n_run}"
	while [[ ${i} -lt ${n_run} ]]; do
		do_tbl_hop ${tbl_sz_a}
		if [[ -n ${tbl_b} ]]; then
			# if ping-pong, the device should automatically switch tables...
			[[ ${tbl_ctl} != "ping-pong" ]] && \
				iio_attr -d ${dev_name} frequency_hopping_hop${hop}_table_select "TABLE_B" 1>/dev/null
			do_tbl_hop ${tbl_sz_b}
			# switch back to table a
			[[ ${tbl_ctl} != "ping-pong" ]] && \
				iio_attr -d ${dev_name} frequency_hopping_hop${hop}_table_select "TABLE_A" 1>/dev/null
		fi

		let i+=1
	done

	return 0
}

# make sure iio tools are available
command -v iio_info >/dev/null 2>&1 || error "libiio and it's tools must be installed..."
command -v realpath >/dev/null 2>&1 || error "realpath not found..."

while [[ ${#} -gt 0 ]]; do
	case "${1}" in
	-n|--n-run)
		n_run="${2}"
		shift 2
		;;
	-p|--profile)
		# we must always give a valid stream for the profile
		file_exists "${2}"
		file_exists "${3}"
		stream="$(realpath "${2}")"
		profile="$(realpath "${3}")"
		shift 3
		;;
	-c|--table-ctl)
		[[ ${2} != "gpio" && ${2} != "loop" && ${2} != "ping-pong" ]] && \
						error "Invalid table control mode: \"${2}\""
		tbl_ctl=${2}
		shift 2
		;;
	-s|--hop-signal)
		[[ ${2} != 1 && ${2} != 2 ]] && error "Invalid hop signal: \"${2}\""
		hop=${2}
		[[ ${hop} == 2 ]] && max_tbl_sz=32
		shift 2
		;;
	-r|--rx)
		rx="true"
		shift
		;;
	-d|--debug)
		verbose="y"
		shift
		;;
	-h|--help)
		usage
		;;
	*)
		[[ -n ${tbl_a} && -n ${tbl_b} ]] && error "Both tables given already... Unknown option: \"${1}\""
		[[ -z ${tbl_a} ]] && tbl_a="$(realpath "${1}")" || tbl_b="$(realpath "${1}")"
		shift
		;;
        esac
done

# we just validate the tables now as it's size depends on the hop signal selected
validate_tbl ${tbl_a} "a"
[[ -n ${tbl_b} ]] && validate_tbl ${tbl_b} "b"

do_config
do_dev_init
do_gpios_export
do_hopping
do_gpios_unexport
