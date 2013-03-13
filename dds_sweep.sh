#!/bin/sh

# find the DAC
for i in $(find /sys -name name)
do
  if [ "`cat $i`" = "cf-ad9122-core-lpc" ] ; then
     dac_path=$(echo $i | sed 's:/name$::')
  fi
done

#save the current settings
init=`cat $dac_path/out_altvoltage0_1A_frequency`

# Set DDSn_A
freq_A(){
  echo $1 > $dac_path/out_altvoltage0_1A_frequency
  echo $1 > $dac_path/out_altvoltage2_2A_frequency
}

# Set DDSn_B
freq_B(){
  echo $1 > $dac_path/out_altvoltage1_1B_frequency
  echo $1 > $dac_path/out_altvoltage3_2B_frequency
}

for i in 10 20 30 40 50 60 70 80 90 100 110
do
  freq_A `expr $i \\* 1000000`
  freq_B `expr \( 120 - $i \) \\* 1000000`
  sleep 1
done

freq_A $init
freq_B $init
