# Install target
TWIKI=$(TWIKI_HOME)

FILES=	TWIKI/lib/TWiki/Plugins/FormQueryPlugin.pm \
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/Arithmetic.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/Archive.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/Array.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/ColourMap.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/FileTime.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/Map.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/Relation.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/ReqDBSupport.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/Search.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/TableFormat.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/TableDef.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/WebDB.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/ArchiveTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/ArithmeticTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/ArrayTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/ColourMapTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/FileTimeTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/FormQuerySuite.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/FuncFixture.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/MapTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/SearchTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/TableDefTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/TableFormatTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/RelationTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/WebDBTest.pm\
	TWIKI/lib/TWiki/Plugins/FormQueryPlugin/test/testDB.dat\
	TWIKI/data/TWiki/FormQueryPlugin.txt\
	TWIKI/bin/autocreate\
	TWIKI/bin/tasknotify

TARGETS=$(FILES:TWIKI/%=${TWIKI}/%)

$(TARGETS): ${TWIKI}/%: %
	-@ ( [ -d $< ] && mkdir $@ ) || cp $< $@
	@ chmod 777 $@

install: $(TARGETS)
	-@echo FormQueryPlugin installed in $(TWIKI)

uninstall:
	-rm -r $(TARGETS)
	-@echo FormQueryPlugin uninstalled from $(TWIKI)

zip:
	zip -9 FormQueryPlugin.zip $(FILES:TWIKI/%=%)

test:
	cd lib/TWiki/Plugins/FormQueryPlugin/test && perl -w -I../../../.. -I. TestRunner.pl FormQuerySuite

release:
	$(MAKE) test
	$(MAKE) zip
