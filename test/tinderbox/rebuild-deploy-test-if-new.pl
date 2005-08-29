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

use FindBin;
use Cwd;
use Data::Dumper;
use Getopt::Long;

use constant BUILD_LOCK => '.build';
use constant LAST_BUILD => '.last_build';

my $Config = {
    force => 0,
};

my $result = GetOptions( $Config,
#
			 'force|f',
			);

# make easy to work as a crontab job
chdir( $FindBin::Bin );

my $buildInProgress = -x BUILD_LOCK;
exit if $buildInProgress;

chomp( my ( $rev, $author ) = `./latest-svn-checkin.pl` );

my $lastVersion = '';
if ( open( VERSION, LAST_BUILD ) )
{
    chomp( $lastVersion = <VERSION> );
    close( VERSION );
}

my $newVersionAvailable = !$lastVersion || ($rev > $lastVersion);
if ( $Config->{force} || $newVersionAvailable )
{
    # start new build
    open( LOCK, ">.build" ) or die $!;
    print LOCK "$rev\n";
    close( LOCK );

#    system( 'svn cleanup ../..' );

    system( './doit.pl' );
    if ($? == -1) {
	print "failed to execute: $!\n";
    }
    elsif ($? & 127) {
                       printf "child died with signal %d, %s coredump\n",
		       ($? & 127),  ($? & 128) ? 'with' : 'without';
                   }
    else {
	printf "child exited with value %d\n", $? >> 8;
    }

    # mark build complete
    rename BUILD_LOCK, LAST_BUILD;
}
