DESTDIR ?=
PREFIX ?= /usr/local

install:
	install -d $(DESTDIR)$(PREFIX)/bin
	install ./*.sh $(DESTDIR)$(PREFIX)/bin/

	install -D -m 0644 ./power-service/adi-power.service $(DESTDIR)/etc/systemd/system/adi-power.service
	install -D -m 0644 ./power-service/adi_power.py $(DESTDIR)/usr/share/systemd/adi_power.py
	install -D -m 0644 ./power-service/stingray_power.py $(DESTDIR)/usr/share/systemd/stingray_power.py

	install -D -m 0644 ./lightdm_timeout.conf $(DESTDIR)/etc/systemd/system/lightdm.service.d/timeout.conf

	install -D -m 0644 ./jupiter_scripts/fan-control.service $(DESTDIR)/etc/systemd/system/fan-control.service
	install -D -m 0744 ./jupiter_scripts/fan-control $(DESTDIR)$(PREFIX)/bin/fan-control

	install -D -m 0644 ./fix-display-port.service $(DESTDIR)/etc/systemd/system/fix-display-port.service

ifeq ($(DESTDIR),)
	systemctl enable adi-power.service
	systemctl enable fan-control.service
	systemctl enable fix-display-port.service

	/bin/sh usb-gadget-service/install_gt.sh
endif
