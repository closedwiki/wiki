#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002,2003 Tait Cyrus, tait.cyrus@usa.net
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This plugin provides various database access routines.  Currently
# implimented features are:
#    %DATABASE_TABLE{description="table_description" headers="hdr1,hdr2,hdr3" columns="col1,col2,col3"}% 
#	Using the database information specified by 'table_description',
#	create a TWiki table that contains the contents of the specified
#	database
#
#	description	- Refers to the DatabasePlugin table (specified in
#			  the "DatabasePluginConfig" package
#	columns		- (optional) Defines the columns from the table
#			  matched by 'description'.
#			  NOTE: If columns is not defined, the default
#			  value used is '*'
#			  NOTE: columns CAN be '*' to get ALL columns from
#			  the table in the database.  In this case the
#			  plugin will auto-detect the column names using them
#			  when displaying the TWiki table (if 'headers' is
#			  not defined)
#	headers		- (optional) Defines the column header names to use
#			  when displaying the resulting table.  If not
#			  defined, the table column headers names will be
#			  the same as the column names.
#
#    %DATABASE_SQL_TABLE{description="table_description" command="..SQL COMMAND.." headers="hdr1,hdr2,hdr3"}% 
#	Using the database information specified by 'table_description',
#	and the specified SQL command, create a TWiki table that contains
#	the contents of the specified database
#	description	- Refers to the DatabasePlugin table (specified in
#			  the "DatabasePluginConfig" package
#	command		- Defines the SQL command to run on the table
#			  described by 'description'.
#			  NOTE: a trailing ';' is not needed since the
#			  plugin will add one for you.  Adding one yourself
#			  will not hurt anything though.
#	headers		- Defines the column header names to use when
#			  displaying the resulting table.
#
#    %DATABASE_REPEAT{description="table_description" columns="col1,col2,col3"}% .... user formating .... %DATABASE_REPEAT%
#	Using the database information specified by 'table_description',
#	extract the columns and substitute for user specified columns where
#	columns are represented using %column_name%
#
#	description	- Refers to the DatabasePlugin table (specified in
#			  the "DatabasePluginConfig" package
#	columns		- (optional) Defines the columns from the table
#			  matched by 'description'.
#			  NOTE: If columns is not defined, the default
#			  value used is '*'
#			  NOTE: columns CAN be '*' to get ALL columns from
#			  the table in the database.  In this case the
#			  plugin will auto-detect the column names using them
#			  when displaying the TWiki table (if 'headers' is
#			  not defined)
#
#    %DATABASE_SQL_REPEAT{description="table_description" command="..SQL COMMAND.." columns="col1,col2,col3"}% .... user formating .... %DATABASE_SQL_REPEAT%
#	Using the database information specified by 'table_description',
#	extract the columns and substitute for user specified columns where
#	columns are represented using %column_name%
#	description	- Refers to the DatabasePlugin table (specified in
#			  the "DatabasePluginConfig" package
#	command		- Defines the SQL command to run on the table
#			  described by 'description'.
#			  NOTE: a trailing ';' is not needed since the
#			  plugin will add one for you.  Adding one yourself
#			  will not hurt anything though.
#	columns		- (optional) Defines the columns from the table
#			  matched by 'description'.  Since the code doesn't
#			  know what columns the SQL command will return, we
#			  allow the user to tell us.
#			  NOTE: If columns is not defined, the default
#			  value used is all of the columns in the specified
#			  table.
#    %DATABASE_EDIT{description="table_description" display_text="Edit the above table"}%
#	Using the database information specified by 'table_description',
#	allow the user to edit the specified database.
#	description	- Refers to the DatabasePlugin table (specified in
#			  the "DatabasePluginConfig" package
#	display_text	- (optional) The HTML link text.  If not specified,
#			  defaults to 'edit'
#
# Variables:
#    $security_on	- if non-zero, then this plugin will NOT allow the
#    			  main DatabasePlugin database to be displayed
#    			  since it contains user names and clear text
#    			  passwords for other databases.

# =========================
package TWiki::Plugins::DatabasePlugin;

use DBI;
use DatabasePluginConfig;
use strict;

# =========================
use vars qw(
	$web $topic $user $installWeb $VERSION $debug $security_on
	$security_message $description %db_driver %db_name %db_sid %db_table
	%db_username %db_password %db_hostname
    );

