#!/bin/sh

# buffer size, let's use 512 samples, or 1024 bytes
buffer_size=1024

# find the DAC
for i in $(find /sys -name name)
do
  dev_name=$(cat $i)
  if [ "$dev_name" = "cf-ad9122-core-lpc" ] || [ "$dev_name" = "axi-ad9144-hpc" ] || [ "$dev_name" = "cf-ad9361-dds-core-lpc" ] ; then
     dac_path=$(echo $i | sed 's:/name$::')
     break
  fi
done

# Get the associated dev file
dev=/dev/$(echo $dac_path |  awk -F "/" '{print $NF}')
if [ ! -c $dev ] ; then
  echo "Can't find device $dev"
  exit
fi

# set the buffer size
echo $buffer_size > $dac_path/buffer/length

# generate the random data, and give it to the DAC
dd if=/dev/urandom of=$dev bs=$buffer_size count=1

#enable things
echo 1 > $dac_path/buffer/enable

#Wait 5 seconds
sleep 5

#turn if off before we bring down everyone's WiFi
echo 0 > $dac_path/buffer/enable

