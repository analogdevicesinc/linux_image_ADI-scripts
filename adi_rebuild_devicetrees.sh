#!/bin/sh

find_current_setup ()
{
	key=`md5sum $1/devicetree.dtb | awk '{print $1}'`

	for file in $1/* ; do
		if [ -d $file ] ; then
			if [ -f $file/devicetree.dtb ] ; then
				t=`md5sum $file/devicetree.dtb | awk '{print $1}'`
				if [ "$t" = "$key" ] ; then
					echo $file
					exit
				fi
			fi
		fi
	done
}

FAT_MOUNT=/media/boot

mkdir $FAT_MOUNT 2>/dev/null
umount /dev/mmcblk0p1 2>/dev/null
mount /dev/mmcblk0p1 $FAT_MOUNT

if [ $? -ne 0 ]
then
  echo "Mounting /dev/mmcblk0p1 failed - already mounted?" 1>&2
  exit 1
fi

# Try to restore current BOOT.BIN and devicetree.dtb
CURRENT_CONFIG=`find_current_setup $FAT_MOUNT`
echo "CURRENT BOARD CONFIG: $CURRENT_CONFIG"

for i in $(find $FAT_MOUNT -type d 2>/dev/null)
do
  cd $i
  if [ -f *.dts ]
   then
     dtc -O dtb -o devicetree.dtb *.dts
  fi
done

if [ "$CURRENT_CONFIG" != "" ]
then
  echo "Updating $CURRENT_CONFIG/devicetree.dtb -> $FAT_MOUNT/devicetree.dtb"
  cp $CURRENT_CONFIG/devicetree.dtb $FAT_MOUNT/devicetree.dtb
fi

cd ~
sync
umount $FAT_MOUNT
echo "DONE"
