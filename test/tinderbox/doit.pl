#! /usr/bin/perl -w
# Copyright 2005 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

# build a new twiki kernel
# build a new distribution
# install the distribution
# run the tests
# post the tests to tinderbox.wbniv.wikihosting.com

BEGIN {
    my $cpan = '/home/wbniv/tinderbox.wbniv.wikihosting.com/cgi-bin/lib/CPAN/';
    my @localLibs = ( "$cpan/lib", "$cpan/lib/arch" );
    unshift @INC, @localLibs;
}

#use Cwd qw( cwd );
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use WWW::Mechanize;
use WWW::Mechanize::TWiki 0.08;

my $Config = {
# 
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

my $result = GetOptions( $Config,
# miscellaneous/generic options
			'agent=s', 'help', 'man', 'debug', 'verbose|v',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
print STDERR Dumper( $Config ) if $Config->{debug};

my $TWIKIDEV = $ENV{TWIKIDEV};
die "must set environment variable TWIKIDEV" unless $TWIKIDEV;
	 
################################################################################

my $svnRev = 4000;

# build a new twiki kernel
system( 'bash' => '-c' => "cd ../.. && svn update" ) == 0 or die $!;
system( '../../tools/distro/build-twiki-kernel.pl', '--nogendocs', '--notar', '--outputdir' => "$TWIKIDEV/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/downloads/releases/" ) == 0 or die $!;

# build a new distribution
system( 'bash' => '-c' => "cd $TWIKIDEV/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/ && make distro" );

# install the distribution

# run the tests
`cp doit.pl report.txt`;	# for testing

# post the tests to tinderbox.wbniv.wikihosting.com
my $report = 'report.txt';
system( './report-test.pl','--svn' => $svnRev, '--report' => $report );

exit 0;

################################################################################
################################################################################

__DATA__
=head1 NAME

doit.pl - TWiki:Codev.DailyBuildAndSmokeTest

=head1 SYNOPSIS

doit.pl [options]

Copyright 2004, 2005 Will Norris and Sven Dowideit.  All Rights Reserved.

 Options:
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=back

=head1 DESCRIPTION


=head2 SEE ALSO

	http://twiki.org/cgi-bin/view/Codev/DailyBuildAndSmokeTest

=cut
