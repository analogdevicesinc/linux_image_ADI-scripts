#!/bin/sh

INI_FILE=/etc/libiio.ini

# Point people to the correct thing.
SELF=$0
[ -r "$SELF" ] || SELF=$(
	IFS=:; set -f
	for i in ${PATH-$(getconf PATH)}""; do
		case $i in
			"") p=$SELF;;
			*/) p=$i$SELF;;
			*) p=$i/$SELF
		esac
		[ -r "$p" ] && exec printf '%s\n' "$p"
	done
	exit 1
) && SELF=$(readlink -e -- "$SELF") || SELF=unknown

#some systems have null in the device tree, so replace those with spaces
#some systems include non-printable chars, or color codes so also remove those.
sanitize_str() {
	echo "$@" |  tr '\0' ' ' | sed -e 's/ $//g' -e 's/\x1b\[[0-9;]*m//g' | tr -cd '[:print:]\n'
}
sanitize() {
	cat $1 | tr '\0' ' ' | sed -e 's/ $//g' -e 's/\x1b\[[0-9;]*m//g' | tr -cd '[:print:]\n'
}

#run on x86 and ARM
MODEL="/proc/device-tree/model"
DMI="/sys/class/dmi/id/board_vendor"
if [ -f "${MODEL}" ] ; then
	# Most ARM systems will fill /sys/firmware;
	BASE=$(sanitize $MODEL)
elif [ -f "${DMI}" ] ; then
	# most x86 will fill out Desktop Management Interface
	BASE=$(sanitize "/sys/class/dmi/id/product_name")
	VENDOR=$(sanitize "${DMI}")
fi

SYSID=$(sanitize_str $(dmesg | grep axi_sysid | grep git | head -1 | cut -f2- -d":" | sed -e 's/^[[:space:]]*//' | sed -e 's/</[/g' -e 's/>/]/g'))

UNIQUE_ID=$(sanitize_str $(dmesg | grep SPI-NOR-UniqueID | head -1))
UNIQUE_ID=${UNIQUE_ID#*SPI-NOR-UniqueID }

# If this is an FMC Board, capture the data
command fru-dump -h >/dev/null 2>&1
if [ "$?" = "0" ] ; then
	for i in $(find /sys/ -name eeprom)
	do
		fru-dump $i > /dev/null 2>&1
		if [ $? -eq "0" ] ; then
			BOARD=$(fru-dump $i -b | grep "Part Number" | awk -F: '{print $2}' | sed 's/^[[:space:]]*//')
			SERIAL=$(fru-dump $i -b | grep "Serial Number" | awk -F: '{print $2}' | sed 's/^[[:space:]]*//')
			NAME=$(fru-dump $i -b | grep "Product Name" | awk -F: '{print $2}' | sed 's/^[[:space:]]*//')
			VENDOR=$(fru-dump $i -b | grep "Manufacturer" | awk -F: '{print $2}' | sed 's/^[[:space:]]*//')
			break
		fi
	done
fi

# If you are a Raspberry Pi HAT, add that
if [ -d "/sys/firmware/devicetree/base/hat" ] ; then
	BOARD=$(sanitize "/sys/firmware/devicetree/base/hat/product_id")
	SERIAL=$(sanitize "/sys/firmware/devicetree/base/hat/uuid")
	NAME=$(sanitize "/sys/firmware/devicetree/base/hat/product")
	VENDOR=$(sanitize "/sys/firmware/devicetree/base/hat/vendor")
fi

#Find the overlays that are added
if [ "$(echo ${BASE} | grep Raspberry | wc -c)" -gt "1" ] ; then
	OVERLAY=$(grep ^dtoverlay /boot/config.txt | \
		sed -e 's/,.*$//' -e 's/^.*=//' | \
		tr '\n' ',' | sed 's/,$/\n/g')
fi

# remove this from the file, to make sure stale data isn't hanging around
remove() {
	# If this is called with something that is blank, don't do anything.
	if [ ${#1} -eq 0 ] ; then
		return
	fi
	if [ ! -f ${INI_FILE} ] ; then
		return
	fi
	if ! grep -q $1 ${INI_FILE} ; then
		return
	fi
	rep=$(grep -e "^$1=" ${INI_FILE})
	sed -i "/^${1}=/d" ${INI_FILE}
}

# build up ${INI_FILE} or add to it if it is not there
replace_or_add() {
	if [ ${#1} -eq 0 ] ; then
		return
	fi
	if [ ${#2} -eq 0 ] ; then
		remove $1
		return
	fi
	if grep -q $1 ${INI_FILE} ; then
		sed -i -e "/$1/c $1=$2" ${INI_FILE}
	else
		echo "$1=$2" >> ${INI_FILE}
	fi
}

if [ "$1" = "clean" ] ; then
	rm ${INI_FILE}
fi

#prep the file
if [ ! -f ${INI_FILE} ] ; then
	echo "# This file is autogenerated from:\n#\t${SELF}\n[Context Attributes]" > ${INI_FILE}
else
	if  [ $(grep "autogenerated from /etc/init.d/iiod" ${INI_FILE} | wc -c) -gt 1 ] ; then
		#old file, update
		sed -i "/autogenerated from \/etc\/init.d\/iiod/d" ${INI_FILE}
		sed -i "1,1s|^|# This file is autogenerated from:\n#\t${SELF}\n|" ${INI_FILE}
	fi
	if [ $(grep autodate ${INI_FILE} | wc -c) -eq 0 ] ; then
		sed -i '2a# autodate' ${INI_FILE}
	fi
fi
sed -i -e "/autodate/c # autodate $(date)" ${INI_FILE}
grep -q '\[Context Attributes\]' ${INI_FILE} || echo "[Context Attributes]" >> ${INI_FILE}

# save all we learned into the file
replace_or_add hdl_system_id "${SYSID}"
if [ "${BOARD+x}x" != "x" -a "${BASE}x" != "x" ] ; then
	replace_or_add hw_model "${BOARD} on ${BASE}"
fi
replace_or_add hw_carrier "${BASE}"
replace_or_add hw_mezzanine "${BOARD}"
replace_or_add hw_name "${NAME}"
replace_or_add hw_vendor "${VENDOR}"
replace_or_add hw_serial "${SERIAL}"
replace_or_add unique_id "${UNIQUE_ID}"
replace_or_add dtoverlay "${OVERLAY}"

EXTRA_EEPROM_BOARDS="EVAL-CN0511-RPIZ"
EXTRA_EEPROM_FILE="/sys/devices/platform/soc/fe804000.i2c/i2c-1/1-0051/eeprom"
CAN_READ_EXTRA_EEPROM=0

if echo "$EXTRA_EEPROM_BOARDS" | grep -w -q "$NAME"; then
	CAN_READ_EXTRA_EEPROM=1
fi

if [ "$CAN_READ_EXTRA_EEPROM" = "1" -a -f "$EXTRA_EEPROM_FILE" ]; then
	while read -r LINE; do
		IFS='=' read -r KEY VALUE <<-EOF
		$LINE
		EOF
		if [ -n "$KEY" -a -n "$VALUE" ]; then
			replace_or_add "$KEY" "$VALUE"
		fi
	done < "$EXTRA_EEPROM_FILE"
fi

exit 0
