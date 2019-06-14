#!/bin/bash

# Turn off continous SYSREF, and enable GPI SYSREF request
iio_reg hmc7044 0x5a 0

for i in {0..11}
do
  echo Performing MCS step: $i

  iio_attr  -q -d adrv9009-phy multichip_sync $i >/dev/null 2>&1
  iio_attr  -q -d adrv9009-phy-b multichip_sync $i >/dev/null 2>&1

done
