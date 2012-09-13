# ---+ Extensions
# ---++ ExternalLinkTrackerPlugin

# **BOOLEAN**
# Show a small external icon next to external links.
$TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{ExternalIcon} = 1;

# **BOOLEAN**
# Force authentication before redirect of external links.
# If not set and if a non-authenticated user follows an external link,
# he/she will be recorded as TWikiGuest. It does not need to be set if
# users are authenticated at all times on the TWiki site.
$TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{ForceAuth} = 1;

# **STRING 50**
# Group that defines who can see the external link tracker statistics 
# topic. Set to empty value to open it up to all. 
# Default: <tt>ExternalLinkAdminGroup</tt>
$TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{AdminGroup} = 'ExternalLinkAdminGroup';

# **BOOLEAN**
# Debug plugin. See output in data/debug.txt
$TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{Debug} = 0;

1;
