# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
#
# For licensing info read license.txt file in the TWiki root.
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
=begin twiki

---+ TWiki::UI::Edit
Edit command handler

=cut
package TWiki::UI::Edit;

use strict;
use TWiki;
use TWiki::Form;
use TWiki::Plugins;
use TWiki::Prefs;
use TWiki::Store;
use TWiki::UI;
use Error qw( :try );
use TWiki::UI::OopsException;

=pod

---++ edit( $webName, $topic, $userName, $query )
Edit handler. Most parameters are in the CGI query:
| =cmd= | |
| =breaklock= | if defined, breaks any pre-existing lock before edit |
| =onlywikiname= | if defined, requires a wiki name for the topic name if this is a new topic |
| =onlynewtopic= | if defined, and the topic exists, then moans |
| =formtemplate= | name of the form for the topic; will replace existing form |
| =templatetopic= | name of the topic to copy if creating a new topic |
| =skin= | skin to use |
| =topicparent= | what to put in the topic prent meta data |
| =text= | text that will replace the old topic text if a formtemplate is defined (what the heck is this for?) |
| =contenttype= | optional parameter that defines the application type to write into the CGI header. Defaults to text/html. |

=cut
sub edit {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $userName = $session->{userName};

    my $saveCmd = $query->param( 'cmd' ) || "";
    my $breakLock = $query->param( 'breaklock' ) || "";
    my $onlyWikiName = $query->param( 'onlywikiname' ) || "";
    my $onlyNewTopic = $query->param( 'onlynewtopic' ) || "";
    my $formTemplate  = $query->param( "formtemplate" ) || "";
    my $templateTopic = $query->param( "templatetopic" ) || "";
    # apptype is undocumented legacy
    my $cgiAppType = $query->param( 'contenttype' ) ||
      $query->param( 'apptype' ) || "text/html";
    my $skin = $session->getSkin();
    my $theParent = $query->param( 'topicparent' ) || "";
    my $ptext = $query->param( 'text' );

    my $getValuesFromFormTopic = ( ( $formTemplate ) && ( ! $ptext ) );

    TWiki::UI::checkWebExists( $session, $webName, $topic );
    TWiki::UI::checkMirror( $session, $webName, $topic );

    my $tmpl = "";
    my $text = "";
    my $meta = "";
    my $extra = "";
    my $topicExists  = $session->{store}->topicExists( $webName, $topic );

    # Prevent editing existing topic?
    if( $onlyNewTopic && $topicExists ) {
        # Topic exists and user requested oops if it exists
        throw TWiki::UI::OopsException( $webName, $topic, "createnewtopic" );
    }

    # prevent non-Wiki names?
    if( ( $onlyWikiName )
        && ( ! $topicExists )
        && ( ! TWiki::isValidTopicName( $topic ) ) ) {
        # do not allow non-wikinames, redirect to view topic
        # SMELL: this should be an oops, shouldn't it?
        $session->redirect( $session->getScriptUrl( $webName, $topic, "view" ));
        return;
    }

    my $wikiUserName = $session->{wikiUserName};

    if( $topicExists ) {
        ( $meta, $text ) =
          $session->{store}->readTopic( $wikiUserName, $webName,
                                    $topic, undef, 1 );
    }

    # If you want to edit, you have to be able to view and change.
    TWiki::UI::checkAccess( $session, $webName, $topic,
                            "view", $wikiUserName );
    TWiki::UI::checkAccess( $session, $webName, $topic,
                            "change", $wikiUserName );

    if( $saveCmd ) {
        TWiki::UI::checkAdmin( $session, $webName, $topic, $wikiUserName );
    }

    # Check for locks
    my( $lockUser, $lockTime ) =
      $session->{store}->topicIsLockedBy( $webName, $topic );
    if( ( ! $breakLock ) && ( $lockUser ) ) {
        # warn user that other person is editing this topic
        $lockUser = $session->{users}->userToWikiName( $lockUser );
        use integer;
        $lockTime = ( $lockTime / 60 ) + 1; # convert to minutes
        my $editLock = $TWiki::editLockTime / 60;
        throw TWiki::UI::OopsException( $webName, $topic, "locked",
                                        $lockUser, $editLock, $lockTime );
    }
    $session->{store}->lockTopic( $webName, $topic );

    my $templateWeb = $webName;

    # Get edit template, standard or a different skin
    $tmpl = $session->{templates}->readTemplate( "edit", $skin );
    unless( $topicExists ) {
        if( $templateTopic ) {
            if( $templateTopic =~ /^(.+)\.(.+)$/ ) {
                # SMELL: this is pointless, according to the spec of readTopic
                # is "Webname.SomeTopic"
                $templateWeb   = $1;
                $templateTopic = $2;
            }

            ( $meta, $text ) =
              $session->{store}->readTopic( $wikiUserName, $templateWeb,
                                        $templateTopic, undef, 0 );
        }
        unless( $text ) {
            ( $meta, $text ) = TWiki::UI::readTemplateTopic( $session, "WebTopicEditTemplate" );
        }
        $extra = "(not exist)";

        # If present, instantiate form
        if( ! $formTemplate ) {
            my %args = $meta->findOne( "FORM" );
            $formTemplate = $args{"name"};
        }

        $text = $session->expandVariablesOnTopicCreation( $text, $userName );
    }

    # parent setting
    if( $theParent eq "none" ) {
        $meta->remove( "TOPICPARENT" );
    } elsif( $theParent ) {
        if( $theParent =~ /^([^.]+)\.([^.]+)$/ ) {
            my $parentWeb = $1;
            if( $1 eq $webName ) {
                $theParent = $2;
            }
        }
        $meta->put( "TOPICPARENT", ( "name" => $theParent ) );
    }
    $tmpl =~ s/%TOPICPARENT%/$theParent/;

    # Processing of formtemplate - comes directly from query parameter formtemplate , 
    # or indirectly from webtopictemplate parameter.
    my $oldargsr;
    if( $formTemplate ) {
        my @args = ( name => $formTemplate );
        $meta->remove( "FORM" );
        if( $formTemplate ne "none" ) {
            $meta->put( "FORM", @args );
        } else {
            $meta->remove( "FORM" );
        }
        $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
        if( defined $ptext ) {
            $text = TWiki::decodeSpecialChars( $ptext );
        }
    }

    if( $saveCmd eq "repRev" ) {
        $text = $session->{store}->readTopicRaw( $wikiUserName, $webName, $topic,
                                             undef, 0 );
    }

    $text =~ s/&/&amp\;/go;
    $text =~ s/</&lt\;/go;
    $text =~ s/>/&gt\;/go;
    $text =~ s/\t/   /go;

    $session->{plugins}->beforeEditHandler( $text, $topic, $webName ) unless( $saveCmd eq "repRev" );

    if( $TWiki::doLogTopicEdit ) {
        # write log entry
        $session->writeLog( "edit", "$webName.$topic", $extra );
    }

    if( $saveCmd ) {
        $tmpl =~ s/\(edit\)/\(edit cmd=$saveCmd\)/go;
    }
    $tmpl =~ s/%CMD%/$saveCmd/go;
    $tmpl = $session->handleCommonTags( $tmpl, $topic );
    $tmpl = $session->{renderer}->renderMetaTags( $webName, $topic, $tmpl, $meta, $saveCmd eq "repRev" );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl );

    # Don't want to render form fields, so this after getRenderedVersion
    my %formMeta = $meta->findOne( "FORM" );
    my $form = "";
    $form = $formMeta{"name"} if( %formMeta );
    if( $form && $saveCmd ne "repRev" ) {
        my @fieldDefs = $session->{form}->getFormDef( $templateWeb, $form );

        if( ! @fieldDefs ) {
            throw TWiki::UI::OopsException( $webName, $topic, "noformdef" );
        }
        my $formText = $session->{form}->renderForEdit( $webName, $topic, $form, $meta, $getValuesFromFormTopic, @fieldDefs );
        $tmpl =~ s/%FORMFIELDS%/$formText/go;
    } elsif( $saveCmd ne "repRev" && $session->{prefs}->getPreferencesValue( "WEBFORMS", $webName )) {
        # follows a hybrid html monster to let the 'choose form button' align at
        # the right of the page in all browsers
        $form = '<div style="text-align:right;"><table width="100%" border="0" cellspacing="0" cellpadding="0" class="twikiChangeFormButtonHolder"><tr><td align="right">'
          . &TWiki::Form::chooseFormButton( "Add form" )
            . '</td></tr></table></div>';
        $tmpl =~ s/%FORMFIELDS%/$form/go;
    } else {
        $tmpl =~ s/%FORMFIELDS%//go;
    }

    $tmpl =~ s/%FORMTEMPLATE%//go; # Clear if not being used
    $tmpl =~ s/%TEXT%/$text/go;
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags

    $session->writeCompletePage( $tmpl, 'edit', $cgiAppType );
}

1;
