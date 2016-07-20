#!/bin/bash

/usr/local/bin/osc -p /usr/local/lib/osc/profiles/PZSDR2_2400TDD_test.ini
ret=$?

if [[ ${ret} -eq 0 ]] ; then
	/sbin/shutdown -h now
fi
