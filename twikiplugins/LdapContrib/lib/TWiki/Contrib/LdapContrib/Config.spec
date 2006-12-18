# ---+ LDAP settings
# This is the configuration used by the <b>LdapContrib</b> and the
# <b>LdapNgPlugin</b>. Please have a look at the
# <a href="http://twiki.org/cgi-bin/view/Plugins/LdapContrib">your
# LdapContrib documentation</a> for more information.
#
# To use an LDAP server for authentication you have to use the LdapUser PasswordManager.
# Using groups defined in LDAP enable the LdapUserMapping UserMappingManager.
# (see the Security Setting section)

# ---++ General Settings
# **STRING**
# IP address (or hostname) of the LDAP server
$TWiki::cfg{Ldap}{Host} = 'my.domain.com';

# **NUMBER**
# Port used when binding to the LDAP server
$TWiki::cfg{Ldap}{Port} = 389;

# **NUMBER**
# Ldap protocol version to use when querying the server; 
# Possible values are: 2, 3
$TWiki::cfg{Ldap}{Version} = '3';

# **STRING**
# The base to be use in default searches
$TWiki::cfg{Ldap}{Base} = 'dc=my,dc=domain,dc=com';

# **STRING**
# The DN to use when binding to the LDAP server; if undefined anonymous binding
# will be used. Example 'cn=proxyuser,dc=my,dc=domain,dc=com'
$TWiki::cfg{Ldap}{BindDN} = '';

# **PASSWORD**
# The password used when binding to the LDAP server
$TWiki::cfg{Ldap}{BindPassword} = 'secret';

# **BOOLEAN**
# Negotiate ssl when binding to the server
# TODO: not implemented yet
$TWiki::cfg{Ldap}{SSL} = 0;

# ---++ User Settings
# The options below configure how TWiki will extract account records from LDAP.

# **STRING**
# The distinguished name of the users tree. All user accounts will
# be searched for in the subtree under BasePasswd.
$TWiki::cfg{Ldap}{BasePasswd} = 'ou=people,dc=my,dc=domain,dc=com';

# **STRING**
# The user login name attribute. This is the attribute name that is
# used to login.
$TWiki::cfg{Ldap}{LoginAttribute} = 'uid';

# **STRING**
# The user's wiki name attribute. This is the attribute to generate
# the WikiName from. 
$TWiki::cfg{Ldap}{WikiNameAttribute} = 'cn';

# **STRING**
# Filter to be used to find login accounts. Compare to GroupFilter below
$TWiki::cfg{Ldap}{LoginFilter} = 'objectClass=posixAccount';

# ---++ Group Settings
# The settings below configures the mapping and processing of LoginNames to WikiNames as
# well as the use of LDAP groups in TWiki. 
# In any case you have to select the LdapUserMapping as the UserMappingManager in the
# Security Section section above.

# **BOOLEAN**
# Enable use of LDAP groups in TWiki. If you switch this off the group-related settings
# below have no effect
$TWiki::cfg{Ldap}{MapGroups} = 0;

# **STRING**
# The distinguished name of the groups tree. All group definitions
# are used in the subtree under BaseGroup. 
$TWiki::cfg{Ldap}{BaseGroup} = 'ou=group,dc=my,dc=domain,dc=com';

# **STRING**
# This is the name of the attribute that holds the name of the 
# group in a group record.
$TWiki::cfg{Ldap}{GroupAttribute} = 'cn';

# **STRING**
# Filter to be used to find groups. Compare to LoginFilter.
$TWiki::cfg{Ldap}{GroupFilter} = 'objectClass=posixGroup';

# **BOOLEAN**
# Flag indicating wether we fallback to TWikiGroups. If this is switched on, 
# standard TWiki groups will be used as a fallback if a group definition of a given
# name was not found in the LDAP database.
$TWiki::cfg{Ldap}{TWikiGroupsBackoff} = 1;

# **STRING**
# The attribute that should be used to collect group members. This is the name of the
# attribute in a group record used to point to the user record. For example, in a possix setting this
# is the uid of the relevant posixAccount. If groups are implemented using the object class
# 'groupOfNames' the MemberAttribute will store a literal DN pointing to the account record. In this
# case you have to switch on the MemberIndirection flag below.
$TWiki::cfg{Ldap}{MemberAttribute} = 'memberUid';

# **BOOLEAN**
# Flag indicating wether the MemberAttribute of a group stores a DN. 
$TWiki::cfg{Ldap}{MemberIndirection} = 0;

# ---+++ Expert settings
# The following settings are used to optimize performance in your environment. Please take care.

# **NUMBER** 
# Refresh rate when the ldap cache is fetched from the LDAP server; 
# a value of -1 means unlimitted caching; 
# a value of 0 disables the cache; 
# default is -1. Note, that this will only take effect if you use a perl accelerator like speedy-cgi, mod-perl
# or fastcgi.
$TWiki::cfg{Ldap}{MaxCacheHits} = -1;

# **STRING 50**
# Prevent certain names from being looked up in LDAP
$TWiki::cfg{Ldap}{Exclude} = 'TWikiGuest, TWikiContributor, TWikiRegistrationAgent, TWikiAdminGroup, NobodyGroup';

# **NUMBER**
# Number of user objects to fetch in one paged result when building the username mappings;
# this is a speed optimization option, use this value with caution.
$TWiki::cfg{Ldap}{PageSize} = 200; 

# **BOOLEAN**
# Flag to remove non-wikiname chars in the WikiNameAttribute. 
# If the WikiNameAttribute is set to 'mail' a trailing @my.domain.com
# is stripped. WARNING: if you switch this off you have to garantee that the WikiNames
# in the WikiNameAttribute don't contain whitespaces at least.
$TWiki::cfg{Ldap}{NormalizeWikiNames} = 1;
