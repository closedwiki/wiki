#!/usr/bin/perl -w
use strict;
use Data::Dumper qw( Dumper );
++$|;

# TODO:
#  * rewrite extension2url() in terms of CGI's query_form() (used in tools/test/TWikiTopic2TestCase.pl)
#  * change ( install_account, install_host, install_dir ) into an URI (i think it's URI)
#  * update man pod docs {grin}
#  * 

use File::Copy qw( cp mv );
use File::Basename qw( basename );
use Getopt::Long qw( :config bundling auto_version );
use Pod::Usage;
use WWW::Mechanize::TWiki 0.05;

$main::VERSION = '0.50';
my $Config = {
# TEST OPTIONS
    testweb => 'GameDev',
# BUILD OPTIONS
	platform => $^O,				# only darwin and sourceforge atm
	twikiplugins => '/Users/wbniv/twiki/twikiplugins',
	twikisync => 0,					# download latest versions of plugins, addons, etc from twiki.org	
# INSTALL OPTIONS
	# TODO: change to use a URI (?)
	install_account => 'twiki',
	install_host => 'localhost',
	install_dir => '~/Sites',
# HELP OPTIONS
	agent => basename( $0 ),
	verbose => 0,
    help => 0,
    man => 0,
   	debug => 0,
};
Getopt::Long::Configure( "bundling" );
my $result = GetOptions( $Config,
			'testweb=s', 'platform=s', 'twikiplugins=s', 'twikisync',
# plugin, addon, contrib
			'plugin=s@', 'addon=s@', 'contrib=s@',
# install_account, install_host, install_dir
# plugin, contrib, addon
			'verbose', 'help|?', 'man', 'debug',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};

$Config->{plugin} ||= [ qw( PerlDocPlugin 
		    FindElsewherePlugin InterwikiPlugin SpreadSheetPlugin TablePlugin TocPlugin 
		    SpacedWikiWordPlugin ChartPlugin 
		    TWikiReleaseTrackerPlugin
		   	) ];	#+ ActionTrackerPlugin BeautifierPlugin CalendarPlugin CommentPlugin SpacedWikiWordPlugin
$Config->{contrib} ||= [ qw( DistributionContrib ) ];	#+ AttrsContrib DBCacheContrib JSCalendarContrib TWikiShellContrib
$Config->{addon} ||= [ qw( GetAWebAddOn ) ];		#+ PluginBenchmarkAddOn
$Config->{_installer}->{dir} = "$Config->{twikiplugins}/lib/TWiki/Contrib/TWikiInstallerContrib/";
$Config->{_installer}->{TWikiReleases} = "$Config->{_installer}->{dir}/downloads/releases/";
print Dumper( $Config ) if $Config->{debug};

################################################################################

# build kernel
my $newDistro = BuildTWikiKernel({ %$Config }) or die;
cp( $newDistro, $Config->{_installer}->{TWikiReleases} ) or die $!;
# build twiki distribution
BuildTWikiDistribution({ %$Config }); 
# install reference version
PushRemoteTWikiInstall({ %$Config, kernel => 'TWiki20040901.tar.gz' });
# run test
TWikiTopics2TestCases({ %$Config });
# save web
GetAWeb({ %$Config, web => $Config->{testweb} });
# delete first install
UninstallTWiki({ %$Config });
# reinstall new version to be tested (with newly-saved test web)
PushRemoteTWikiInstall({ %$Config, kernel => $newDistro, testweb => "$Config->{testweb}.wiki.tar.gz", kernel => 'TWiki20040901.tar.gz' });
# compare rendered html
my $comparisonResults = RunComparisonTests({ %$Config });
print Dumper( $comparisonResults ) if $Config->{debug};
# make tml-style report page
my $textTopicReport = MakeComparisonTestsResultsReport({ %$Config, results => $comparisonResults });
print Dumper( $textTopicReport ) if $Config->{debug};
# post the results to the wiki
PostComparisonTestsResultsReport({ %$Config, text => $textTopicReport });
$Config->{isInstalled} = 1;

END {
	# final installation report
	WebBrowser({ url => "http://$Config->{install_host}/~$Config->{install_account}/cgi-bin/twiki/view/TWiki/TWikiInstallationReport" }) if $Config->{isInstalled};
}

################################################################################
sub logSystem
{
	print STDERR Dumper( \@_ ) if $Config->{debug};
	system( @_ );
}
################################################################################

sub PostComparisonTestsResultsReport
{
	my $parms = shift;
	print STDERR "PostComparisonTestsResultsReport: ", Dumper( $parms ) if $parms->{debug};
	my $text = $parms->{text} or die "no text?";
	die "no testweb" unless $parms->{testweb};

	my $agent = "TWikiInstaller: " . basename( $0 ) . ' [post comparison results]';
	my $mech = WWW::Mechanize::TWiki->new( agent => "$agent", autocheck => 1 ) or die $!;
	$mech->cgibin( "http://$parms->{install_host}/~$parms->{install_account}/cgi-bin/twiki" );

	my $topic = "$parms->{testweb}ComparisonsReport";
	$mech->edit( "TWiki.$topic" );
 
	$mech->field( text => $text );
	$mech->click_button( value => 'Save' );
}

