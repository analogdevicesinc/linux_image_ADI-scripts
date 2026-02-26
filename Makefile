DESTDIR ?=
PREFIX ?= /usr/local

# Service templates and generated files
SERVICE_TEMPLATES = \
	jupiter_scripts/fan-control.service.in \
	fix-display-port.service.in \
	power-service/adi-power.service.in \
	usb-gadget-service/systemd/gt.service.in \
	usb-gadget-service/systemd/gt-start.service.in \
	usb-gadget-service/systemd/iiod_context_attr.service.in

SERVICE_FILES = $(SERVICE_TEMPLATES:.service.in=.service)

# Config file templates
CONFIG_TEMPLATES = \
	usb-gadget-service/defaults/usb_gadget.in

CONFIG_FILES = $(CONFIG_TEMPLATES:.in=)

# Rule to generate .service files from .service.in templates
%.service: %.service.in
	sed 's|@PREFIX@|$(PREFIX)|g' $< > $@

# Rule to generate config files from .in templates
usb-gadget-service/defaults/usb_gadget: usb-gadget-service/defaults/usb_gadget.in
	sed 's|@PREFIX@|$(PREFIX)|g' $< > $@

install: $(SERVICE_FILES) $(CONFIG_FILES)
	install -d $(DESTDIR)$(PREFIX)/bin
	install ./*.sh $(DESTDIR)$(PREFIX)/bin/

	install -D -m 0644 ./power-service/adi-power.service $(DESTDIR)/etc/systemd/system/adi-power.service
	install -D -m 0644 ./power-service/adi_power.py $(DESTDIR)$(PREFIX)/share/systemd/adi_power.py
	install -D -m 0644 ./power-service/stingray_power.py $(DESTDIR)$(PREFIX)/share/systemd/stingray_power.py

	install -D -m 0644 ./lightdm_timeout.conf $(DESTDIR)/etc/systemd/system/lightdm.service.d/timeout.conf

	install -D -m 0644 ./jupiter_scripts/fan-control.service $(DESTDIR)/etc/systemd/system/fan-control.service
	install -D -m 0744 ./jupiter_scripts/fan-control $(DESTDIR)$(PREFIX)/bin/fan-control

	install -D -m 0644 ./fix-display-port.service $(DESTDIR)/etc/systemd/system/fix-display-port.service

	# USB gadget service files
	install -D -m 0644 ./usb-gadget-service/systemd/gt.service $(DESTDIR)/etc/systemd/system/gt.service
	install -D -m 0644 ./usb-gadget-service/systemd/gt-start.service $(DESTDIR)/etc/systemd/system/gt-start.service
	install -D -m 0644 ./usb-gadget-service/systemd/gt.target $(DESTDIR)/etc/systemd/system/gt.target
	install -D -m 0644 ./usb-gadget-service/systemd/iiod_ffs.service $(DESTDIR)/etc/systemd/system/iiod_ffs.service
	install -D -m 0644 ./usb-gadget-service/systemd/dev-iio_ffs.mount $(DESTDIR)/etc/systemd/system/dev-iio_ffs.mount
	install -D -m 0644 ./usb-gadget-service/systemd/iiod_context_attr.service $(DESTDIR)/etc/systemd/system/iiod_context_attr.service

	install -D -m 0644 ./usb-gadget-service/defaults/usb_gadget $(DESTDIR)/etc/default/usb_gadget
	install -D -m 0644 ./usb-gadget-service/defaults/iiod $(DESTDIR)/etc/default/iiod

	install -d $(DESTDIR)$(PREFIX)/share/adi-scripts/gt/schemes
	install -m 0644 ./usb-gadget-service/schemes/iio_acm_generic.scheme $(DESTDIR)$(PREFIX)/share/adi-scripts/gt/schemes/iio_acm_generic.scheme
	install -m 0644 ./usb-gadget-service/schemes/iio_ncm.scheme $(DESTDIR)$(PREFIX)/share/adi-scripts/gt/schemes/iio_ncm.scheme
	install -m 0644 ./usb-gadget-service/schemes/iio_acmx2_rndis.scheme $(DESTDIR)$(PREFIX)/share/adi-scripts/gt/schemes/iio_acmx2_rndis.scheme

	install -D -m 0755 ./usb-gadget-service/scripts/iiod_context.sh $(DESTDIR)$(PREFIX)/bin/iiod_context.sh
	install -D -m 0755 ./usb-gadget-service/scripts/usb_gadget.sh $(DESTDIR)$(PREFIX)/bin/usb_gadget.sh

	install -D -m 0644 ./usb-gadget-service/udev/99-udc.rules $(DESTDIR)/etc/udev/rules.d/99-udc.rules

	# Other configuration files
	install -D -m 0644 ./fw_env.config $(DESTDIR)/etc/fw_env.config
	install -D -m 0644 ./ttyGS0.conf $(DESTDIR)/etc/ttyGS0.conf
	install -D -m 0644 ./input-event-daemon.conf.rfsombox $(DESTDIR)/etc/input-event-daemon.conf.rfsombox

ifeq ($(DESTDIR),)
	# Build and install gt
	/bin/sh usb-gadget-service/install_gt.sh

	systemctl enable adi-power.service fan-control.service fix-display-port.service
	systemctl enable iiod_context_attr.service gt.service dev-iio_ffs.mount iiod_ffs.service gt-start.service gt.target
endif

clean:
	rm -f $(SERVICE_FILES) $(CONFIG_FILES)

.PHONY: install clean
