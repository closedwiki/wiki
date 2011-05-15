# ---+ Extensions
# ---++ ReStructuredTextPlugin
# **PATH M**
# Path to trip executable, located at =twiki/lib/TWiki/Plugins/ReStructuredTextPlugin/trip/bin/trip=. Set this to an absolute path matching your TWiki installation.
$TWiki::cfg{Plugins}{ReStructuredTextPlugin}{TripCmd} = '$TWiki::cfg{DataDir}/../lib/TWiki/Plugins/ReStructuredTextPlugin/trip/bin/trip';
# **TEXT**
# Default options of trip
$TWiki::cfg{Plugins}{ReStructuredTextPlugin}{TripOptions} = '-D source_link=0 -D time=0 -D xformoff=DocTitle -D generator=0 -D tabstops=3';
# **BOOLEAN**
# Debug flag
$TWiki::cfg{Plugins}{ReStructuredTextPlugin}{Debug} = 0;
1;
