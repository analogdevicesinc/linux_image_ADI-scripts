#!/bin/bash

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

BUILDS_DEV="linux_image_ADI-scripts:origin/main \
	libiio:origin/main \
	libad9361-iio:origin/main \
	libad9166-iio:origin/main \
	iio-oscilloscope:origin/main \
	fru_tools:origin/main \
	iio-fm-radio:origin/main \
	jesd-eye-scan-gtk:origin/main \
	diagnostic_report:origin/main \
	wiki-scripts:origin/main \
	colorimeter:origin/main"

BUILDS_NEXT_STABLE="linux_image_ADI-scripts:origin/main \
	libiio:origin/next_stable \
	libad9361-iio:origin/next_stable \
	libad9166-iio:origin/next_stable \
	iio-oscilloscope:origin/next_stable \
	fru_tools:origin/main \
	iio-fm-radio:origin/main \
	jesd-eye-scan-gtk:origin/main \
	diagnostic_report:origin/main \
	wiki-scripts:origin/main \
	colorimeter:origin/2023_R2"

BUILDS_2021_R1="linux_image_ADI-scripts:origin/main \
	libiio:origin/2021_R1 \
	libad9361-iio:origin/2021_R1 \
	libad9166-iio:origin/main \
	iio-oscilloscope:origin/2021_R1\
	fru_tools:origin/2021_R1 \
	iio-fm-radio:origin/main \
	wiki-scripts:origin/main \
	jesd-eye-scan-gtk:origin/2021_R1 \
	diagnostic_report:origin/main \
	colorimeter:origin/2021_R1"

BUILDS_2021_R2="linux_image_ADI-scripts:origin/main \
	libiio:origin/2021_R2 \
	libad9361-iio:origin/2021_R2 \
	libad9166-iio:origin/main \
	iio-oscilloscope:origin/2021_R2\
	fru_tools:origin/2021_R2 \
	iio-fm-radio:origin/main \
	wiki-scripts:origin/main \
	jesd-eye-scan-gtk:origin/2021_R2 \
	diagnostic_report:origin/main \
	colorimeter:origin/2021_R2"

BUILDS_2022_R2="linux_image_ADI-scripts:origin/main \
	libiio:origin/2022_R2 \
	libad9361-iio:origin/2022_R2 \
	libad9166-iio:origin/2022_R2 \
	iio-oscilloscope:origin/2022_R2\
	fru_tools:origin/2022_R2 \
	iio-fm-radio:origin/main \
	wiki-scripts:origin/main \
	jesd-eye-scan-gtk:origin/2022_R2 \
	diagnostic_report:origin/main \
	colorimeter:origin/2022_R2"

BUILDS_2023_R2="linux_image_ADI-scripts:origin/main \
	libiio:origin/2023_R2 \
	libad9361-iio:origin/2023_R2 \
	libad9166-iio:origin/2023_R2 \
	iio-oscilloscope:origin/2023_R2\
	fru_tools:origin/2023_R2 \
	iio-fm-radio:origin/main \
	wiki-scripts:origin/main \
	jesd-eye-scan-gtk:origin/2023_R2 \
	diagnostic_report:origin/main \
	colorimeter:origin/2023_R2"

# Define file where to save git info
VERSION="/ADI_repos_git_info.txt"
[ -f $VERSION ] && rm -rf $VERSION
touch $VERSION

write_git_info()
{
   local git_link="https://github.com/analogdevicesinc/$1"
   local git_branch=$2
   echo "Repo   : $git_link" >> $VERSION
   echo "Branch : $git_branch"	>> $VERSION
   echo "Git_sha: $(git rev-parse --short HEAD)\n" >> $VERSION
}


