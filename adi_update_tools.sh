#!/bin/sh

if [ "$(id -u)" != "0" ] ; then
	echo "This script must be run as root"
	exit 1
fi

wget --spider -nv http://github.com/analogdevicesinc
EC=$?
if [ $EC -ne 0 ];then
   ifconfig
   echo "\n\nNetwork Connection: FAILED\n"
   exit $EC
fi

#find md5of this file
md5_self=`md5sum $0`

# Keeps the scripts as the first thing, so we can check for updated
# scripts ...
# repository:branch:make_target

BUILDS_DEV="linux_image_ADI-scripts:origin/master \
	fmcomms1-eeprom-cal:origin/master \
	libiio:origin/master \
	libad9361-iio:origin/master \
	iio-oscilloscope:origin/master \
	fru_tools:origin/master \
	iio-fm-radio:origin/master \
	jesd-eye-scan-gtk:origin/master \
	diagnostic_report:origin/master \
	colorimeter:origin/master"

BUILDS_2018_R1="linux_image_ADI-scripts:origin/master \
	fmcomms1-eeprom-cal:origin/2015_R2 \
	libiio:origin/2018_R1 \
	libad9361-iio:origin/master \
	iio-oscilloscope:origin/2018_R1\
	fru_tools:origin/2018_R1 \
	iio-fm-radio:origin/2015_R2 \
	jesd-eye-scan-gtk:origin/2018_R2 \
	diagnostic_report:origin/master \
	colorimeter:origin/2016_R2 \
	mathworks_tools:origin/2015_R1"

BUILDS_2018_R2="linux_image_ADI-scripts:origin/master \
	fmcomms1-eeprom-cal:origin/2015_R2 \
	libiio:origin/2018_R2 \
	libad9361-iio:origin/master \
	iio-oscilloscope:origin/2018_R2\
	fru_tools:origin/2018_R2 \
	iio-fm-radio:origin/2015_R2 \
	jesd-eye-scan-gtk:origin/2018_R2 \
	diagnostic_report:origin/master \
	colorimeter:origin/2018_R2"

do_build ()
{
  local prj=$1
  local target=$2
  make clean;
  make -j3 $target && make install && echo "\n Building $prj target $target finished Successfully\n" ||
	echo "Building $prj Failed\n"
}

