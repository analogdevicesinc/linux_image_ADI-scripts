DESTDIR ?=
PREFIX ?= /usr/local
SYSTEMD_DIR ?= /etc/systemd/system

# Pure file installation (no systemctl, no network): safe for packaging
install:
	install -d $(DESTDIR)$(PREFIX)/bin
	install ./*.sh $(DESTDIR)$(PREFIX)/bin/

	install -D -m 0644 ./power-service/adi-power.service $(DESTDIR)$(SYSTEMD_DIR)/adi-power.service
	install -D -m 0644 ./power-service/adi_power.py $(DESTDIR)/usr/share/systemd/adi_power.py
	install -D -m 0644 ./power-service/stingray_power.py $(DESTDIR)/usr/share/systemd/stingray_power.py

	install -D -m 0644 ./lightdm_timeout.conf $(DESTDIR)$(SYSTEMD_DIR)/lightdm.service.d/timeout.conf

	install -D -m 0644 ./jupiter_scripts/fan-control.service $(DESTDIR)$(SYSTEMD_DIR)/fan-control.service
	install -D -m 0744 ./jupiter_scripts/fan-control $(DESTDIR)/usr/bin/fan-control

	install -D -m 0644 ./fix-display-port.service $(DESTDIR)$(SYSTEMD_DIR)/fix-display-port.service

	# USB gadget service files (gt itself comes from the gt package)
	for f in gt.service gt-start.service gt.target iiod_ffs.service dev-iio_ffs.mount iiod_context_attr.service; do \
		install -D -m 0644 usb-gadget-service/systemd/$$f $(DESTDIR)$(SYSTEMD_DIR)/$$f; \
	done
	install -D -m 0644 usb-gadget-service/defaults/usb_gadget $(DESTDIR)/etc/default/usb_gadget
	install -D -m 0644 usb-gadget-service/defaults/iiod $(DESTDIR)/etc/default/iiod
	for f in usb-gadget-service/schemes/*.scheme; do \
		install -D -m 0644 $$f $(DESTDIR)$(PREFIX)/etc/gt/adi/$$(basename $$f); \
	done
	install -D -m 0744 usb-gadget-service/scripts/iiod_context.sh $(DESTDIR)$(PREFIX)/bin/iiod_context.sh
	install -D -m 0744 usb-gadget-service/scripts/usb_gadget.sh $(DESTDIR)$(PREFIX)/bin/usb_gadget.sh
	install -D -m 0644 usb-gadget-service/udev/99-udc.rules $(DESTDIR)/etc/udev/rules.d/99-udc.rules

# On-device setup (previous behaviour of "make install"): enable services and build gt
enable:
	systemctl daemon-reload
	systemctl enable adi-power.service
	systemctl enable fan-control.service
	systemctl enable fix-display-port.service

	/bin/sh usb-gadget-service/install_gt.sh

.PHONY: install enable
