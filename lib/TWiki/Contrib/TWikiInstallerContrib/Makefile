
PLATFORM ?= sourceforge

TAR_EXCLUDE = --exclude CVS --exclude *~ --exclude bak

twiki-$(PLATFORM).tar.bz2 :
	tar -c $(TAR_EXCLUDE) --no-recursion -f twiki-$(PLATFORM).tar --directory platform/$(PLATFORM) `cd platform/$(PLATFORM); ls` 
	tar -r $(TAR_EXCLUDE) --exclude "downloads/*/*.zip" -f twiki-$(PLATFORM).tar bin/* cpan/*.pl cpan/MIRROR/TWIKI downloads 
	bzip2 twiki-$(PLATFORM).tar

distro : cpan release plugins contrib addons patches twiki-$(PLATFORM).tar.bz2 

cpan :
	cd cpan ; ./mirror-cpan.pl `./calc-twiki-deps.pl`

release :
	wget -nc --http-user=TWikiGuest --http-passwd=guest -O downloads/releases/TWiki20040901.tar.gz http://twiki.org/release/TWiki20040901.tar.gz

plugins :
	bin/download-twiki-plugins.pl 
	bin/zip2tgz.pl downloads/plugins/*.zip

contrib :
	bin/download-twiki-contribs.pl 
	bin/zip2tgz.pl downloads/contrib/*.zip

addons :
	bin/download-twiki-addons.pl 
	bin/zip2tgz.pl downloads/addons/*.zip

patches :
	bin/download-twiki-patches.pl

print :
	@echo PLATFORM = $(PLATFORM)
