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

use vars qw( $VERSION $RELEASE $pluginName $debug @modes $doneHeader $twistyCount
$prefMode $prefShowLink $prefHideLink $prefRemember
$defaultMode $defaultShowLink $defaultHideLink $defaultRemember $needPostRenderingHandler );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.3.0';

$pluginName = 'TwistyPlugin';

my $TWISTYPLUGIN_COOKIE_PREFIX = "TwistyContrib_";
my $TWISTYPLUGIN_CONTENT_HIDDEN = 0;
my $TWISTYPLUGIN_CONTENT_SHOWN = 1;

#there is no need to document this.
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

	_setDefaults();
	
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    $doneHeader = 0;
    $twistyCount = 0;
    $needPostRenderingHandler = 0;
    
    $prefMode = TWiki::Func::getPreferencesValue( 'TWISTYMODE' ) || TWiki::Func::getPluginPreferencesValue( 'TWISTYMODE' ) || $defaultMode;
    $prefShowLink = TWiki::Func::getPreferencesValue( 'TWISTYSHOWLINK' ) || TWiki::Func::getPluginPreferencesValue( 'TWISTYSHOWLINK' ) || $defaultShowLink;
    $prefHideLink = TWiki::Func::getPreferencesValue( 'TWISTYHIDELINK' ) || TWiki::Func::getPluginPreferencesValue( 'TWISTYHIDELINK' ) || $defaultHideLink;
    $prefRemember = TWiki::Func::getPreferencesValue( 'TWISTYREMEMBER' ) || TWiki::Func::getPluginPreferencesValue( 'TWISTYREMEMBER' ) || $defaultRemember;
    	
    TWiki::Func::registerTagHandler('TWISTYSHOW',\&_TWISTYSHOW);
    TWiki::Func::registerTagHandler('TWISTYHIDE',\&_TWISTYHIDE);
    TWiki::Func::registerTagHandler('TWISTYBUTTON',\&_TWISTYBUTTON);
    TWiki::Func::registerTagHandler('TWISTY',\&_TWISTY);
    TWiki::Func::registerTagHandler('ENDTWISTY',\&_ENDTWISTYTOGGLE);
    TWiki::Func::registerTagHandler('TWISTYTOGGLE',\&_TWISTYTOGGLE);
    TWiki::Func::registerTagHandler('ENDTWISTYTOGGLE',\&_ENDTWISTYTOGGLE);
	
    return 1;
}

sub _setDefaults {
	$defaultMode = 'span';
	$defaultShowLink = '';
	$defaultHideLink = '';
	$defaultRemember = ''; # do not default to 'off' or all cookies will be cleared!
}

sub _addHeader {
    return if $doneHeader;
    $doneHeader = 1;

    my $header=<<'EOF'; 
<style type="text/css" media="all">
@import url("%PUBURL%/%TWIKIWEB%/TwistyContrib/twist.css");
</style>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TWikiJavascripts/twikilib.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TWikiJavascripts/twikiPref.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TWikiJavascripts/twikiCSS.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/BehaviourContrib/behaviour.compressed.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TwistyContrib/twist.compressed.js"></script>
EOF

  TWiki::Func::addToHEAD('TWISTYPLUGIN_TWISTY',$header)
}

sub _TWISTYSHOW {
    return _twistyWrapInSpan(_twistyBtn('show', @_));
}

sub _TWISTYHIDE {
    return _twistyWrapInSpan(_twistyBtn('hide', @_));
}

sub _TWISTYBUTTON {
    return _twistyWrapInSpan(
      _twistyBtn('show', @_) . 
      _twistyBtn('hide', @_));
}

sub _TWISTY {
	my($session, $params, $theTopic, $theWeb) = @_;
	_addHeader();
	$twistyCount++;
	my $id = $params->{'id'};
	if (!defined $id || $id eq '') {
		$params->{'id'} = 'twistyId'.$theWeb.$theTopic.$twistyCount;
	}
	my $prefix = $params->{'prefix'} || '';
	my $suffix = $params->{'suffix'} || '';
    return $prefix . _TWISTYBUTTON(@_) . $suffix . _TWISTYTOGGLE(@_);
}