do_build ()
{
  local prj=$1
  local target=$2
  make clean;
  make -j $(nproc) $target && make install && echo "\n Building $prj target $target finished Successfully\n" ||
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

	sudo apt-get -y install qt5-default gpsd python-gps gpsd-clients libmozjs-24-bin \
		mplayer libx264-142 libncurses5 libreadline5 libreadline-dev libexif12 \
		libexif-dev python3-scipy sox

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

	write_git_info "rfsom-box-gui" "master"

	if [ ! -d ./build_packrf ] ; then
		mkdir ./build_packrf
	fi
	cd ./build_packrf
	qmake ..
	make && make install
	cd ..

	sudo systemctl daemon-reload
	#auto-start packrf
	sudo systemctl enable packrf.service

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

	write_git_info "plutosdr_scripts" "master"

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
if [[ "$1" =~ "dev" ]] || [[ "$1" = "main" ]]
then
  BUILDS=$BUILDS_DEV
elif [[ "$1" = "2018_R2" ]] || [[ "$1" = "2018_r2" ]] || \
     [[ "$1" = "2019_R1" ]] || [[ "$1" = "2019_r1" ]] || \
     [[ "$1" = "2019_R2" ]] || [[ "$1" = "2019_r2" ]]
then
  echo "Only last two releases are supported for update."
  exit 1
elif [[ "$1" = "2021_R1" ]] || [[ "$1" = "2021_r1" ]]
then
  BUILDS=$BUILDS_2021_R1
elif [[ "$1" = "2021_R2" ]] || [[ "$1" = "2021_r2" ]]
then
  BUILDS=$BUILDS_2021_R2
elif [[ "$1" = "2022_R2" ]] || [[ "$1" = "2022_r2" ]]
then
  BUILDS=$BUILDS_2022_R2
elif [[ "$1" = "2023_R2" ]] || [[ "$1" = "2023_r2" ]]
then
  BUILDS=$BUILDS_2023_R2
elif [[ "$1" = "NEXT_STABLE" ]] || [[ "$1" = "next_stable" ]]
then
  BUILDS=$BUILDS_NEXT_STABLE
elif [ -n "$1" ]
then
  BUILDS=$1
else
  BUILDS=$BUILDS_2022_R2
fi

for i in $BUILDS
do
  REPO=`echo $i | cut -d':' -f1`
  BRANCH=`echo $i | cut -s -d':' -f2`
  TARGET=`echo $i | cut -s -d':' -f3`

# selective build without branch? use main
  if [ -z $BRANCH ]
  then
    echo HERE
    BRANCH=origin/main
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
  else
    echo "\n *** Cloning $REPO/$BRANCH ***"
    git clone https://github.com/analogdevicesinc/$REPO.git || continue
    cd ./$REPO
    git checkout $BRANCH || continue
  fi

  write_git_info "$REPO" "$BRANCH"

  echo "\n *** Building $REPO ***"

# Handle some specialties here
  if [ $REPO = "linux_image_ADI-scripts" ]
  then
    new=`md5sum ./adi_update_tools.sh`
    if [ "$new" = "$md5_self" ]
    then
      echo ./adi_update_tools.sh script is the same, continuing
      # Now we are sure we are using the latest, make sure the pre-reqs
      # are installed. If someone reports an error, fix the list.
      apt-get -y install libgtk2.0-dev libmatio-dev \
        libfftw3-dev libxml2 libxml2-dev bison flex libavahi-common-dev \
        libavahi-client-dev libcurl4-openssl-dev libjansson-dev cmake libaio-dev ncurses-dev \
        libserialport-dev libcdk5-dev
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
  elif [ $REPO = "libiio" ]
  then
    # Just in case an old version is still under /usr/local
    rm -f /usr/local/lib/libiio.so* /usr/local/sbin/iiod \
        /usr/local/bin/iio_* /usr/local/include/iio.h \
        /usr/local/lib/pkgconfig/libiio.pc

    # Remove old services file
    rm -f /etc/avahi/services/iio.service

    # Remove old init.d links if they exist
    if [ -f /etc/init.d/iiod.sh ] ; then
	rm -f /etc/init.d/iiod.sh
	update-rc.d -f iiod.sh remove
    fi
    if [ -f /etc/init.d/iiod ] ; then
	rm -f /etc/init.d/iiod
	update-rc.d -f iiod remove
    fi

    # New libiio versions install to /usr/lib/arm-linux-gnueabihf;
    # remove the old ones that might still be inside /usr/lib
    rm -f /usr/lib/libiio.so*

    grep -q usb_functionfs_descs_head_v2 /usr/include/linux/usb/functionfs.h
    if [ "$?" -eq "1" ] ; then
        # Get a more recent version of functionfs.h, allowing libiio to build
	# the IIOD USB backend
        wget -O /usr/include/linux/usb/functionfs.h http://raw.githubusercontent.com/torvalds/linux/master/include/uapi/linux/usb/functionfs.h
    fi

    rm -rf build

    # Apparently, under undetermined circumstances CMake will output the build
    # files to the source directory instead of the current directory.
    # Here we use the undocumented -B and -H options to force the directory
    # where the build files are generated.
    if grep -Fxq "/lib/systemd" /sbin/init
    then
	EXTRA_CMAKE=$EXTRA_CMAKE" -DWITH_SYSTEMD=ON"
    elif grep -Fxq "upstart" /sbin/init
    then
	EXTRA_CMAKE=$EXTRA_CMAKE" -DWITH_UPSTART=ON"
    else
	EXTRA_CMAKE=$EXTRA_CMAKE" -DWITH_SYSVINIT=ON"
    fi

    cmake ${EXTRA_CMAKE} -DWITH_HWMON=ON -DWITH_SERIAL_BACKEND=ON -DWITH_MAN=ON -DWITH_EXAMPLES=ON \
	    -DPYTHON_BINDINGS=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_COLOR_MAKEFILE=OFF -Bbuild -H.
    cd build
  elif [ $REPO = "libad9361-iio" ]
  then
	  rm -rf build

	  # Same as above
	  cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DCMAKE_COLOR_MAKEFILE=OFF -Bbuild -H.
	  cd build
  elif [ $REPO = "libad9166-iio" ]
  then
	  rm -rf build

	  cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DCMAKE_COLOR_MAKEFILE=OFF \
		-DPYTHON_BINDINGS=ON -Bbuild -H.
	  cd build
  elif [ $REPO = "mathworks_tools" ]
  then
    cd ./motor_control/linux_utils/
  elif [ $REPO = "iio-oscilloscope" ]
  then
	rm -rf build
	cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_COLOR_MAKEFILE=OFF -Bbuild -H.
	cd build
  elif [ $REPO = "wiki-scripts" ]
  then
	cd iio/iio_jesd204_fsm_sync
	rm -rf build
	cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_COLOR_MAKEFILE=OFF -Bbuild -H.
	cd build
  fi

  do_build $REPO $TARGET
done
