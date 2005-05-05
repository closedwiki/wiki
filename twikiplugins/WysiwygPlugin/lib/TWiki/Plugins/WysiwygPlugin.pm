=pod

---+ package WysiwygPlugin

=cut

package TWiki::Plugins::WysiwygPlugin;

use vars qw( $VERSION );

$VERSION = '1.00';

# Singleton convertor objects, only created on demand
my $html2tml;
my $tml2html;

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # Plugin correctly initialized
    return 1;
}

# Before we edit, convert TML text to HTML for the WYSIWYG editor
sub beforeEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    return unless TWiki::Func::getSkin() eq 'kupu';

    unless( $tml2html ) {
        require TWiki::Plugins::WysiwygPluginTML2HTML;
        $tml2html = new TWiki::Plugins::WysiwygPluginTML2HTML();
    }

    $_[0] = $tml2html->convert( $_[0] );
}

# Before we save, convert HTML text to TML
#sub beforeSaveHandler {
#    my( $_[0], $topic, $web ) = @_;
#
#    unless( $html2tml ) {
#        require TWiki::Plugins::WysiwygPluginHTML2TML;
#        $html2tml = new TWiki::Plugins::WysiwygPluginHTML2TML();
#    }
#
#    my @rescue;
#    $_[0] =~ s/^(%META:[A-Z]+{.*?}%)$/push(@rescue,$1);"<!--\007@#rescue-->"/ge;
#
#    $_[0] = $html2tml->convert( $_[0] );
#
#    $_[0] =~ s/^<!--\007(\d+)-->$/$rescue[$1]/g;
#}

1;
