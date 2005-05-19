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

use vars qw( $VERSION $convertSkin $html2tml $tml2html $inSave $imgMap $calledThisSession $currentWeb );

$VERSION = '0.05';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    $currentWeb = $web;
    $convertSkin = TWiki::Func::getPreferencesValue("WYSIWYGPLUGIN_SKIN_NAME");
    $calledThisSession = 0;

    # Plugin correctly initialized
    return 1;
}

# Invoked when the selected skin is in use to convert HTML to
# TML (best offorts)
sub beforeSaveHandler {
    #my( $text, $topic, $web ) = @_;
    my $query = TWiki::Func::getCgiQuery();

    return unless $query;

    return unless defined( $query->param( 'wysiwyg_edit' ));

    unless( $html2tml ) {
        require TWiki::Plugins::WysiwygPlugin::HTML2TML;

        $imgMap = {};
        my $imgs = TWiki::Func::getPreferencesValue( "WYSIWYGPLUGIN_ICONS" );
        if( $imgs ) {
            $inSave = 1;
            while( $imgs =~ s/src="(.*?)" alt="(.*?)"// ) {
                my( $src, $alt ) = ( $1, $2 );
                $src = TWiki::Func::expandCommonVariables( $src,$_[1],$_[2] );
                $alt .= '%' if $alt =~ /^%/;
                $imgMap->{$src} = $alt;
            }
            $inSave = 0;
        }
        $html2tml = new TWiki::Plugins::WysiwygPlugin::HTML2TML
          ( { convertImage => sub { my $x = shift; return $imgMap->{$x}; },
              parseWikiUrl => \&parseWikiUrl } );
    }

    my @rescue;

    # SMELL: really, really bad smell; bloody core should NOT pass text
    # with embedded meta to plugins! It is VERY BAD DESIGN!!!
    $_[0] =~ s/^(%META:[A-Z]+{.*?}%)\s*$/push(@rescue,$1);"<!--\007@#rescue-->"/gem;

    # undo the munging that has already been done (grrrrrrrrrr!!!!)
    $_[0] =~ s/\t/   /g;

    $_[0] = $html2tml->convert( $_[0] );

    $_[0] =~ s/^<!--\007(\d+)-->$/$rescue[$1]/g;
}

# Invoked when the selected skin is in use to convert the text to HTML
# We can't use the beforeEditHandler, because the editor loads up and then
# uses a URL to fetch the text to be edited. This handler is designed to
# provide the text for that request. It's a realy struggle, because the
# commonTagsHandler is called so many times that getting the right
# call is a struggle, and then preventing a repeat call is another
# struggle!.
sub commonTagsHandler {
    #my ( $text, $topic, $web )

    return if ( $inSave || $calledThisSession );

    my $query = TWiki::Func::getCgiQuery();
    return unless defined( $query->param( 'wysiwyg_edit' ));

    # stop it from processing the template without expanded
    # %TEXT% (grr; we need a better way to tell where we
    # are in the processing pipeline)
    return if( $_[0] =~ /^<!-- WysiwygPlugin Template/ );

    # Translate the topic text to pure HTML.
    unless( $tml2html ) {
        require TWiki::Plugins::WysiwygPlugin::TML2HTML;
        $tml2html = new TWiki::Plugins::WysiwygPlugin::TML2HTML(\&getViewUrl);
    }

    my( $meta, $text ) = TWiki::Func::readTopic( $_[2], $_[1] );
    $_[0] = $tml2html->convert( $text );
    $calledThisSession = 1;
}

sub getViewUrl {
    my( $web, $topic ) = @_;

    # the documentation says getViewUrl defaults the web. It doesn't.
    $web ||= $currentWeb;
    return TWiki::Func::getViewUrl( $web, $topic );
}

sub parseWikiUrl {
    my $url = shift;

    my $aurl = TWiki::Func::getViewUrl('WEB', 'TOPIC');
    $aurl =~ s!WEB/TOPIC.*$!!;

    return undef unless length($url) >= length($aurl);

    return undef unless substr($url, 0, length($aurl)) eq $aurl;
    $url = substr($url,length($aurl),length($url));
    return undef unless $url =~ /^(\w+)[.\/](\w+)$/;

    return "$1.$2";
}

1;
