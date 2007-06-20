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

---+ package TwistyPlugin

Convenience plugin for TWiki:Plugins.TwistyContrib.
It has two major features:
   * When active, the Twisty javascript library is included in every topic.
   * Provides a convenience syntax to define twisty areas.

=cut

package TWiki::Plugins::TwistyPlugin;

use TWiki::Func;
use CGI::Cookie;
use strict;

use vars
  qw( $VERSION $RELEASE $pluginName $debug @modes $doneHeader $twistyCount
  $prefMode $prefShowLink $prefHideLink $prefRemember
  $defaultMode $defaultShowLink $defaultHideLink $defaultRemember );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.4.0';

$pluginName = 'TwistyPlugin';

my $TWISTYPLUGIN_COOKIE_PREFIX  = "TwistyContrib_";
my $TWISTYPLUGIN_CONTENT_HIDDEN = 0;
my $TWISTYPLUGIN_CONTENT_SHOWN  = 1;

#there is no need to document this.
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    _setDefaults();

    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    $doneHeader  = 0;
    $twistyCount = 0;

    $prefMode = TWiki::Func::getPreferencesValue('TWISTYMODE')
      || TWiki::Func::getPluginPreferencesValue('TWISTYMODE')
      || $defaultMode;
    $prefShowLink = TWiki::Func::getPreferencesValue('TWISTYSHOWLINK')
      || TWiki::Func::getPluginPreferencesValue('TWISTYSHOWLINK')
      || $defaultShowLink;
    $prefHideLink = TWiki::Func::getPreferencesValue('TWISTYHIDELINK')
      || TWiki::Func::getPluginPreferencesValue('TWISTYHIDELINK')
      || $defaultHideLink;
    $prefRemember = TWiki::Func::getPreferencesValue('TWISTYREMEMBER')
      || TWiki::Func::getPluginPreferencesValue('TWISTYREMEMBER')
      || $defaultRemember;

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
    $defaultMode     = 'span';
    $defaultShowLink = '';
    $defaultHideLink = '';
    $defaultRemember =
      '';    # do not default to 'off' or all cookies will be cleared!
}

sub _addHeader {
    return if $doneHeader;
    $doneHeader = 1;

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%TWIKIWEB%/TwistyContrib/twist.css");
</style>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TWikiJavascripts/twikilib.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TWikiJavascripts/twikiPref.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TWikiJavascripts/twikiCSS.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/BehaviourContrib/behaviour.compressed.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TwistyContrib/twist.compressed.js"></script>
<style type="text/css" media="all">
.twikiMakeVisible,
.twikiMakeVisibleInline,
.twikiMakeVisibleBlock {
	display:none; /* will be made visible with javascript */
}
</style>
<script type="text/javascript">
var styleText = '<style type="text/css" media="all">.twikiMakeVisible{display:inline;}.twikiMakeVisibleInline{display:inline;}.twikiMakeVisibleBlock{display:block;}.twikiMakeHidden{display:none;}</style>';
document.write(styleText);
</script>
EOF

    TWiki::Func::addToHEAD( 'TWISTYPLUGIN_TWISTY', $header );
}

sub _TWISTYSHOW {
    return _wrapInButtonHtml( _twistyBtn( 'show', @_ ) );
}

sub _TWISTYHIDE {
    return _wrapInButtonHtml( _twistyBtn( 'hide', @_ ) );
}

sub _TWISTYBUTTON {
    return _wrapInButtonHtml(
        _twistyBtn( 'show', @_ ) . _twistyBtn( 'hide', @_ ) );
}

sub _TWISTY {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    _addHeader();
    $twistyCount++;
    my $id = $params->{'id'};
    if ( !defined $id || $id eq '' ) {
        $params->{'id'} = 'twistyId' . $theWeb . $theTopic . $twistyCount;
    }
    my $prefix = $params->{'prefix'} || '';
    my $suffix = $params->{'suffix'} || '';
    return $prefix . _TWISTYBUTTON(@_) . ' ' . $suffix . ' ' . _TWISTYTOGGLE(@_);
}

