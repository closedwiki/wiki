
PLATFORM ?= darwin

TAR_EXCLUDE = --exclude CVS --exclude *~ --exclude bak

twiki-$(PLATFORM).tar.bz2 : twiki-$(PLATFORM).tar
	bzip2 twiki-$(PLATFORM).tar

twiki-$(PLATFORM).tar : 
	tar -c $(TAR_EXCLUDE) --no-recursion -f twiki-$(PLATFORM).tar --directory platform/$(PLATFORM) `cd platform/$(PLATFORM); ls` 
	tar -r $(TAR_EXCLUDE) --exclude "downloads/*/*.zip" -f twiki-$(PLATFORM).tar bin/* cpan/*.pl downloads/ config/ cpan/MIRROR/TWIKI/
	tar -r $(TAR_EXCLUDE) -f twiki-$(PLATFORM).tar webs/local/

components : twiki-cpan plugins contribs addons release 

distro : components twiki-$(PLATFORM).tar.bz2 

test-distro : components twiki-$(PLATFORM).tar

minicpan :
	cd cpan ; ./mirror-cpan.pl

twiki-cpan :
	cd cpan ; ./mirror-cpan.pl --twiki `./calc-twiki-deps.pl`

release :
	REL=TWiki20040902.tar.gz; OUT=downloads/releases/$$REL; [ -e $$OUT ] || wget -nc --http-user=TWikiGuest --http-passwd=guest -O $$OUT http://twiki.org/release/$$REL

plugins :
	bin/download-twiki-extensions.pl plugins
	bin/zip2tgz.pl downloads/plugins/*.zip

contribs :
	bin/download-twiki-extensions.pl contribs
	bin/zip2tgz.pl downloads/contribs/*.zip

addons :
	bin/download-twiki-extensions.pl addons
	bin/zip2tgz.pl downloads/addons/*.zip

print :
	@echo Settings
	@echo ================================================================================
	@echo PLATFORM = $(PLATFORM)

help : print
	@echo 
	@echo Usage
	@echo ================================================================================
	@echo make twiki-$(PLATFORM).tar[.bz2] - bundle existing extensions + kernels into .tar[.bz2]
	@echo make test-distro - download and bundle extensions + kernel
	@echo make distro - test-distro + bzip2 compression
	@echo make plugins contribs addons - download and convert extensions
	@echo make minicpan - mirror latest version of cpan
	@echo make twiki-cpan - create twiki cpan repository
	@echo 
