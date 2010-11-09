#---+ Extensions
#---++ GoogleAnalyticsPlugin
# **BOOLEAN**
# Enable debugging (debug messages will be written to data/debug.txt)
$TWiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Debug} = 0;
# **STRING 30**
# Web Property ID, informally referred to as UA number, can be found by clicking the "check status" link in your Google Analytics account. Also referred to as "Google Site Key".
$TWiki::cfg{Plugins}{GoogleAnalyticsPlugin}{WebPropertyId} = '';
# **STRING 100**
# Comma-separated list of scripts in the bin directory where you want pages to be tracked. Script <code>view</code> is used for viewing topics, script <code>edit</code> for editing topics.<br />
# Use <code>*</code> as wildcard to enable tracking pages from all scripts.<br />
# Possible script names, by default provided by TWiki (more may be installed with extensions): <code>attach, changes, configure, edit, login, logon, manage, oops, preview, rdiff, rdiffauth, register, rename, resetpasswd, rest, save, search, statistics, test, update-develop-links, upload, view, viewauth, viewfile</code>.
$TWiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Scripts} = '*';
# **STRING 200**
# Comma-separated list of webs to track.<br />
# Use <code>*</code> as wildcard to enable tracking in all webs.
$TWiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Webs} = '*';
# **STRING 200**
# Comma-separated list of webs to <strong>not</strong> track.<br />
# Use <code>*</code> as wildcard to disable tracking in all webs. This setting overrides the <code>Enable</code> setting.
$TWiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Webs} = '';
# **STRING 200**
# Comma-separated list of users to track.<br />
# Use <code>*</code> as wildcard to enable tracking of everyone's visits.
$TWiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Enable}{Users} = '*';
# **STRING 200**
# Comma-separated list of users to <strong>not</strong> track. For instance, you might want to disable tracking visits from AdminUser.<br />
# Use <code>*</code> as wildcard to disabled tracking of everyone's visits. This setting overrides the <code>Enable</code> setting.
$TWiki::cfg{Plugins}{GoogleAnalyticsPlugin}{Tracking}{Disable}{Users} = '';
