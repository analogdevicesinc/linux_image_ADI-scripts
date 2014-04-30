#!/bin/sh

BUILDS="fmcomms1-eeprom-cal \
	libiio \
	iio-cmdsrv \
	iio-oscilloscope \
	fru_tools \
	iio-cgi-netscope \
	iio-fm-radio \
	linux_image_ADI-scripts"

ARG2=""

do_build ()
{
  local prj=$1
  local arg=$2
  make -j2 && make install $arg && echo "\n Building $prj finished Successfully\n" ||
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

  if [ -d $i ]
  then
    cd ./$i
    echo "\n *** Updating $i ***"
    git pull || continue
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
    make clean
    git checkout master
  elif [ $i = "libiio" ]
  then
    ARG2="PREFIX=/usr"
  fi

  do_build $i $ARG2
done
