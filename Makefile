DESTDIR=/usr/local

install:
	install -d $(DESTDIR)/bin
	install ./*.sh $(DESTDIR)/bin/
	/bin/sh usb-gadget-service/install_gt.sh
