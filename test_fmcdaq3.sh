#!/bin/bash

# initialize scale to workaround dBFS GUI reload issue
/usr/local/bin/dds_set_scale.sh 0 >/dev/null

tmpdir=$(mktemp -d --tmpdir=/tmp fmcdaq3-test.XXXXXX)
pushd ${tmpdir} >/dev/null
/usr/local/bin/osc -p /usr/local/lib/osc/profiles/AD-FMCDAQ3_test.ini
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