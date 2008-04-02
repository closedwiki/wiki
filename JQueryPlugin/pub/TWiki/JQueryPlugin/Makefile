TWIKIROOT=~/twiki/MAIN
TARGET= \
  jquery-all.js \
  jquery-all.css \
  jquery.superfish.js \
  jquery.superfish.css

MINIFYJS=$(TWIKIROOT)/tools/minifyjs
MINIFYCSS=$(TWIKIROOT)/tools/minifycss


all: $(TARGET)
clean: 
	rm -f $(TARGET)

JS_SOURCES=\
  jquery.js \
  jquery.metadata.js \
  jquery.easing.js \
  jquery.hoverIntent.js \
  jquery.bgiframe.js \
  jquery.shrinkurls.js \
  jquery.blockUI.js \
  jquery.dimensions.js \
  jquery.innerfade.js \
  jquery.dom.js \
  jquery.nifty.js \
  jquery.tooltip.js \
  jquery.treeview.uncompressed.js \
  jquery.twiki.js \
  jquery.tabpane.js

CSS_SOURCES=\
  jquery.nifty.css \
  jquery.twiki.css \
  jquery.tabpane.css \
  jquery.treeview.css

jquery-all.js: $(JS_SOURCES) Makefile $(MINIFYJS)
	@echo creating $@
	@$(MINIFYJS) $(JS_SOURCES) > $@


jquery-all.css: $(CSS_SOURCES) Makefile
	@echo creating $@
	@$(MINIFYCSS) $(CSS_SOURCES) > $@

jquery.superfish.js: jquery.superfish.uncompressed.js
	@echo creating $@
	@$(MINIFYJS) $< > $@

jquery.superfish.css: jquery.superfish.uncompressed.css
	@echo creating $@
	@$(MINIFYCSS) $< > $@