sub _TWISTYTOGGLE {
    my($session, $params, $theTopic, $theWeb) = @_;
    my $id = $params->{'id'};
    if (!defined $id || $id eq '') {
		return '';
	}
    my $idTag = $id.'toggle';
    my $mode = $params->{'mode'} || $prefMode;
    unshift @modes,$mode;
    
    my $isTrigger = 0;
    my $cookieState = _readCookie($session, $idTag);
    my @propList = _createHtmlProperties(undef, $idTag, $params, $isTrigger, $cookieState);
    my $props = @propList ? " ".join(" ",@propList) : '';
    my $modeTag = '<'.$mode.$props.'>';
    $modeTag .= _createJavascriptTriggerCall($session, $idTag);
    return _twistyOpenDiv().$modeTag;
}

sub _ENDTWISTYTOGGLE {
    my($session, $params, $theTopic, $theWeb) = @_;
    my $mode = shift @modes;
    my $modeTag = ($mode) ? '</'.$mode.'>' : '';
    return $modeTag._twistyCloseDiv();
}

=pod

Removes _TWISTYSCRIPT tags written in the topic text, so users cannot use this
construct to write Javascript even if {AllowInlineScript} has been set to false.

=cut

sub beforeCommonTagsHandler {

    return if $needPostRenderingHandler; # don't remove _TWISTYSCRIPT too early
                                         # see Item3159

    # do not uncomment, use $_[0], $_[1]... instead
    $_[0] =~ s/\%_TWISTYSCRIPT{\"(.*?)\"}\%/$1/g;
}

=pod

Convert the semi-variable tag to JavaScript.

=cut

sub postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    if ($_[0] =~ s/\%_TWISTYSCRIPT{\"(.*?)\"}\%/<script type="text\/javascript\"\>$1<\/script>/g) {
      $needPostRenderingHandler = 0;
    }
}

sub _twistyBtn {
    my($theState, $session, $params, $theTopic, $theWeb) = @_;

    _addHeader();

	# not used yet:
	#my $triangle_right = '&#9658;';
	#my $triangle_down = '&#9660;';
	
    my $id = $params->{'id'};
    if (!defined $id || $id eq '') {
		return '';
	}
    my $idTag = $id.$theState if ( $theState) || '';
    
    my $defaultLink = ( $theState eq 'show' ) ? $prefShowLink : $prefHideLink;
    # link="" takes precedence over showlink="" and hidelink=""
    my $link = $params->{'link'};
    
    if (!defined $link) {
    	# if 'link' is not set, try 'showlink' / 'hidelink'
    	$link = $params->{$theState.'link'};
    }
    if (!defined $link) {
    	$link = $defaultLink || '';
    }

    my $img = $params->{$theState.'img'} || $params->{'img'} || '';
    my $imgright = $params->{$theState.'imgright'} || $params->{'imgright'} || '';
    my $imgleft = $params->{$theState.'imgleft'} || $params->{'imgleft'} || '';
    $img =~ s/['\"]//go;
    $imgright =~ s/['\"]//go;
    $imgleft =~ s/['\"]//go;
    my $imgTag = ($img ne '') ? '<img src="'.$img.'" border="0" alt="" />' : '';
    my $imgRightTag = ($imgright ne '') ? '<img src="'.$imgright.'" border="0" alt="" />' : '';
    my $imgLeftTag = ($imgleft ne '') ? '<img src="'.$imgleft.'" border="0" alt="" />' : '';        
    my $imgLinkTag = '<a href="#">'.$imgLeftTag.'<span class="twikiLinkLabel">'.$link.'</span>'.$imgTag.$imgRightTag.'</a>';
	
	my $isTrigger = 1;
    my $props = '';
    if ($idTag && $params) {
        my $cookieState = _readCookie($session, $idTag);
	    my @propList = _createHtmlProperties($theState, $idTag, $params, $isTrigger, $cookieState);
    	$props = @propList ? " ".join(" ",@propList) : '';
    }
    my $triggerTag = '<span'.$props.'>'.$imgLinkTag.'</span>';
    $triggerTag .= _createJavascriptTriggerCall($session, $idTag);
    
    return $triggerTag;
}

sub _createHtmlProperties {
	my($theState, $idTag, $params, $isTrigger, $cookieState) = @_;
	my $class = $params->{'class'} || '';
    my $start = $params->{start} || '';
    my $startHide = ($start eq 'hide');
    my $startShow = ($start eq 'show');
    my $firststart = $params->{'firststart'} || '';
    my $firstStartHide = ($firststart eq 'hide');
    my $firstStartShow = ($firststart eq 'show');
    my $remember = $params->{'remember'} || $prefRemember;
    my $noscript = $params->{'noscript'} || '';
    my $noscriptHide = ($noscript eq 'hide');
    
	my @classList = ();
    push (@classList, $class) if $class && !$isTrigger;
    push (@classList, 'twistyRememberSetting') if ($remember eq 'on');
    push (@classList, 'twistyForgetSetting') if ($remember eq 'off');
    push (@classList, 'twistyStartHide') if $startHide;
    push (@classList, 'twistyStartShow') if $startShow;
    push (@classList, 'twistyFirstStartHide') if $firstStartHide;
    push (@classList, 'twistyFirstStartShow') if $firstStartShow;
    
=pod

    # Mimic the rules in twist.js, function _update()
    
    if ($cookieState == $TWISTYPLUGIN_CONTENT_HIDDEN) {
        if ($isTrigger && $theState eq 'hide') {
            push (@classList, 'twistyHidden');
        }
        if (!$isTrigger) {
            push (@classList, 'twistyHidden');
        }
    }
    if ($cookieState == $TWISTYPLUGIN_CONTENT_SHOWN) {
        if ($isTrigger && $theState eq 'show') {
            push (@classList, 'twistyHidden');
        }
    }
    if (!$cookieState && $isTrigger) {
    	# don't assume javascript is on
    	# in case of no javascript, the controls should be hidden
    	push (@classList, 'twistyMakeVisible');
    }
    if ($isTrigger) {
    	push (@classList, 'twistyTrigger');
    }
    if (!$isTrigger) {
    	# content
    	push (@classList, 'twistyContent');
    	push (@classList, 'twistyMakeHidden') if !$noscriptHide; # don't set hidden directly but make it hidden with javascript, no browser without script will be able to see content
    	push (@classList, 'twistyMakeVisible') if $noscriptHide;
    }
    
=cut

    if ($isTrigger) {
    	push (@classList, 'twistyTrigger');
    	push (@classList, 'twistyMakeVisible');
    }
    if (!$isTrigger) {
    	# content
    	push (@classList, 'twistyContent');
    	push (@classList, 'twistyMakeHidden') if !$noscriptHide; # don't set hidden directly but make it hidden with javascript, no browser without script will be able to see content
    	push (@classList, 'twistyMakeVisible') if $noscriptHide;
    }
    
    my @propList = ();
    push (@propList, 'id="'.$idTag.'"');
    push (@propList, 'class="'.join(" ",@classList).'"');
    return @propList;
} 

=pod
If we write a JavaScript tag here, it will be removed at render time in 
Render.getRenderedVersion if configure option AllowInlineScript is not set.
So we create a semi-variable tag here and convert it to a JavaScript tag in #postRenderingHandler.
=cut

sub _createJavascriptTriggerCall {
	my($session, $idTag) = @_;

    $needPostRenderingHandler = 1; # notifies postRenderingHandler and beforeCommonTagsHandler
	return '%_TWISTYSCRIPT{"twiki.TwistyPlugin.init("'.$idTag.'");"}%';
}

sub _readCookie {
    my($session, $idTag) = @_;
    
    return '' if !$idTag;
    
    # which state do we use?
    my $query = $session->{cgiQuery};
    my $cookie = $query->cookie('TWIKIPREF');
    my $tag = $idTag;
    $tag =~ s/^(.*)(hide|show|toggle)$/$1/go;
    my $key = $TWISTYPLUGIN_COOKIE_PREFIX . $tag;
    return $TWISTYPLUGIN_CONTENT_SHOWN
      unless (defined($key) && defined($cookie));
    my $value = $cookie =~ s/$key\=(.*?)/$1/g;
    return $value;
}

sub _twistyWrapInDiv {
	 my($text) = @_;
	 return _twistyOpenDiv().$text._twistyCloseDiv();
}

sub _twistyOpenDiv {
	 return '<div class="twistyPlugin" style="display:inline;">';
}

sub _twistyCloseDiv {
	 return '</div><!-- END twistyPlugin-->';
}

sub _twistyWrapInSpan {
	 my($text) = @_;
	 return _twistyOpenSpan().$text._twistyCloseSpan();
}

sub _twistyOpenSpan {
	 return '<span class="twistyPlugin">';
}

sub _twistyCloseSpan {
	 return '</span><!-- END twistyPlugin-->';
}

1;
