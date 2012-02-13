# ---+ Extensions
# ---++ MessageSequenceChartPlugin
# **PATH M**
# Path to mscgen executable on your system
$TWiki::cfg{Plugins}{MessageSequenceChartPlugin}{mscGenCmd} = '/usr/bin/mscgen';
# **PATH M**
# Path to the MessageSequenceChart.pl script (should be in your tools directory)
$TWiki::cfg{Plugins}{MessageSequenceChartPlugin}{mscScript} = '$TWiki::cfg{DataDir}/../tools/MessageSequenceChart.pl';
# **BOOLEAN**
# Debug plugin. See output in data/debug.txt.
$TWiki::cfg{Plugins}{MessageSequenceChartPlugin}{Debug} = 0;
1;
