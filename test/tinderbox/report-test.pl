#! /usr/bin/perl -w
# Copyright 2005 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

BEGIN {
    my $cpan = '/home/wbniv/tinderbox.wbniv.wikihosting.com/cgi-bin/lib/CPAN/';
    my @localLibs = ( "$cpan/lib", "$cpan/lib/arch" );
    unshift @INC, @localLibs;
}

use Cwd qw( cwd );
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use WWW::Mechanize;
use WWW::Mechanize::TWiki 0.08;

my $Config = {
    svn => undef,
    report => undef,
    attachment => [],
# 
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

my $result = GetOptions( $Config,
#
			 'svn=i', 'report=s', 'attachment=s@',
# miscellaneous/generic options
			'agent=s', 'help', 'man', 'debug', 'verbose|v',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
print STDERR Dumper( $Config ) if $Config->{debug};
	 
die "svn is a required parameter" unless $Config->{svn};
die "report is a required parameter" unless $Config->{report};
die "no report '$Config->{report}'?" unless -e $Config->{report};

################################################################################

my $agent = "TWikiTestInfrastructure: " . File::Basename::basename( $0 );
my $mech = WWW::Mechanize::TWiki->new( agent => "$agent", autocheck => 1 ) or die $!;
$mech->cgibin( 'http://ntwiki.ethermage.net/~develop/cgi-bin' );

my $topic = "Tinderbox.TestsReportSvn$Config->{svn}";

$mech->edit( "$topic", { 
    topicparent => 'WebHome', 
    templatetopic => 'TestReportTemplate',
    formtemplate => 'TestReportForm',
} );
$mech->click_button( value => 'Save' );

$mech->follow_link( text => 'Attach' );
$mech->submit_form( fields => {
    filepath => $Config->{report},
    filecomment => `date`,
    hidefile => undef,
} );

foreach my $attachment ( @{$Config->{attachment}} )
{
    print $attachment, "\n";
#    print Dumper( $attachment ), "\n";
    $mech->follow_link( text => 'Attach' );
    $mech->submit_form( fields => {
	filepath => $attachment,
	filecomment => `date`,
	hidefile => undef,
    } );
}

exit 0;

################################################################################
################################################################################

__DATA__
=head1 NAME

report-test.pl - Codev.

=head1 SYNOPSIS

kernel-manifest.pl [options]

Copyright 2004, 2005 Will Norris and Sven Dowideit.  All Rights Reserved.

 Options:
   -svn
   -report
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=back

=head1 DESCRIPTION


=head2 SEE ALSO

	http://twiki.org/cgi-bin/view/Codev/TWikiTestInfrastructure

=cut
