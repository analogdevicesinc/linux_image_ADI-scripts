#!/bin/sh

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

for mag in 1.000000 0.500000 0.250000 0.125000 0.062500 0.031250 0.015625 0.007812 0.003906 0.001953 0.000976 0.000488 0.000244 0.000122 0.000061 0.000030;
do
  for attr in $attrs
  do
    echo $mag > $dac_path/$attr
  done
  echo $mag
  sleep 1
done

mag=0.250000
for attr in $attrs
do
  echo $mag > $dac_path/$attr
done
