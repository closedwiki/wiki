#CommentPlugin written by David Weller (dgweller@yahoo.com)
#Rev 1.0 -- Initial release
#Rev 1.1 -- Incorporate changes suggested by Andrea Sterbini and John Rouillard
#Rev 1.2 -- Additional user feedback incorporated

package TWiki::Plugins::CommentPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $exampleCfgVar
    );

$VERSION = '1.1';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::CommentPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- CommentPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

}

# =========================
sub handleComment
{

    my ( $attributes ) = @_;

&TWiki::Func::writeDebug( "\n - CommentPlugin:: Parsing begins...." );

&TWiki::Func::writeDebug( "\n - CommentPlugin:: attributes is $attributes" );

    my $text ="";
    my $r = scalar &TWiki::extractNameValuePair( $attributes, "rows" );
    my $c = scalar &TWiki::extractNameValuePair( $attributes, "cols" );
    my $mode = &TWiki::extractNameValuePair( $attributes, "mode" );
    my $button =  &TWiki::extractNameValuePair( $attributes, "button" );
    my $commentname =  &TWiki::extractNameValuePair( $attributes, "id" );

    my $defaultRows = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_ROWS", "TWiki");
    my $defaultCols = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_COLS");
    my $defaultBtnName = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_BUTTONNAME");
    my $defaultPrefixName = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_PREFIXMODENAME");
    my $defaultPrefixLabel = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_PREFIXLABEL");
    my $defaultPostfixName = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_POSTFIXMODENAME");
    my $defaultPostfixLabel = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_POSTFIXLABEL");

&TWiki::Func::writeDebug( "- CommentPlugin:: row value is $r, defaultRows is $defaultRows" );

    my $positionLabel = $defaultPrefixLabel;

    if (! $r || $r < 1 ) { $r = $defaultRows }

&TWiki::Func::writeDebug( "- CommentPlugin:: col value is $c, defaultCols is $defaultCols" );

    if (! $c || $c < 10) { $c = $defaultCols }


&TWiki::Func::writeDebug( "- CommentPlugin:: button value is $button, defaultBtnName is $defaultBtnName" );

    if (! $button || $button eq "" ) { $button = $defaultBtnName }

&TWiki::Func::writeDebug( "- CommentPlugin:: comment name value is :$commentname: use __default__ if blank" );

    if (! $commentname || $commentname eq "" ) { $commentname = "__default__" }
    if (! $mode ) { $mode = $defaultPrefixName; }

&TWiki::Func::writeDebug( "- CommentPlugin:: mode is :$mode: use defaultPostfixName of $defaultPostfixName if mode is blank" );

    if ($mode eq $defaultPostfixName) { $positionLabel = $defaultPostfixLabel; }

    my $actionUrlPath = &TWiki::Func::getScriptUrl($web, $topic,'savecomment');
    $text="\n\n<form name=\"comment\" action=\"$actionUrlPath\" method=\"post\">\n";
    $text .= "\t  <textarea rows=\"$r\" cols=\"$c\" name=\"comment\" wrap=soft></textarea><br />\n" ;

;

&TWiki::Func::writeDebug( "- CommentPlugin:: parsing ends......" );

    $text .= $positionLabel;
    $text .= "<input type=\"submit\" value=\"$button\" />\n";
    $text .= "<input type=\"hidden\" name=\"mode\" value=\"$mode\" />\n";
    $text .= "<input type=\"hidden\" name=\"commentname\" value=\"$commentname\" />\n";
    $text .= "</form>\n";
    return $text;
}


# =========================
sub endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- CommentPlugin::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop


    $_[0] =~ s/%COMMENT%/&handleComment()/geo;
    $_[0] =~ s/%COMMENT{(.*?)}%/&handleComment($1)/geo;

}

# =========================

1;
