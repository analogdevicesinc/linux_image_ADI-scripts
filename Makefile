DESTDIR=/usr/local

install:
	install -d $(DESTDIR)/bin
	install ./*.sh $(DESTDIR)/bin/

	install -D -m 0644 ./power-service/adi-power.service /etc/systemd/system/
	install -D -m 0644 ./power-service/adi_power.py /usr/share/systemd/
	install -D -m 0644 ./power-service/stingray_power.py /usr/share/systemd/

	install -D -m 0644 ./lightdm_timeout.conf /etc/systemd/system/lightdm.service.d/timeout.conf

	systemctl daemon-reload
	systemctl enable adi-power.service

	/bin/sh usb-gadget-service/install_gt.sh
