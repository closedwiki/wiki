#! /usr/bin/perl -w
################################################################################
# download-twiki-contribs.pl
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL
#
# mirrors contribs locally from their distribution/topic pages
# prints out a report (suitable for inclusion as a twiki page)
#
################################################################################
use strict;
use diagnostics;
++$|;

BEGIN {
    use Cwd qw( cwd getcwd );
    use Config;
    my $localLibBase = getcwd() . "/lib/CPAN/lib/site_perl/" . $Config{version};
    unshift @INC, ( $localLibBase, "$localLibBase/$Config{archname}" );
}

################################################################################
# config
my $Config = {
    local_cache => 'downloads/contribs',
    twiki => {
	pub => 'http://twiki.org/p/pub',
    },
};

################################################################################

use LWP::Simple qw( mirror RC_OK RC_NOT_MODIFIED );
use File::Path qw( mkpath );
use HTML::TokeParser;

mkpath $Config->{local_cache} or die $! unless -d $Config->{local_cache};
my @errors;
my ( $nContribs, $nDownloadedContribs ) = ( 0, 0 );
my @contribs = getContribsCatalogList();

print "\n| *Contrib* | *Download Status* |";
foreach my $contribS ( @contribs )
{
    my $contrib = $contribS->{name} or die "no name?";

    print "\n| TWiki:Plugins.$contrib ";
    ++$nContribs;

    my $remote_uri = "$Config->{twiki}->{pub}/Plugins/$contrib/$contrib.zip";
    my $local_file = "$Config->{local_cache}/$contrib.zip";
    # download contrib
    my $status = mirror( $remote_uri, $local_file );

    if ($status == RC_OK) {
	++$nDownloadedContribs;
	print "| downloaded";
	$contribS->{file} = $local_file;
    } elsif ($status != RC_NOT_MODIFIED) {
	print "| $!: $remote_uri";
	push @errors, $contrib;
    } else {
	++$nDownloadedContribs;
	print "| updated";
#	$contribS->{file} = $local_file;
    }
    print " |";
}

# print summary results (suitable for inclusion as a TWiki page)
print "\n| *Contribs Processed* | $nDownloadedContribs/$nContribs |";
print "\n\n";
local $, = "\n   * TWiki:Plugins.";
print "Missing/Error contrib topics: ", @errors; 
print "\n";

use XML::Simple;
my $xs = new XML::Simple() or die $!;
open( XML, ">$Config->{local_cache}/contribs.xml" ) or die $!;
print XML $xs->XMLout( { contrib => [ @contribs ] }, NoAttr => 1 );
close( XML ) or warn $!;

################################################################################

sub getContribsCatalogList
{
    # get contribs catalog page
    my $contribsCatalogPage = LWP::Simple::get( qw( http://twiki.org/cgi-bin/search/Plugins/?scope=text&web=Plugins&order=topic&search=%5BT%5DopicClassification.*value%5C%3D%5C%22%5BC%5DontributedCode&casesensitive=on&regex=on&nosearch=on&nosummary=on&limit=all&skin=plain ) )
	|| LWP::Simple::get( "file:$Config->{local_cache}/TWikiContribs.html" )
	or die $!;

    # get list of contribs (from the links)
    my @contribs = qw();

    my $stream = new HTML::TokeParser( \$contribsCatalogPage ) or die $!;
    while ( my $tag = $stream->get_tag('a'))
    {
	next unless $tag->[1]{href} && $tag->[1]{href} =~ m|/view/Plugins/.+Contrib$|;
	my ( $contrib ) = $tag->[1]{href} =~ m|.+/(.+Contrib)|;
	next unless $contrib;
	push @contribs, {
	    name => $contrib,
	    description => "$contrib description",
	    homepage => "http://twiki.org/cgi-bin/view/Plugins/$contrib",
	};
    }

    return @contribs;
}

################################################################################
