#!/bin/bash

tmpdir=$(mktemp -d --tmpdir=/tmp fmcadc2-test.XXXXXX)
pushd ${tmpdir} >/dev/null
OSC_FORCE_PLUGIN=scpi /usr/local/bin/osc -p /usr/local/lib/osc/profiles/AD-FMCADC2_test.ini
rc=$?
popd >/dev/null

# save test output
serial="$(find /sys -name eeprom -size 256c | xargs fru-dump -b -i | awk '/^Serial Number/ {print $NF}')"
if [[ -n ${serial} ]]; then
	# failing cards have log dirs named ${serial}-failed
	[[ ${rc} -eq 0 ]] || serial+="-failed"
	mkdir -p "/root/osc-logs/${serial}"
	if [[ ! -d "/root/osc-logs/${serial}" ]]; then
		mv ${tmpdir} "/root/osc-logs/${serial}"
	else
		# serial number collision
		rand=$(basename ${tmpdir})
		rand=${rand##*.}
		mv ${tmpdir} "/root/osc-logs/${serial}.${rand}"
	fi
fi

/sbin/shutdown -h now
