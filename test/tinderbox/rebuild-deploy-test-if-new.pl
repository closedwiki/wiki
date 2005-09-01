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
use Pod::Usage;
use LWP::Simple;

use constant BUILD_LOCK => '.build';
use constant LAST_BUILD => '.last_build';

my $Config = {
    force => 0,
# 
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

my $result = GetOptions( $Config,
#
			 'force|f',
# miscellaneous/generic options
			'help', 'man', 'debug', 'verbose|v',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
print STDERR Dumper( $Config ) if $Config->{debug};

# make easy to work as a crontab job
chdir( $FindBin::Bin );

# bail early (as early as possible) if we're already doing a build
exit 0 if -e BUILD_LOCK;

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
    open( LOCK, ">", BUILD_LOCK ) or die $!;
    print LOCK "$rev\n";
    close( LOCK );

#    system( 'svn cleanup ../..' );

    system( './doit.pl' );
    # SMELL: switch to exceptions
    if ( $? == 0 )
    {
	my $wikiPage = LWP::Simple::get( 'http://tinderbox.wbniv.wikihosting.com/cgi-bin/twiki/view.cgi/TWiki/WebHome' );
	if ( defined $wikiPage )
	{   # mark build complete
	    rename BUILD_LOCK, LAST_BUILD;
	}
	else
	{   # try again next crontab iteration
	    unlink BUILD_LOCK;
	}
    }
    else
    {   # try again next crontab iteration
	unlink BUILD_LOCK;
    }
}

exit 0;

################################################################################
################################################################################

__DATA__
=head1 NAME

rebuild-deploy-test-if-new.pl - 

=head1 SYNOPSIS

rebuild-deploy-test-if-new.pl [options]

crontab-compatible script used to perform the following:

   * run the (unit) tests
   * build a new twiki kernel
   * build a new distribution
   * publish the distribution
   * install the distribution
   * run the (golden html) tests
   * post the test results to tinderbox.wbniv.wikihosting.com

Copyright 2005 Will Norris.  All Rights Reserved.

 Options:
   -force                       force a new build, test, and install procedure even if current
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=back

=head1 DESCRIPTION


=head2 SEE ALSO

=cut
