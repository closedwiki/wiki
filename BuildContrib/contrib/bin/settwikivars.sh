# Because this script sets variables that must persist,
# this script may best be executed in the current shell's context, not as 
# a child script.

export TWIKI_RUNTIMELIB=$HOME/latestbetatwiki.mrjc.com/twiki/lib
export TWIKI_LIBSDIR=$HOME/twikiplugindev/twikiplugins/
export TWIKI_LIBS=`echo $TWIKI_LIBSDIR*/lib/ | tr " " ":"`:$TWIKI_RUNTIMELIB
export TWIKI_HOMES="latestbetatwiki.mrjc.com/twiki athenstwiki.mrjc.com/twiki beijingtwiki.mrjc.com/twiki cairotwiki.mrjc.com/twiki cleaver.org/twiki mbawiki.com/twiki testwiki.mrjc.com/twiki"
