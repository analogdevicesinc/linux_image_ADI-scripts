#!/bin/bash

if [ "$1" == "" ]; then
	echo "usage: $0 <IPADDR> [<key> <value>]"
	exit
fi;

rxlo=`iio_attr -q -u ip:$1 -c ad9361-phy altvoltage0 frequency`
txlo=`iio_attr -q -u ip:$1 -c ad9361-phy altvoltage1 frequency`
rxgcm=`iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 gain_control_mode`
rxsamp=`iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 sampling_frequency`
rxbw=`iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 rf_bandwidth`
txbw=`iio_attr -q -o -u ip:$1 -c ad9361-phy voltage0 rf_bandwidth`
rxport=`iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 rf_port_select`
txport=`iio_attr -q -o -u ip:$1 -c ad9361-phy voltage0 rf_port_select`
rxgain=`iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 hardwaregain | cut -f1 -d ' '`
txgain=`iio_attr -q -o -u ip:$1 -c ad9361-phy voltage0 hardwaregain | cut -f1 -d ' '`


if [ "$2" != "" ] && [ "$3" != "" ]; then
	iio_attr -q -u ip:$1 -D ad9361-phy $2 $3 > /dev/null
	echo "wrote $2 = $3"
fi

iio_attr -q -o -u ip:$1 -D ad9361-phy initialize 1 > /dev/null

iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 rf_port_select $rxport > /dev/null
iio_attr -q -o -u ip:$1 -c ad9361-phy voltage0 rf_port_select $txport > /dev/null
iio_attr -q -u ip:$1 -c ad9361-phy altvoltage0 frequency $rxlo > /dev/null
iio_attr -q -u ip:$1 -c ad9361-phy altvoltage1 frequency $txlo > /dev/null
iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 sampling_frequency $rxsamp > /dev/null
iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 rf_bandwidth $rxbw > /dev/null
iio_attr -q -o -u ip:$1 -c ad9361-phy voltage0 rf_bandwidth $txbw > /dev/null
iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 gain_control_mode $rxgcm > /dev/null
iio_attr -q -i -u ip:$1 -c ad9361-phy voltage0 hardwaregain $rxgain > /dev/null
iio_attr -q -o -u ip:$1 -c ad9361-phy voltage0 hardwaregain $txgain > /dev/null
