# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Sven Dowideit SvenDowideit@wikiring.com
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

---+ package InlineEditPlugin

This is the InlineEditPlugin TWiki plugin that allows the user to edit a TWiki topic from the view
screen without requireing a round trip to the server

=cut

use strict;

package TWiki::Plugins::InlineEditPlugin;

use JSON;

use vars qw( $VERSION $pluginName $debug  $currentWeb %vars %sectionIds $lastSection
    $templateText $WEB $TOPIC $USER $EDITORSLIST @EDITORS $MODERN $sendHTML $minimumSectionLength $supportedSkins $tml2html $html2tml);
use vars qw( %TWikiCompatibility %changedSections);

$VERSION = '0.900';
$pluginName = 'InlineEditPlugin';  # Name of this Plugin

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

not used for plugins specific functionality at present

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    setupTWiki4Compatibility();
    registerRESTHandler('getTopicState', \&REST_getTopicState);
    registerRESTHandler('setTopicLock', \&REST_setTopicLock);

    if( defined( &TWiki::Func::normalizeWebTopicName )) {
        $MODERN = 1;
    }

	$WEB = $web;
	$TOPIC= $topic;
    $USER = $user;
	$templateText = '';
    $EDITORSLIST = TWiki::Func::getPluginPreferencesValue( 'EDITORS' ) || 'textarea';
    @EDITORS = split(/[, ]/, $EDITORSLIST);
	$sendHTML = TWiki::Func::getPluginPreferencesValue( 'SENDHTML' ) || 0;
    $minimumSectionLength = TWiki::Func::getPluginPreferencesValue( 'MINIMUMSECTIONLENGTH' ) || 0;
    $supportedSkins = TWiki::Func::getPluginPreferencesValue( 'SKINS' ) || '';
    $lastSection = 0;

    # Plugin correctly initialized
    return 1;
}

###############################################################
#Plugin handlers

sub beforeCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my ( $text, $topic, $web ) = @_;

    return unless (pluginApplies('view'));
    #only process the topic text,not the templates
    if ($TWiki::Plugins::VERSION eq 1.025) {
    } else {
        return unless ( TWiki::Func::getContext()->{'body_text'});
    }

    fakeTWiki4RestHandlers(@_);

    #TODO:why is this called multiple times?
    return unless ($lastSection == 0);  #TODO: add naming of sections code so it actually works
    #This is a whole topic edit - non-sectional
    #$sectionIds{$lastSection} = $_[0];
    #$_[0] = "<div class='inlineeditTopicHTML' id='".$lastSection."'>\n".$_[0]."\n</div>";
    #$lastSection++;

#TODO: think about tuning this - but simple is more re-producable
#save will need to look at the verision that its comming from , not the head..
    my $newDoc = '';
    my $dashes = '';
    my $sections = getSection($_[0]);
    foreach my $sec (@{$sections}) {
            $lastSection++;
            $sectionIds{$lastSection} = $sec;
            $newDoc .= "<div id='inlineeditTopicHTML_".$lastSection."' class='inlineeditTopicHTML'>\n".$dashes.$sec."\n</div>";
    }
    $_[0] = $newDoc;
}

sub beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ## my ( $text, $topic, $web, $meta ) = @_;

    return unless (pluginApplies('save'));

   my $query = TWiki::Func::getCgiQuery();

   return unless defined($query->param('inlineeditsave'));

