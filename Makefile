DESTDIR=/usr/local

install:
	install -d $(DESTDIR)/bin
	install ./*.sh $(DESTDIR)/bin/

	install -D -m 0644 ./power-service/adi-power.service /etc/systemd/system/
	install -D -m 0644 ./power-service/adi_power.py /usr/share/systemd/
	install -D -m 0644 ./power-service/stingray_power.py /usr/share/systemd/

	install -D -m 0644 ./lightdm_timeout.conf /etc/systemd/system/lightdm.service.d/timeout.conf

	install -D -m 0644 ./jupiter_scripts/fan-control.service /etc/systemd/system/fan-control.service
	install -D -m 0744 ./jupiter_scripts/fan-control /usr/bin/fan-control

	install -D -m 0644 ./fix-display-port.service /etc/systemd/system/fix-display-port.service

	systemctl daemon-reload
	systemctl enable adi-power.service
	systemctl enable fan-control.service
	systemctl enable fix-display-port.service

	/bin/sh usb-gadget-service/install_gt.sh
