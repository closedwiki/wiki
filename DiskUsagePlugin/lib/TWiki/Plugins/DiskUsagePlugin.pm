#! perl -w
use strict;
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::DiskUsagePlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar $usedColour $unusedColour
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'DiskUsagePlugin';  # Name of this Plugin

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

    $usedColour = TWiki::Func::getPluginPreferencesValue("UNUSED") || "lightblue";
    $unusedColour = TWiki::Func::getPluginPreferencesValue("UNUSED") || "lightcyan";


    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub logSizes {
    my $debugSize = -s $TWiki::debugFilename;
    my $warningSize = -s $TWiki::warningFilename;

    return "   * Debug log is $debugSize\n".
           "   * Warning log is $warningSize\n";
} 


sub diskusage {
    my $web = TWiki::Func::extractNameValuePair( @_, "web" );
    $web =~ s/\W//go;
    TWiki::Func::writeDebug( "- ${pluginName}::diskusage($web)" ) if $debug;

    my $dd = TWiki::Func::getDataDir();
    my $cmd = "/usr/bin/du -k $dd/$web/*.txt 2>&1";

    my @lines = `$cmd`;
    my %usageByTopic;

    foreach my $line (@lines) {
      my ($kb, $file) = split /\s+/, $line;
      $topic = $file;
      $topic =~ s!$dd/(.*).txt!$1!;
      $topic =~ s!/!.!;
      $usageByTopic{$topic}{text} = $kb;
      my $sz = (-s "$file,v") || 0;
      $usageByTopic{$topic}{history} = $sz % 1024;
    }

    $cmd = "/usr/bin/du -k $TWiki::pubDir/$web/* 2>&1";

    @lines = `$cmd`;
    my %pubByTopic;

    foreach my $line (@lines) {
      my ($kb, $topic) = split /\s+/, $line;
      $topic =~ s!$TWiki::pubDir/(.*)!$1!;
      $topic =~ s!/!.!;
      $usageByTopic{$topic}{attachments} = $kb;
    }

    my $ans = "| *Topic* | *Topic (Kb)* | *History (Kb)* | *Attachments (Kb)* | *Total (Kb)*| \n";
    my @topics = sort keys %usageByTopic;
    foreach my $topic (@topics) {
       my $lineTotal = $usageByTopic{$topic}{text} + 
		+ $usageByTopic{$topic}{history} +
		+ $usageByTopic{$topic}{attachments};
       $ans .= "| $topic |  ". $usageByTopic{$topic}{text} 
             ."|  ". $usageByTopic{$topic}{history}
             ."|  ". $usageByTopic{$topic}{attachments} 
             ."|  ". $lineTotal . "|\n";
    }

    return $ans;
}

sub quotaData {
    my $cmd = "/usr/bin/quota -v 2>&1";

    my @lines = `$cmd`;
    my $lastLine = $lines[$#lines];
    my @fields = split /\s+/, $lastLine;
    return ($fields[2], $fields[3]);
}

sub quotaString {
    my ($blocks, $quota) = quotaData();
    return "$blocks of $quota";
}

sub quotaPercentage {
    my ($blocks, $quota) = quotaData();
    return $blocks / $quota;
}


sub quotaGraph {
    my $length = quotaPercentage() * 100;
    return "<TABLE WIDTH=100 CELLSPACING=0 CELLPADDING=0><TR><TD BGCOLOR=$usedColour WIDTH='$length'></TD><TD bgcolor=$unusedColour>&nbsp;</TD><TR></TABLE>"

}
sub quota {
   return quotaGraph(). " ".quotaString(); 
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $web = $_[2];
    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%DISKUSAGE%/&diskusage("web=\"$web\"")/ge;
    $_[0] =~ s/%DISKUSAGE{(.*?)}%/&diskusage($1)/ge;

    $_[0] =~ s/%QUOTA%/&quota()/ge;
    $_[0] =~ s/%LOGSIZES%/&logSizes()/ge;
}

# =========================

1;
