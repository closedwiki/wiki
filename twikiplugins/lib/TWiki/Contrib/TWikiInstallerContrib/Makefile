
PLATFORM ?= darwin
TWIKIDEV ?= ~/twiki

all : help

TAR_EXCLUDE = --exclude CVS --exclude *~ --exclude bak

twiki-$(PLATFORM).tar.bz2 : twiki-$(PLATFORM).tar
	bzip2 twiki-$(PLATFORM).tar

twiki-$(PLATFORM).tar : 
	tar -c $(TAR_EXCLUDE) --no-recursion -f twiki-$(PLATFORM).tar --directory platform `cd platform; ls` --directory platform/$(PLATFORM) README
	tar -r $(TAR_EXCLUDE) --exclude "downloads/*/*.zip" -f twiki-$(PLATFORM).tar bin/* cpan/*.pl downloads/ config/ cpan/MIRROR/TWIKI/
	tar -r $(TAR_EXCLUDE) -f twiki-$(PLATFORM).tar 

extensions : twiki-cpan plugins contribs addons release 

distro : extensions twiki-$(PLATFORM).tar.bz2 

test-distro : extensions twiki-$(PLATFORM).tar

minicpan :
	cpan/mirror-cpan.pl

twiki-cpan : minicpan
	cpan/mirror-cpan.pl --twiki `cpan/calc-twiki-deps.pl`

release :
	REL=TWiki20040902.tar.gz; OUT=downloads/releases/$$REL; [ -e $$OUT ] || wget -nc --http-user=TWikiGuest --http-passwd=guest -O $$OUT http://twiki.org/release/$$REL

plugins :
	bin/download-twiki-extensions.pl plugins

contribs :
	bin/download-twiki-extensions.pl contribs

addons :
	bin/download-twiki-extensions.pl addons

################################################################################

print :
	@echo Settings
	@echo ================================================================================
	@echo PLATFORM = $(PLATFORM)
	@echo TWIKIDEV = $(TWIKIDEV)

#	@echo "  [also] `ls -m platform/ | grep -v ^CVS$$`"
help : print
	@echo 
	@echo Usage
	@echo ================================================================================
	@echo make twiki-$(PLATFORM).tar[.bz2] - bundle already-downloaded extensions + kernels into .tar[.bz2]
	@echo "  [also] `ls -m platform/`"
	@echo 
	@echo make test-distro - download and bundle extensions + kernel
	@echo make distro - test-distro + bzip2 compression
	@echo 
	@echo "make extensions - download extensions (all of plugins, contribs, addons)"
	@echo make plugins contribs addons - download specific extensions types
	@echo 
	@echo make minicpan - mirror latest version of cpan
	@echo make twiki-cpan - create twiki cpan repository
	@echo 
