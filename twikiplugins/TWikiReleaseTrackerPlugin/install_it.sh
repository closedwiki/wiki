export TWIKI_LIBSDIR=$HOME/twikiplugindev/twikiplugins/

export TWIKI_SHARED=`pwd`
export TWIKI_LIBS=`echo $TWIKI_LIBSDIR*/lib/ | tr " " ":"`


cd lib/TWiki/Plugins/TWikiReleaseTrackerPlugin

for i in beijingtwiki.mrjc.com/twiki
#athenstwiki.mrjc.com/twiki beijingtwiki.mrjc.com/twiki cairotwiki.mrjc.com/twiki cleaver.org/twiki
do
   echo "Installing to $i"
   export TWIKI_HOME=/home/mrjc/$i
   perl build.pl install
   echo
done

