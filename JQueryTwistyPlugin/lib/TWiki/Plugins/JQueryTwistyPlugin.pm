# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Rafael Alvarez, soronthar@sourceforge.net
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

=pod

---+ package JQueryTwistyPlugin

It has two major features:
   * When active, the Twisty javascript library is included in every topic.
   * Provides a convenience syntax to define twisty areas.

=cut

package TWiki::Plugins::JQueryTwistyPlugin;

use TWiki::Func;
use CGI::Cookie;
use strict;

use vars
  qw( $VERSION $RELEASE $pluginName @modes $doneHeader $doneDefaults $twistyCount
  $prefMode $prefShowLink $prefHideLink $prefRemember);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.0';

$pluginName = 'JQueryTwistyPlugin';

my $JQUERYTWISTYPLUGIN_COOKIE_PREFIX  = "JQueryTwistyPlugin_";
my $JQUERYTWISTYPLUGIN_CONTENT_HIDDEN = 0;
my $JQUERYTWISTYPLUGIN_CONTENT_SHOWN  = 1;

#there is no need to document this.
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $doneDefaults = 0;
    $doneHeader   = 0;
    $twistyCount  = 0;

    TWiki::Func::registerTagHandler( 'TWISTYSHOW',      \&_TWISTYSHOW );
    TWiki::Func::registerTagHandler( 'TWISTYHIDE',      \&_TWISTYHIDE );
    TWiki::Func::registerTagHandler( 'TWISTYBUTTON',    \&_TWISTYBUTTON );
    TWiki::Func::registerTagHandler( 'TWISTY',          \&_TWISTY );
    TWiki::Func::registerTagHandler( 'ENDTWISTY',       \&_ENDTWISTYTOGGLE );
    TWiki::Func::registerTagHandler( 'TWISTYTOGGLE',    \&_TWISTYTOGGLE );
    TWiki::Func::registerTagHandler( 'ENDTWISTYTOGGLE', \&_ENDTWISTYTOGGLE );

    return 1;
}

sub _setDefaults {
    return if $doneDefaults;
    $doneDefaults = 1;

    $prefMode = TWiki::Func::getPreferencesValue('TWISTYMODE')
      || TWiki::Func::getPluginPreferencesValue('TWISTYMODE')
      || 'span';
    $prefShowLink = TWiki::Func::getPreferencesValue('TWISTYSHOWLINK')
      || TWiki::Func::getPluginPreferencesValue('TWISTYSHOWLINK')
      || '';
    $prefHideLink = TWiki::Func::getPreferencesValue('TWISTYHIDELINK')
      || TWiki::Func::getPluginPreferencesValue('TWISTYHIDELINK')
      || '';
    $prefRemember = TWiki::Func::getPreferencesValue('TWISTYREMEMBER')
      || TWiki::Func::getPluginPreferencesValue('TWISTYREMEMBER')
      || '';

}

sub _addHeader {
    return if $doneHeader;
    $doneHeader = 1;

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%TWIKIWEB%/JQueryTwistyPlugin/twist.css");
</style>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/JQueryTwistyPlugin/twist.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TWikiJavascripts/twikiPref.js"></script>
<script type="text/javascript">
// <![CDATA[
var styleText = '<style type="text/css" media="all">.twikiMakeVisible{display:inline;}.twikiMakeVisibleInline{display:inline;}.twikiMakeVisibleBlock{display:block;}.twikiMakeHidden{display:none;}</style>';
document.write(styleText);
// ]]>
</script>
EOF

    TWiki::Func::addToHEAD( 'JQUERYTWISTYPLUGIN_TWISTY', $header );
}

sub _TWISTYSHOW {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    _setDefaults();

    my $mode = $params->{'mode'} || $prefMode;
    my $btn = _twistyBtn( 'show', @_ );
    return _wrapInButtonHtml( $btn, $mode );
}

sub _TWISTYHIDE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    _setDefaults();
    my $mode = $params->{'mode'} || $prefMode;
    my $btn = _twistyBtn( 'hide', @_ );
    return _wrapInButtonHtml( $btn, $mode );
}

sub _TWISTYBUTTON {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    _setDefaults();

    my $mode = $params->{'mode'} || $prefMode;
    my $btnShow = _twistyBtn( 'show', @_ );
    my $btnHide = _twistyBtn( 'hide', @_ );
    my $prefix = $params->{'prefix'} || '';
    my $suffix = $params->{'suffix'} || '';
    my $btn = $prefix . ' ' . $btnShow . $btnHide . ' ' . $suffix;
    return _wrapInButtonHtml( $btn, $mode );
}

sub _TWISTY {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    
    _addHeader();
    $twistyCount++;
    my $id = $params->{'id'};
    if ( !defined $id || $id eq '' ) {
        $params->{'id'} = 'twistyId' . $theWeb . $theTopic . $twistyCount;
    }
    return _TWISTYBUTTON(@_) . ' ' . _TWISTYTOGGLE(@_);
}

