#! /usr/bin/perl -w
use strict;
################################################################################
# latest-svn-checkin.pl - parses output returned by svnlog.xslt
# Copyright 2005 Will Norris.  All Rights Reserved.
# License: GPL
################################################################################

my ( $TWIKIDEV, $BRANCH );
	 
BEGIN {
    $TWIKIDEV = $ENV{TWIKIDEV};
    die "must set environment variable TWIKIDEV" unless $TWIKIDEV;

    $BRANCH = $ENV{BRANCH};
    die "must set environment varibale BRANCH" unless $BRANCH;

    my $cpan = "$TWIKIDEV/CPAN/";
    die "no cpan directory [$cpan]" unless -d $cpan;
    my @localLibs = ( "$cpan/lib", "$cpan/lib/arch" );
    unshift @INC, @localLibs;
}

use XML::RSS;
use LWP::Simple;

# Declare variables for URL to be parsed
my $url2parse;
# Get the command-line argument
my $arg = shift || 'http://develop.twiki.org/~develop/pub/svn2rss.xml';

# Create new instance of XML::RSS
my $rss = new XML::RSS;
# Get the URL, assign it to url2parse, and then parse the RSS content
$url2parse = get($arg);
die "Could not retrieve $arg" unless $url2parse;
$rss->parse($url2parse);

################################################################################

# find first (latest) non-blank entry
foreach my $item (@{$rss->{'items'}}) {
    next unless defined($item->{'title'});

    my ( $rev, $author ) = ( $item->{title} =~ /Revision\s+(\d+)\s+by\s+(.+)$/ );

    print "$rev", "\n";
    print quotify($author), "\n";
    last;
}

################################################################################

sub quotify
{
    my $str = shift;
    $str =~ s/'/\\'/g;
    return $str;
}

################################################################################
