=begin text

---++ Package TWiki::Store - test fixture
A test fixture module that provides an ultra-thin implementation of the
functions of the TWiki::Store module that are required by plugins and add-ons.

Only the methods encountered in testing to date are implemented.

For full details, read the code.

=cut
use strict;

package TWiki::Store;

use vars qw( %templateVars );

use BaseFixture;
use TWiki::Contrib::CairoContrib;

sub _readTemplateFile {
  return readTemplateFile( @_ );
}

sub readTemplateFile {
    my( $theName, $theSkin ) = @_;
    $theSkin = "" unless $theSkin; # prevent 'uninitialized value' warnings

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.skin).tmpl
    my $tmplDir = BaseFixture::getTemplatesDir();
    if( opendir( DIR, $tmplDir ) ) {
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

  return TWiki::Contrib::CairoContrib::readTemplate($theName, $theSkin);
}

sub getAllWebs {
    return BaseFixture::webList();
}

sub handleTmplP
{
    # Print template variable, called by %TMPL:P{"$theVar"}%
    my( $theVar ) = @_;

    my $val = "";
    if( ( %templateVars ) && ( exists $templateVars{ $theVar } ) ) {
        $val = $templateVars{ $theVar };
        $val =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&handleTmplP($1)/geo;  # recursion
    }
    if( ( $theVar eq "sep" ) && ( ! $val ) ) {
        # set separator explicitely if not set
        $val = " | ";
    }
    return $val;
}

1;