sub _TWISTYTOGGLE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $id = $params->{'id'};
    if ( !defined $id || $id eq '' ) {
        return '';
    }
    _setDefaults();
    my $idTag = $id . 'toggle';
    my $mode = 'div'; #$params->{'mode'} || $prefMode;
    unshift @modes, $mode;

    my $isTrigger = 0;
    my $cookieState = _readCookie( $session, $idTag );
    my @propList =
      _createHtmlProperties( undef, $idTag, $mode, $params, $isTrigger,
        $cookieState );
    my $props = @propList ? " " . join( " ", @propList ) : '';
    my $modeTag = '<' . $mode . $props . '>';
    return _wrapInContentHtmlOpen($mode) . $modeTag;
}

sub _ENDTWISTYTOGGLE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $mode = shift @modes;
    my $modeTag = ($mode) ? '</' . $mode . '>' : '';
    return $modeTag . _wrapInContentHtmlClose($mode);
}

sub _twistyBtn {
    my ( $twistyControlState, $session, $params, $theTopic, $theWeb ) = @_;

    _addHeader();

    # not used yet:
    #my $triangle_right = '&#9658;';
    #my $triangle_down = '&#9660;';

    my $id = $params->{'id'};
    if ( !defined $id || $id eq '' ) {
        return '';
    }
    my $idTag = $id . $twistyControlState if ($twistyControlState) || '';

    my $defaultLink =
      ( $twistyControlState eq 'show' ) ? $prefShowLink : $prefHideLink;

    # link="" takes precedence over showlink="" and hidelink=""
    my $link = $params->{'link'};

    if ( !defined $link ) {

        # if 'link' is not set, try 'showlink' / 'hidelink'
        $link = $params->{ $twistyControlState . 'link' };
    }
    if ( !defined $link ) {
        $link = $defaultLink || '';
    }

    my $img = $params->{ $twistyControlState . 'img' }
      || $params->{'img'}
      || '';
    my $imgright = $params->{ $twistyControlState . 'imgright' }
      || $params->{'imgright'}
      || '';
    my $imgleft = $params->{ $twistyControlState . 'imgleft' }
      || $params->{'imgleft'}
      || '';
    $img      =~ s/['\"]//go;
    $imgright =~ s/['\"]//go;
    $imgleft  =~ s/['\"]//go;
    my $imgTag =
      ( $img ne '' ) ? '<img src="' . $img . '" border="0" alt="" />' : '';
    my $imgRightTag =
      ( $imgright ne '' )
      ? '<img src="' . $imgright . '" border="0" alt="" />'
      : '';
    my $imgLeftTag =
      ( $imgleft ne '' )
      ? '<img src="' . $imgleft . '" border="0" alt="" />'
      : '';
    my $imgLinkTag =
        '<a href="#">'
      . $imgLeftTag
      . '<span class="twikiLinkLabel twikiUnvisited">'
      . $link
      . '</span>'
      . $imgTag
      . $imgRightTag . '</a>'
      . ' ';

    my $isTrigger = 1;
    my $props     = '';

    if ( $idTag && $params ) {
        my $cookieState = _readCookie( $session, $idTag );
        my @propList =
          _createHtmlProperties( $twistyControlState, $idTag, undef, $params,
            $isTrigger, $cookieState );
        $props = @propList ? " " . join( " ", @propList ) : '';
    }
    my $triggerTag = '<span' . $props . '>' . $imgLinkTag . '</span>' . ' ';
    return $triggerTag;
}

sub _createHtmlProperties {
    my ( $twistyControlState, $idTag, $mode, $params, $isTrigger, $cookie ) = @_;
    my $class = $params->{'class'} || '';
    my $firststart = $params->{'firststart'} || '';
    my $firstStartHidden;
    $firstStartHidden = 1 if ( $firststart eq 'hide' );
    my $firstStartShown;
    $firstStartShown = 1 if ( $firststart eq 'show' );
    my $cookieShow;
    $cookieShow = 1 if defined $cookie && $cookie == 1;
    my $cookieHide;
    $cookieHide = 1 if defined $cookie && $cookie == 0;
    my $start = $params->{start} || '';
    my $startHidden;
    $startHidden = 1 if ( $start eq 'hide' );
    my $startShown;
    $startShown = 1 if ( $start eq 'show' );

    _setDefaults();
    my $remember = $params->{'remember'} || $prefRemember;
    my $noscript = $params->{'noscript'} || '';
    my $noscriptHide;
    $noscriptHide = 1 if ( $noscript eq 'hide' );
    $mode ||= $prefMode;

    my @classList = ();
    push( @classList, $class ) if $class && !$isTrigger;
    push( @classList, 'twistyRememberSetting' ) if ( $remember eq 'on' );
    push( @classList, 'twistyForgetSetting' )   if ( $remember eq 'off' );
    push( @classList, 'twistyStartHide' )      if $startHidden;
    push( @classList, 'twistyStartShow' )      if $startShown;
    push( @classList, 'twistyFirstStartHide' ) if $firstStartHidden;
    push( @classList, 'twistyFirstStartShow' ) if $firstStartShown;

    # Mimic the rules in twist.js, function _update()
    my $state = '';
    $state = $JQUERYTWISTYPLUGIN_CONTENT_HIDDEN if $firstStartHidden;
    $state = $JQUERYTWISTYPLUGIN_CONTENT_SHOWN if $firstStartShown;
    # cookie setting may override  firstStartHidden and firstStartShown
    $state = $JQUERYTWISTYPLUGIN_CONTENT_HIDDEN if $cookieHide;
    $state = $JQUERYTWISTYPLUGIN_CONTENT_SHOWN  if $cookieShow;
    # startHidden and startShown may override cookie
    $state = $JQUERYTWISTYPLUGIN_CONTENT_HIDDEN if $startHidden;
    $state = $JQUERYTWISTYPLUGIN_CONTENT_SHOWN  if $startShown;

    # assume trigger should be hidden
    # unless explicitly said otherwise
    my $shouldHideTrigger = 1;
    if ($isTrigger) {
        push( @classList, 'twistyTrigger twikiUnvisited' );

        if (   $state eq $JQUERYTWISTYPLUGIN_CONTENT_SHOWN
            && $twistyControlState eq 'hide' )
        {
            $shouldHideTrigger = 0;
        }
        if (   $state eq $JQUERYTWISTYPLUGIN_CONTENT_HIDDEN
            && $twistyControlState eq 'show' )
        {
            $shouldHideTrigger = 0;
        }
        push( @classList, 'twistyHidden' ) if $shouldHideTrigger;
    }

    # assume content should be hidden
    # unless explicitly said otherwise
    my $shouldHideContent = 1;
    if ( !$isTrigger ) {
        push( @classList, 'twistyContent' );

        if ( $state eq $JQUERYTWISTYPLUGIN_CONTENT_SHOWN ) {
            $shouldHideContent = 0;
        }
        push( @classList, 'twikiMakeHidden' ) if $shouldHideContent;
    }

    # deprecated
    # should be done by twiki template scripts instead
    if ( !$isTrigger && $noscriptHide ) {
        if ( $mode eq 'div' ) {
            push( @classList, 'twikiMakeVisibleBlock' );
        }
        else {
            push( @classList, 'twikiMakeVisibleInline' );
        }
    }

    # let javascript know we have set the state already
    push( @classList, 'twistyInited' . $state );

    my @propList = ();
    push( @propList, 'id="' . $idTag . '"' );
    my $classListString = join( " ", @classList );
    push( @propList, 'class="' . $classListString . '"' );
    return @propList;
}

=pod

Reads a setting from the TWIKIPREF cookie.
Returns:
   * 1 if the cookie has been set (meaning: show content)
   * 0 if the cookie is '0' (meaning: hide content)
   * undef if no cookie has been set

=cut

sub _readCookie {
    my ( $session, $idTag ) = @_;

    return '' if !$idTag;

    # which state do we use?
    my $cgi = new CGI;
    my $cookie = $cgi->cookie('TWIKIPREF');
    my $tag    = $idTag;
    $tag =~ s/^(.*)(hide|show|toggle)$/$1/go;
    my $key = $JQUERYTWISTYPLUGIN_COOKIE_PREFIX . $tag;

    return unless ( defined($key) && defined($cookie) );

    my $value = '';
	if ($cookie =~ m/\b$key\=(.+?)\b/gi) {
		$value = $1;
	}
    
    return if $value eq '';
    return ($value eq '1') ? 1 : 0;
}

sub _wrapInButtonHtml {
    my ($text, $mode) = @_;
    return _wrapInContainerHideIfNoJavascripOpen($mode) . "\n" . $text
      . _wrapInContainerDivIfNoJavascripClose($mode);
}

sub _wrapInContentHtmlOpen {
    my $mode = shift;
    return '<'.$mode.' style="display:inline;" class="twistyPlugin">';
}

sub _wrapInContentHtmlClose {
    my $mode = shift;
    return '</'.$mode.'><!--/twistyPlugin-->';
}

sub _wrapInContainerHideIfNoJavascripOpen {
    my ($mode) = @_;
    return '<' . $mode . ' class="twistyPlugin twikiMakeVisibleInline">';
}

sub _wrapInContainerDivIfNoJavascripClose {
    my ($mode) = @_;
    return '</' . $mode . '><!--/twistyPlugin twikiMakeVisibleInline-->';
}

1;