#detect if we've been sent a JSON package, and un-ravel that.
    my $dataType = $query->param('dataType') || '';
    if ($dataType eq 'JSON') {
        my %changedSections = ();
        my %newSections = ();
        my $data = $query->param('data') || '';
        my @jsons = split('####', $data);
        foreach my $json (@jsons) {
            my $obj = jsonToObj($json);
            my $sectionName = $obj->{topicSection};
            $sectionName =~ s/"//g;
            $changedSections{$sectionName} = $obj;
        }
        my ($meta,$text) = TWiki::Func::readTopic($_[2],$_[1]);
        $text =~ s/^%META:TOPICINFO{.*}%$//g;
        my $sections = getSection($text);
        my $count = 1;

        for my $sec (@{$sections}) {
            if (!defined($changedSections{$count})) {
                $changedSections{$count} = ();
                $changedSections{$count}->{value} = $sec;
            }
            $count++;
        }
        $_[0] = '';
        my $sectionOrder = jsonToObj($query->param('sectionOrder') || '');
        for my $sectionName (@$sectionOrder) {
            $_[0] .= $changedSections{$sectionName}->{value};
        }

    } else {
        #TODO: deprecated
        #the old one section only save (still used by wikiwyg and TinyMCE)
        my $section = $query->param('section');
        my $sourceRevision = $query->param('originalrev');#TODO:make sure that there has not been an edit in between
        my $htmlSection = $query->param( 'html2tml' );

        if ($htmlSection) {
            #convert from html2tml
            convertHtml2Tml($_[0], $_[1], $_[2]);
        }
        if ($section > 0) {
            my $sectionText=$_[0];
            $_[0] = '';
            my ($meta,$text) = TWiki::Func::readTopic($_[2],$_[1]);
            $text =~ s/^%META:TOPICINFO{.*}%$//g;
            my $sections = getSection($text);
            my $count = 1;

            for my $sec (@{$sections}) {
                if ($count eq $section) {
                    $_[0] .= $sectionText;
                } else {
                    $_[0] .= $sec;
                }
                $count++;
            }
        }
    }

}

#wikiwyg uses XHTTPRequest to save, and thus save should _just_ return success, not the full view
sub afterSaveHandler() {
    my ( $text, $topic, $web, $errors ) = @_;

   my $query = TWiki::Func::getCgiQuery();
   my $replywitherrors = $query->param('replywitherrors') || 0;
    if ($replywitherrors == 1) {
        print $query->header(
                    -content_type => 'text',
             );
        my $data = $query->param('data') || '';
        my @jsons = split('####', $data);
        foreach my $json (@jsons) {
            my $obj = jsonToObj($json);
            print "\n<p />".$obj->{topicSection};
            print "\n<p />".$obj->{value};
        }
        my $sectionOrder = jsonToObj($query->param('sectionOrder') || '');
        print "\n<p />order: ".join(', ', @$sectionOrder);

        print $errors;
        exit 1;
    }
}

