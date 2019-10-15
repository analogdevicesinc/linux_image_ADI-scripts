#!/bin/sh

for i in $(find -L /sys/bus/iio/devices -maxdepth 2 -name name)
do
  dev_name=$(cat $i)
  # find the DAC on FMComms1
  if [ "$dev_name" = "cf-ad9122-core-lpc" ] || [ "$dev_name" = "axi-ad9144-hpc" ] ; then
     dac_path=$(echo $i | sed 's:/name$::')
     A1=out_altvoltage0_1A_frequency
     A2=out_altvoltage2_2A_frequency
     B1=out_altvoltage1_1B_frequency
     B2=out_altvoltage3_2B_frequency
     sampl=`cat $dac_path/out_altvoltage_sampling_frequency`
     init=`cat $dac_path/out_altvoltage0_1A_frequency`
     break
  fi

  # if that didn't work, try FMComms2/3
  if [ "$dev_name" = "cf-ad9361-dds-core-lpc" ] ; then
     dac_path=$(echo $i | sed 's:/name$::')
     A1=out_altvoltage0_TX1_I_F1_frequency
     B1=out_altvoltage1_TX1_I_F2_frequency
     A2=out_altvoltage2_TX1_Q_F1_frequency
     B2=out_altvoltage3_TX1_Q_F2_frequency
     A3=out_altvoltage4_TX2_I_F1_frequency
     B3=out_altvoltage5_TX2_I_F2_frequency
     A4=out_altvoltage6_TX2_Q_F1_frequency
     B4=out_altvoltage7_TX2_Q_F2_frequency
     sampl=`cat $dac_path/out_altvoltage_sampling_frequency`
     init=`cat $dac_path/out_altvoltage0_TX1_I_F1_frequency`
     break
  fi
done

if [ -z $dac_path ] ; then
  echo Could not find any DDS to set
  exit
fi

ny=`expr $sampl / 2`

# Set DDSn_A
freq_A(){
  if [ ! -z $A1 ] ; then echo $1 > $dac_path/$A1; fi
  if [ ! -z $A2 ] ; then echo $1 > $dac_path/$A2; fi
  if [ ! -z $A3 ] ; then echo $1 > $dac_path/$A3; fi
  if [ ! -z $A4 ] ; then echo $1 > $dac_path/$A4; fi
}

# Set DDSn_B
freq_B(){
  if [ ! -z $B1 ] ; then echo $1 > $dac_path/$B1; fi
  if [ ! -z $B2 ] ; then echo $1 > $dac_path/$B2; fi
  if [ ! -z $B3 ] ; then echo $1 > $dac_path/$B3; fi
  if [ ! -z $B4 ] ; then echo $1 > $dac_path/$B4; fi
}

for i in `seq 1000000 1000000 $ny`
do
  freq_A $i
  freq_B `expr $ny - $i`
  echo $i
  sleep 1
done

freq_A $init
freq_B $init
