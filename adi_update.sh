#!/bin/sh

BUILDS="fmcomms1-eeprom-cal \
	iio-cmdsrv \
	iio-oscilloscope \
	fru_tools \
	iio-cgi-netscope \
	iio-fm-radio \
	linux_image_ADI-scripts"

do_build ()
{
  local prj=$1
  make && make install && echo "\n Building $prj finished Successfully\n" ||
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

  if [ -d $i ]
  then
    cd ./$i
    echo "\n *** Updating $i ***"
    git pull
    cd ..
  else
    echo "\n *** Cloning $i ***"
    git clone https://github.com/analogdevicesinc/$i.git
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
  fi

  do_build $i
done
