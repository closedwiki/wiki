#! /usr/bin/perl -w
################################################################################
# download-twiki-patches.pl
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL
#
# mirrors patchs locally from their distribution/topic pages
# prints out a report (suitable for inclusion as a twiki page)
#
# http://search.cpan.org/~msisk/HTML-TableExtract-1.08/lib/HTML/TableExtract.pm
# http://www.mamiyami.com/document/perl_cookbook_2nd_edition/0596003137_perlckbk2-chp-20-sect-19.html
#
################################################################################
use strict;
use diagnostics;
++$|;

my $account;
BEGIN {
    use Cwd qw( cwd getcwd );
    use Config;
    chomp( $account = `whoami` );
    my $localLibBase = getcwd() . "/lib/CPAN/lib/site_perl/" . $Config{version};
    unshift @INC, ( $localLibBase, "$localLibBase/$Config{archname}" );
}

use LWP;
use LWP::Simple;
use Cwd qw( getcwd );
use File::Path qw( rmtree mkpath );
use Data::Dumper qw( Dumper );
use TWiki::Contrib::Attrs;

################################################################################
# config
my $Config = {
    local_cache => 'downloads/patches',
    twiki => {
	pub => 'http://twiki.org/p/pub',
	view => 'http://twiki.org/cgi-bin/view',
    },
};

################################################################################

use LWP::Simple qw( mirror RC_OK RC_NOT_MODIFIED );
use File::Path qw( mkpath );
use HTML::TableExtract;

mkpath $Config->{local_cache} or die $! unless -d $Config->{local_cache};
my @errors;
my ( $nPatches, $nDownloadedPatches ) = qw( 0 0 );
my @patches = getPatchesCatalogList();

mkdir "$Config->{local_cache}/web" or die $! unless -e "$Config->{local_cache}/web";

print "\n| *Patch* | *Download Status* |";
foreach my $patchS ( @patches )
{
    my $patch = $patchS->{patch};
    my $topic = $patchS->{patch};
    my $web = $patchS->{web};

    print "\n| TWiki:${web}.${patch} ";
    ++$nPatches;

    my $remote_uri = "$Config->{twiki}->{view}/$web/$topic?skin=text&raw=debug";
    print "$remote_uri\n";

    File::Path::mkpath( "$Config->{local_cache}/web/$topic/data" ) or die $! unless -e "$Config->{local_cache}/web/$topic/data";
    File::Path::mkpath( "$Config->{local_cache}/web/$topic/pub" ) or die $! unless -e "$Config->{local_cache}/web/$topic/pub";

    mirror( $remote_uri, "$Config->{local_cache}/web/$topic/data/$topic.txt" );
    my $patchTopic = LWP::Simple::get( "file:$Config->{local_cache}/web/$topic/data/$topic.txt" ) or die $!;
#    print "$patchTopic";

    # CODE_SMELL: hopefully won't run into a }% in any of the attributes
    while ( $patchTopic =~ m|META:FILEATTACHMENT{(^(}%)+)|gsi )
    {
	#name="Func.pm.patch" attr="" comment="Patch for Func.pm" date="1097756003" path="Func.pm.patch" size="478" user="JChristophFuchs" version="1.1"
	print "Attrs=[[$1]]\n";
	my $attrsAttach = TWiki::Contrib::Attrs->new( $1 );
	print Data::Dumper::Dumper( $attrsAttach );
	my $remote_attachment_uri = "$Config->{twiki}->{pub}/$web/$topic/$attrsAttach->{path}";
	print "$remote_attachment_uri\n";
	# CODE_SMELL: if path contained an actual path (subdirectory), what would happen... ? should be using File::Path::mkpath...
	my $status = mirror( $remote_attachment_uri, "$Config->{local_cache}/web/$topic/pub/$attrsAttach->{path}" );
    }

    # create a GetAWebAddOn-compatable (er, really the installer at this point)
    system( "tar czvf $Config->{local_cache}/$topic.wiki.tar.gz -C $Config->{local_cache}/web/$topic ." );

##    File::Path::rmtree( "$Config->{local_cache}/web/$topic" ) or warn $!;

#    if ($status == RC_OK) {
#	++$nDownloadedPatches;
#	print "| downloaded";
#    } elsif ($status != RC_NOT_MODIFIED) {
#	print "| $!: $remote_uri";
#	push @errors, $patch;
#    } else {
#	++$nDownloadedPatches;
#	print "| updated";
#    }
    print " |";

#    last;
}

File::Path::rmtree( "$Config->{local_cache}/web" ) or warn $!;

## print summary results (suitable for inclusion as a TWiki page)
#print "\n| *Patches Processed* | $nDownloadedPatches/$nPatches |";
#print "\n\n";
#local $, = "\n   * TWiki:.";
#print "Missing/Error patch topics: ", @errors; 
#print "\n";

use XML::Simple;
my $xs = new XML::Simple() or die $!;
open( XML, ">$Config->{local_cache}/patches.xml" ) or die $!;
print XML $xs->XMLout( { patch => [ @plugins ] }, NoAttr => 1 );
close( XML ) or warn $!;

################################################################################

sub getPatchesCatalogList
{
    # get patches catalog page
    my $pg = 'PatchProposal';

    mirror( "http://twiki.org/cgi-bin/view/Codev/${pg}?skin=plain", "${pg}.html" );
    my $patchesCatalogPage = LWP::Simple::get( "file:${pg}.html" ) or die $!;

    # get list of patches (from the links)
    my @patches = qw();

#    my $te = HTML::TableExtract->new( headers => [ 'Patch Topic', 'Creation Date', 'Stinkiness', 'Topic Creator', 'Core Assignment' ], keep_html => 1 );
    my $te = HTML::TableExtract->new( headers => [ 'Patch Topic' ], keep_html => 1 );
    $te->parse( $patchesCatalogPage );

    # Examine all matching tables
    foreach my $ts ($te->table_states) {
#	print Data::Dumper::Dumper( $ts );
	foreach my $row ($ts->rows) {
	    ( my $patchPage = $row->[0] ) =~ m|href=".+/(.+?)/(.+?)"|;
#<a class="twikiLink" href="/cgi-bin/view/Codev/LocationLocationLocation">LocationLocationLocation</a>
	    push @patches, { web => "$1", patch => "$2" };
	}
    }

    return @patches;
}

################################################################################

__END__

#LWP::Simple::get( qw( http://twiki.org/cgi-bin/view/Codev/PatchAdjustmentRequired?skin=plain ) );
##LWP::Simple::get( qw( http://twiki.org/cgi-bin/view/Codev/PatchReadyForCVS?skin=plain ) );
#LWP::Simple::get( qw( http://twiki.org/cgi-bin/view/Codev/PatchAccepted?skin=plain ) );
##LWP::Simple::get( qw( http://twiki.org/cgi-bin/view/Codev/PatchWithdrawn?skin=plain ) );
