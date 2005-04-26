#!/usr/bin/perl -w
# Copyright 2004,2005 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );
++$|;

# TODO:
#  * convert command line parameters to URI's
#  * update man pod docs {grin}
#  * interactive/confirmation mode

BEGIN {
    my $dirHome = $ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7];
    $ENV{TWIKIDEV} ||= "$dirHome/twiki";
    eval qq{ use lib( "$ENV{TWIKIDEV}/CPAN/lib", "$ENV{TWIKIDEV}/CPAN/lib/arch" ) };
}

use File::Copy qw( cp mv );
use File::Basename qw( basename );
use Getopt::Long qw( :config bundling auto_version );
use Pod::Usage;
use WWW::Mechanize::TWiki 0.05;
use URI;

sub mychomp { chomp $_[0]; $_[0] }

$main::VERSION = '0.50';
my $Config = {
# INSTALL OPTIONS
	distro => undef,
    kernel => undef,
#    web => '',
	# TODO: change to use a URI (?)
	install_account => undef,
	install_host => undef,
	install_dir => undef,
	cgiurl => undef,
#
	scriptsuffix => '',
	perl => undef,
	report => 1,
#
	force => 0,
# HELP OPTIONS
	agent => basename( $0 ),
	verbose => 0,
    help => 0,
    man => 0,
   	debug => 0,
};
Getopt::Long::Configure( "bundling" );
my $result = GetOptions( $Config,
			'distro=s', 'kernel=s', 'web=s@',
			 'scriptsuffix=s', 'perl=s', 'cgiurl=s',
# plugin, addon, contrib
			'plugin=s@', 'addon=s@', 'contrib=s@',
# install_account, install_host, install_dir
			'install_account=s', 'install_host=s', 'install_dir=s', 'force|f!',
# plugin, contrib, addon
			'report!', 'verbose', 'help|?', 'man', 'debug', 'agent=s',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};

# generated config variables
$Config->{distro} = 'http://twikiplugins.sourceforge.net/twiki.tar.bz2';
$Config->{cgibin} = $Config->{install_dir} . "/cgi-bin";

# set defaults
$Config->{plugin} ||= [];	# qw( TWikiReleaseTrackerPlugin ) ];
$Config->{contrib} ||= [];	# qw( DistributionContrib ) ];
$Config->{addon} ||= [];	# qw( GetAWebAddOn ) ];
$Config->{web} ||= [];
print Dumper( $Config ) if $Config->{debug};

# check installation requirements
$Config->{cgiurl} =~ m|cgi-bin/?$| or die "cgiurl must end with 'cgi-bin' (feel free to send patches;-)";
$Config->{install_account} or die "no install_account?";
$Config->{install_host} or die "no install_host?";
$Config->{install_dir} or die "no install_dir?";
$Config->{distro} or die "no distro?";

################################################################################
# install 
PushRemoteTWikiInstall({ %$Config });
# mark installation as successful/completed, so that the report is generated
$Config->{isInstalled} = 1;

END {
	if ( $Config->{isInstalled} && $Config->{report} )
	{ # final installation report
	    WebBrowser({ url => URI->new( "$Config->{cgiurl}/twiki/view$Config->{scriptsuffix}/TWiki/TWikiInstallationReport" ) });
	}
}

################################################################################
sub logSystem
{
	print STDERR "logSystem: ", Dumper( \@_ ) if $Config->{debug};
	system( @_ );
}
################################################################################
sub WebBrowser
{
	my $parms = shift;
	print STDERR "WebBrowser: ", Dumper( $parms ) if $parms->{debug};
	my $url = $parms->{url} or die "url?";
	
	logSystem( firefox => $url );
}
################################################################################
################################################################################

