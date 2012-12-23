# ---+ Extensions
# ---++ TWikiGuestCacheAddOn

# **STRING**
# Comma-space delimited list of tier 1 topic names.
$TWiki::cfg{TWikiGuestCacheAddOn}{Tier1Topics} = 'WebAtom, WebChanges, WebRss';

# **STRING 10**
# Maximum cache age for tier 1 pages, in hours.
$TWiki::cfg{TWikiGuestCacheAddOn}{Tier1CacheAge} = '1';

# **STRING**
# Comma-space delimited list of tier 2 topic names.
$TWiki::cfg{TWikiGuestCacheAddOn}{Tier2Topics} = 'WebHome, WebTopicList';

# **STRING 10**
# Maximum cache age for tier 2 pages, in hours.
$TWiki::cfg{TWikiGuestCacheAddOn}{Tier2CacheAge} = '6';

# **STRING 10**
# Maximum cache age for all other pages, in hours.
$TWiki::cfg{TWikiGuestCacheAddOn}{CacheAge} = '48';

# **STRING**
# Path, command and parameters of wget command. Used to grab a
# rendered page for caching.
$TWiki::cfg{TWikiGuestCacheAddOn}{WgetCmd} = '/usr/bin/wget --user-agent=TWikiGuestCacheAddOn -
O';

# **BOOLEAN**
# Debug flag. See output in STDERR, e.g. apache error log.
$TWiki::cfg{TWikiGuestCacheAddOn}{Debug} = 0;

