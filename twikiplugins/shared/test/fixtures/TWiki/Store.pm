#
# Test fixture that implements the "Store" interface of TWiki.
# Only the methods encountered in testing to date are implemented.
#
# To use this base class, inherit from it instead of inheriting from
# Test::Unit::TestCase
use strict;

package TWiki::Store;

use BaseFixture;

# Required for CairoCompatabilityMode
sub readTemplateFile {
    my( $theName, $theSkin ) = @_;
    $theSkin = "" unless $theSkin; # prevent 'uninitialized value' warnings

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.skin).tmpl
    my $tmplDir = BaseFixture::getTemplatesDir();
    if( ( ! $tmplFile ) && ( opendir( DIR, $tmplDir ) ) ) {
        my @filelist = grep /^$theName\..*tmpl$/, readdir DIR;
        closedir DIR;
        $tmplFile = "$theName.$theSkin.tmpl";
        if( ! grep { /^$tmplFile$/ } @filelist ) {
            $tmplFile = "$theName.tmpl";
            if( ! grep { /^$tmplFile$/ } @filelist ) {
                $tmplFile = "";
            }
        }
        if( $tmplFile ) {
            $tmplFile = "$tmplDir/$tmplFile";
        }
    }

    # read the template file
    if( -e $tmplFile ) {
        return BaseFixture::readFile( $tmplFile );
    }
    return "";
}

# required for Cairo mode
sub readTemplate {
  my( $theName, $theSkin ) = @_;

  return CairoCompatibilityModule::readTemplate($theName, $theSkin);
}

1;
