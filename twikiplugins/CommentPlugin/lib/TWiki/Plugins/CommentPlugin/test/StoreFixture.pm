#
# Test fixture that implements the "Store" interface of TWiki. It can't
# override the actual "TWiki::Store" methods themselves, but instead
# provides blanks for the methods so that if the fixture is used in place
# of a class object "TWiki::Store" it can step in.
#

package TWiki::Store;

use base qw(Test::Unit::TestCase);
use vars qw( %templateVars );

sub _readTemplateFile
{
    my( $theName, $theSkin ) = @_;
    $theSkin = "" unless $theSkin; # prevent 'uninitialized value' warnings

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.skin).tmpl
    my $tmplDir = TWiki::Func::TESTgetTemplatesDir();
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
        return TWiki::Func::TESTreadFile( $tmplFile );
    }
    return "";
}
1;
