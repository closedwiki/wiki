export TWIKI_SHARED=`pwd`
cd lib/TWiki/Plugins/TWikiReleaseTrackerPlugin

for i in athenstwiki.mrjc.com/twiki beijingtwiki.mrjc.com/twiki cairotwiki.mrjc.com/twiki cleaver.org/twiki
do
   export TWIKI_HOME=/home/mrjc/$i
   perl build.pl install
done

