# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Pointwise, Inc and Mike Eggleston
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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

# =========================
package TWiki::Plugins::ParseTopicTablesPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
);

$VERSION = '1.001';
$RELEASE = '2010-11-10';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    &TWiki::Func::writeDebug("- TWiki::Plugins::ParseTopicTablesPlugin::initPlugin is OK") if $debug;

    # check for Plugins.pm versions
	if( $TWiki::Plugins::VERSION < 1 ) {
		&TWiki::Func::writeWarning("Version mismatch between ParseTopicTablesPlugin and Plugins.pm");
		return 0;
	}

	# Get plugin debug flag
	$debug = &TWiki::Func::getPreferencesFlag("PARSETOPICTABLESPLUGIN_DEBUG") || 0;

	# Plugin correctly initialized
	&TWiki::Func::writeDebug("- TWiki::Plugins::ParseTopicTablesPlugin::initPlugin( $web.$topic ) is OK")
			if $debug;

	return 1;
}


# =========================
sub commonTagsHandler
{
	### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

	&TWiki::Func::writeDebug("- ParseTopicTablesPlugin::commonTagsHandler( $_[2].$_[1] )")
			if $debug;

	$_[0] =~ s/%PARSETOPICTABLES\{([^,]+),([^}]+)\}%/&parseTopic($1, $2)/geo;
}

# =========================

# check permissions to read the given topic, parse the given topic creating a table
# whose columns are specified in the second argument
sub parseTopic {
	my $topic = shift;
	my $colsparm = shift;

	$colsparm =~ s/^\s+//o;
	$colsparm =~ s/\s+$//o;
	&TWiki::Func::writeDebug("- TWiki::Plugins::ParseTopicTablesPlugin::topic=$topic colsparm=$colsparm")
			if $debug;

	# does the user have permissions to read the requested topic?
	my $web = $topic;
	$web =~ s/\..*$//o;		# for the topic Main.Topic remove .Topic
	$topic =~ s/^.*\.//o;	# for the topic Main.Topic remove Main.
	$wikiUserName = &TWiki::Func::getWikiUserName();

	my $viewAccessOK = &TWiki::Func::checkAccessPermission('view', $wikiUserName, undef, $topic, $web);
	return "Permission denied to read the topic." unless $viewAccessOK;

	# generate the meta-data for the columns requested, needed for parsing
	my $idx = 0;
	my @colsarray = split(/\s*,\s*/o, $colsparm);
	my %colshash;
	map {$colshash{$_} = $idx++} @colsarray;
	$idx = $colsarray[0];				# the first column is the main column

	# does the topic exist, pull the topic, ignore the meta data
	my ($meta, $text) = &TWiki::Func::readTopic($web, $topic, undef);

	# loop through the text, ignore the meta data, create a hash of the requested columns
	my %values;
	my $hashkey;
	my @lines = split(/[\r\n]/o, $text);
	foreach my $line (@lines) {
		next unless $line =~ /^\|/o;		# skip unless is a row of a table
		my @a = split(/\s*\|\s*/o, $line);
		if(scalar(@a) != 2) {
			shift(@a) if $a[0] eq '';
			my $key = $a[0];
			$key =~ s/^\s+//o;
			$key =~ s/\s+$//o;
			my $val = $a[1];
			$val =~ s/^\s+//o;
			$val =~ s/\s+$//o;
			$val =~ s/<br>//oi;
			$val =~ s/\s*\\$/ [[$web.$topic#$hashkey][...]]/o;
			if(defined($colshash{$key})) {
				if($key eq $idx) {		# is this the index of the parsed table?
					$hashkey = $val;
				}
				# $idx = $key = 'hostname'
				# $colshash{$key} = $colshash{'hostname'} = 0
				# $val = 'urchin'
				# $hash{'hostname'}->[0] = 'urchin';
				#$values{$hashkey}->[$colshash{$key}] = $val;
				$values{$hashkey}->{$key} = $val;
			}
		}
	}

	# if anything was found and parsed, then generated a table
	my $table = "No tables parsed from $web.$topic";
	my @keys = sort(keys(%values));
	if(scalar(@keys) > 0) {
		# print the table headers
		$table = '%TABLE{sort="off"}%' . "\n";
		$table .= '| *' . join('* | *', @colsarray) . "* |\n";
		foreach my $key (@keys) {
			$table .= &genRow($values{$key}, \@colsarray) . "\n";
		}
	}
	$table .= "\n";

	# clean up
	undef %values;
	undef $text;
	undef @lines;
	undef @keys;

	# simply return a bunch of characters
	return $table;
}

# given a hash ref of values, an array ref of columnes return a string for TWiki
sub genRow {
	my $h = shift;			# hash ref of values
	my $a = shift;			# array ref of columns
	my $r = '|';			# start the row

	foreach my $col (@{$a}) {
		$r .= defined($h->{$col}) ? (' ' . $h->{$col} . ' |') : ' |';
	}

	return $r;
}

1;
