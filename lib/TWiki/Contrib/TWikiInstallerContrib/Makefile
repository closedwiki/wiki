
PLATFORM ?= sourceforge

TAR_EXCLUDE = --exclude CVS --exclude *~ --exclude bak

sfwiki.tar.bz2 :
	tar -c $(TAR_EXCLUDE) --no-recursion -f sfwiki.tar --directory platform/$(PLATFORM) `cd platform/$(PLATFORM); ls` 
	tar -r $(TAR_EXCLUDE) --exclude "downloads/*/*.zip" -f sfwiki.tar bin/* cpan/*.pl cpan/MIRROR/TWIKI downloads 
#	tar -r $(TAR_EXCLUDE) --exclude downloads/webs --exclude "downloads/*/*.zip" -f sfwiki.tar bin/* cpan/*.pl cpan/MIRROR/TWIKI downloads 
	bzip2 sfwiki.tar

distro : sfwiki.tar.bz2 cpan release plugins contrib addons

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


print :
	@echo PLATFORM = $(PLATFORM)
