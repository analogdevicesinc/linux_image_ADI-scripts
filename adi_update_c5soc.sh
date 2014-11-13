#!/bin/bash

wget http://wiki.analog.com/_media/resources/tools-software/linux-software/altera_soc/altera_soc.zip
unzip altera_soc.zip
dd of=/dev/mmcblk0p3 bs=512 if=boot-partition.img
cp soc_system.rbf /media/BOOT/soc_system.rbf
cp socfpga.dtb /media/BOOT/socfpga.dtb
cp uImage /media/BOOT/uImage
rm altera_soc.zip
rm boot-partition.img
rm soc_system.rbf
rm socfpga.dtb
rm uImage
sync

echo "DONE"
exit 0
