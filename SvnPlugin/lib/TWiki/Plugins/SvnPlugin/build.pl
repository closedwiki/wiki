#!/usr/bin/perl -w
BEGIN {
    unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
}
use TWiki::Contrib::Build;

$build = new TWiki::Contrib::Build('SvnPlugin');

$build->{UPLOADTARGETWEB} = 'Plugins';
$build->{UPLOADTARGETPUB} = 'http://twiki.org/p/pub';
$build->{UPLOADTARGETSCRIPT} = 'http://twiki.org/cgi-bin';
$build->{UPLOADTARGETSUFFIX} = '';

$build->build($build->{target});
