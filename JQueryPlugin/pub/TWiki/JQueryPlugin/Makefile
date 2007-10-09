TWIKIROOT=~/twiki/MAIN
TARGET= jquery-all.js jquery-all.css
MINIFYJS=$(TWIKIROOT)/tools/minifyjs
MINIFYCSS=$(TWIKIROOT)/tools/minifycss


all: $(TARGET)
clean: 
	
	rm -f $(TARGET)

JS_SOURCES=\
  jquery.js \
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
  jquery.treeview.js \
  jquery.twiki.js

CSS_SOURCES=\
  jquery.nifty.css \
  jquery.twiki.css

jquery-all.js: $(JS_SOURCES) Makefile $(MINIFYJS)
	@echo creating $@
	@$(MINIFYJS) $(JS_SOURCES) > $@


jquery-all.css: $(CSS_SOURCES) Makefile
	@echo creating $@
	@$(MINIFYCSS) $(CSS_SOURCES) > $@

