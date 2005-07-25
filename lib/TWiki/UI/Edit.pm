# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::UI::Edit
Edit command handler

=cut
package TWiki::UI::Edit;

use strict;
use Assert;
use TWiki;
use TWiki::Form;
use TWiki::Plugins;
use TWiki::Prefs;
use TWiki::Store;
use TWiki::UI;
use Error qw( :try );
use TWiki::OopsException;
use CGI qw( -any );

=pod

---++ StaticMethod edit( $session )

Edit command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Most parameters are in the CGI query:

| =cmd= | Undocumented save command, passed on to save script |
| =onlywikiname= | if defined, requires a wiki name for the topic name if this is a new topic |
| =onlynewtopic= | if defined, and the topic exists, then moans |
| =formtemplate= | name of the form for the topic; will replace existing form |
| =templatetopic= | name of the topic to copy if creating a new topic |
| =skin= | skin(s) to use |
| =topicparent= | what to put in the topic prent meta data |
| =text= | text that will replace the old topic text if a formtemplate is defined (what the heck is this for?) |
| =contenttype= | optional parameter that defines the application type to write into the CGI header. Defaults to text/html. |
| =action= | Optional. If supplied, use the edit${action} template instead of the standard edit template. An empty value means edit both form and text, "form" means edit form only, "text" means edit text only |


=cut

