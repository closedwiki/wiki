#!/usr/bin/perl -w
use strict;
use Data::Dumper qw( Dumper );
++$|;

# TODO:
#  * rewrite extension2url() in terms of CGI's query_form() (used in TWikiTopic2TestCase.pl)
#  * change ( install_account, install_host, install_dir ) into an URI (i think it's URI)
#  * update man pod docs {grin}

use File::Copy qw( cp mv );
use File::Basename qw( basename );
use Getopt::Long qw( :config bundling auto_version );
use Pod::Usage;
use WWW::Mechanize::TWiki 0.05;

$main::VERSION = '0.50';
my $Config = {
# INSTALL OPTIONS
	distro => undef,
    kernel => undef,
#    web => '',
	# TODO: change to use a URI (?)
	install_account => 'twiki',
	install_host => 'localhost',
	install_dir => '~/Sites',
#	installurl = 'localhost/~twiki',
	report => 0,
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
# plugin, addon, contrib
			'plugin=s@', 'addon=s@', 'contrib=s@',
# install_account, install_host, install_dir
			'install_account=s', 'install_host=s', 'install_dir=s',
# plugin, contrib, addon
			'report!', 'verbose', 'help|?', 'man', 'debug', 'agent=s',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
die "no distro?" unless $Config->{distro};

$Config->{plugin} ||= [ qw( TWikiReleaseTrackerPlugin ) ];
$Config->{contrib} ||= [ qw( DistributionContrib ) ];
$Config->{addon} ||= [ qw( GetAWebAddOn ) ];
$Config->{web} ||= [ qw() ];
print Dumper( $Config ) if $Config->{debug};

################################################################################
# install 
PushRemoteTWikiInstall({ %$Config });
$Config->{isInstalled} = 1;

END {
	if ( $Config->{isInstalled} && $Config->{report} )
	{ # final installation report
		WebBrowser({ url => "http://$Config->{install_host}/~$Config->{install_account}/cgi-bin/twiki/view/TWiki/TWikiInstallationReport" })
	}
}

################################################################################
sub logSystem
{
	print STDERR Dumper( \@_ ) if $Config->{debug};
	system( @_ );
}
################################################################################
sub WebBrowser
{
	my $parms = shift;
	print STDERR "WebBrowser: ", Dumper( $parms ) if $parms->{debug};
	my $url = $parms->{url} or die "url?";
	
	logSystem( open => $url );
}
################################################################################
################################################################################

sub PushRemoteTWikiInstall
{
	my $parms = shift;
	print STDERR "PushRemoteTWikiInstall: ", Dumper( $parms ) if $parms->{debug};
	my $distro = $parms->{distro} or die "no distro?";
	my $kernel = $parms->{kernel} or die "no kernel?";

	die "no account?" unless $parms->{install_account};
	die "no host?" unless $parms->{install_host};
	die "no dir?" unless $parms->{install_dir};

	# copy TWikiDistribution
    logSystem( qq{scp $distro $parms->{install_account}\@$parms->{install_host}:$parms->{install_dir}} );
	# if web(s)
    logSystem( qq{ssh $parms->{install_account}\@$parms->{install_host} "mkdir -p $parms->{install_dir}/webs/local/"} );

	# copy webs to .../webs/local; create $parms->{localweb} for actual *installation* portion
	foreach my $web ( @{$parms->{web}} )
	{
		warn qq{web "$web" doesn't exist}, next unless -e $web;
	    logSystem( qq{scp $web $parms->{install_account}\@$parms->{install_host}:$parms->{install_dir}/webs/local/} );

		my $web_basename = basename( $web );
		push @{$parms->{localweb}}, $web_basename;
	}
	
    # run the install program ( pre-twiki.sh, install_twiki.cgi (with install options), post-twiki.pl )
	my $twiki_config = extensions2uri({ 
		plugin => $parms->{plugin}, 
		addon => $parms->{addon}, 
		contrib => $parms->{contrib}, 
		localweb => $parms->{localweb},
	});
#	warn "no (install) config" unless $parms->{install};
	print "twiki_config = [$twiki_config]\n" if $parms->{debug};
	my $distro_basename = basename( $distro );
    logSystem( qq{ssh $parms->{install_account}\@$parms->{install_host} "cd $parms->{install_dir}; tar xjf $distro_basename; time ./pre-twiki.sh; time curl --silent --show-error 'http://$parms->{install_host}/~$parms->{install_account}/cgi-bin/install_twiki.cgi?${twiki_config};twiki=${kernel};install=install' -o 'TWikiInstallationReport.html'; ./post-twiki.pl"} );
}

################################################################################
################################################################################
sub extensions2uri
{
    my $config = shift or die;

    my @config;
    foreach my $ext ( keys %$config )
    {
		push @config, join( ';', map { "${ext}=$_" } @{$config->{$ext}} );
    }
    return join( ';', @config );
}

################################################################################
###############################################################################

__DATA__
=head1 NAME

install-remote-twiki.pl - ...

=head1 SYNOPSIS

test.pl [options] --distro -kernel [-web]*
	[-install_account [twiki]] [-install_host [localhost]] [-install_dir=[~/Sites]]
	[-plugin ...]* [-contrib ...]* [-addon ...]*
	[-verbose] [-debug] [-help] [-man]

Copyright 2004 Will Norris.  All Rights Reserved.

  Install Options:
   -distro 
   -kernel						TWiki20040901.tar.gz
   -web []						...

   -install_account [twiki]
   -install_host [localhost]
   -install_dir [\~/Sites]
   [-plugin ...]*
   [-contrib ...]*
   [-addon ...]*
   
   --report, --no-report		report

  Miscellaneous Options:
   -verbose
   -debug
   -help						this documentation
   -man							full docs

=head1 OPTIONS

=over 8

=item B<-distro [distro]>

=item B<-kernel [kernel]>

=item B<-web [web]>

=item B<-install_account [twiki]>

=item B<-install_host [localhost]>

=item B<-install_dir [~/Sites]>

=item B<-plugin>

=item B<-contrib>

=item B<-addon>

=item B<--report>
=item B<--no-report>

=item B<-verbose>

=item B<-help>, B<-?>

=item B<-man>


=back

=head1 DESCRIPTION

B<install-remote-twiki.pl> ...                                                                                                                                                                                                                                                                                                                                                                     

=head2 SEE ALSO

  http://twiki.org/cgi-bin/view/Codev/...

=cut
