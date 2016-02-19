#!/bin/bash

/usr/local/bin/osc -p /usr/local/lib/osc/profiles/AD-TRXBOOST1_test.ini
ret=$?

if [[ ${ret} -eq 0 ]] ; then
	/sbin/shutdown -h now
fi
