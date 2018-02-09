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

for i in $(find -L /sys/bus/iio/devices -maxdepth 2 -name name)
do
  dev_name=$(cat $i)
  if [ "$dev_name" = "ad9361-phy" ]; then
     phy_path=$(echo $i | sed 's:/name$::')
     cd $phy_path
     break
  fi
done

if [ "$dev_name" != "ad9361-phy" ]; then
 exit
fi

#Setup 8 Profiles 10MHz spaced
for i in `seq 0 7`
do
  echo $((2400000000 + $i * 10000000)) > out_altvoltage1_TX_LO_frequency
  echo "Initializing PROFILE $i at $((2400000000 + $i * 10000000)) MHz"
  echo $i > out_altvoltage1_TX_LO_fastlock_store
done

#Enable Fastlock Mode
iio_attr -D ad9361-phy adi,tx-fastlock-pincontrol-enable 1
echo 0 > out_altvoltage1_TX_LO_fastlock_recall

find_zynq_base_gpio
GPIO_BASE=$?

cd /sys/class/gpio

if [ $GPIO_BASE -ge 0 ]
then
  GPIO_CTRL_IN1=`expr $GPIO_BASE + 95`
  GPIO_CTRL_IN2=`expr $GPIO_BASE + 96`
  GPIO_CTRL_IN3=`expr $GPIO_BASE + 97`
  #Export the CTRL_IN GPIOs
  echo $GPIO_CTRL_IN1 > export 2> /dev/null
  echo $GPIO_CTRL_IN2 > export 2> /dev/null
  echo $GPIO_CTRL_IN3 > export 2> /dev/null
else
  echo ERROR: Wrong board?
  exit
fi

CTRL_IN1=gpio${GPIO_CTRL_IN1}/direction
CTRL_IN2=gpio${GPIO_CTRL_IN2}/direction
CTRL_IN3=gpio${GPIO_CTRL_IN3}/direction

for i in `seq 0 7`
do
  echo Setting PROFILE $i
  # BIT 0
  if [ $(($i & 1)) -gt 0 ]
  then
    echo CTRL_IN1:1
    echo high > $CTRL_IN1
  else
    echo CTRL_IN1:0
    echo low > $CTRL_IN1
  fi

  # BIT 1
  if [ $(($i & 2)) -gt 0 ]
  then
    echo CTRL_IN2:1
    echo high > $CTRL_IN2
  else
    echo CTRL_IN2:0
    echo low > $CTRL_IN2
  fi

  # BIT 2
  if [ $(($i & 4)) -gt 0 ]
  then
    echo CTRL_IN3:1
    echo high > $CTRL_IN3
  else
    echo CTRL_IN3:0
    echo low > $CTRL_IN3
  fi

  sleep 1
done
