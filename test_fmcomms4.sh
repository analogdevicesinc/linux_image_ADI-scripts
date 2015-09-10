#!/bin/bash

OSC_FORCE_PLUGIN=scpi /usr/local/bin/osc -p /usr/local/lib/osc/profiles/FMComms4_test.ini
rc=$?

if [[ "$rc" = "0" ]] ; then
	/sbin/shutdown -h now
fi

