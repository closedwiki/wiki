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

BEGIN {
    unshift @INC, '/Users/wbniv/twiki/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/cpan/lib';
    unshift @INC, '/Users/wbniv/Sites/twiki/lib';
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
my @patches = #( { web => 'Codev', patch => 'DebugDoesNotWork' } ) ||
    getPatchesCatalogList();

-e "web" || ( mkdir "web" or die $! );

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

    -e "web/$topic/data" || ( File::Path::mkpath( "web/$topic/data" ) or die $! );
    -e "web/$topic/pub" || ( File::Path::mkpath( "web/$topic/pub" ) or die $! );

    mirror( $remote_uri, "web/$topic/data/$topic.txt" );
    my $patchTopic = LWP::Simple::get( "file:web/$topic/data/$topic.txt" ) or die $!;
#    print "$patchTopic";

#    %META:FILEATTACHMENT{name="Func.pm.patch" attr="" comment="Patch for Func.pm" date="1097756003" path="Func.pm.patch" size="478" user="JChristophFuchs" version="1.1"}%
    # CODE_SMELL: are %'s inside the attrs required to be escaped? (i know there were issues with ImageGalleryPlugin using attachment comments)
    # nope, oops, ran into this on ..., hm, what was it?  NoSearchResultsForALLOWWEBVIEW, i think...
#    while ( $patchTopic =~ m|META:FILEATTACHMENT{([^}]+)|gsi )
    while ( $patchTopic =~ m|META:FILEATTACHMENT{(^(}%)+)|gsi )
    {
	#name="Func.pm.patch" attr="" comment="Patch for Func.pm" date="1097756003" path="Func.pm.patch" size="478" user="JChristophFuchs" version="1.1"
	print "Attrs=[[$1]]\n";
	my $attrsAttach = TWiki::Contrib::Attrs->new( $1 );
	print Data::Dumper::Dumper( $attrsAttach );
	my $remote_attachment_uri = "$Config->{twiki}->{pub}/$web/$topic/$attrsAttach->{path}";
	print "$remote_attachment_uri\n";
	# CODE_SMELL: if path contained an actual path (subdirectory), what would happen... ? should be using File::Path::mkpath
	my $status = mirror( $remote_attachment_uri, "web/$topic/pub/$attrsAttach->{path}" );
    }

    # create a GetAWebAddOn-compatable (er, really the installer at this point)
    system( "tar czvf $Config->{local_cache}/$topic.wiki.tar.gz -C web/$topic ." );

    File::Path::rmtree( "web/$topic" ) or warn $!;

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

File::Path::rmtree( "web" ) or warn $!;

## print summary results (suitable for inclusion as a TWiki page)
#print "\n| *Patches Processed* | $nDownloadedPatches/$nPatches |";
#print "\n\n";
#local $, = "\n   * TWiki:.";
#print "Missing/Error patch topics: ", @errors; 
#print "\n";

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
