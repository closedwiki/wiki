=pod

---+ package WysiwygPlugin

This plugin is responsible for translating TML to HTML before an edit starts
and translating the resultant HTML back into TML.
The flow of control is as follows:
   1 User hits "edit"
   2 The kupu 'edit' template is instantiated with all the js and css and a 'view' url that specifies =wysiwyg_edit=
   3 kupu editor invokes view URL to obtain document
   4 commonTagsHandler here performs the necessary translation
   5 editor saves by posting back with a "convert=html2tml" parameter
   6 the beforeSaveHandler sees this and converts the HTML back to tml

=cut

package TWiki::Plugins::WysiwygPlugin;

use CGI qw( -any );
use strict;
use TWiki::Func;

use vars qw( $VERSION $convertSkin $html2tml $tml2html );

$VERSION = '1.00';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    $convertSkin = TWiki::Func::getPreferencesValue("WYSIWYGPLUGIN_SKIN_NAME");

    # Plugin correctly initialized
    return 1;
}

# Invoked when the selected skin is in use to convert the text to HTML
sub commonTagsHandler {
    #my ( $text, $topic, $web )

    my $query = TWiki::Func::getCgiQuery();
    return unless defined( $query->param( 'wysiwyg_edit' ));

    # stop it from processing the template (grr; we need a better
    # way to tell where we are in the processing pipeline)
    return if( $_[0] =~ /^<!-- WysiwygPlugin Template/ );

    # Translate the topic text to pure HTML.
    unless( $tml2html ) {
        require TWiki::Plugins::WysiwygPlugin::TML2HTML;
        $tml2html = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
    }

    my( $meta, $text ) = TWiki::Func::readTopic( $_[2], $_[1] );
    $_[0] = $tml2html->convert( $text );

}

# Invoked when the selected skin is in use to convert HTML to
# TML (best offorts)
sub beforeSaveHandler {
    #my( $text, $topic, $web ) = @_;

    my $skin = TWiki::Func::getSkin();

    return unless( $skin =~ /(^|\s)$convertSkin(\s|$)/o );

    unless( $html2tml ) {
        require TWiki::Plugins::WysiwygPlugin::HTML2TML;
        $html2tml = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    }

    my @rescue;
    # SMELL: really, really bad smell; bloody core should NOT pass text
    # with embedded meta to plugins! It is VERY BAD DESIGN!!!
    $_[0] =~ s/^(%META:[A-Z]+{.*?}%)$/push(@rescue,$1);"<!--\007@#rescue-->"/ge;

    $_[0] = $html2tml->convert( $_[0] );

    $_[0] =~ s/^<!--\007(\d+)-->$/$rescue[$1]/g;
}

1;