$VERSION = '1.4';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between DatabasePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "DATABASEPLUGIN_DEBUG" );
    # Get plugin security flag
    $security_on = &TWiki::Func::getPreferencesFlag( "DATABASEPLUGIN_SECURITY" );
    # Get plugin security flag
    $security_message = &TWiki::Func::getPreferencesValue( "DATABASEPLUGIN_SECURITY_MESSAGE" );

    if ($DatabasePluginConfig::db_driver =~ m/local/i) {
	foreach my $info (@DatabasePluginConfig::dbinfo) {
	    my @info = @$info;
	    my $description		= $info[0];
	    $db_driver{$description}	= $info[1];
	    $db_name{$description}	= $info[2];
	    $db_sid{$description}	= $info[3];
	    $db_table{$description}	= $info[4];
	    $db_username{$description}	= $info[5];
	    $db_password{$description}	= $info[6];
	    $db_hostname{$description}	= $info[7];
	}
    } else {
	# Everything else is assumed to be the same as 'remote' Go to the
	# default database (specified in DatabasePluginConfig.pm) to obtain
	# secure information.  This is done so increase security by
	# minimizing the availability of clear text database passwords.
	my $sid = "";
	if ($DatabasePluginConfig::db_sid ne "") {
	    $sid = ";sid=$DatabasePluginConfig::db_sid"
	}
	my $db = DBI->connect("DBI:$DatabasePluginConfig::db_driver:database=$DatabasePluginConfig::db_database;host=$DatabasePluginConfig::db_hostname$sid", $DatabasePluginConfig::db_username, $DatabasePluginConfig::db_password, {PrintError=>1, RaiseError=>0});
	if (! $db ) {
	    return make_error("Can't open initialization DatabasePlugin database '$DatabasePluginConfig::db_database'");
	}
	my $cmd = "SELECT description, driver, db_name, db_sid, table_name, ro_username, ro_password, hostname FROM $DatabasePluginConfig::db_table";
	&TWiki::Func::writeDebug( "- TWiki::Plugins::DatabasePlugin [$cmd]") if $debug;
	my $sth = $db->prepare($cmd);
	$sth->execute;
	# Fill hashes with the database information.
	while (my @row = $sth->fetchrow_array()) {
	    $db_driver{$row[0]}		= $row[1];
	    $db_name{$row[0]}		= $row[2];
	    $db_sid{$row[0]}		= $row[3];
	    $db_table{$row[0]}		= $row[4];
	    $db_username{$row[0]}	= $row[5];
	    $db_password{$row[0]}	= $row[6];
	    $db_hostname{$row[0]}	= $row[7];
	}
	$db->disconnect();
    }
    &TWiki::Func::writeDebug( "- TWiki::Plugins::DatabasePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
# Given a list of TWiki variable args, parse out 'description' handling any
# error conditions
sub get_description {
    my ($args) = @_;
    my ($description);
    # Get the description (which maps to a DatabasePlugin entry)
    my $tmp = &TWiki::Func::extractNameValuePair( $args, "description" );
    if( defined $tmp && $tmp ne "" ) {
	$description = $tmp;
    } else {
	return (undef, "Required option 'description' not found");
    }
    if (! $db_driver{$description} ) {
	return (undef, "Database description \"$description\" not found");
    }
    return ($description, "");
}

# =========================
# Produce a TWiki table from the specified database
sub do_table {
    my ($args) = @_;
    my ($tmp, @columns, @headers);

    my ($description, $error) = get_description($args);
    return make_error($error) if (! defined($description));

    my $db_driver	= $db_driver{$description};
    my $database	= $db_name{$description};
    my $db_sid		= $db_sid{$description};
    my $user		= $db_username{$description};
    my $password	= $db_password{$description};
    my $table		= $db_table{$description};
    my $hostname	= $db_hostname{$description};

    # If the user is concerned about security, make sure that a request to
    # display the main DatabasePlugin is not allowed.
    if ($security_on &&
        ($DatabasePluginConfig::db_driver eq $db_driver) &&
        ($DatabasePluginConfig::db_database eq $database) &&
        ($DatabasePluginConfig::db_table eq $table)) {
	return $security_message;
    }

    # Define the columns in the associated table
    $tmp = &TWiki::Func::extractNameValuePair( $args, "columns" );
    if (! $tmp) {
	$tmp = "*";	# Default to '*' if columns not specified.
    }
    # Since columns might be '*', we need to get the column names that
    # will be returned by '*'.
    if ($tmp eq "*") {
	@columns = get_column_names($db_driver, $database, $db_sid, $hostname, $user, $password, $table);
    } else {
	@columns = split( /,\s*/, $tmp );
    }

    # See if the column headers is defined.  If not, then use the column
    # names as the column headers
    $tmp = &TWiki::Func::extractNameValuePair( $args, "headers" );
    if ($tmp) {
	@headers = split( /,\s*/, $tmp );
    } else {
	@headers = @columns;
    }

    my $sid = "";
    if ($db_sid ne "") {
	$sid = ";sid=$db_sid";
    }
    my $db = DBI->connect("DBI:$db_driver:database=$database;host=$hostname$sid", $user, $password, {PrintError=>1, RaiseError=>1});
    if (! $db ) {
	return make_error("Can't open database specified by description '$description'");
    }

    # Generate table header using the table column names
    my $line = "| ";
    for my $c (@headers) {
	$line .= "*$c* | ";
    }
    $line .= "\n";
    my $col = join(", ", @columns);
    my $cmd = "SELECT $col FROM $table";
    &TWiki::Func::writeDebug( "- TWiki::Plugins::DatabasePlugin [$cmd]") if $debug;
    my $sth = $db->prepare($cmd);
    $sth->execute;
    while (my @row = $sth->fetchrow_array()) {
	my $row = "| ";
	for my $c (@row) {
	    $c = "" unless $c;	# prevent 'uninitialized value' warnings
	    $row .= "$c | ";
	}
	$row =~ s/\r\n/<br>/g;
	$line .= "$row\n";
    }
    $db->disconnect();
    return $line;
}

# =========================
# Produce a TWiki table using a user specified SQL command.  Since we don't
# know what columns will be returned, we assume the user will define these
# using the 'columns' argument
sub do_sql_table {
    my ($args) = @_;
    my ($description, $error) = get_description($args);
    return make_error($error) if (! defined($description));

    # Since we don't know what columns will be returned by the users SQL
    # statement, we just need to know what headers to put onto of each of
    # teh columns.
    my $tmp = &TWiki::Func::extractNameValuePair( $args, "headers" );
    my @headers;
    if( defined $tmp && $tmp ne "" ) {
	@headers = split( /,\s*/, $tmp ) if( $tmp );
    } else {
	return make_error("Required option 'headers' not found");
    }

    # Get the SQL command
    $tmp = &TWiki::Func::extractNameValuePair( $args, "command" );
    my $command = $tmp if( defined $tmp && $tmp ne "" );

    my $db_driver	= $db_driver{$description};
    my $database	= $db_name{$description};
    my $db_sid		= $db_sid{$description};
    my $user		= $db_username{$description};
    my $password	= $db_password{$description};
    my $table		= $db_table{$description};
    my $hostname	= $db_hostname{$description};

    # If the user is concerned about security, make sure that a request to
    # display the main DatabasePlugin is not allowed.
    if ($security_on &&
        ($DatabasePluginConfig::db_driver eq $db_driver) &&
        ($DatabasePluginConfig::db_database eq $database) &&
        ($DatabasePluginConfig::db_table eq $table)) {
	return $security_message;
    }
    my $sid = "";
    if ($db_sid ne "") {
	$sid = ";sid=$db_sid";
    }
    my $db = DBI->connect("DBI:$db_driver:database=$database;host=$hostname$sid", $user, $password, {PrintError=>1, RaiseError=>1});
    if (! $db ) {
	return make_error("Can't open database specified by description '$description'");
    }
    my $cmd = "$command";
    &TWiki::Func::writeDebug( "- TWiki::Plugins::DatabasePlugin [$cmd]") if $debug;
    my $sth = $db->prepare($cmd);
    $sth->execute;
    # Generate table header using the 'headers' values for column names
    my $line = "| ";
    for my $c (@headers) {
	$line .= "*$c* | ";
    }
    $line .= "\n";
    while (my @row = $sth->fetchrow_array()) {
	my $row = "| ";
	for my $c (@row) {
	    $c = "" unless $c;	# prevent 'uninitialized value' warnings
	    $row .= "$c | ";
	}
	$row =~ s/\r\n/<br>/g;
	$line .= "$row\n";
    }
    $db->disconnect();
    return $line;
}

# =========================
# Produce a TWiki table from the specified database using the user
# specified formatting.  Columns names are specified using %name% where
# 'name' is any column name.
sub do_repeat {
    my ($args, $repeat_info) = @_;
    my ($tmp, @columns);

    my ($description, $error) = get_description($args);
    return make_error($error) if (! defined($description));

    my $db_driver	= $db_driver{$description};
    my $database	= $db_name{$description};
    my $db_sid		= $db_sid{$description};
    my $user		= $db_username{$description};
    my $password	= $db_password{$description};
    my $table		= $db_table{$description};
    my $hostname	= $db_hostname{$description};

    # If the user is concerned about security, make sure that a request to
    # display the main DatabasePlugin is not allowed.
    if ($security_on &&
        ($DatabasePluginConfig::db_driver eq $db_driver) &&
        ($DatabasePluginConfig::db_database eq $database) &&
        ($DatabasePluginConfig::db_table eq $table)) {
	return $security_message;
    }

    # Define the columns in the associated table
    $tmp = &TWiki::Func::extractNameValuePair( $args, "columns" );
    if (! $tmp) {
	$tmp = "*";	# Default to '*' if columns not specified.
    }
    # Since columns might be '*', we need to get the column names that
    # will be returned by '*'.
    if ($tmp eq "*") {
	@columns = get_column_names($db_driver, $database, $hostname, $user, $password, $table);
    } else {
	@columns = split( /,\s*/, $tmp );
    }

    my $sid = "";
    if ($db_sid ne "") {
	$sid = ";sid=$db_sid";
    }
    my $db = DBI->connect("DBI:$db_driver:database=$database;host=$hostname$sid", $user, $password, {PrintError=>1, RaiseError=>1});
    if (! $db ) {
	return make_error("Can't open database specified by description '$description'");
    }

    my $col = join(", ", @columns);
    my $cmd = "SELECT $col FROM $table";
    &TWiki::Func::writeDebug( "- TWiki::Plugins::DatabasePlugin [$cmd]") if $debug;
    my $sth = $db->prepare($cmd);
    $sth->execute;
    my $line;
    while (my @row = $sth->fetchrow_array()) {
	# Now for each row in the database, we attempt to perform any
	# column substitution that is found in the $repeat_info
	my $repeat_info_copy = $repeat_info;
	for my $index (0..@row) {
	    # Fix the info from the DB replacing newlines with <BR>
	    (my $fix = $row[$index]) =~ s/\r\n/<BR>/g;
	    $repeat_info_copy =~ s/%$columns[$index]%/$fix/g;
	}
	$line .= $repeat_info_copy;
    }
    $db->disconnect();
    return $line;
}

# =========================
# Produce a TWiki table from the specified database using the user
# specified SQL and the user specified formatting.  Columns names are
# specified using %name% where 'name' is any column name.
sub do_sql_repeat {
    my ($args, $repeat_info) = @_;
    my ($tmp, @columns);

    my ($description, $error) = get_description($args);
    return make_error($error) if (! defined($description));

    # Get the SQL command
    $tmp = &TWiki::Func::extractNameValuePair( $args, "command" );
    my $command = $tmp if( defined $tmp && $tmp ne "" );

    my $db_driver	= $db_driver{$description};
    my $database	= $db_name{$description};
    my $db_sid		= $db_sid{$description};
    my $user		= $db_username{$description};
    my $password	= $db_password{$description};
    my $table		= $db_table{$description};
    my $hostname	= $db_hostname{$description};

    # Define the columns in the associated table
    $tmp = &TWiki::Func::extractNameValuePair( $args, "columns" );
    if (! $tmp) {
	# If not defined, then get the list of columns the table actually
	# has.  We need to know this since all the user has specified is an
	# SQL command and we don't know what columns might exist.
	# NOTE: This assumes that the table columns are actually what is being
	# returned and not some other SQL type information that really doesn't
	# have anything to do with the specified table (db stats for example)
	@columns = get_column_names($db_driver, $database, $hostname, $user, $password, $table);
    } else {
	@columns = split( /,\s*/, $tmp );
    }

    # If the user is concerned about security, make sure that a request to
    # display the main DatabasePlugin is not allowed.
    if ($security_on &&
        ($DatabasePluginConfig::db_driver eq $db_driver) &&
        ($DatabasePluginConfig::db_database eq $database) &&
        ($DatabasePluginConfig::db_table eq $table)) {
	return $security_message;
    }

    my $sid = "";
    if ($db_sid ne "") {
	$sid = ";sid=$db_sid";
    }
    my $db = DBI->connect("DBI:$db_driver:database=$database;host=$hostname$sid", $user, $password, {PrintError=>1, RaiseError=>1});
    if (! $db ) {
	return make_error("Can't open database specified by description '$description'");
    }
    my $cmd = $command;
    &TWiki::Func::writeDebug( "- TWiki::Plugins::DatabasePlugin [$cmd]") if $debug;
    my $sth = $db->prepare("$cmd");
    $sth->execute;

    my $line;
    while (my @row = $sth->fetchrow_array()) {
	# Now for each row in the database, we attempt to perform any
	# column substitution that is found in the $repeat_info
	my $repeat_info_copy = $repeat_info;
	for my $index (0..@row) {
	    # Fix the info from the DB replacing newlines with <BR>
	    (my $fix = $row[$index]) =~ s/\r\n/<BR>/g;
	    $repeat_info_copy =~ s/%$columns[$index]%/$fix/g;
	}
	$line .= $repeat_info_copy;
    }
    $db->disconnect();
    return $line;
}

sub do_edit {
    my ($args) = @_;

    my ($description, $error) = get_description($args);
    return make_error($error) if (! defined($description));

    my $db_driver	= $db_driver{$description};
    my $database	= $db_name{$description};
    my $user		= $db_username{$description};
    my $password	= $db_password{$description};
    my $table		= $db_table{$description};
    my $hostname	= $db_hostname{$description};

    # If the user is concerned about security, make sure that a request to
    # display the main DatabasePlugin is not allowed.
    if ($security_on &&
        ($DatabasePluginConfig::db_driver eq $db_driver) &&
        ($DatabasePluginConfig::db_database eq $database) &&
        ($DatabasePluginConfig::db_table eq $table)) {
	return $security_message;
    }

    # Define the display text
    my $display_text = &TWiki::Func::extractNameValuePair( $args, "display_text" );
    if (! $display_text) {
	$display_text = "edit";
    }

    return "<a onClick=\"nw=window.open('$TWiki::scriptUrlPath/DatabasePluginEdit%SCRIPTSUFFIX%?database=$database&table=$table','edit','scrollbars,resizable,location');nw.focus(); return false;\" href='#'>$display_text</a>";
}

# =========================
# Go out to the specified database table and return the columns available
# in that table.
sub get_column_names {
    my ($db_driver, $database, $db_sid, $hostname, $user, $password, $table) = @_;
    my $sid = "";
    if ($db_sid ne "") {
	$sid = ";sid=$db_sid";
    }
    my $db = DBI->connect("DBI:$db_driver:database=$database;host=$hostname$sid", $user, $password, {PrintError=>1, RaiseError=>1});
    if (! $db ) {
	return "Can't open database specified by description '$description'";
    }
    my $cmd;
    if ($db_driver eq "Oracle") {
	$cmd = "SELECT COLUMN_NAME FROM all_tab_columns WHERE TABLE_NAME = '$table'";
    } else {
	$cmd = "DESCRIBE $table";
    }
    &TWiki::Func::writeDebug( "- TWiki::Plugins::DatabasePlugin [$cmd]") if $debug;
    my $sth = $db->prepare($cmd);
    $sth->execute;
    my @columns;
    while (my @row = $sth->fetchrow_array()) {
	push (@columns, $row[0]);
    }
    $db->disconnect();
    return @columns;
}

sub make_error {
    my ($msg) = @_;
    return "<font color=red>$msg</font>";
}

# =========================
sub commonTagsHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- TWiki::Plugins::DatabasePlugin [$_[0]]") if $debug;
    $_[0] =~ s/%DATABASE_TABLE{(.*)}%/&do_table($1)/eog;
    $_[0] =~ s/%DATABASE_SQL_TABLE{(.*)}%/&do_sql_table($1)/eog;
    $_[0] =~ s/%DATABASE_REPEAT{(.*?)}%(.*?)%DATABASE_REPEAT%/&do_repeat($1, $2)/seog;
    $_[0] =~ s/%DATABASE_SQL_REPEAT{(.*?)}%(.*?)%DATABASE_SQL_REPEAT%/&do_sql_repeat($1, $2)/seog;
    $_[0] =~ s/%DATABASE_EDIT{(.*)}%/&do_edit($1)/eog;
}

1;
