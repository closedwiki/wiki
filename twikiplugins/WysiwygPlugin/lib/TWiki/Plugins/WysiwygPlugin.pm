=pod

---+ package WysiwygPlugin

This plugin is responsible for translating TML to HTML before an edit starts
and translating the resultant HTML back into TML.
The flow of control is as follows:
   1 User hits "edit"
   2 The kupu 'edit' template is instantiated with all the js and css
   3 kupu editor invokes view URL with the 'wysiwyg_edit=1' parameter to obtain clean document
   4 commonTagsHandler here performs the necessary translation
   5 editor saves by posting to 'save' with the 'wysiwyg_edit=1' parameter
   6 the beforeSaveHandler sees this and converts the HTML back to tml

=cut

package TWiki::Plugins::WysiwygPlugin;

use CGI qw( -any );
use strict;
use TWiki::Func;

use vars qw( $VERSION $convertSkin $html2tml $tml2html );

$VERSION = '0.01';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    $convertSkin = TWiki::Func::getPreferencesValue("WYSIWYGPLUGIN_SKIN_NAME");

    # Plugin correctly initialized
    return 1;
}

# Invoked when the selected skin is in use to convert HTML to
# TML (best offorts)
sub beforeSaveHandler {
    #my( $text, $topic, $web ) = @_;
    my $query = TWiki::Func::getCgiQuery();

    return unless defined( $query->param( 'wysiwyg_edit' ));

    unless( $html2tml ) {
        require TWiki::Plugins::WysiwygPlugin::HTML2TML;

        my $imgMap = {};
        my $imgs = TWiki::Func::getPreferencesValue( "WYSIWYGPLUGIN_ICONS" );
        if( $imgs ) {
            $imgs = TWiki::Func::expandCommonVariables( $imgs );
            while( $imgs =~ s/src="(.*?)" alt="(.*?)"// ) {
                my( $src, $alt ) = ( $1, $2 );
                $alt .= '%' if $alt =~ /^%/;
                $imgMap->{$src} = $alt;
            }
        }

        $html2tml =
          new TWiki::Plugins::WysiwygPlugin::HTML2TML($imgMap,
                                                      \&parseWikiUrl);
    }

    my @rescue;
    # SMELL: really, really bad smell; bloody core should NOT pass text
    # with embedded meta to plugins! It is VERY BAD DESIGN!!!
    $_[0] =~ s/^(%META:[A-Z]+{.*?}%)$/push(@rescue,$1);"<!--\007@#rescue-->"/ge;

    $_[0] = $html2tml->convert( $_[0] );

print STDERR "POST CONVERSION $_[0]\n";
    $_[0] =~ s/^<!--\007(\d+)-->$/$rescue[$1]/g;
}

# Invoked when the selected skin is in use to convert the text to HTML
sub commonTagsHandler {
    #my ( $text, $topic, $web )

    my $query = TWiki::Func::getCgiQuery();
    return unless defined( $query->param( 'wysiwyg_edit' ));

    # stop it from processing the template without expanded
    # %TEXT% (grr; we need a better way to tell where we
    # are in the processing pipeline)
    return if( $_[0] =~ /^<!-- WysiwygPlugin Template/ );

    # Translate the topic text to pure HTML.
    unless( $tml2html ) {
        require TWiki::Plugins::WysiwygPlugin::TML2HTML;
        $tml2html = new TWiki::Plugins::WysiwygPlugin::TML2HTML(\&TWiki::Func::getViewUrl);
    }

    my( $meta, $text ) = TWiki::Func::readTopic( $_[2], $_[1] );
    $_[0] = $tml2html->convert( $text );
}

sub parseWikiUrl {
    my( $url ) = @_;

    my $aurl = TWiki::Func::getViewUrl('WEB', 'TOPIC');
    $aurl =~ s!WEB/TOPIC.*$!!;

    return (undef, undef) unless length($url) >= length($aurl);

    return (undef, undef) unless substr($url, 0, length($aurl)) eq $aurl;
    $url = substr($url,length($aurl),length($url));
    return (undef, undef) unless $url =~ /^(\w+)[.\/](\w+)$/;

    return( $1, $2 );
}

1;
