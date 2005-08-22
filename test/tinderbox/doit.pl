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

my $TWIKIDEV;
	 
BEGIN {
    $TWIKIDEV = $ENV{TWIKIDEV};
    die "must set environment variable TWIKIDEV" unless $TWIKIDEV;

    my $cpan = "$TWIKIDEV/CPAN/";
    die "no cpan directory [$cpan]" unless -d $cpan;
    my @localLibs = ( "$cpan/lib", "$cpan/lib/arch" );
    unshift @INC, @localLibs;
}

use FindBin;
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

# check for prerequisites
my $prereq = {
    # base cpan requirements
    'ExtUtils::MakeMaker' => { },
    'Storable' => { },
    # build-twiki-kernel.pl dependencies
    'Cwd' => { },
    'File::Copy' => { },
    'File::Path' => { },
    'File::Spec::Functions' => { },
    'File::Find::Rule' => { },
    'File::Slurp' => { },
    'File::Slurp::Tree' => { },
    'LWP::UserAgent' => { },
    'Getopt::Long' => { },
    'Pod::Usage' => { },
    'LWP::UserAgent::TWiki::TWikiGuest' => { },

    'WWW::Mechanize::TWiki' => { version => '0.08' },
    'WWW::Mechanize' => { },

    'Apache::Htpasswd' => { },
};

if ( $Config->{debug} )
{
    print "Installed  Required  CPAN Module\n";
    while ( my ( $module, $value ) = each %$prereq )
    {
	eval "require $module";
	my $minVersion = $value->{version} || 0;
	my $moduleVersion = $module->VERSION || '';
	print sprintf("%-9s  %-8s  %s", $moduleVersion, ( $minVersion || '' ), $module );
	print "\tERROR!" unless ( $moduleVersion && $moduleVersion >= $minVersion );
	print "\n";
    }
}

################################################################################

chdir $FindBin::Bin;

chomp( my @svnInfo = `svn info .` );
die "no svn info?" unless @svnInfo;
my ( $svnRev ) = ( ( grep { /^Revision:\s+(\d+)$/ } @svnInfo )[0] ) =~ /(\d+)$/;

################################################################################
# build a new twiki kernel
system( 'bash' => '-c' => "cd ../.. && svn update" ) == 0 or die $!;
system( '../../tools/distro/build-twiki-kernel.pl', '--nochangelog', '--nogendocs', '--notar', '--outputdir' => "$TWIKIDEV/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/downloads/kernels/" ) == 0 or die $!;

################################################################################
# build a new distribution
system( 'bash' => '-c' => "cd $TWIKIDEV/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/ && make distro && scp twiki.tar.bz2 wbniv\@twikiplugins.sourceforge.net:/home/groups/t/tw/twikiplugins/htdocs/" );

################################################################################
# install the distribution

my $SERVER_NAME = 'tinderbox.wbniv.wikihosting.com';
my $DHACCOUNT = 'wbniv';
my $ADMIN = 'WillNorris';

# TODO: look into usefulness of --plugin=TWikiReleaseTrackerPlugin --contrib=DistributionContrib for testing purposes
system( 'bash' => '-c' => qq{$TWIKIDEV/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/bin/install-remote-twiki.pl --force --report --verbose --debug --install_account=$DHACCOUNT --administrator=$ADMIN --install_host=$SERVER_NAME --install_dir=/home/$DHACCOUNT/$SERVER_NAME --kernel=LATEST --addon=GetAWebAddOn --scriptsuffix=.cgi --cgiurl=http://$SERVER_NAME/cgi-bin} ) == 0 or die $!;

################################################################################

my $report = 'report.txt';

################################################################################
# run the tests
system( 'bash' => '-c' => qq{cd ../unit && perl ../bin/TestRunner.pl TWikiUnitTestSuite.pm >&../tinderbox/$report} );

################################################################################
# post the tests to tinderbox.wbniv.wikihosting.com
system( './report-test.pl','--svn' => $svnRev, '--report' => $report, 
	'--attachment' => "$SERVER_NAME-install.html",
);

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