rfsom_box ()
{
	cd /usr/local/src

	if [ -d "input-event-daemon" ] ; then
	  cd ./input-event-daemon
	  git pull
	else
	  git clone https://github.com/gandro/input-event-daemon.git
	  cd ./input-event-daemon
	fi
	make clean
	make input-event-daemon
	make install
	if [ "$(grep input-event-daemon /etc/rc.local | wc -l)" -eq "0" ] ; then
	  # add /usr/bin/input-event-daemon to /etc/rc.local
	  sed -i '0,/^exit 0$/s/^exit 0.*/\/usr\/bin\/input-event-daemon\n&/' /etc/rc.local
	fi

	cp $1/input-event-daemon.conf.rfsombox /etc/input-event-daemon.conf

	cd /usr/local/src

	sudo apt-get -y install qt5-default gpsd python-gps gpsd-clients libmozjs-24-bin mplayer libx264-142 libncurses5 libreadline5 libreadline-dev libexif12 libexif-dev

	curl -L http://github.com/micha/jsawk/raw/master/jsawk > /tmp/jsawk
	mv /tmp/jsawk /usr/bin/jsawk
	chmod 777 /usr/bin/jsawk
	ln -s /usr/bin/js24 /usr/bin/js

	if [ -d "rfsom-box-gui" ] ; then
	  cd ./rfsom-box-gui
	  for i in $(find ./ -name Makefile -exec -exec dirname {}  \; ) ; do
		pushd $(pwd)
		cd ${i}
		if [ $(grep "uninstall:" Makefile | wc -l) -ne "0" ] ; then
			make uninstall 2>/dev/null
		fi
		popd
	  done
	  git clean -f -d -x
	  git fetch
	  git checkout -f master
	  git pull
	else
	  git clone https://github.com/analogdevicesinc/rfsom-box-gui.git
	  cd ./rfsom-box-gui
	fi

	if [ ! -d ./build_packrf ] ; then
		mkdir ./build_packrf
	fi
	cd ./build_packrf
	qmake ..
	make && make install
	cd ..

	if [ "$(grep rfsom-box-gui-start /etc/rc.local | wc -l)" -eq "0" ] ; then
	  # add /usr/local/bin/rfsom-box-gui-start.sh to /etc/rc.local
	  sed -i '0,/^exit 0$/s/^exit 0.*/\/usr\/local\/bin\/rfsom-box-gui-start.sh\n&/' /etc/rc.local
	fi

	if [ ! -d ./build_fft ] ; then
		mkdir ./build_fft
	fi
	cd ./build_fft
	cmake ../fft-plot
	make && make install

	cd ../tun_tap
	make && make install
	cd ..

	#install ffmpeg, if needed
	if [ $(which ffmpeg | wc -l) -eq "0" ] ; then
		if [ "$(arch)" = "armv7l" ] ; then
			cd /usr/local/src
			wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-armhf-32bit-static.tar.xz
			mkdir ffmpeg-release-armhf-32bit
			cd ffmpeg-release-armhf-32bit
			# skip first level
			tar xvf ../ffmpeg-release-armhf-32bit-static.tar.xz --strip 1
			rm ../ffmpeg-release-armhf-32bit-static.tar.xz
			ln -s /usr/local/src/ffmpeg-release-armhf-32bit/ffmpeg \
				 /usr/local/bin/ffmpeg
		fi
		# should support 64-bit, but not yet
	fi

	#install fim
	# FIM (Fbi IMproved) image viewer program
	if [ $(which fim | wc -l) -eq "0" ] ; then
		cd /usr/local/src
		wget http://download.savannah.nongnu.org/releases/fbi-improved/fim-0.6-trunk.tar.gz
		tar xvf fim-0.6-trunk.tar.gz
		cd fim-0.6-trunk
		./configure
		make && make install

		rm /usr/local/src/fim-0.6-trunk.tar.gz
	fi

	cd /usr/local/src/
	#install plutosdr-scripts
	git clone https://github.com/analogdevicesinc/plutosdr_scripts
	cd plutosdr_scripts
	make
	cp cal_ad9361 /usr/local/bin

	/usr/local/src/rfsom-box-gui/wpa-supplicant/install.sh

	# install a low end terminal (bterm) for /dev/fb
	apt-get -y install libbogl-dev bogl-bterm fonts-droid otf2bdf
	# create a bitmap font, from the true-type font
	otf2bdf -p 8 -d 140 \
		-o /usr/share/fonts/truetype/droid/DroidSansMono.bdf \
		/usr/share/fonts/truetype/droid/DroidSansMono.ttf
	# create a font for the terminal
	# https://manpages.debian.org/jessie/libbogl-dev/bdftobogl.1.en.html
	bdftobogl -b /usr/share/fonts/truetype/droid/DroidSansMono.bdf > \
		/usr/share/fonts/truetype/droid/DroidSansMono.bgf

}

# Allow selective builds by default build the latest release branches
if [ "$1" = "dev" ]
then
  BUILDS=$BUILDS_DEV
elif [ "$1" = "2018_R2" ]
then
  BUILDS=$BUILDS_2018_R2
elif [ -n "$1" ]
then
  BUILDS=$1
else
  BUILDS=$BUILDS_2018_R1
fi

for i in $BUILDS
do
  REPO=`echo $i | cut -d':' -f1`
  BRANCH=`echo $i | cut -s -d':' -f2`
  TARGET=`echo $i | cut -s -d':' -f3`

