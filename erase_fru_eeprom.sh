#!/bin/bash

if [ "$(id -u)" != "0" ] ; then
	echo "This script must be run as root"
	exit 1
fi

for i in $(find /sys/ -name eeprom)
do
	if [ `stat -c %s $i` -ne "256" ] ; then
		continue;
	fi

	yn=foo
	while [[ "$yn" != "yes" && "$yn" != "no" ]]
	do
		echo $i
		read -p "erase that file? <yes|no> " yn
	done

	if [ "$yn" != "yes" ] ; then
		echo Did not erase $i
		continue
	fi

	echo erasing $i
	dd if=/dev/zero of=$i bs=256 count=1
done
