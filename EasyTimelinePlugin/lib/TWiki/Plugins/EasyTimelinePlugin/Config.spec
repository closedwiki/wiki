# ---+ Extensions
# ---++ EasyTimelinePlugin
# **PATH M**
# Path to Ploticus on your system
$TWiki::cfg{Plugins}{EasyTimelinePlugin}{PloticusCmd} = '/usr/local/bin/pl';
# **PATH M**
# Path to the EasyTimeline.pl script (should be in your tools directory)
$TWiki::cfg{Plugins}{EasyTimelinePlugin}{EasyTimelineScript} = '$TWiki::cfg{DataDir}/../tools/EasyTimeline.pl';
# **BOOLEAN**
# Debug flag
$TWiki::cfg{Plugins}{EasyTimelinePlugin}{Debug} = 0;
1;
