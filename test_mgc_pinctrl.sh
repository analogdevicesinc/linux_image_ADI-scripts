#!/bin/sh

find_zynq_base_gpio () {
	for i in /sys/class/gpio/gpiochip*; do
		if [ "zynq_gpio" = `cat $i/label` ]; then
			return `echo $i | sed 's/^[^0-9]\+//'`
			break
		fi
	done
	return -1
}

if [ `id -u` != "0" ]
then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ `iio_attr -q  -D ad9361-phy adi,mgc-rx1-ctrl-inp-enable` = "0" ];then
	#Enable Pin Control Mode
	iio_attr -D ad9361-phy adi,mgc-rx1-ctrl-inp-enable 1 > export 2> /dev/null
	iio_attr -D ad9361-phy adi,mgc-rx2-ctrl-inp-enable 1 > export 2> /dev/null
	iio_attr -D ad9361-phy initialize 1 > export 2> /dev/null

	sleep 1
fi

iio_attr -c ad9361-phy voltage0 gain_control_mode manual > export 2> /dev/null
iio_attr -c ad9361-phy voltage1 gain_control_mode manual > export 2> /dev/null

find_zynq_base_gpio
GPIO_BASE=$?
cd /sys/class/gpio

if [ $GPIO_BASE -ge 0 ]
then
  GPIO_CTRL_IN0=`expr $GPIO_BASE + 94`
  GPIO_CTRL_IN1=`expr $GPIO_BASE + 95`
  GPIO_CTRL_IN2=`expr $GPIO_BASE + 96`
  GPIO_CTRL_IN3=`expr $GPIO_BASE + 97`
  #Export the CTRL_IN GPIOs
  echo $GPIO_CTRL_IN0 > export 2> /dev/null
  echo $GPIO_CTRL_IN1 > export 2> /dev/null
  echo $GPIO_CTRL_IN2 > export 2> /dev/null
  echo $GPIO_CTRL_IN3 > export 2> /dev/null
else
  echo ERROR: Wrong board?
  exit
fi

CTRL_IN0=gpio${GPIO_CTRL_IN0}/direction
CTRL_IN1=gpio${GPIO_CTRL_IN1}/direction
CTRL_IN2=gpio${GPIO_CTRL_IN2}/direction
CTRL_IN3=gpio${GPIO_CTRL_IN3}/direction

if [ "$1" = "1" ];then
	iio_attr -i -c ad9361-phy voltage0 hardwaregain

	if [ "$2" = "up" ];then
		echo low > $CTRL_IN0
		echo high > $CTRL_IN0
	elif [ "$2" = "down" ];then
		echo low > $CTRL_IN1
		echo high > $CTRL_IN1
	else
		echo "usage: $0 <1|2> <up|down>"
		exit
	fi
	iio_attr -i -c ad9361-phy voltage0 hardwaregain

elif [ "$1" = "2" ];then
	iio_attr -i -c ad9361-phy voltage1 hardwaregain
	if [ "$2" = "up" ];then
		echo low > $CTRL_IN2
		echo high > $CTRL_IN2
	elif [ "$2" = "down" ];then
		echo low > $CTRL_IN3
		echo high > $CTRL_IN3
	else
		echo "usage: $0 <1|2> <up|down>"
		exit
	fi
	iio_attr -i -c ad9361-phy voltage1 hardwaregain
else
	echo "usage: $0 <1|2> <up|down>"
	exit
fi
