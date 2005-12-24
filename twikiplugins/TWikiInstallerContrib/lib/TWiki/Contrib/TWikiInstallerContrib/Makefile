
TWIKIDEV ?= ~/twiki
BRANCH ?= DEVELOP
MakeFor ?= twiki.org-`bin/svnrev.pl`

all : help

TAR_EXCLUDE = --exclude CVS --exclude .svn --exclude "*~" --exclude bak

kernel : 
	[ -e components/kernel ] || mkdir -p components/kernel
	cd $(TWIKIDEV)/$(BRANCH)/tools/; TWIKI_LIBS=$(TWIKIDEV)/$(BRANCH)/twikiplugins/BuildContrib/lib/ perl build.pl release; cp $(TWIKIDEV)/$(BRANCH)/TWiki.zip $(TWIKIDEV)/$(BRANCH)/twikiplugins/TWikiInstallerContrib/lib/TWiki/Contrib/TWikiInstallerContrib/components/kernel/TWikiKernel$(BRANCH)`$(TWIKIDEV)/$(BRANCH)/twikiplugins/TWikiInstallerContrib/lib/TWiki/Contrib/TWikiInstallerContrib/bin/svnrev.pl`.zip

$(MakeFor).zip : kernel 
	zip -r $(MakeFor).zip components/extension/ components/kernel/TWikiKernel$(BRANCH)`bin/svnrev.pl`.*

#	tar --file=$(MakeFor).tar --create $(TAR_EXCLUDE) components/extension/ components/kernel/TWikiKernel$(BRANCH)`bin/svnrev.pl`.*

extensions : 
	cd $(TWIKIDEV)/$(BRANCH)/tools/; TWIKI_LIBS=$(TWIKIDEV)/$(BRANCH)/twikiplugins/BuildContrib/lib/ perl build_all_extensions.pl
	[ -e components/extension ] || mkdir -p components/extension
	cp $(TWIKIDEV)/$(BRANCH)/twikiplugins/*/*.zip components/extension

copy_extensions : 
	[ -e components/extension ] || mkdir -p components/extension
	cp $(TWIKIDEV)/$(BRANCH)/twikiplugins/*/*.zip components/extension

TWikiFor : $(MakeFor).zip

distro : extensions $(MakeFor).zip

################################################################################

publish : 
	scp $(MakeFor).zip $(PUBLISH_TO)/twiki.org.zip

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
	@echo make [build-options] MakeFor.zip - build and bundle extensions + kernels into .zip
	@echo 
	@echo make distro - download and bundle extensions + kernel
	@echo 
	@echo "make kernel - build TWikiKernel"
	@echo "make extensions - build extensions (all of plugins, contribs, addons)"
	@echo 
	@echo make publish - upload distro
	@echo 
	@echo ================================================================================
	@echo build-options:
	@echo   MakeFor - distribution name
