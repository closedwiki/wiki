# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Vadim Belman, voland@lflat.org
# Copyright (C) 2009 TWiki:Main.ThomasWeigert
# Copyright (C) 2009-2011 TWiki Contributors. All Rights Reserved.
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
package TWiki::Contrib::DatabaseContrib;
use strict;

use DBI;
# use Error qw(:try);
use CGI qw(:html2);
use Carp qw(longmess);

## Do not use Error right now, but this makes sometimes confusing error
## messages, as the connection failure might not be apparent as the
## error trickles up.

# =========================

use vars qw( $initialized %dbi_connections $dieOnFailure );

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = '2011-03-13';

$SHORTDESCRIPTION = 'Set up connection to database through DBI.';

use Exporter;
our (@ISA, @EXPORT);
@ISA=qw(Exporter);

@EXPORT = qw( db_connect db_disconnect db_connected db_allowed );


# =========================

sub warning
{
    return TWiki::Func::writeWarning( @_);
}

# =========================
sub init
{
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.000 ) {
        warning( "Version mismatch between DatabaseContrib.pm and Plugins.pm" );
        return 0;
    }

    my $cfg_file = $TWiki::cfg{Plugins}{DatabaseContrib}{connections};
    unless ($cfg_file) {
	warning "No connections defined.";
	return 0;
    }
    $cfg_file = "( $cfg_file , );";
    %dbi_connections = eval $cfg_file;

    $dieOnFailure = 0;

    # Contrib correctly initialized
    return 1;
}

sub failure
{
    my $msg = shift;
    if ($dieOnFailure) {
	die $msg;
    } else {
	return 1;
    }
}

# =========================

sub db_connected
{
    unless ($initialized) {
	init;
	$initialized = 1;
    }

    my ($conname) = @_;

    return (defined $dbi_connections{$conname})?1:0;
}

sub db_set_codepage
{
    my $conname = shift;
    my $connection = $dbi_connections{$conname};
    if ($connection->{codepage}) {
	# SETTING CODEPAGE $connection->{codepage} for $conname\n";
	if ($connection->{driver} =~ /^(mysql|Pg)$/) {
	    $connection->{dbh}->do("SET NAMES $connection->{codepage}");
	    $connection->{dbh}->do("SET CHARACTER SET $connection->{codepage}")
		if $connection->{driver} eq 'mysql';
	}
    }
}

sub find_allowed
{
    my ($allow) = @_;

    my $curUser = TWiki::Func::getWikiUserName();
    my $users = $TWiki::Plugins::SESSION->{users};
    my $found = 0;
    my $allowed;
    foreach my $entity (@$allow) {
	$allowed = $entity;
	# Checking for access of $curUser within $entity
	if ($users->isGroup($entity)) {
	    # $entity is a group
	    $found = userIsInGroup($curUser, $entity);
	} else {
	    $entity = TWiki::Func::userToWikiName(TWiki::Func::wikiToUserName($entity), 0);
	    $found = ($curUser eq $entity);
	}
	last if $found;
    }
    return $allowed if $found;
    return;
}

sub db_allowed
{
    my ($conname, $section) = @_; 
    my $connection = $dbi_connections{$conname};

    $section = "default" unless defined($connection->{allow_do}) && defined($connection->{allow_do}{$section});
    my $allow = defined($connection->{allow_do}) && defined($connection->{allow_do}{$section}) && ref($connection->{allow_do}{$section}) eq 'ARRAY' ?
	$connection->{allow_do}{$section} :
	[];
    my $allowed = find_allowed($allow);
    return defined $allowed;

}

sub userIsInGroup
{
    my ($user, $group) = @_;
    if ($TWiki::Plugins::VERSION < 1.1) {
	return TWiki::Access::userIsInGroup($user, $group);
    } else {
	my $users = $TWiki::Plugins::SESSION->{users};
	my $userObj = $users->findUserByWikiName($user);
	return 0 unless defined $userObj;
 	return $users->isInList($userObj->[0], $group);
    }
}

sub db_connect
{
    unless ($initialized) {
	init;
	$initialized = 1;
    }

    my $conname = shift;
    my $connection = $dbi_connections{$conname};
    my @required_fields = qw(database driver);

    unless (defined $connection->{dsn}) {
	foreach my $field (@required_fields) {
	    unless (defined $connection->{$field}) {
		return if failure "Required field $field is not defined for database connection $conname.\n";
	    }
	}
    }

    my ($dbuser, $dbpass) = ($connection->{user} || "", $connection->{password} || "");

    if (defined($connection->{usermap})) {
	my @maps = sort {($a =~ /Group$/) <=> ($b =~ /Group$/)} keys %{$connection->{usermap}};

	my $allowed = find_allowed(\@maps);
	if ($allowed) {
	    $dbuser = $connection->{usermap}{$allowed}{user};
	    $dbpass = $connection->{usermap}{$allowed}{password};
	}
    }

    unless ($dbuser) {
	return if failure "User is not allowed to connect to database";
    }

    # CONNECTING TO $conname, ", (defined $connection->{dbh} ? $connection->{dbh} : "*undef*"), ", ", (defined $dbi_connections{$conname}{dbh} ? $dbi_connections{$conname}{dbh} : "*undef*"), "\n";
    unless ($connection->{dbh}) {
	# CONNECTING TO $conname\n";
	my $server = $connection->{server} ? "server=$connection->{server};" : "";
	my $dsn;
	if (defined $connection->{dsn}) {
	    $dsn = $connection->{dsn};
	} else {
	    $dsn = "dbi:$connection->{driver}\:${server}database=$connection->{database}";
	    $dsn .= ";host=$connection->{host}" if $connection->{host};
	}
	my $dbh = DBI->connect(
	    $dsn, $dbuser, $dbpass,
	    {
		RaiseError => 1,
		PrintError => 1,
		FetchHashKeyName => NAME_lc =>
		@_
	    }
	);
	unless (defined $dbh) {
#	    throw Error::Simple("DBI connect error for connection $conname: $DBI::errstr");
	    return;
	}
	$connection->{dbh} = $dbh;
    }

    db_set_codepage($conname);

    if (defined $connection->{init}) {
	$connection->{dbh}->do($connection->{init});
    }

    return $connection->{dbh};
}

sub db_disconnect
{
    foreach my $conname (keys %dbi_connections) {
	if ($dbi_connections{$conname}{dbh}) {
	    $dbi_connections{$conname}{dbh}->commit
		unless $dbi_connections{$conname}{dbh}{AutoCommit};
	    $dbi_connections{$conname}{dbh}->disconnect;
	    delete $dbi_connections{$conname}{dbh};
	}
    }
}

1;
#