################################################################################

sub MakeComparisonTestsResultsReport
{
	my $parms = shift;
	print STDERR "MakeComparisonTestsResultsReport: ", Dumper( $parms ) if $parms->{debug};
	my $results = $parms->{results} or die "no results?";
	die "no install_host" unless $parms->{install_host};
	die "no install_account" unless $parms->{install_account};

	my $textComparisonReport = qq[%TOC%\n\n];
	foreach my $result ( keys %$results )
	{
		$textComparisonReport .= "\n---++ $result\n";
		foreach my $topic ( @{$results->{$result}} )
		{
			$textComparisonReport .= qq{   * [[$topic->{topic}]] [<a href="http://$parms->{install_host}/~$parms->{install_account}/cgi-bin/twiki/view/?topic=$topic->{topic};test=compare">run</a>]\n};
		}
	}
	return $textComparisonReport;
}

################################################################################

sub RunComparisonTests
{
	my $parms = shift;
	print STDERR "RunComparisonTests: ", Dumper( $parms ) if $parms->{debug};
	my $iWeb = $parms->{testweb} or die "no testweb?";

    my $mech = WWW::Mechanize::TWiki->new( agent => "$parms->{agent} [testweb comparison]", autocheck => 1 ) or die $!;
    $mech->cgibin( "http://$parms->{install_host}/~$parms->{install_account}/cgi-bin/twiki" );

	my @topics = grep { !/^Web/ } $mech->getPageList( $iWeb );
	my $results;
	foreach my $topic ( @topics )
	{
		my $testTopic = "$iWeb.$topic";
		my $text = $mech->view( $testTopic, { skin => 'text', test => 'compare' } )->content();
		my $passOrFail = 
			$text =~ /TESTS FAILED/ && 'failed' ||
			$text =~ /TESTS PASSED/ && 'passed' ||
			'unknown';
		push @{$results->{$passOrFail}}, {
			topic => $testTopic,
			};
	}
	return $results;
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

sub UninstallTWiki
{
	my $parms = shift;
	print STDERR "UninstallTWiki: ", Dumper( $parms ) if $parms->{debug};
	die "install_account?" unless $parms->{install_account};
	die "install_host?" unless $parms->{install_host};
	die "install_dir?" unless $parms->{install_dir};
	
	die "no testweb?" unless $parms->{testweb};
	my $cmdUninstallWeb = $parms->{testweb} && "rm webs/local/$parms->{testweb}.wiki.tar.gz; rmdir webs/local; rmdir webs" || '';
	logSystem( qq{ssh $parms->{install_account}\@$parms->{install_host} "cd $parms->{install_dir}; ./un-twiki.sh; ./uninstall.sh; $cmdUninstallWeb"} );
}

################################################################################

sub GetAWeb
{
	my $parms = shift;
	print STDERR "GetAWeb: ", Dumper( $parms ) if $parms->{debug};
	my $install_account = $parms->{install_account} or die "install_account?";	
	my $web = $parms->{web} or die "web?";
	
	print "Retrieving web=[$web]\n" if $parms->{verbose};
    my $mech = WWW::Mechanize::TWiki->new( agent => "$parms->{agent} [testweb]", autocheck => 1 ) or die $!;
    $mech->cgibin( "http://$parms->{install_host}/~$parms->{install_account}/cgi-bin/twiki" );

    my $webOutput = "${web}testcases";

    my $getaweb = 'get-a-web';
    my $exportWeb = "$webOutput.tar";
    $mech->$getaweb( $exportWeb, { output => $exportWeb, gzip => 1, saveasweb => $web } );
###
    open( WEB, ">$exportWeb" ) or die $!;
    print WEB $mech->content() or die $!;
    close( WEB ) or warn $!;

    logSystem( gzip => $exportWeb );
###
    mv( "${exportWeb}.gz", $exportWeb = "${web}.wiki.tar.gz" ) or die $!;
}

################################################################################

sub TWikiTopics2TestCases
{ 
	my $parms = shift;
	print STDERR "TWikiTopics2TestCases: ", Dumper( $parms ) if $parms->{debug};	
	my $testweb = $parms->{testweb} or die "no testweb?";
	
    logSystem( './TWikiTopic2TestCase.pl' => "--web=$testweb" => '--verbose' => '--debug' );
}

################################################################################

sub PushRemoteTWikiInstall
{
	my $parms = shift;
	print STDERR "PushRemoteTWikiInstall: ", Dumper( $parms ) if $parms->{debug};
	my $kernel = $parms->{kernel} or die "no kernel?";
	my $dirInstaller = $parms->{_installer}->{dir} or die "no installer dir?";
	my $platform = $parms->{platform} or die "no platform?";

	die "no account?" unless $parms->{install_account};
	die "no host?" unless $parms->{install_host};
	die "no dir?" unless $parms->{install_dir};
	# TODO: handle testweb as an optional parameter
	die "no testweb?" unless $parms->{testweb};

	my $testweb = -e $parms->{testweb} ? $parms->{testweb} : "${dirInstaller}/webs/local/$parms->{testweb}.wiki.tar.gz";
	my $testweb_basename = basename( $testweb );

	# copy TWikiDistribution, $testweb to webs/local/
    logSystem( qq{scp ${dirInstaller}/twiki-${platform}.tar.bz2 $parms->{install_account}\@$parms->{install_host}:$parms->{install_dir}} );
    logSystem( qq{scp $testweb $parms->{install_account}\@$parms->{install_host}:$parms->{install_dir}} );
    logSystem( qq{ssh $parms->{install_account}\@$parms->{install_host} "cd $parms->{install_dir}; mkdir -p webs/local; mv $testweb_basename webs/local/"} );
    # run the install program ( pre-twiki.sh, install_twiki.cgi (with install options), post-twiki.pl )
	my $twiki_config = extensions2uri({ plugin => $Config->{plugin}, addon => $Config->{addon}, contrib => $Config->{contrib} });
#	warn "no (install) config" unless $parms->{install};
	print "twiki_config = [$twiki_config]\n" if $parms->{debug};
    logSystem( qq{ssh $parms->{install_account}\@$parms->{install_host} "cd $parms->{install_dir}; tar xjf twiki-${platform}.tar.bz2; time ./pre-twiki.sh; time curl 'http://$parms->{install_host}/~$parms->{install_account}/cgi-bin/install_twiki.cgi?${twiki_config};twiki=${kernel};install=install;localweb=$testweb_basename' -o 'TWikiInstallationReport.html'; ./post-twiki.pl"} );
}

################################################################################

sub BuildTWikiKernel
{
	my $parms = shift;
	print STDERR "BuildTWikiKernel: ", Dumper( $parms ) if $parms->{debug};

	print "Building a new TWikiKernel\n" if $parms->{verbose};
	chomp( my $newDistro = basename( (`./build-twiki-kernel.pl`)[-1] ) );		# last line output is the resultant distro tar file
	die "no TWikiKernel built?: [$newDistro]" unless $newDistro =~ /TWikiKernel-[^-]+-\d{8}.\d{6}.tar.gz/;
	print "Build complete: $newDistro\n";	

	return $newDistro;
}

################################################################################

sub BuildTWikiDistribution
{
	my $parms = shift;
	print STDERR "BuildTWikiDistribution: ", Dumper( $parms ) if $parms->{debug};

	my $platform = $parms->{platform} or die "platform?";
	my $dirInstaller = $parms->{_installer}->{dir} or die "no installer dir?";
	my $fullbuild = $parms->{twikisync} || 0;
	
	unlink "${dirInstaller}/twiki-${platform}.tar.bz2";
	print "Building a new TWikiDistribution\n" if $parms->{verbose};
#	unless ( canConnectToTwiki.org ) $fullBuild = 0;
	my $buildParms = $fullbuild ? 'distro' : "twiki-${platform}.tar.bz2";
	logSystem( qq{cd $dirInstaller ; make platform=\U$platform\E $buildParms} );
}

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

tests.pl - ...

=head1 SYNOPSIS

test.pl [options] [-testweb=] 
	[-platform=[$^O]] [-twikiplugins=] [-twikisync=[0]]
	[-install_account=[twiki]] [-install_host=[localhost]] [-install_dir=[~/Sites]]
	[-plugin=(...)] [-contrib=(...)] [-addon=(...)]
	[-verbose] [-help] [-man]

Copyright 2004 Will Norris.  All Rights Reserved.

  Test Options:
   -testweb=[GameDev]				...

  Build Options:
   -platform=[$^O]					(darwin|sourceforge)
   -twikiplugins=[/Users/wbniv/twiki/twikiplugins]
   -twikisync                       download latest versions of plugins, addons, etc from twiki.org	

  Install Options:
   -install_account=[twiki]
   -install_host=[localhost]
   -install_dir=[~/Sites]
   [-plugin ...]*
   [-contrib ...]*
   [-addon ...]*

  Miscellaneous Options:
   -verbose
   -help							this documentation
   -man								full docs

=head1 OPTIONS

=over 8

=item B<-platform=[$^O]>

=item B<-twikiplugins=[/Users/wbniv/twiki/twikiplugins]>

=item B<-twikisync=(0|1)>

=item B<-install_account=[twiki]>

=item B<-install_host=[localhost]>

=item B<-install_dir=[~/Sites]>

=item B<-plugin>

=item B<-contrib>

=item B<-addon>

=item B<-verbose>

=item B<-help>, B<-?>

=item B<-man>


=back

=head1 DESCRIPTION

B<test.pl> ...                                                                                                                                                                                                                                                                                                                                                                     

=head2 SEE ALSO

  http://twiki.org/cgi-bin/view/Codev/...

=cut
