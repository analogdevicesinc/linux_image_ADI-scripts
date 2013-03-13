#!/bin/sh

#check in the input
if [ $1 -le -1 ] ; then
  echo "input out of range, (needs to be 0-4)"
  exit
fi

if [ $1 -ge 5 ] ; then
  echo "input out of range (needs to be 0-4)"
  exit
fi

# find the DAC
for i in $(find /sys -name name 2>/dev/null)
do
  if [ "`cat $i`" = "cf-ad9122-core-lpc" ] ; then
     dac_path=$(echo $i | sed 's:/name$::')
  fi
done

echo $(echo "scale=4; 1 / ( 2 ^ $1 )" | bc) > $dac_path/out_altvoltage0_1A_scale
echo $(echo "scale=4; 1 / ( 2 ^ $1 )" | bc) > $dac_path/out_altvoltage1_1B_scale
echo $(echo "scale=4; 1 / ( 2 ^ $1 )" | bc) > $dac_path/out_altvoltage2_2A_scale
echo $(echo "scale=4; 1 / ( 2 ^ $1 )" | bc) > $dac_path/out_altvoltage3_2B_scale

echo -n "amplitude set to "
cat $dac_path/out_altvoltage0_1A_scale
