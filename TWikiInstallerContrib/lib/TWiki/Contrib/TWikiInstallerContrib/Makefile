
TWIKIDEV ?= ~/twiki
MakeFor ?= twiki.org-`bin/svnrev.pl`

all : help

TAR_EXCLUDE = --exclude CVS --exclude *~ --exclude bak

$(MakeFor).tar.bz2 : $(MakeFor).tar
	bzip2 -f $(MakeFor).tar

$(MakeFor).tar : 
	tar -f $(MakeFor).tar -c $(TAR_EXCLUDE) --no-recursion --directory platform `cd platform && find -maxdepth 1 -type f`
	tar -f $(MakeFor).tar -r $(TAR_EXCLUDE) bin/* cpan/*.pl downloads/addons/ downloads/contribs/ downloads/plugins/ downloads/kernels/TWikiKernel-$(BRANCH)-`bin/svnrev.pl`.* config/ cpan/MIRROR/TWIKI/
	tar -f $(MakeFor).tar -r $(TAR_EXCLUDE) 

extensions : plugins contribs addons

distro : twiki-cpan extensions $(MakeFor).tar.bz2 

test-distro : twiki-cpan extensions $(MakeFor).tar

minicpan :
	cpan/mirror-cpan.pl

twiki-cpan : minicpan
	cpan/mirror-cpan.pl --twiki `bin/calc-twiki-deps.pl`

plugins :
	bin/download-twiki-extensions.pl plugins

contribs :
	bin/download-twiki-extensions.pl contribs

addons :
	bin/download-twiki-extensions.pl addons

################################################################################

publish :
	scp $(MakeFor).tar.bz2 $(PUBLISH_TO)

################################################################################

print :
	@echo Settings
	@echo ================================================================================
	@echo MakeFor = $(MakeFor)
	@echo TWIKIDEV = $(TWIKIDEV)
	@echo PUBLISH_TO = $(PUBLISH_TO)

help : print
	@echo 
	@echo Usage
	@echo ================================================================================
	@echo make [build-options] MakeFor.tar[.bz2] - bundle already-downloaded extensions + kernels into .tar[.bz2]
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
	@echo make publish - upload distro
	@echo 
	@echo ================================================================================
	@echo build-options:
	@echo   MakeFor - distribution name