sub postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;
    return unless (pluginApplies('view'));

    my $scriptHeader = '';

   my $pluginPubUrl = TWiki::Func::getPubUrlPath().'/'.
            TWiki::Func::getTwikiWebname().'/'.$pluginName;

    #add the initialisation javascript
    my $jscript .= TWiki::Func::readTemplate ( 'inlineeditplugin', 'prejavascript' );
    $scriptHeader .= $jscript;

    my $hiddenStyle = 'style="display:none;" ';#visibility:hidden;height:0px;" ';
    my $output = '';

    #disable if the user does not have edit permissions
    #TODO: need to check if this user is allowed to run the edit / save script (templateLogin makes the checkAccessPermission check a little less useful)
    if (TWiki::Func::checkAccessPermission( 'CHANGE', $USER, undef, $TOPIC, $WEB ) != 1) {
        $scriptHeader .= TWiki::Func::readTemplate ( 'inlineeditplugin', 'nopermission' );

        #lets add an InfoSection for the topic.
        my $section = 0;
        my ($response, $date, $user, $rev, $comment, $oopsUrl, $loginName, $unlockTime, $viewUrl, $saveUrl, $restUrl, $sectionName) = _getTopicState($WEB, $TOPIC, $section);
        my $topicState = '<div class="inlineeditTopicInfo" '.$hiddenStyle.'id="inlineeditTopicInfo_'.$section.'" '.'>'.$response.'</div>';
        $output .= $topicState;
    } else {
    	#add the inlineEdit JavaScript
        foreach my $EDITOR (@EDITORS) {
            $jscript = TWiki::Func::readTemplate ( 'inlineeditplugin', $EDITOR );
            $scriptHeader .= $jscript;
        }

        foreach my $key (keys(%sectionIds)) {
    #TODO: exctract into a func to use with sectional edit
            my $section = $key;
            my ($response, $date, $user, $rev, $comment, $oopsUrl, $loginName, $unlockTime, $viewUrl, $saveUrl, $restUrl, $sectionName) = _getTopicState($WEB, $TOPIC, $section);

            #my ($meta, $tml) = TWiki::Func::readTopic($WEB, $TOPIC);
            my $tml = $sectionIds{$key};

            $output .= '<div class="inlineeditTopicTML" '.$hiddenStyle.'id="inlineeditTopicTML_'.$section.'" '.'>'.$tml.'</div>';
            #these need to remain in seperate divs to avoid needing to escape them
    	   if ( $sendHTML == 1) {
                unless ( $tml2html ) {
                    require TWiki::Plugins::WysiwygPlugin::TML2HTML;
                    $tml2html = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
                }
                #TODO: move out to template
                my $formelements = '<input name="text" type="hidden" value=""><input name="inlineeditsave" type="hidden" value="1"><input name="html2tml" type="hidden" value="1"><input name="section" type="hidden" value="'.$section.'"><input name="rev" type="hidden" value="'.$rev.'">';
                my $converted = $tml2html->convert( $tml, {
                                                    getViewUrl=>  \&TWiki::Plugins::WysiwygPlugin::getViewUrl,
                                                    expandVarsInURL => \&TWiki::Plugins::WysiwygPlugin::expandVarsInURL,        #TODO: not sure if this will work without more magic
                                                    markVars=>1} );
                $converted = $tml2html->cleanup( $converted );
                my $tml2htmloutput .= '<form action="'.$saveUrl.'" method="POST"><div class="inlineeditTopicTML2HTML" '.$hiddenStyle.'id="inlineeditTopicTML2HTML_'.$section.'" '.'>'.$converted.'</div>'.$formelements.'</form>';
                #do this so that the editor form div directly follows the HTML we are editing
                $_[0] =~ s/(<div id=.inlineeditTopicHTML_)/$tml2htmloutput$1/g;#TODO: this presumes only one editor
            } else {
            }
            my $topicState = '<div class="inlineeditTopicInfo" '.$hiddenStyle.'id="inlineeditTopicInfo_'.$section.'" '.'>'.$response.'</div>';
            $output .= $topicState;
        }
    }
    $_[0] =~ s/(<\/body>)/$output$1/g;

    #add the initialisation javascript
    $jscript = TWiki::Func::readTemplate ( 'inlineeditplugin', 'javascript' );
    $scriptHeader .= $jscript;
    $scriptHeader =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;

    addToHEAD($pluginName.'-javascript', $scriptHeader);
}

# DEPRECATED in Dakar (postRenderingHandler does the job better)
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
$TWikiCompatibility{endRenderingHandler} = 1.1;
$TWikiCompatibility{beforeEditHandler} = 1.1;
sub endRenderingHandler {
  return postRenderingHandler( @_ );
}
sub beforeEditHandler
{
#my( $text, $topic, $web, $meta ) = @_;
    fakeTWiki4RestHandlers(@_);
#  #   my %contexts = %{TWiki::Func::getContext()};
#    die 'gibber'.join(', ', keys(%contexts)) if ($_[1] =~ /SvenDowideit/ );

    unless ( $TWiki::Plugins::SESSION->{store}->topicExists( $_[2], $_[1] )) {
        beforeCommonTagsHandler(@_);
#HiJack the creatio of new topics

#        throw TWiki::OopsException( 'accessdenied',
#                                    def => 'no_such_topic',
#                                    web => $_[2],
#                                    topic => $_[1],
#                                    params => 'view' );
    }

}