sub PushRemoteTWikiInstall
{
	my $parms = shift;
	print STDERR "PushRemoteTWikiInstall: ", Dumper( $parms ) if $parms->{debug};

	my $distro = $parms->{distro} or die "no distro?";
	my $kernel = $parms->{kernel} or die "no kernel?";

	die "no install_account?" unless $parms->{install_account};
	die "no install_host?" unless $parms->{install_host};
	die "no install_dir?" unless $parms->{install_dir};

	my $SERVER_NAME = $Config->{install_host};

	if ( $Config->{force} )
	{	    
	    # CAUTION: erase an existing installation
	    logSystem(qq{ssh $Config->{install_account}\@$SERVER_NAME "cd $SERVER_NAME && chmod -R a+rwx . && rm -rf *"});
	}

	# untar the tarball from sourceforge.net, install prerequisite CPAN modules
	$Config->{verbose} &&
	    print "Downloading TWiki distribution and installing CPAN modules (this can take many minutes...)\n";
	logSystem( qq{ssh $Config->{install_account}\@$SERVER_NAME "cd $SERVER_NAME && wget -q http://twikiplugins.sourceforge.net/twiki.tar.bz2 -O - | tar xj && SERVER_NAME=$SERVER_NAME perl pre-twiki.pl >&pre-twiki.log </dev/null"} );

	# install the actual wiki and extensions
	$Config->{verbose} && print "Installing TWiki and TWikiExtensions\n";

	use URI;
	my $urlInstallWithConfig = URI->new( "$Config->{cgiurl}/install_twiki.cgi" );
	$urlInstallWithConfig->query_form({ 
		plugin => $parms->{plugin}, 
		addon => $parms->{addon}, 
		contrib => $parms->{contrib}, 
		localweb => $parms->{localweb},
		kernel => $parms->{kernel},
		scriptsuffix => $parms->{scriptsuffix},
		perl => $parms->{perl},
		cgibin => $parms->{cgibin},
		install => 'install',
	});
	$Config->{debug} && print "\n$urlInstallWithConfig\n";

	logSystem( qq{wget -O $SERVER_NAME-install.html "$urlInstallWithConfig"} );
#	logSystem( qq{curl --silent --show-error "http://$parms->{install_host}/cgi-bin/install_twiki.cgi?${twiki_config};twiki=${kernel};install=install' -o 'TWikiInstallationReport.html"} );
}

################################################################################
###############################################################################

__DATA__
=head1 NAME

install-remote-twiki.pl - fully automated network TWiki installation frontend

Copyright 2004,2005 Will Norris.  All Rights Reserved.

=head1 SYNOPSIS

install-remote-twiki.pl -kernel [-web ...]* -install_account -install_host -install_dir -force|-f [-plugin ...]* [-contrib ...]* [-addon ...]* [-report|-noreport] [-verbose] [-debug] [-help] [-man]

=head1 OPTIONS

=over 8

=item B<-distro [distro]>				TWikiDistribution filename (.tar.bz2)
    (hardwrired to use the latest development version from twikiplugins.sourceforge.net)

=item B<-kernel [kernel|LATEST]>			

=item B<-web [web]>					filename of web exported by TWiki:Codev.GetAWebAddOn

=item B<-install_account>				account name under which to install the wiki

=item B<-install_host>					hostname to install wiki on

=item B<-install_dir>					TWiki:Codev.TWikiRootDirectory

=item B<-cgiurl> 					.

=item B<-force|f>					Erase and overwrite an existing TWiki installation CAUTION!

=item B<-plugin>					name of plugin to install (eg, SpreadSheetPlugin, FindElsewherePlugin)

=item B<-contrib>					name of contrib module to install (eg, AttrsContrib, DistributionContrib)

=item B<-addon>						name of addon to install (eg, GetAWebAddOn)

=item B<-(no-)report>					control creation of TWiki.TWikiInstallationReport on the installed wiki

=item B<-verbose>					show the babblings of the machine

=item B<-debug>						even more output

=item B<-help>, B<-?>

=item B<-man>


=back

=head1 DESCRIPTION

B<install-remote-twiki.pl> ...                                                                                                                                                                                                                                                                                                                                                                     

=head2 SEE ALSO

  http://twiki.org/cgi-bin/view/Codev/...

=cut
