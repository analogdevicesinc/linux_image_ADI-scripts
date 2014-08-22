#!/bin/bash

if [ $# -eq 1 ]
then
  SERVER=http://$1
  SPATH=files
else
  SERVER=http://wiki.analog.com
  SPATH=_media/resources/tools-software/linux-drivers/platforms
fi

FILE=latest_zynq_boot.txt

FAT_MOUNT=/media/boot
CURRENT=$FAT_MOUNT/VERSION

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

if [ `id -u` != "0" ]
then
   echo "This script must be run as root" 1>&2
   exit 1
fi

mkdir -p $FAT_MOUNT 2>/dev/null
if ! mountpoint -q $FAT_MOUNT
then
  mount /dev/mmcblk0p1 $FAT_MOUNT

  if [ $? -ne 0 ]
  then
    echo "Mounting /dev/mmcblk0p1 failed" 1>&2
    exit 1
  fi
fi

rm $FILE 2>/dev/null
wget $SERVER/$SPATH/$FILE

if [ $? -ne 0 ]
then
 echo "Download failed - aborting"  1>&2
 umount $FAT_MOUNT
 exit 1
fi

oldversion=`sed -n 1p $CURRENT`
version=`sed -n 1p $FILE`
newurl=`sed -n 2p $FILE`
md5=`sed -n 3p $FILE | awk '{print $1}'`
newfile=`sed -n 3p $FILE | awk '{print $2}'`

echo "CURRENT VERSION: $oldversion"
echo "NEW VERSION    : $version"

if [ -f $CURRENT ]
then
  if [ $version == $oldversion ]
  then
   echo "Already up to date"  1>&2
   umount $FAT_MOUNT
   exit 1
  fi
fi

wget -nc $newurl

if [ $? -ne 0 ]
then
 echo "Download failed - aborting" 1>&2
 umount $FAT_MOUNT
 exit 1
fi

key=`md5sum $newfile | awk '{print $1}'`

if [ $key != $md5 ]
then
   echo "MD5SUM Error" 1>&2
   rm $newfile
   umount $FAT_MOUNT
   exit 1
fi

# Try to restore current BOOT.BIN and devicetree.dtb
CURRENT_CONFIG=`find_current_setup $FAT_MOUNT`
echo "CURRENT BOARD CONFIG: $CURRENT_CONFIG"

echo "Extracting - Be patient!"
tar -C $FAT_MOUNT -xzf ./$newfile --no-same-owner --checkpoint=.1000
echo $version > $CURRENT

if [ "$CURRENT_CONFIG" != "" ]
then
  cp $CURRENT_CONFIG/devicetree.dtb $FAT_MOUNT/devicetree.dtb
  cp $CURRENT_CONFIG/BOOT.BIN $FAT_MOUNT/BOOT.BIN
  if [ "$CURRENT_CONFIG" == "/media/boot/zynq-zed-mc" ]
  then
    cp $CURRENT_CONFIG/uImage $FAT_MOUNT/uImage
  else
    cp /media/boot/common/uImage $FAT_MOUNT/uImage
  fi
fi

sync

rm $FILE
rm $newfile
umount $FAT_MOUNT
echo "DONE"
exit 0