##############################################################
#REST Handlers
sub REST_getTopicState {
   my $session = shift;

   my $topicName = $session->{cgiQuery}->param('topicName') || return 'topic not specified';
   my $section = $session->{cgiQuery}->param('section') || 0;
   my ($web, $topic) = ('', $topicName);
   ($web, $topic) = normalizeWebTopicName($web, $topic);

    my ($response, $date, $user, $rev, $comment, $oopsUrl, $loginName, $unlockTime) = _getTopicState($web, $topic, $section);
   return $response;
}

#TODO: seperate out into topic state and info that is for this plugin
sub REST_setTopicLock {
   my $session = shift;

   my $topicName = $session->{cgiQuery}->param('topicName') || return 'topic not specified';
   my $section = $session->{cgiQuery}->param('section') || 0;
   my ($web, $topic) = ('', $topicName);
   ($web, $topic) = normalizeWebTopicName($web, $topic);

   TWiki::Func::setTopicEditLock($web, $topic, 1);

    my ($response, $date, $user, $rev, $comment, $oopsUrl, $loginName, $unlockTime) = _getTopicState($web, $topic, $section);
   return $response;
}

##############################################################
#supporting functions

#return false if this plugin should not be active for this call
sub pluginApplies {
    my $scriptContext = shift;

#TODO: test for command line / for robots / other scripted access

    if ($TWiki::Plugins::VERSION > 1.025) {
        return 0 unless( TWiki::Func::getContext()->{$scriptContext} );
    } else {
        return 0 unless (TWiki::getPageMode() eq 'html');
        if( $ENV{"SCRIPT_FILENAME"} && $ENV{"SCRIPT_FILENAME"} =~ /^(.+)\/([^\/]+)$/ ) {
            my $script = $2;
            return 0 unless ($script eq $scriptContext);
        }
    }

    #lets only apply to the skins i've tested on (nat, pattern, classic, koala)
    my @supported = split(/[, ]/, $supportedSkins);
    my @skinset = split(/[, ]/, TWiki::Func::getSkin());
    foreach my $skin (@skinset) {
        return 0 unless (grep {$skin eq $_ } @supported);
    }

    my $cgiQuery = TWiki::Func::getCgiQuery();
    #lets only work in text/html....
    #and not with any of the 'special' options (rev=, )
    my $getViewRev = $cgiQuery->param('rev');
    my $getViewRaw = $cgiQuery->param('raw');
    my $getViewContentType = $cgiQuery->param('contenttype');
    my $getViewTemplate = $cgiQuery->param('template');
    return 0 if ( (defined($getViewRev)) ||
                                    (defined($getViewRaw)) ||
                                    (defined($getViewContentType)) ||
                                    (defined($getViewTemplate)) );

    return 1;   #TRUE
}

