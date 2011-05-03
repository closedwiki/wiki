# ---+ Extensions
# ---++ AccessStatsPlugin
# **BOOLEAN**
# Debug plugin. See output in data/debug.txt
$TWiki::cfg{Plugins}{AccessStatsPlugin}{Debug} = 0;
# **STRING 50**
# Apache log directory
$TWiki::cfg{Plugins}{AccessStatsPlugin}{LogDirectory} = '/var/logs/httpd';
# **STRING 50**
# Name of log file
$TWiki::cfg{Plugins}{AccessStatsPlugin}{LogFileName} = 'access_log';
# **BOOLEAN**
# Enable regular expression search
$TWiki::cfg{Plugins}{AccessStatsPlugin}{EnableRegexSearch} = 0;
1;
