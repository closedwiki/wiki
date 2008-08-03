

# ---+ Plugins
# ---++ TracQueryPlugin
# to use the TracQueryPlugin, you need to set the following settings
# **STRING 25**
# Domain (and path) for the Trac UserId cookie (must be on the same domain and path TWiki is running from)
#  (value like http://twiki.org/cgi-bin - would presume that trac and twiki both are in the cgi-bin dir on a host ending with twiki.org)
# <ol><li>
# if set to '' (empty string), the {DefaultUrlHost} will be used
# </li></ol>
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DOMAIN} = '';
# **STRING 25**
# The path to the trac data base
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB_NAME} = '/path/to/trac/db/trac.db';
# **STRING 25**
# The user to connect to the Trac Database. (not required for SQLite)
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_USER} = '';
# **PASSWORD**
# The password to connect to the Trac Database. (not required for SQLite)
$TWiki::cfg{Plugins}{TracQueryPlugin}{DBI_password} = '';
