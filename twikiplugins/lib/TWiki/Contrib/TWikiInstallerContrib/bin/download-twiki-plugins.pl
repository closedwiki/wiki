#! /usr/bin/perl -wT
################################################################################
# download-twiki-plugins.pl
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL
#
# mirrors plugins locally from their distribution/topic pages
# prints out a report (suitable for inclusion as a twiki page)
#
################################################################################
use strict;
use diagnostics;
++$|;

my $account;

BEGIN {
    chomp( $account = 'twiki' || `whoami` );
    unshift @INC, "/Users/$account/Sites/cgi-bin/lib/CPAN/lib/site_perl/5.8.4";
    unshift @INC, "/Users/$account/Sites/cgi-bin/lib/CPAN/lib/site_perl/5.8.4/darwin-thread-multi-2level";
    # TODO: use setlib.cfg (TWiki:Codev.SetMultipleDirsInSetlibDotCfg)
}

################################################################################
# config
my $Config = {
    local_cache => 'downloads/plugins',
    twiki => {
	pub => 'http://twiki.org/p/pub',
    },
};

################################################################################

use LWP::Simple qw( mirror RC_OK RC_NOT_MODIFIED );
use File::Path qw( mkpath );
use HTML::TokeParser;

mkpath $Config->{local_cache} or die $! unless -d $Config->{local_cache};
my ( @errors, $nPlugins, $nDownloadedPlugins );
my @plugins = getPluginsCatalogList();

print "\n| *Plugin* | *Download Status* |";
foreach my $pluginS ( @plugins )
{
    my $plugin = $pluginS->{name};

    print "\n| TWiki:Plugins.$plugin ";
    ++$nPlugins;

    my $remote_uri = "$Config->{twiki}->{pub}/Plugins/$plugin/$plugin.zip";
    my $local_file = "$Config->{local_cache}/$plugin.zip";
    # download plugin
    my $status = mirror( $remote_uri, $local_file );

    if ($status == RC_OK) {
	++$nDownloadedPlugins;
	print "| downloaded";
	$pluginS->{file} = $local_file;
    } elsif ($status != RC_NOT_MODIFIED) {
	print "| $!: $remote_uri";
	push @errors, $plugin;
    } else {
	++$nDownloadedPlugins;
	print "| updated";
#	$pluginS->{file} = $local_file;
    }
    print " |";
}

# print summary results (suitable for inclusion as a TWiki page)
print "\n| *Plugins Processed* | $nDownloadedPlugins/$nPlugins |";
print "\n\n";
local $, = "\n   * TWiki:Plugins.";
print "Missing/Error plugin topics: ", @errors; 
print "\n";

use XML::Simple;
my $xs = new XML::Simple() or die $!;
open( XML, ">$Config->{local_cache}/plugins.xml" ) or die $!;
print XML $xs->XMLout( { plugin => [ @plugins ] }, NoAttr => 1 );
close( XML ) or warn $!;

################################################################################

sub getPluginsCatalogList
{
    # get plugins catalog page
    my $pluginsCatalogPage = LWP::Simple::get( qw( http://twiki.org/cgi-bin/search/Plugins/?scope=text&web=Plugins&order=topic&search=%5BT%5DopicClassification.*value%5C%3D%5C%22%5BP%5DluginPackage&casesensitive=on&regex=on&nosearch=on&nosummary=on&limit=all&skin=plain ) ) ||
	LWP::Simple::get( "file:$Config->{local_cache}/TWikiPlugins.html" )
	or die $!;

    # get list of plugins (from the links)
    my @plugins = qw();

    my $stream = new HTML::TokeParser( \$pluginsCatalogPage ) or die $!;
    while ( my $tag = $stream->get_tag('a'))
    {
	next unless $tag->[1]{href} && $tag->[1]{href} =~ m|/view/Plugins/.+Plugin$|;
	my ( $plugin ) = $tag->[1]{href} =~ m|.+/(.+Plugin)|;
	next unless $plugin;
	push @plugins, { 
	    name => $plugin,
	    description => "$plugin description",
	    homepage => "http://twiki.org/cgi-bin/view/Plugins/$plugin",
	};
    }

    return @plugins;
}

################################################################################
