DESTDIR=/usr/local

install:
	install -d $(DESTDIR)/bin
	install ./*.sh $(DESTDIR)/bin/
