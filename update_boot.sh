#!/bin/bash

SERVER=http://wiki.analog.com
SPATH=_media/resources/tools-software/linux-drivers/platforms
FILE=latest_zynq_boot.txt

FAT_MOUNT=/media/boot
CURRENT=$FAT_MOUNT/VERSION

if [ `id -u` != "0" ]
then
   echo "This script must be run as root" 1>&2
   exit 1
fi

mkdir $FAT_MOUNT 2>/dev/null
mount /dev/mmcblk0p1 $FAT_MOUNT

if [ $? -ne 0 ]
then
  echo "Mounting /dev/mmcblk0p1 failed" 1>&2
  exit 1
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

echo CURRENT VERSION: $oldversion
echo NEW VERSION    : $version

if [ -f $CURRENT ]
then
  if [ $version==$oldversion ]
  then
   echo "Already up to date"  1>&2
   umount $FAT_MOUNT
   exit 1
  fi
fi

wget -nc $newurl

if [ $? -ne 0 ]
then
 echo "Download failed - aborting"  1>&2
 umount $FAT_MOUNT
 exit 1
fi

key=`md5sum $newfile | awk '{print $1}'`

if [ $key != $md5 ]
then
   echo "MD5SUM Error"  1>&2
   umount $FAT_MOUNT
   exit 1
fi

echo "Extracting - Be patient!"
tar -C $FAT_MOUNT -xzf ./$newfile --no-same-owner --checkpoint=.1000
echo $version >> $CURRENT
sync
rm $FILE
rm $newfile
umount $FAT_MOUNT
echo "DONE"
exit 0
