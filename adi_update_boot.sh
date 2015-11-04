#!/bin/bash

REPO="linux_image_ADI-scripts"
BRANCH="origin/master"

cd /usr/local/src

echo Verifying if ./adi_update_boot.sh is up to date...

if [ -d $REPO ]
then
  cd ./$REPO
  git checkout -f $BRANCH
  make uninstall 2>/dev/null
  git fetch
  git checkout -f $BRANCH 2>/dev/null
  cd ..
else
  git clone https://github.com/analogdevicesinc/$REPO.git || continue
fi

cd ./$REPO

md5_self=`md5sum $0 | awk '{print $1}'`
md5_new=`md5sum ./adi_update_boot.sh | awk '{print $1}'`
echo $md5_self
echo $md5_new
if [ $md5_new != $md5_self ]
then
  echo ./adi_update_boot.sh has been updated, installing and switching to new one...
  make install
  ./adi_update_boot.sh $@
  exit
else
  echo ./adi_update_boot.sh is up to date, continuing...
fi

if [ $# -eq 1 ]
then
  SERVER=http://$1
  SPATH=files
else
  SERVER=http://swdownloads.analog.com
  SPATH=update
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

fatsize=`df | grep /dev/mmcblk0p1 | sed -n '1p' | awk '{print $2}'`
if [ $fatsize -lt 300000 ];
then
  echo -e "\n==== WARNING ====\n
Old SD Card Image detected. Please update!\n\n
See http://wiki.analog.com/resources/tools-software/linux-software/zynq_images\n
================="
SERVER=http://wiki.analog.com
SPATH=_media/resources/tools-software/linux-drivers/platforms
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

  oldversion_date=$(echo "$oldversion" | sed 's/\(.\{13\}\)//')
  oldversion_date=$(echo "$oldversion_date" | sed -r 's/[_]+/-/g')
  version_date=$(echo "$version" | sed 's/\(.\{13\}\)//')
  version_date=$(echo "$version_date" | sed -r 's/[_]+/-/g')
  if [ $(date -d $oldversion_date +%s) -gt $(date -d $version_date +%s) ]
  then
    echo "The current version is newer than the one that can be downloaded"
    umount $FAT_MOUNT
    exit 1
  fi

  version_2015_r1_date="2015-08-22"
  if [ $(date -d $oldversion_date +%s) -lt $(date -d $version_2015_r1_date +%s) ]
  then
    echo "Old SD Card Image detected.
The entire content of the BOOT partition will be deleted!!!"

    while true
    do
      read -r -p 'Are you sure you want to continue? (y/n) ' answer
      case "$answer" in
        n)
          umount $FAT_MOUNT
          exit 1
          ;;
        y)
          rm -rf $FAT_MOUNT/*
          break
          ;;
        *)
          echo 'Valid answers: y/n'
          ;;
        esac
    done
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
else
  echo -e "\n==== WARNING ====\n
Custom devicetree detected; you will have to manually copy the boot files.
See http://wiki.analog.com/resources/tools-software/linux-software/zynq_images#staying_up_to_date\n
================="
fi

sync

rm $FILE
rm $newfile
umount $FAT_MOUNT
echo "DONE"

if [ $fatsize -lt 300000 ];
then
  echo -e "\n==== WARNING ====\n
Old SD Card Image detected. Please update!\n\n
See http://wiki.analog.com/resources/tools-software/linux-software/zynq_images\n
================="
fi

exit 0
