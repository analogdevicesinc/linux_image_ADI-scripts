#!/bin/sh

#check in the input
if [ $1 -le -1 ] ; then
  echo "input out of range, (needs to be 0-15)"
  exit
fi

if [ $1 -ge 16 ] ; then
  echo "input out of range (needs to be 0-15)"
  exit
fi

# find the DAC
for i in $(find -L /sys/bus/iio/devices -maxdepth 2 -name name)
do
  dev_name=$(cat $i)
  if [ "$dev_name" = "cf-ad9122-core-lpc" ] || [ "$dev_name" = "axi-ad9144-hpc" ] ; then
    dac_path=$(echo $i | sed 's:/name$::')
    attrs="out_altvoltage0_1A_scale \
      out_altvoltage1_1B_scale \
      out_altvoltage2_2A_scale \
      out_altvoltage3_2B_scale"
  elif [ "$dev_name" = "cf-ad9361-dds-core-lpc" ] ; then
    dac_path=$(echo $i | sed 's:/name$::')
    attrs="out_altvoltage0_TX1_I_F1_scale \
      out_altvoltage1_TX1_I_F2_scale \
      out_altvoltage2_TX1_Q_F1_scale \
      out_altvoltage3_TX1_Q_F2_scale \
      out_altvoltage4_TX2_I_F1_scale \
      out_altvoltage5_TX2_I_F2_scale \
      out_altvoltage6_TX2_Q_F1_scale \
      out_altvoltage7_TX2_Q_F2_scale"
  fi
done

mag=$(echo "scale=6; 1 / ( 2 ^ $1 )" | bc)
for attr in $attrs
do
  echo $mag > $dac_path/$attr
done

echo -n "amplitude set to "
cat $dac_path/$(echo $attrs | cut -d" " -f 1)
