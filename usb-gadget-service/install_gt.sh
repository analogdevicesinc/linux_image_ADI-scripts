if [ "$(id -u)" != "0" ] ; then
	echo "This script must be run as root"
	exit 1
fi

apt-get -y install autoconf libtool libconfig-dev

cd /usr/local/src

if [ ! -d libusbgx ] ; then
    git clone https://github.com/linux-usb-gadgets/libusbgx.git
	cd libusbgx
else
    cd libusbgx
    git pull
fi

autoreconf -i
./configure
make && make install
cd -

if [ ! -d gt ] ; then
    git clone https://github.com/linux-usb-gadgets/gt.git
	cd gt
else
    cd gt
    git pull
fi

cd source
cmake -DENABLE_MANUAL_PAGE=off .
make && make install
cd -

ldconfig
