# Information in this file is intended for use by the DatabasePlugin.  It
# is assumed that the location of this file is such that it is NOT
# accessible from a browser or is in a location that can't be viewed from a
# browser.  This is done since it contains secure database access
# information.

package DatabasePluginConfig;

# Define the default information used by the DatabasePlugin specifying
# where to go to get the real information used by the DatabasePlugin.
$db_driver	= "mysql";
$db_database	= "db";
$db_username	= "table";
$db_password	= "password";
$db_table	= "DatabasePlugin";

$db_hostname	= "localhost";
$db_edit_prefix	= "https";
$db_edit_url	= "phpMyAdmin-2.2.2-rc1";

1;
