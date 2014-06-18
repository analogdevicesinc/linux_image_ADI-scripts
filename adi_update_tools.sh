#!/bin/sh

if [ "$(id -u)" != "0" ] ; then
	echo "This script must be run as root"
	exit 1
fi

#find md5of this file
md5_self=`md5sum $0`

# Keeps the scripts as the first thing, so we can check for updated
# scripts ...
# repository:branch:make_target

BUILDS="linux_image_ADI-scripts:origin/master \
	fmcomms1-eeprom-cal:origin/master \
	libiio:origin/v0.1:iiod \
	iio-cmdsrv:origin/master \
	iio-oscilloscope:origin/master \
	iio-oscilloscope:origin/osc_iio_utils_legacy \
	fru_tools:origin/master \
	iio-cgi-netscope:origin/master \
	iio-fm-radio:origin/master \
	jesd-eye-scan-gtk:origin/master \
	thttpd:origin/master"

do_build ()
{
  local prj=$1
  local target=$2
  make clean;
  make -j3 $target && make install && echo "\n Building $prj target $target finished Successfully\n" ||
	echo "Building $prj Failed\n"
}

# Allow selective builds
if [ -n "$1" ]
then
BUILDS=$1
fi

for i in $BUILDS
do
  REPO=`echo $i | cut -d':' -f1`
  BRANCH=`echo $i | cut -s -d':' -f2`
  TARGET=`echo $i | cut -s -d':' -f3`

# slective build without branch? use master
  if [ -z $BRANCH ]
  then
    echo HERE
    BRANCH=origin/master
    TARGET=""
  fi

  cd /usr/local/src

  if [ -d $REPO ]
  then
    cd ./$REPO
    echo "\n *** Updating $REPO BRANCH $BRANCH ***"
    dirty=`git diff --shortstat 2> /dev/null | tail -n1`
    if [ "$dirty" != "" ]
    then
      echo "Tree is dirty - generting branch" `date +"%F"`
      git branch `date +"%F"`
    fi
    git checkout -f $BRANCH
    make uninstall 2>/dev/null
    git fetch
    git checkout -f $BRANCH 2>/dev/null
    cd ..
  else
    echo "\n *** Cloning $REPO ***"
    git clone https://github.com/analogdevicesinc/$REPO.git || continue
  fi

  echo "\n *** Building $REPO ***"
  cd ./$REPO

# Handle some specialties here
  if [ $REPO = "linux_image_ADI-scripts" ]
  then
    new=`md5sum ./adi_update_tools.sh`
    if [ "$new" = "$md5_self" ]
    then
      echo ./adi_update_tools.sh script is the same, continuing
      # Now we are sure we are using the latest, make sure the pre-reqs are installed
      apt-get -y install libgtkdatabox-0.9.1-1-dev libmatio-dev libxml2 libxml2-dev bison flex libavahi-common-dev libavahi-client-dev
    else
      # run the new one instead, and then just quit
      echo ./adi_update_tools.sh has been updated, switching to new one
      ./adi_update_tools.sh
      exit
    fi
  elif [ $REPO = "iio-cmdsrv" ]
  then
    cd ./server
  elif [ $REPO = "libiio" ]
  then
    # Just in case an old version is still under /usr/local
    make uninstall PREFIX=/usr/local 2>/dev/null
  elif [ $REPO = "thttpd" ]
  then
    ./configure
  fi

  do_build $REPO $TARGET
done
