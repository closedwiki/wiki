# Information in this file is intended for use by the DatabasePlugin.  It
# is assumed that the location of this file is such that it is NOT
# accessible from a browser or is in a location that can't be viewed from a
# browser.  This is done since it contains secure database access
# information.

package DatabasePluginConfig;

$ENV{ORACLE_HOME} = "/usr/local/oracle/product/8.1.7";

# Define the default information used by the DatabasePlugin specifying
# where to go to get the real information used by the DatabasePlugin.
$db_driver	= "Local";
$db_database	= "";
$db_sid		= "";
$db_username	= "";
$db_password	= "";
$db_table	= "";

$db_hostname	= "";
$db_edit_prefix	= "https";
$db_edit_url	= "phpMyAdmin-2.2.2-rc1";

# Master database information if $db_driver = 'local' 
# The fields are:
#     description	= This field acts as the look-up mechanism for the
#     			  indirection. A TWiki page would reference this
#     			  name instead of having to publicly specify user
#     			  names, passwords, etc.
#     db_driver		= values like: mysql, Oracle, etc.
#     db_name		= DB name
#     db_sid		= SID of database
#     db_table		= table user data is located in
#     db_username	= username to access table
#     db_password	= password to access table
#     db_hostname	= host on which the DB lives
@dbinfo = (
    [
    "YourDescription",		# description
    "Oracle",			# DB driver
    "DB",			# DB name
    "mySID",			# DB sid
    "Table",			# DB table
    "name",			# DB username
    "pw",			# DB password
    "host.domain"		# DB host
    ] 
);

1;
