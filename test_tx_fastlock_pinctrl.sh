#!/bin/sh

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
echo 0 > out_altvoltage1_TX_LO_fastlock_recall

cd /sys/class/gpio

if [ -e gpiochip138 ]
then
  #Export the CTRL_IN GPIOs
  echo 235 > export 2> /dev/null
  echo 234 > export 2> /dev/null
  echo 233 > export 2> /dev/null
else
  echo ERROR: Wrong board?
  exit
fi

CTRL_IN1=gpio233/direction
CTRL_IN2=gpio234/direction
CTRL_IN3=gpio235/direction

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
