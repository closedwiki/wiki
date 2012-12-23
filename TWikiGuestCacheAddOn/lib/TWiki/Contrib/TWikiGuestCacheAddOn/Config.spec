# ---+ Extensions
# ---++ TWikiGuestCacheAddOn

# **STRING**
# Path, command and parameters of wget command. Used to grab a 
# rendered page for caching.
$TWiki::cfg{TWikiGuestCacheAddOn}{WgetCmd} = '/usr/bin/wget --user-agent=TWikiGuestCacheAddOn -O';

# **STRING 10**
# Maximum cache age for default pages, in hours.
$TWiki::cfg{TWikiGuestCacheAddOn}{CacheAge} = '48';

# **STRING 10**
# Maximum cache age for tier 1 pages, in hours.
$TWiki::cfg{TWikiGuestCacheAddOn}{Tier1CacheAge} = '6';

# **STRING**
# Comma-space delimited list of tier 1 topic names.
$TWiki::cfg{TWikiGuestCacheAddOn}{Tier1Topics} = 'WebHome, WebTopicList';

# **STRING 10**
# Maximum cache age for tier 2 pages, in hours.
$TWiki::cfg{TWikiGuestCacheAddOn}{Tier2CacheAge} = '1';

# **STRING**
# Comma-space delimited list of tier 1 topic names.
$TWiki::cfg{TWikiGuestCacheAddOn}{Tier2Topics} = 'WebAtom, WebChanges, WebRss';

# **BOOLEAN**
# Debug flag. See output in STDERR, e.g. apache error log.
$TWiki::cfg{TWikiGuestCacheAddOn}{Debug} = 0;

