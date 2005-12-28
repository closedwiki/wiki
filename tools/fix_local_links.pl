#! /usr/bin/perl -w
use strict;

BEGIN {
    use File::Spec;

    unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
    unshift @INC, '../lib/CPAN/lib/';
    unshift @INC, '../lib/';

    # designed to be run from within an SVN checkout area
    my @path = split( /\/+/, File::Spec->rel2abs($0) );
    pop(@path); # the script name
}
use TWiki;

my $BASE = {url=>'',};

#print 'url: ', $TWiki::cfg{DefaultUrlHost}, "\n";
#print 'pub: ', $TWiki::cfg{PubUrlPath}, "\n";
#print 'script: ', $TWiki::cfg{ScriptUrlPath}, "\n";

while ( <> ) {
    # <base href=".../view/TWiki/TWikiDocumentation" />
    my ( @a ) = m|<base href="([^"]*)/view[^/]*/([A-Za-z]+)/([A-Za-z]+)"|i;
    my %base;
    @base{ 'url', 'web', 'topic' } = @a;

    if ( $base{url} ) {
        $BASE = \%base;
        next;
    }

    s|(?<=[?;&])TWIKISESSID=\w*[;&]?||g;

    s|$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{PubUrlPath}/*|http://twiki.org/p/pub/|g;

    s|($TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath})/*|http://twiki.org/cgi-bin/|g;

    # SMELL: do we really need this?
    s|(src=".*?/TWikiDocGraphics)Pattern(/)|$1$2|g;

    print;
}
