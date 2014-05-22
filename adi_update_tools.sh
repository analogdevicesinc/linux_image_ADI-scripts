#!/bin/sh

if [ "$(id -u)" != "0" ] ; then
	echo "This script must be run as root"
	exit 1
fi

#find md5of this file
md5_self=`md5sum $0`

# Keeps the scripts as the first thing, so we can check for updated
# scripts ...
BUILDS="linux_image_ADI-scripts \
	fmcomms1-eeprom-cal \
	libiio \
	iio-cmdsrv \
	iio-oscilloscope \
	fru_tools \
	iio-cgi-netscope \
	iio-fm-radio \
	jesd-eye-scan-gtk"

do_build ()
{
  local prj=$1
  local arg=$2
  local target=$3
  make clean;
  make -j3 $target && make install $arg && echo "\n Building $prj finished Successfully\n" ||
	echo "Building $prj Failed\n"
}

# Allow selective builds
if [ -n "$1" ]
then
BUILDS=$1
fi

for i in $BUILDS
do
  cd /usr/local/src
  ARG2=""
  ARG_TARGET=""

  if [ -d $i ]
  then
    cd ./$i
    echo "\n *** Updating $i ***"
    git pull;
    cd ..
  else
    echo "\n *** Cloning $i ***"
    git clone https://github.com/analogdevicesinc/$i.git || continue
  fi

  echo "\n *** Building $i ***"
  cd ./$i

# Handle some specialties here
  if [ $i = "linux_image_ADI-scripts" ]
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
  elif [ $i = "iio-cmdsrv" ]
  then
    cd ./server
  elif [ $i = "iio-oscilloscope" ]
  then
    git checkout origin/libiio-rc1
    do_build "$i-multi_plot_osc-libiio-rc1"
    git checkout master
  elif [ $i = "libiio" ]
  then
    ARG2="PREFIX=/usr"
    ARG_TARGET="libiio iiod"
  fi

  do_build $i $ARG2 $ARG_TARGET
done
