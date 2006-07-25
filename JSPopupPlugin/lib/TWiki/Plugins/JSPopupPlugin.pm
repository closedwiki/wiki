# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 sven Dowideit, SvenDowideit@wikiring.com
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

=pod

---+ package JSPopupPlugin


=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::JSPopupPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName $WEB $TOPIC );
use vars qw( %TWikiCompatibility $popupSectionNumber );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'JSPopupPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in


=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    setupTWiki4Compatibility();
    TWiki::Func::registerTagHandler( 'POPUP', \&handlePopup );

    $WEB = $web;
    $TOPIC= $topic;
    $popupSectionNumber = 0;

    # Plugin correctly initialized
    return 1;
}


#this is only there to support the addition of HEAD sections
sub commonTagsHandler {
#    my ( $text, $topic, $web ) = @_;

#TODO: implement the regex for registerHandler
    
    return unless ($_[0] =~ /<\/head>/);
    return unless (keys(%{$TWikiCompatibility{HEAD}}) > 0);
    
    my $query = TWiki::Func::getCgiQuery();
    my $fromPopup = $query->param('fromPopup');
    return if (defined($fromPopup));#avoid nesting popups

        #fake up addToHead for cairo
    if ($TWiki::Plugins::VERSION eq 1.025) {
        my $htmlHeader = join(
            "\n",
            map { '<!--'.$_.'-->'.$TWikiCompatibility{HEAD}{$_} }
                keys %{$TWikiCompatibility{HEAD}});
        $_[0] =~ s/([<]\/head[>])/$htmlHeader$1/i if $htmlHeader;
        chomp($_[0]);

        %{$TWikiCompatibility{HEAD}} = ();
    }
}

#TODO:   * popuptexttype ="" - tml, rest
#TODO:      * TODO: delayedtml, javascript
#TODO:   * popuplocation="" - general location relative to the anchor (center, above, below, left, right) - center is default *TODO: only center and below are implemented*
#TODO:      * TODO: its currently relative to the mouse event, not the anchor
#TODO:      * TODO: add location on screen, not- relative to mouse.. (popup in top right)
#TODO:   * buttons="" - what buttons to show (ok, cancel, save...) *TODO*
#TODO:    * popuplocation="" - general location relative to the anchor (center, above, below, left, right) - center is default *TODO: only center and below are implemented*
sub handlePopup {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $default = $params->{_DEFAULT} || '';    #TODO: not sure what thus should be :)

    my $anchor = $params->{anchor};
    my $anchortype = $params->{anchortype} || 'onclick';
    my $popuptext = $params->{popuptext};
    my $popuptexttype = $params->{popuptexttype} || 'tml';
    my $popuplocation = $params->{popuplocation} || 'center';
    my $border = $params->{border} || 'on';
    my $buttons = $params->{buttons};
    my $evaluate = $params->{eval};
    
    my $output = '';
    if (defined($anchor)) {
        my $event = 'onclick="TWiki.JSPopupPlugin.openPopupSectional(event, \'popupSection'.$popupSectionNumber.'\')"';#ASSUME onclick
        if ($anchortype eq 'onmouseover') {
            $event = 'onmouseover="TWiki.JSPopupPlugin.openPopupSectional(event, \'popupSection'.$popupSectionNumber.'\')"';
        }
        $output .= '<span '.$event.'>'."\n".$anchor."\n".'</span>';
        
        #TODO: work out a way to mix tml mode in topic, and rest & delayedtml mode where it needs to be added in the postRenderingHandler (and can use JSON)
        if ($popuptexttype eq 'rest') {
            #nasty way to stop the url from getting TWiki'd
        } else {
            $popuptext = "\n".$popuptext."\n";
        }
        #TODO: this should really get added outside the topic like InlineEdit
        $output .= '<span style="display:none;" id="popupSection'.$popupSectionNumber.
            '" anchortype="'.$anchortype.
            '" type="'.$popuptexttype.
            '" location="'.$popuplocation.
            '" border="'.$border.'">'.$popuptext.'</span>';
    }
    $popupSectionNumber++;
    return $output;
}

sub postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;

    my $query = TWiki::Func::getCgiQuery();
    my $fromPopup = $query->param('fromPopup');
    return if (defined($fromPopup));#avoid nesting popups

   my $pluginPubUrl = TWiki::Func::getPubUrlPath().'/'.
            TWiki::Func::getTwikiWebname().'/'.$pluginName;

    #add the ComponentEdit JavaScript
    my $jscript = TWiki::Func::readTemplate ( 'jspopupplugin', 'javascript' );
    $jscript =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    addToHEAD($pluginName, $jscript);

    #TODO: evaluate the MAKETEXT's, and the variables....
    my $templateText = TWiki::Func::readTemplate ( 'jspopupplugin', 'popup' );
    $jscript =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    $templateText = TWiki::Func::expandCommonVariables( $templateText, $TOPIC, $WEB );

    $_[0] =~ s/(<\/body>)/$templateText $1/g;
}


##########################################################
#Cairo compat gumpf

# DEPRECATED in Dakar (postRenderingHandler does the job better)
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
$TWikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler {
  return postRenderingHandler( @_ );
}


sub registerRESTHandler {
    if ($TWiki::Plugins::VERSION eq 1.025) {
        my ($name, $funcRef) = @_;
        $TWikiCompatibility{RESTHandlers}{$pluginName.'.'.$name} = $funcRef;
    } else {
        TWiki::Func::registerRESTHandler(@_);
    }
}

#to fake TWiki4 restHanders in Cairo, use the view script (url is different too :( view/WEB/TOPIC?rest=InlineEditPlugin.restHandlerFuncName)
#and add this sub to your beforeCommonTagsHandler
sub fakeTWiki4RestHandlers {
    my ( $text, $topic, $web ) = @_;   #params passed on from beforeCommonTagsHandler
    #This is the view script based REST Handler cludge
   my $query = TWiki::Func::getCgiQuery();
   my $restCall = $query->param('rest');
    if (defined ($restCall) && defined($TWikiCompatibility{RESTHandlers}{$restCall})) {
        my $function = $TWikiCompatibility{RESTHandlers}{$restCall};
        print $query->header(
                    -content_type => 'text',
             );
        no strict 'refs';
        my $session = {};
        $session->{cgiQuery} = $query;
        my $result='';
        $result=&$function($session,$web,$topic);
        print $result;
        exit 1;
    }
}


sub addToHEAD {
    if ($TWiki::Plugins::VERSION eq 1.025) {
        my ($name, $text) = @_;
        $TWikiCompatibility{HEAD}{$name} = $text;
    } else {
        TWiki::Func::addToHEAD( @_ );
    }
}

sub setupTWiki4Compatibility {
    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.025 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm (tested on Cairo and TWiki-4.0))" );
        return 0;
    } elsif ($TWiki::Plugins::VERSION eq 1.025) {
        #Cairo
        %{$TWikiCompatibility{HEAD}} = ();
        %{$TWikiCompatibility{HEAD}} = ();
    } else {
        #TWiki-4.0 and above
    }
}

1;
