#! /usr/bin/perl -w
use strict;
use Data::Dumper qw( Dumper );

BEGIN {
    use File::Spec;

    foreach my $pc (split(/:/, $ENV{TWIKI_LIBS} || '../lib' )) {
        unshift @INC, $pc;
    }

    # designed to be run within a SVN checkout area
    my @path = split( /\/+/, File::Spec->rel2abs($0) );
    pop(@path); # the script name
}
use TWiki;

my $BASE = {url=>'',};

#print 'url: ', $TWiki::cfg{DefaultUrlHost}, "\n";
#print 'pub: ', $TWiki::cfg{PubUrlPath}, "\n";
#print 'script: ', $TWiki::cfg{ScriptUrlPath}, "\n";

while ( <> )
{
    # <base href="NOT SETNOT SET/view/TWiki/TWikiDocumentation" />
#    my ( $base ) = m|<base href="(.*TWiki/TWikiDocumentation)"|;
#    my ( @a ) = m|<base href="([^"]*)/view[^/]*/([A-Za-z])+/([A-Za-z])"|;
    my ( @a ) = m|<base href="([^"]*)/view[^/]*/([A-Za-z]+)/([A-Za-z]+)"|;
    my %base;
    @base{ 'url', 'web', 'topic' } = @a;
#    my @base{ qw( url web topic ) } = m|<base href="([^"]*)/view[^/]*/([A-Za-z])+/([A-Za-z])"|;
    if ( $base{url} ) {
	$BASE = \%base;
#print "src [" . Dumper( $BASE) . "]\n";
	next;
    }

    # <a href="#TWiki_System_Requirements?CGISESSID=1b0111425eeb13f3d05508ff6e4ca920">
    # <a href="NOT SETNOT SET/view/TWiki/TWikiDocumentation#ManualUpgradeProcedure?CGISESSID=1b0111425eeb13f3d05508ff6e4ca920" class="twikiAnchorLink">
    s|(\?CGISESSID=[^"]*)||g;

    # <a href="NOT SETNOT SET/view/TWiki/TWikiSite"

    # src="NOT SETNOT SET/TWiki/TWikiDocGraphicsPattern/help.gif"
#    s|$BASE->{url}||g if $BASE->{url};

    # <img src="NOT SET/icn/txt.gif"

    # src="NOT SETNOT SET/TWiki/TWikiDocGraphicsPattern/help.gif"
    s|(src=")($TWiki::cfg{DefaultUrlHost}$TWiki::cfg{PubUrlPath})(/)|$1http://twiki.org/p/pub$3|g;

    # <a href="NOT SETNOT SET/view/TWiki/TWikiDocumentation#ManualUpgradeProcedure" class="twikiAnchorLink">manual upgrade procedure</a> 
    s|(href=")($TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath})(/)|$1http://twiki.org/cgi-bin$3|g;

    # src="http://twiki.org/p/pub/TWiki/TWikiDocGraphicsPattern/help.gif"
    s|(src=")(.*?/TWikiDocGraphics)Pattern(/)|$1$2$3|g;

    # 
    print;
}
