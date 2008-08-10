# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 Thomas Weigert
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

# =========================
package TWiki::Plugins::TracQueryPlugin;    

use DBI;

use strict;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $debug $RELEASE $pluginName
  %db $url $dbHost $dbName $dbUser $dbPasswd $dbPort $dbType );

$VERSION = '$Rev: 17316 (03 Aug 2008) $';
$RELEASE = 'TWiki 4.2';
$pluginName = "TracQueryPlugin";  # Name of this Plugin
$debug = 0;

%db = ();

# =========================
sub initPlugin
{
  ( $topic, $web, $user, $installWeb ) = @_;
  
  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
    return 0;
  }

  # Get plugin debug flag
  $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );
  $url = TWiki::Func::getPreferencesValue( "\U$pluginName\E_URL" ) || '';
  if ( $url =~ /\/$/ ) { $url =~ s/(.*?)\/$/$1/; }
  
  $dbType = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB} || 'SQLite';   # Trac data base (either SQLite or MySQL)
  $dbType = lc($dbType);
  $dbName = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB_NAME};   # Trac database name
  $dbHost = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_HOST} || '';   # Trac database host
  $dbPort = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB_PORT};   # Trac database name
  $dbUser = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_USER} || '';  # user who has access to $dbName database
  $dbPasswd = $TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_PASSWD} || '';     # password for $dbUser

  TWiki::Func::registerTagHandler( 'TRAC', \&handleQuery,
                                     'context-free' );

  # Plugin correctly initialized
  TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

# =========================

sub handleQuery
{
  my ($session, $attributes, $topic, $web) = @_;

  my $webName = $session->{webName};
  my $topicName = $session->{topicName};

  my $format = $attributes->{format} || TWiki::Func::getPreferencesValue( "\U$pluginName\E_FORMAT" ) || "| \$id | \$severity | \$priority | \$status | \$reporter | \$component | \$description |";
  
  my $table = $attributes->{"_DEFAULT"} || 'ticket';
  my $separator = $attributes->{separator};
  my $newline = $attributes->{newline} || "\n";
  my $limit = $attributes->{limit} || 0;
  my $custom = '';
  my @cfields = ();

  if ( $table eq 'ticket' ) {
    $custom = TWiki::Func::getPreferencesValue( "\U$pluginName\E_CUSTOM" ) || '';
    @cfields = split('\s*,\s*', $custom);
  }

  $attributes->remove($TWiki::Attrs::RAWKEY);
  $attributes->remove($TWiki::Attrs::DEFAULTKEY);
  $attributes->remove('format');

  my $sqldb = openDB(%db);
  return unless $sqldb;

  my $statement = "SELECT *";
  if ( @cfields ) {
    # make a renaming for every custom field
    my $cnt = 0;
    foreach ( @cfields ) {
      $statement .= ", c$cnt.value AS $_";
      $cnt++;
    }
  }
  $statement .= " FROM $table";
  if ( @cfields ) {
    # make a join for every custom field
    # SELECT *, c0.value AS test_one FROM ticket LEFT OUTER JOIN ticket_custom c0 ON (ticket.id = c0.ticket AND c0.name = 'test_one') LEFT OUTER JOIN ticket_custom c1 ON (ticket.id = c1.ticket AND c.name = 'test_two') WHERE ticket.id = '1' 
    my $cnt = 0;
    foreach ( @cfields ) {
      $statement .= " LEFT OUTER JOIN ticket_custom c$cnt ON ($table.id = c$cnt.ticket AND c$cnt.name = '$_')";
      $cnt++;
    }
  }
  my @keys = keys %{$attributes};
  $statement .= " WHERE " unless ( $attributes->isEmpty );
  my $i = 0;
  while ( my ( $key, $value ) = each %{$attributes} ) {
    my $j = 0;
    my @tmp = makeArray( $value );
    $statement .= "( " if ( $#tmp > 0 );
    foreach my $tvalue ( @tmp ) {
      #EXCEPTIONS
      # Here we would insert special code to look up in another table
      #        ( $tvalue, $key ) = getField( "name", "component", "description", $tvalue, "component" ) if ( $key eq "component" );
      #/EXCEPTIONS
      if ( $key eq "summary" ) {
	$statement .= "$table.$key GLOB '*$tvalue*' ";
      } elsif ( $key eq "description" ) {
	$statement .= "$table.$key GLOB '*$tvalue*' ";
      } elsif ( $key eq "keyword" ) {
	#Should we isolate single keywords?
	$statement .= "$table.key GLOB '*$tvalue*' ";
      } else {
	$statement .= "$table.$key = '$tvalue' ";
      }
      $statement .= "OR " if ( ( $j >= 0 ) && ( $j < $#tmp ) );
      $j++;
    }
    $statement .= ") " if ( $#tmp > 0 );
    $statement .= "AND " if ( ( $i >= 0 ) && ( $i < $#keys ) );
    $i++;
  }
  &TWiki::Func::writeDebug( "ST = $statement" ) if $debug;
  my $tmp = $sqldb->prepare($statement);
  return unless $tmp;
  $tmp->execute();

  my $result = '';
  while ( my $r = $tmp->fetchrow_hashref ) {
    my $row = $format;
    foreach my $field ( keys( %{$r} ) ) {
      my $value = $$r{$field};
      $value ||= '';
      # Here we would insert special code to look up in another table
      #	      ( $value, $field ) = getField( "description", "component", "name", $$row{$field}, "component" ) if ( $field eq "component" );
      $value = TWiki::Time::formatTime( $value ) if ( $field eq 'time' || $field eq 'changetime' || $field eq 'due' || $field eq 'completed' ) && $value;
      $value =~ s/\r?\n/%BR%/gos;

      $row =~ s/\$$field/$value/g;
    }
    $result .= "$row\n";
  }

  $sqldb->disconnect;
  return $result;

}

sub getField
{
  my ( $what, $table, $field, $value, $key ) = @_;
  my $sqldb = openDB(%db);
  my $statement = "SELECT $what FROM $table WHERE $field = '$value'";
	my $tmp = $sqldb->prepare( $statement );
  $tmp->execute();
  my @row = $tmp->fetchrow_array();
  $tmp->finish;
  $sqldb->disconnect();
  return ( $row[0], $key );
}

sub openDB
{

  my ( $this ) = @_;

  unless (defined($this->{DB})) {
    if ($dbType eq 'sqlite') {
      $this->{DB} = DBI->connect( "dbi:SQLite:dbname=$dbName", $dbUser, $dbPasswd, {PrintError=>1, RaiseError=>0} );
    } elsif ($dbType eq 'mysql') {
      my $host = '';
      $host .= ";host=$dbHost" if ( $dbHost ne '' );
      $host .= ";port=$dbPort" if ( $dbPort ne '' );
      $this->{DB} = DBI->connect("DBI:mysql:$dbName$host", $dbUser, $dbPasswd, {PrintError=>1, RaiseError=>0});
    }
  }
  ## TW: should we test for failure to connect to db?
  return $this->{DB};

}

sub makeArray
{
  my ( $str ) = @_;
  $str =~ s/\s//g;
  return split( /,/, $str );
}

1;