#TODO: seperate this into a JavaScript TopicInfoPlugin and the InlineEditPlugin specific info.
sub _getTopicState {
   my ($web, $topic, $section) = @_;

   my ( $date, $user, $rev, $comment ) = TWiki::Func::getRevisionInfo($web, $topic);

   #TODO: you can't trust checkTopicEditLock in Cairo - if its locked by you, it returns as though there is no lock
   my ( $oopsUrl, $loginName, $unlockTime ) = TWiki::Func::checkTopicEditLock( $web, $topic );
   my $leaseduserWikiName = TWiki::Func::userToWikiName($loginName);
   #TODO: remove lock on save?
#   my $saveUrl = TWiki::Func::getScriptUrl( $WEB, $TOPIC, 'save').'?inlineeditsave=1;html2tml=1;section='.$section.';originalrev='.$rev;
   my $saveUrl = TWiki::Func::getScriptUrl( $WEB, $TOPIC, 'save').'?inlineeditsave=1;section='.$section.';originalrev='.$rev;
#TODO: make this param up to the editor
#   $saveUrl .= ';html2tml=1' if ( $EDITOR ne 'textarea');
   my $viewUrl = TWiki::Func::getScriptUrl( $WEB, $TOPIC, 'view').'?rev='.$rev;
   my $restUrl;
   if ($TWiki::Plugins::VERSION > 1.025) {
       $restUrl = TWiki::Func::getScriptUrl( 'InlineEditPlugin', 'setTopicLock', 'rest');#TODO:groan
   } else {
       $restUrl = TWiki::Func::getScriptUrl( $WEB, $TOPIC, 'view');
   }
   my $authedRestUrl;
   if ($TWiki::Plugins::VERSION > 1.025) {
        #TODO: how do i ensure rest is authed
       $authedRestUrl = TWiki::Func::getScriptUrl( 'InlineEditPlugin', 'setTopicLock', 'rest');#TODO:groan
   } else {
       $authedRestUrl = TWiki::Func::getScriptUrl( $WEB, $TOPIC, 'edit');
   }


   my $sectionName = $viewUrl.';section='.$section;
   my $wikiusername = TWiki::Func::getWikiUserName();
   my $browserLogin =  TWiki::Func::wikiToUserName($wikiusername);

 my $obj = {
    topicName   => $web.$topic,
    topicRev   =>$rev ,
    topicDate   => $date,
    topicUser   =>$user ,
    topicSection   => $section,
    sectionName   => $sectionName,
    leasedBy   => $leaseduserWikiName,
    leasedByLogin   => $loginName,
    leasedFor   => $unlockTime,
    oopsUrl   => $oopsUrl,
    viewUrl   => $viewUrl ,
    saveUrl   => $saveUrl,
    restUrl   => $restUrl,
    authedRestUrl   =>$authedRestUrl ,
    me   => $wikiusername,
    browserLogin => $browserLogin,
    Infoend => 0
 };

   return (objToJson($obj), $date, $user, $rev, $comment, $oopsUrl, $loginName, $unlockTime, $viewUrl, $saveUrl, $restUrl, $sectionName);
}

#TODO: ffs use references
#if sectionNumber is not specified, return a list of all sections
sub getSection {
    my $text = shift;
    my $sectionNumber = shift || -1;

    my @sections = ($text);
    if ($minimumSectionLength > 0) {
        @sections = split(/(\n\n)/, $text);
        #TODO: re-combine sections that are too small
    }
    if ($sectionNumber == -1) {
        return \@sections;
    } else {
        die 'not enough sections' if ($#sections <= $sectionNumber);
        return $sections[$sectionNumber];
    }
}

sub convertHtml2Tml {
    #copied from WysiwygPlugin, because its beforeSaveHandler makes asshumptions
     unless( $html2tml ) {
        require TWiki::Plugins::WysiwygPlugin::HTML2TML;

        $html2tml = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    }


    unless( $MODERN ) {
        # undo the munging that has already been done (grrrrrrrrrr!!!!)
        $_[0] =~ s/\t/   /g;
    }

    $_[0] = $html2tml->convert(
        $_[0],
        {
            web => $_[2],
            topic => $_[1],
            convertImage => \&TWiki::Plugins::WysiwygPlugin::convertImage,
            rewriteURL => \&TWiki::Plugins::WysiwygPlugin::postConvertURL,  #TODO: don't know if this has any chance of working ;((((
        }
       );

    unless( $MODERN ) {
        # redo the munging
        $_[0] =~ s/   /\t/g;
    }
}

##########################################################
#Cairo compat gumpf

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

#TODO:can i make this TWikiCompat too?
#this is only there to support the addition of HEAD sections
sub commonTagsHandler {
#    my ( $text, $topic, $web ) = @_;

    return unless ($_[0] =~ /<\/head>/);
     return unless (keys(%{$TWikiCompatibility{HEAD}}) > 0);

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

sub normalizeWebTopicName {
    my ($theWeb, $theTopic) = @_;
    my $webName = '';
    my $topicName = '';

    if ($TWiki::Plugins::VERSION eq 1.025) {
        #Cairo
        ($webName, $topicName) = TWiki::Store::normalizeWebTopicName($theWeb, $theTopic);
    } else {
        ($webName, $topicName) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);
    }
    return ($webName, $topicName);
}

1;
