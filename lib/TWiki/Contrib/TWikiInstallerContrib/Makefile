
TWIKIDEV ?= ~/twiki

all : help

TAR_EXCLUDE = --exclude CVS --exclude *~ --exclude bak

twiki.tar.bz2 : twiki.tar
	bzip2 -f twiki.tar

twiki.tar : 
	tar -f twiki.tar -c $(TAR_EXCLUDE) --no-recursion --directory platform `cd platform; ls `
	tar -f twiki.tar -r $(TAR_EXCLUDE) bin/* cpan/*.pl downloads/ config/ cpan/MIRROR/TWIKI/
	tar -f twiki.tar -r $(TAR_EXCLUDE) 

extensions : plugins contribs addons

distro : twiki-cpan extensions twiki.tar.bz2 

test-distro : twiki-cpan extensions twiki.tar

minicpan :
	cpan/mirror-cpan.pl

twiki-cpan : minicpan
	cpan/mirror-cpan.pl --twiki `cpan/calc-twiki-deps.pl`

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
	@echo TWIKIDEV = $(TWIKIDEV)

help : print
	@echo 
	@echo Usage
	@echo ================================================================================
	@echo make twiki.tar[.bz2] - bundle already-downloaded extensions + kernels into .tar[.bz2]
	@echo 
	@echo make test-distro - download and bundle extensions + kernel
	@echo make distro - test-distro + bzip2 compression
	@echo 
	@echo "make extensions - download extensions (all of plugins, contribs, addons)"
	@echo make plugins contribs addons - download specific extensions types
	@echo 
	@echo make minicpan - mirror latest version of cpan modules
	@echo make twiki-cpan - create twiki cpan repository
	@echo 
	@echo make publish - 
