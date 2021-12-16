if [ "$(id -u)" != "0" ] ; then
	echo "This script must be run as root"
	exit 1
fi

SCRIPT_PATH=$(dirname $(readlink -f $0))

apt-get -y install libconfig-dev

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

cd $SCRIPT_PATH

install -D -m 0644 systemd/gt.service /etc/systemd/system/
install -D -m 0644 systemd/gt-start.service /etc/systemd/system/
install -D -m 0644 systemd/gt.target /etc/systemd/system/
install -D -m 0644 systemd/iiod_ffs.service /etc/systemd/system/
install -D -m 0644 systemd/dev-iio_ffs.mount /etc/systemd/system/
install -D -m 0644 systemd/iiod_context_attr.service /etc/systemd/system/

install -D -m 0644 -C defaults/usb_gadget /etc/default/
install -D -m 0644 -C defaults/iiod /etc/default/

install -d /usr/local/etc/gt/adi/
install -D -m 0644 schemes/iio_acm_generic.scheme /usr/local/etc/gt/adi/
install -D -m 0644 schemes/iio_ncm.scheme /usr/local/etc/gt/adi/

install -D -m 0744 scripts/iiod_context.sh /usr/local/bin/
install -D -m 0744 scripts/usb_gadget.sh /usr/local/bin/

install -D -m 0644 udev/99-udc.rules /etc/udev/rules.d/

systemctl daemon-reload
systemctl enable iiod_context_attr.service gt.service dev-iio_ffs.mount iiod_ffs.service gt-start.service gt.target

udevadm control --reload-rules
udevadm trigger