sub edit {
    my $session = shift;

    $session->enterContext( 'edit' );

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $user = $session->{user};

    # empty means edit both form and text, "form" means edit form only,
    # "text" means edit text only
    my $editaction = lc($query->param( 'action' )) || "";

    my $saveCmd = $query->param( 'cmd' ) || '';
    my $onlyWikiName = $query->param( 'onlywikiname' ) || '';
    my $onlyNewTopic = $query->param( 'onlynewtopic' ) || '';
    my $formTemplate  = $query->param( 'formtemplate' ) || '';
    my $templateTopic = $query->param( 'templatetopic' ) || '';
    # apptype is undocumented legacy
    my $cgiAppType = $query->param( 'contenttype' ) ||
      $query->param( 'apptype' ) || 'text/html';
    my $skin = $session->getSkin();
    my $theParent = $query->param( 'topicparent' ) || '';
    my $ptext = $query->param( 'text' );
    my $store = $session->{store};

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'edit' );
    TWiki::UI::checkMirror( $session, $webName, $topic );

    my $tmpl = '';
    my $text = '';
    my $meta = '';
    my $extra = '';
    my $topicExists  = $store->topicExists( $webName, $topic );

    # If you want to edit, you have to be able to view and change.
    TWiki::UI::checkAccess( $session, $webName, $topic, 'view', $user );
    TWiki::UI::checkAccess( $session, $webName, $topic, 'change', $user );

    # Check lease, unless we have been instructed to ignore it
    my $breakLock = $query->param( 'breaklock' ) || '';
    unless( $breakLock ) {
        my $lease = $store->getLease( $webName, $topic );
        if( $lease ) {
            my $who = $lease->{user}->webDotWikiName();

            if( $who ne $user->webDotWikiName() ) {
                # redirect; we are trying to break someone else's lease
                my( $future, $past );
                my $why = $lease->{message};
                my $def = 'active';
                if( time() > $lease->{expires} ) {
                    $def = 'old';
                    $past = TWiki::Time::formatDelta(time()-$lease->{expires});
                    $future = '';
                }
                else {
                    $past = TWiki::Time::formatDelta(time()-$lease->{taken});
                    $future = TWiki::Time::formatDelta($lease->{expires}-time());
                }
                # use a 'keep' redirect to ensure we pass parameter
                # values in the query on to the oops script
                throw TWiki::OopsException( 'leaseconflict',
                                            keep => 1,
                                            def => $def,
                                            web => $webName,
                                            topic => $topic,
                                            params => [ $who, $past, $future ] );
            }
        }
    }

    # Prevent editing existing topic?
    if( $onlyNewTopic && $topicExists ) {
        # Topic exists and user requested oops if it exists
        throw TWiki::OopsException( 'attention',
                                    def => 'topic_exists',
                                    web => $webName,
                                    topic => $topic );
    }

    # prevent non-Wiki names?
    if( ( $onlyWikiName )
        && ( ! $topicExists )
        && ( ! TWiki::isValidTopicName( $topic ) ) ) {
        # do not allow non-wikinames, redirect to view topic
        # SMELL: this should be an oops, shouldn't it?
        $session->redirect( $session->getScriptUrl( $webName, $topic, 'view' ));
        return;
    }

    if( $topicExists ) {
        ( $meta, $text ) =
          $store->readTopic( undef, $webName, $topic, undef );
    }

    if( $saveCmd && ! $session->{user}->isAdmin()) {
        throw TWiki::OopsException( 'accessdenied', def=>'only_group',
                                    web => $webName, topic => $topic,
                                    params => $TWiki::cfg{UsersWebName}.
                                    '.'.$TWiki::cfg{SuperAdminGroup} );
    }

    my $templateWeb = $webName;

    # Get edit template, standard or a different skin
    my $template = $session->{prefs}->getPreferencesValue("EDIT_TEMPLATE") ||
        'edit';
    $tmpl = $session->{templates}->readTemplate( "$template$editaction", $skin );
    if( ! $tmpl ) {
        my $mess = CGI::start_html().
          CGI::h1('TWiki Installation Error').
          "Template file \'$template$editaction\' not found or template directory".
            $TWiki::cfg{TemplateDir}.' not found.'.CGI::p().
              'Check the configuration setting for TemplateDir'.
                CGI::end_html();
        $session->writeCompletePage( $mess );
        return;
    }

    unless( $topicExists ) {
        if( $templateTopic ) {
            ( $templateWeb, $templateTopic ) =
              $session->normalizeWebTopicName( $templateWeb, $templateTopic );

            ( $meta, $text ) =
              $store->readTopic( $session->{user}, $templateWeb,
                                        $templateTopic, undef );
        }
        unless( $text ) {
            ( $meta, $text ) = TWiki::UI::readTemplateTopic( $session, 'WebTopicEditTemplate' );
        }

        $extra = "(not exist)";

        # If present, instantiate form
        if( ! $formTemplate ) {
            my $form = $meta->get( 'FORM' );
            $formTemplate = $form->{name} if $form;
        }

        $text = $session->expandVariablesOnTopicCreation( $text, $user );
    }

    # override with parameter if set
    $text = $ptext if defined $ptext;

    # Insert the rev number we are editing. This will be boolean false if
    # this is a new topic.
    if( $topicExists ) {
        my ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
        $tmpl =~ s/%ORIGINALREV%/$orgRev/g;
    } else {
        $tmpl =~ s/%ORIGINALREV%/0/g;
    }

    # parent setting
    if( $theParent eq 'none' ) {
        $meta->remove( 'TOPICPARENT' );
    } elsif( $theParent ) {
        my $parentWeb;
        ($parentWeb, $theParent) =
          $session->normalizeWebTopicName( $webName, $theParent );
        if( $parentWeb ne $webName ) {
            $theParent = $parentWeb.'.'.$theParent;
        }
        $meta->put( 'TOPICPARENT', { name => $theParent } );
    }
    $tmpl =~ s/%TOPICPARENT%/$theParent/;

    if( $formTemplate ) {
        $meta->remove( 'FORM' );
        if( $formTemplate ne 'none' ) {
            $meta->put( 'FORM', { name => $formTemplate } );
        } else {
            $meta->remove( 'FORM' );
        }
        $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
    }

    if( $saveCmd ) {
        $text = $store->readTopicRaw( $session->{user}, $webName,
                                                 $topic, undef );
    }

    $session->{plugins}->beforeEditHandler(
        $text, $topic, $webName, $meta ) unless( $saveCmd );

    if( $TWiki::cfg{Log}{edit} ) {
        # write log entry
        $session->writeLog( 'edit', $webName.'.'.$topic, $extra );
    }

    $tmpl =~ s/\(edit\)/\(edit cmd=$saveCmd\)/go if $saveCmd;

    $tmpl =~ s/%CMD%/$saveCmd/go;
    $tmpl = $session->{renderer}->renderMetaTags( $webName, $topic, $tmpl, $meta, $saveCmd, 0 );
    $tmpl = $session->handleCommonTags( $tmpl, $webName, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $webName, $topic );

    # Don't want to render form fields, so this after getRenderedVersion
    my $formMeta = $meta->get( 'FORM' );
    my $form = '';
    $form = $formMeta->{name} if( $formMeta );
    if( $form && !$saveCmd ) {
        my $formText;
        my $getValuesFromFormTopic = ( $formTemplate && !$ptext );
        # if there's a form template, then pull whatever values exist in
        # the query into the meta, overriding the values in the topic.
        my $formDef = new TWiki::Form( $session, $templateWeb, $form );
        $formDef->getFieldValuesFromQuery( $session->{cgiQuery}, $meta, 0 );
        # and render them for editing
        if ( $editaction eq "text" ) {
            $formText = $formDef->renderHidden( $meta,
                                                $getValuesFromFormTopic );
        } else {
            $formText = $formDef->renderForEdit( $webName, $topic, $meta,
                                                 $getValuesFromFormTopic );
        }
        $tmpl =~ s/%FORMFIELDS%/$formText/go;
    } elsif( !$saveCmd && $session->{prefs}->getPreferencesValue( 'WEBFORMS', $webName )) {
        # follows a html monster to let the 'choose form button' align at
        # the right of the page in all browsers
        my $formText = CGI::submit(-name => 'action',
				   -value => 'Add form',
				   -class => "twikiChangeFormButton twikiSubmit");
        $formText = CGI::Tr(CGI::td( { align=>'right' }, $formText ));
        $formText = CGI::table( { width=>'100%',
				  border=>0,
				  cellspacing=>0,
				  cellpadding=>0,
				  class=>'twikiChangeFormButtonHolder' }, $formText );
        $formText = CGI::div( { style=>'text-align:right;' }, $formText );

        $tmpl =~ s/%FORMFIELDS%/$formText/go;
    } else {
        $tmpl =~ s/%FORMFIELDS%//go;
    }
    $tmpl =~ s/%FORMTEMPLATE%//go; # Clear if not being used
    my $p = $session->{prefs};

    $tmpl =~ s/%UNENCODED_TEXT%/$text/g;

    $text = TWiki::entityEncode( $text );
    $tmpl =~ s/%TEXT%/$text/g;

    $store->setLease( $webName, $topic, $user, $TWiki::cfg{LeaseLength} );

    $session->writeCompletePage( $tmpl, 'edit', $cgiAppType );
}

1;
