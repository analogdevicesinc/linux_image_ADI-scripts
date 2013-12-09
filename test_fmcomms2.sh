#!/bin/bash

/usr/local/bin/osc -p /usr/local/lib/osc/profiles/FMComms2_test.ini
rc=$?

if [[ "$rc" = "0" ]] ; then
	/sbin/shutdown -h now
fi

