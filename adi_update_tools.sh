#!/bin/sh

BUILDS="fmcomms1-eeprom-cal \
	libiio \
	iio-cmdsrv \
	iio-oscilloscope \
	fru_tools \
	iio-cgi-netscope \
	iio-fm-radio \
	linux_image_ADI-scripts"

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

apt-get -y install libxml2 libxml2-dev bison flex

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
  if [ $i = "iio-cmdsrv" ]
  then
    cd ./server
  elif [ $i = "iio-oscilloscope" ]
  then
    git checkout origin/multi_plot_osc
    do_build "$i-multi_plot_osc"
    git checkout master
  elif [ $i = "libiio" ]
  then
    ARG2="PREFIX=/usr"
    ARG_TARGET="libiio iiod"
  fi

  do_build $i $ARG2 $ARG_TARGET
done