# selective build without branch? use master
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
      echo "Tree is dirty - generating branch" `date +"%F"`
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
      # Now we are sure we are using the latest, make sure the pre-reqs
      # are installed. If someone reports an error, fix the list.
      apt-get -y install libgtk2.0-dev libgtkdatabox-dev libmatio-dev \
        libfftw3-dev libxml2 libxml2-dev bison flex libavahi-common-dev \
        libavahi-client-dev libcurl4-openssl-dev libjansson-dev cmake libaio-dev
      if [ "$?" -ne "0" ] ; then
        echo Catastrophic error in prerequisite packages,  please report error to:
        echo https://ez.analog.com/community/linux-device-drivers/linux-software-drivers
        exit
      else
	# Non-essential applications, which help out sometime
	apt-get -y install gpsd gpsd-clients u-boot-tools evtest

	if [ ! -f /etc/fw_env.config ]
	then
	  cp ./fw_env.config /etc/
	fi

	REFCLK=$(fw_printenv -n ad9361_ext_refclk)
	if [ $? -eq 0 ]; then
	  echo $REFCLK | grep '^<.*>$'
	  if [ $? -ne 0 ]; then
	    REFCLK="<${REFCLK}>"
	    fw_setenv ad9361_ext_refclk ${REFCLK}
	  fi
	fi

	p=$(pwd)
	 grep -q "RFSOM-BOX" /sys/firmware/devicetree/base/model && rfsom_box $p
	cd $p
      fi
      #Misc fixup:
      sed -i 's/wiki.analog.org/wiki.analog.com/g'  /etc/update-motd.d/10-help-text
      sed -i 's/ analog.com/ www.wiki.analog.com www.analog.com/g' /etc/network/if-up.d/htpdate
    else
      # run the new one instead, and then just quit
      echo ./adi_update_tools.sh has been updated, switching to new one
      ./adi_update_tools.sh $@
      exit
    fi
  elif [ $REPO = "iio-cmdsrv" ]
  then
    cd ./server
  elif [ $REPO = "libiio" ]
  then
    # Just in case an old version is still under /usr/local
    rm -f /usr/local/lib/libiio.so* /usr/local/sbin/iiod \
        /usr/local/bin/iio_* /usr/local/include/iio.h \
        /usr/local/lib/pkgconfig/libiio.pc

    # Remove old init.d links
    rm -f /etc/init.d/iiod.sh /etc/init.d/iiod
    update-rc.d -f iiod remove
    update-rc.d -f iiod.sh remove

    # New libiio versions install to /usr/lib/arm-linux-gnueabihf;
    # remove the old ones that might still be inside /usr/lib
    rm -f /usr/lib/libiio.so*

    grep -i -q -e 'ZYNQ' -e 'Analog Devices' /sys/firmware/devicetree/base/model
    if [ $? -eq 0 ] ; then
        # Get a more recent version of functionfs.h, allowing libiio to build the IIOD USB backend
        wget -O /usr/include/linux/usb/functionfs.h http://raw.githubusercontent.com/torvalds/linux/master/include/uapi/linux/usb/functionfs.h
        install -m 0755 /usr/local/src/linux_image_ADI-scripts/iiod_usbd.init /etc/init.d/iiod
        install -m 0644 /usr/local/src/linux_image_ADI-scripts/ttyGS0.conf /etc/init/
    else
	# Install the startup script of iiod here, as cmake won't do it
	if [ -f iiod/init/iiod.init ] ; then
		install -m 0755 iiod/init/iiod.init /etc/init.d/iiod
	else
		install -m 0755 debian/iiod.init /etc/init.d/iiod
	fi
    fi
    update-rc.d iiod defaults 99 01

    rm -rf build

    # Apparently, under undetermined circumstances CMake will output the build
    # files to the source directory instead of the current directory.
    # Here we use the undocumented -B and -H options to force the directory
    # where the build files are generated.
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_COLOR_MAKEFILE=OFF -Bbuild -H.
    cd build
  elif [ $REPO = "libad9361-iio" ]
  then
	  rm -rf build

	  # Same as above
	  cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DCMAKE_COLOR_MAKEFILE=OFF -Bbuild -H.
	  cd build
  elif [ $REPO = "thttpd" ]
  then
    ./configure
  elif [ $REPO = "mathworks_tools" ]
  then
    cd ./motor_control/linux_utils/
  fi

  do_build $REPO $TARGET
done