sub _TWISTYTOGGLE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $id = $params->{'id'};
    if ( !defined $id || $id eq '' ) {
        return '';
    }
    my $idTag = $id . 'toggle';
    my $mode = $params->{'mode'} || $prefMode;
    unshift @modes, $mode;

    my $isTrigger = 0;
    my $cookieState = _readCookie( $session, $idTag );
    my @propList =
      _createHtmlProperties( undef, $idTag, $mode, $params, $isTrigger,
        $cookieState );
    my $props = @propList ? " " . join( " ", @propList ) : '';
    my $modeTag = '<' . $mode . $props . '>';
    return _wrapInContentHtmlOpen() . $modeTag;
}

sub _ENDTWISTYTOGGLE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $mode = shift @modes;
    my $modeTag = ($mode) ? '</' . $mode . '>' : '';
    return $modeTag . _wrapInContentHtmlClose();
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
    my ( $twistyControlState, $idTag, $mode, $params, $isTrigger, $cookie ) =
      @_;
    my $class = $params->{'class'} || '';
    my $start = $params->{start}   || '';
    my $startHidden = ( $start eq 'hide' );
    my $startShown  = ( $start eq 'show' );
    my $firststart = $params->{'firststart'} || '';
    my $firstStartHidden = ( $firststart eq 'hide' );
    my $firstStartShown  = ( $firststart eq 'show' );
    my $remember = $params->{'remember'} || $prefRemember;
    my $noscript = $params->{'noscript'} || '';              # deprecated
    my $noscriptHide = ( $noscript eq 'hide' );              # deprecated
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
    my $state;
    $state = $TWISTYPLUGIN_CONTENT_HIDDEN if $firstStartHidden;
    $state = $TWISTYPLUGIN_CONTENT_SHOWN  if $firstStartShown;

    # cookie setting may override  firstStartHidden and firstStartShown
    $state = $TWISTYPLUGIN_CONTENT_HIDDEN if defined $cookie && $cookie == 0;
    $state = $TWISTYPLUGIN_CONTENT_SHOWN  if defined $cookie && $cookie == 1;

    # startHidden and startShown may override cookie
    $state = $TWISTYPLUGIN_CONTENT_HIDDEN if $startHidden;
    $state = $TWISTYPLUGIN_CONTENT_SHOWN  if $startShown;
    $state = $TWISTYPLUGIN_CONTENT_SHOWN  if $noscriptHide;

    # assume trigger should be hidden
    # unless explicitly said otherwise
    my $shouldHideTrigger = 1;
    if ($isTrigger) {
        push( @classList, 'twistyTrigger twikiUnvisited' );

        if (   $state eq $TWISTYPLUGIN_CONTENT_SHOWN
            && $twistyControlState eq 'hide' )
        {
            $shouldHideTrigger = 0;
        }
        if (   $state eq $TWISTYPLUGIN_CONTENT_HIDDEN
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

        if ( $state eq $TWISTYPLUGIN_CONTENT_SHOWN ) {
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

sub _readCookie {
    my ( $session, $idTag ) = @_;

    return '' if !$idTag;

    # which state do we use?
    my $query  = $session->{cgiQuery};
    my $cookie = $query->cookie('TWIKIPREF');
    my $tag    = $idTag;
    $tag =~ s/^(.*)(hide|show|toggle)$/$1/go;
    my $key = $TWISTYPLUGIN_COOKIE_PREFIX . $tag;

    return $TWISTYPLUGIN_CONTENT_SHOWN
      unless ( defined($key) && defined($cookie) );

    my $value = '';
    {
        $cookie =~ s/$key\=(.*?)(\||$)/$1/g;
        $value = $1;
    }

    return $value eq '1';
}

sub _wrapInButtonHtml {
    my ($text) = @_;
    return _wrapInDivHideIfNoJavascripOpen() . $text
      . _wrapInHideDivIfNoJavascripClose();
}

sub _wrapInContentHtmlOpen {
    return '<div style="display:inline;" class="twistyPlugin">';
}

sub _wrapInContentHtmlClose {
    return '</div><!--/twistyPlugin-->';
}

sub _wrapInDivHideIfNoJavascripOpen {
    return '<div class="twistyPlugin twikiMakeVisibleInline">';
}

sub _wrapInHideDivIfNoJavascripClose {
    return '</div><!--/twistyPlugin twikiMakeVisibleInline-->';
}

1;
