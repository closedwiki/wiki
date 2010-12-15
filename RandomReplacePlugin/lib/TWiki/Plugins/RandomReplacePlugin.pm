# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
package TWiki::Plugins::RandomReplacePlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
$web $topic $user $installWeb $VERSION $pluginName
$debug $includecomment
);

$VERSION = '1.021';
$pluginName = 'RandomReplacePlugin';  # Name of this Plugin
$rulesTopic = 'RandomReplaceRules'; #Name of default topic containing rules
$rulesTopicPreference = 'RANDOMREPLACERULESTOPIC'; #Name of preference containing alternate topic containing rules

$ruleNamePattern = '\s*([A-Z][A-Za-z0-9]+)\s*';
$ruleTypePattern = '\s*(Data|Topic|File)\s*';
$ruleDataPattern = '\s*([^|]+)\s+';

$resulthash = {Data => {}, Topic => {}, File => {}};

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
	TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
	return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
    $debug = 1;

    # Get plugin preferences, the variable defined by:  * Set EXAMPLE = ...
    $includecomment = TWiki::Func::getPluginPreferencesValue( "REPLACEONECOMMENT" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub beforeSaveHandler {
    ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010'
    if ($_[0] =~ m/##(\w+?)##/) {
	#Found a potential Tag.  Time to Initialize
	#Init done here to reduce overhead
	#This plugin used rarely and only on save

	#get rules topic
	my $replaceRulesTopic = TWiki::Func::getPluginPreferencesFlag( $rulesTopicPreference ) || "$installWeb.$rulesTopic";

        TWiki::Func::writeDebug( "- RulesTopic $replaceRulesTopic " ) if $debug;

	#get rules topic text
	my @data = split( /[\n\r]+/, TWiki::Func::readTopicText( $installWeb, $replaceRulesTopic, "", 1) );

	@data = grep { m/^\|$ruleNamePattern\|/} @data;

	my %rules;

	foreach my $ruletext (@data) {

            TWiki::Func::writeDebug( "- Rule: $ruletext" ) if $debug;
	    
	    my ($ruleName, $ruleType, $ruleData);
	    ($ruleName, $ruleType, $ruleData) = $ruletext =~
   	        m/^\|$ruleNamePattern\|$ruleTypePattern\|$ruleDataPattern\|/;
        
		TWiki::Func::writeDebug( "- $ruleName -> $ruleType -> $ruleData") if $debug;

	    if ($_[0] =~ m/##$ruleName##/) {
		$_[0] =~ s/##$ruleName##/&getText($ruleName,$ruleType,$ruleData,$replaceRulesTopic)/ge;
	    }
	}
    }
}


sub getText {
    my ($name,$type,$data,$rulestopic) = @_;
    my @results;
    if (exists($resulthash->{$type}->{$data})) {
	TWiki::Func::writeDebug(" - Resuing Data from $type & $data") if $debug;
	@results = @{$resulthash->{$type}->{$data}};
    }
    elsif ($type eq "Data") {
	#$data is colon seperated list
	@results = split /:/, $data;
	$resulthash->{$type}->{$data} = \@results;
    }
    elsif ($type eq "Topic") {
	#$data is topic name
	#Check to make sure that $data exists as topic
	#Check both current web and $data as we.topic string
	my ($dataWeb, $dataTopic);
	if ($data !~ /[.]/) {
	    $data = "$web.$data";
	}

	TWiki::Func::writeDebug("- Reading from Topic ->$data<-") if $debug;

	if (TWiki::Func::topicExists("",$data) ) {

	    @results = split /[\n\r]+/, TWiki::Func::readTopicText("",$data,"",1 );
	    @results = grep { m/^\s*\* / } @results;

	    for my $entry (@results) {
		$entry =~ s/^\s+\* //;
	    }
	}
	$resulthash->{$type}->{$data} = \@results;
    }
    elsif ($type eq "File") {
	#Data is file name located in attachement directory of Rules topic
	my $baseurl = TWiki::Func::getPubDir();
	$rulestopic =~ s/\./\//;
	my $datafilename = join "/", ($baseurl,$rulestopic,$data);

	TWiki::Func::writeDebug("- Reading file $datafilename") if $debug;

	@results = split /[\n\r]+/, TWiki::Func::readFile($datafilename);

	TWiki::Func::writeDebug("- First Line $results[0]") if $debug;
	@results = grep { m/^[^#]/ } @results;


	$resulthash->{$type}->{$data} = \@results;

    }

    my $result = $results[ int(rand(scalar(@results))) ];
    $result ||= "##$name##";
    if ($includecomment) {
	$result .= "<!-- generated with $pluginName using $name rule -->";
    }

    TWiki::Func::writeDebug("- ##$name## replaced with $result") if $debug;

    return $result;
}


1;
