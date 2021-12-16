#!/bin/sh


UNIQUE_ID=$(dmesg | grep SPI-NOR-UniqueID | head -1)
UNIQUE_ID=${UNIQUE_ID#*SPI-NOR-UniqueID }

sha1=`echo $UNIQUE_ID | sha1sum`

host_addr=`echo -n 00:E0:22; echo $sha1 | dd bs=1 count=6 2>/dev/null | hexdump -v -e '/1 ":%01c""%c"'`
dev_addr=`echo -n 00:05:F7; echo $sha1 | dd bs=1 count=6 skip=6 2>/dev/null | hexdump -v -e '/1 ":%01c""%c"'`

replace_or_add() {
	if [ ${#1} -eq 0 ] ; then
		return
	fi
	if [ ${#2} -eq 0 ] ; then
		return
	fi
	if [ ! -f /etc/defaults/adi_usb_gadget ] ; then
		echo "# Defaults for the ADI USB composite gadget" > /etc/defaults/adi_usb_gadget
	fi
	if grep -q $1 /etc/defaults/adi_usb_gadget ; then
		sed -i -e "/$1/c $1=$2" /etc/defaults/adi_usb_gadget
	else
		echo "$1=$2" >> /etc/defaults/adi_usb_gadget
	fi
}

replace_or_add host_addr $host_addr
replace_or_add dev_addr $dev_addr
replace_or_add serial $UNIQUE_ID

exit 0
