# Copyright 2005 Will Norris.  All Rights Reserved.
# License: GPL

# TODO: clean: delete generated directories (eg, darwin-7.8-powerpc/, intel-..., etc.) GENERICALLY (i'm just adding them as i come across them...)

TWIKIDEV ?= ~/twiki
PLATFORM ?= $(TWIKITARGET)
TWIKI_TAR_CACHE_DIR ?= .twiki

DISTRO_LIST = twiki-$(PLATFORM).list

all : help

twiki.list : twiki.list.in
	perl -pe 's/\$${?PLATFORM}?/$(PLATFORM)/' twiki.list.in >twiki.list

twiki.list.in : $(DISTRO_LIST)

pkg : twiki.list
	epm -v -f native twiki
#	epm -v -f portable twiki

$(TWIKIDEV)/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/twiki-$(PLATFORM).tar : 
	( cd $(TWIKIDEV)/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/ && make twiki-$(PLATFORM).tar )

$(TWIKI_TAR_CACHE_DIR)/README : $(TWIKIDEV)/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/twiki-$(PLATFORM).tar
	rm -rf $(TWIKI_TAR_CACHE_DIR) && mkdir $(TWIKI_TAR_CACHE_DIR) && tar --extract --directory $(TWIKI_TAR_CACHE_DIR) --file $(TWIKIDEV)/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/twiki-$(PLATFORM).tar
	touch $(TWIKI_TAR_CACHE_DIR)/README

$(DISTRO_LIST) : $(TWIKI_TAR_CACHE_DIR)/README
	mkepmlist -g twiki -u twiki --prefix /home/twiki/html $(TWIKI_TAR_CACHE_DIR) >$(DISTRO_LIST)

clean : 
	rm -rf twiki.list twiki-*.list $(TWIKI_TAR_CACHE_DIR)/ *~ 
	rm -rf darwin-7.8-powerpc/

help : print
	@echo Usage
	@echo ===============================================================================
	@echo make pkg
	@echo make twiki.list
	@echo make $(DISTRO_LIST)
	@echo make print
	@echo make clean
	@echo make help

print :
	@echo Settings
	@echo ===============================================================================
	@echo PLATFORM=$(PLATFORM)
	@echo TWIKIDEV=$(TWIKIDEV)
	@echo DISTRO_LIST=$(DISTRO_LIST)
	@echo TWIKI_TAR_CACHE_DIR = $(TWIKI_TAR_CACHE_DIR)
	@echo 
