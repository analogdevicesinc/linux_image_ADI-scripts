#!/bin/bash

OSC_FORCE_PLUGIN=scpi /usr/local/bin/osc -p /usr/local/lib/osc/profiles/FMComms5_test.ini
rc=$?

# save marker logs
if [[ ${rc} -eq 0 ]] ; then
	eeprom=$(find /sys -name eeprom -size 256c)
	serial=$(fru-dump "${eeprom}" -b | awk '/^Serial Number/ {print $NF}')
	[[ -d /root/osc-logs ]] || mkdir -p /root/osc-logs
	mv log.txt /root/osc-logs/"${serial}"-log.txt
fi

/sbin/shutdown -h now
