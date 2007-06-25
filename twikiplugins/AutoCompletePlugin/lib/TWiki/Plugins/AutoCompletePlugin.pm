# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Andrew Jones, andrewjones86@googlemail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::AutoCompletePlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4.2';
$SHORTDESCRIPTION = 'Provides an Autocomplete input field based on Yahoo\'s User Interface Library';

$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'AutoCompletePlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'AUTOCOMPLETE', \&_handleTag );

    # Plugin correctly initialized
    return 1;
}

# =========================
# handles autocomplete boxes in topics
sub _handleTag {
#    my($session, $params, $theTopic, $theWeb) = @_;
  
    return _createTextfield($_[1]);
}

# Used to provide autocomplete text boxes in forms
sub renderFormFieldForEditHandler {
    my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;
    return undef unless $type eq 'autocomplete';

    my %params = TWiki::Func::extractParameters($possibleValues);
    
    $params{name} = $name;
    $params{size} = $size;
    $params{value} = $value;

    return _createTextfield(\%params);

}

# =========================
sub _createTextfield {
    my $params = shift;

    unless( $params->{name} ){
        return _returnError( "The 'name' parameter is required." );
    }
    unless( TWiki::Func::topicExists( undef, $params->{datatopic} ) ){
        return _returnError( "$params->{datatopic} does not exist." );
    }

    _addJavascript(
        $params->{name},
        $params->{datatopic},
        $params->{datasection},
        $params->{itemformat} || 'item',
        $params->{delimchar} || 'null'
    );
    _addYUI();
    _addStyle(
        $params->{name},
        $params->{size} || '20em',
        $params->{formname}
    );

    my $textfield = CGI::textfield( { id => $params->{name} . 'Input',
                                      name => $params->{name},
                                      class => 'twikiInputField twikiEditFormTextField',
                                      value => $params->{value} } );

    my $results = '<div id="' . $params->{name} . 'Results"></div>';

    return ($textfield . "\n" . $results);

}

# =========================
# adds the javascript that makes it all work
sub _addJavascript {
    my ( $name, $datatopic, $datasection, $itemformat, $delemchar ) = @_;

    my $Input = $name . 'Input';
    my $Results = $name . 'Results';

    my $js = <<"EOT";
<script type="text/javascript">
    twiki.Event.addLoadEvent(initAutoComplete, true);
    function initAutoComplete() {
        var topics = [%INCLUDE{"$datatopic" section="$datasection"}%];
        var oACDS = new YAHOO.widget.DS_JSArray(topics);
        var topicAC = new YAHOO.widget.AutoComplete("$Input", "$Results", oACDS);
        topicAC.queryDelay = 0;
        topicAC.autoHighlight = true;
        topicAC.useIFrame = false;
        topicAC.prehighlightClassName = "yui-ac-prehighlight";
        topicAC.typeAhead = false;
        topicAC.delimChar = "$delemchar";
        topicAC.allowBrowserAutocomplete = false;
        topicAC.useShadow = false;
        topicAC.formatResult = function(item, query) { return $itemformat; };
    }
</script>
EOT

    TWiki::Func::addToHEAD($pluginName . '_js', $js);
}

# adds the YUI Javascript files from header
# these are from the YahooUserInterfaceContrib, if installed
# or directly from the internet (See http://developer.yahoo.com/yui/articles/hosting/)
sub _addYUI {

    my $yui;
        
    eval 'use TWiki::Contrib::YahooUserInterfaceContrib';
    if (! $@ ) {
        _Debug( 'YahooUserInterfaceContrib is installed, using local files' );
        $yui = '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
             . '<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/YahooUserInterfaceContrib/build/autocomplete/autocomplete-min.js"></script>'
    } else {
        _Debug( 'YahooUserInterfaceContrib is not installed, using Yahoo servers' );
        $yui = '<script type="text/javascript" src="http://yui.yahooapis.com/2.2.2/build/yahoo-dom-event/yahoo-dom-event.js"></script>'
             . '<script type="text/javascript" src="http://yui.yahooapis.com/2.2.2/build/autocomplete/autocomplete-min.js"></script>';
    }

    TWiki::Func::addToHEAD($pluginName . '_yui', $yui);    
}

# adds style sheet
sub _addStyle {
    my ( $name, $size, $formName ) = @_;

    my $Input = '#' . $name . 'Input';
    my $Results = '#' . $name . 'Results';

    my $style = <<"EOT";
<style type="text/css" media="all">
$formName form {
    position:relative;
}
$Input {
    width:$size;
}
$Results {
    position:relative;
    width:$size;
}
$Results .yui-ac-content {
    position:absolute;
    width:100%;
    font-size:94%; /* mimic twikiInputField */
    padding:0 .2em; /* mimic twikiInputField */
    border-width:1px;
    border-style:solid;
    border-color:#ddd #888 #888 #ddd;
    background:#fff;
    overflow:hidden;
    z-index:9050;
}
$Results .yui-ac-shadow {
    display:none;
    position:absolute;
    margin:2px;
    width:100%;
    background:#ccc;
    z-index:9049;
}
$Results ul {
    margin:0;
    padding:0;
    list-style:none;
}
$Results li {
    cursor:default;
    white-space:nowrap;
    margin:0 -.2em;
    padding:.1em .2em; /* mimic twikiInputField */
}
$Results li.yui-ac-highlight,
$Results li.yui-ac-prehighlight {
    background:#06c; /* link blue */
    color:#fff;
}
</style>
EOT
    
    TWiki::Func::addToHEAD($pluginName . '_style', $style);
}

# =========================
sub _Debug {
    my $text = shift;

    my $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;

    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}: $text" ) if $debug;
}

sub _returnError {
    my $text = shift;

    _Debug( $text );

    return "<span class='twikiAlert'>${pluginName} error: $text</span>";
}

1;
