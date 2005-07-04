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

---+ package TWiki::UI::Manage

UI functions for web, topic and user management

=cut

package TWiki::UI::Manage;

use strict;
use Assert;
use TWiki;
use TWiki::UI;
use TWiki::User;
use TWiki::Sandbox;
use Error qw( :try );
use TWiki::OopsException;
use TWiki::UI::Register;

=pod

---++ StaticMethod manage( $session )
=manage= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

=cut

sub manage {
    my $session = shift;

    my $action = $session->{cgiQuery}->param( 'action' );

    if( $action eq 'createweb' ) {
        TWiki::UI::Manage::createWeb( $session );
    } elsif( $action eq 'changePassword' ) {
        TWiki::UI::Register::changePassword( $session );
    } elsif ($action eq 'bulkRegister') {
        TWiki::UI::Register::bulkRegister( $session );
    } elsif( $action eq 'deleteUserAccount' ) {
        TWiki::UI::Manage::removeUser( $session );
    } elsif( $action eq 'editSettings' ) {
        TWiki::UI::Manage::editSettings( $session );
    } elsif( $action eq 'saveSettings' ) {
        TWiki::UI::Manage::saveSettings( $session );
    } elsif( $action ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'unrecognized_action',
                                    params => $action );
    } else {
        throw TWiki::OopsException( 'attention', def => 'missing_action' );
    }
}

=pod

---++ StaticMethod removeUser( $session )
=removeuser= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Renames the user's topic (with renaming all links) and
removes user entry from passwords. CGI parameters:
| =password= | |

=cut

sub removeUser {
    my $session = shift;

    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $query = $session->{cgiQuery};
    my $user = $session->{user};

    my $password = $query->param( 'password' );

    # check if user entry exists
    # TODO: need to handle the NoPasswdUser case (userPasswordExists
    # will return false here)
    if( $user && !$user->passwordExists()) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'notwikiuser',
                                    params => $user->stringify() );
    }

    #check to see it the user we are trying to remove is a member of a group.
    #initially we refuse to delete the user
    #in a later implementation we will remove the from the group (if Access.pm implements it..)
    my @groups = $user->getGroups();
    if ( scalar( @groups ) > 0 ) { 
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'in_a_group',
                                    params =>
                                    [ $user->stringify(),
                                      join(', ',
                                           map { $_->stringify() }
                                           @groups ) ] );
    }

    unless( $user->checkPasswd( $password ) ) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'wrong_password');
    }

    $user->remove();

    throw TWiki::OopsException( 'attention',
                                def => 'remove_user_done',
                                web => $webName,
                                topic => $topic,
                                params => $user->webDotWikiName() );
}

sub _isValidHTMLColor {
    my $c = shift;
    return $c =~ m/^(#[0-9a-f]{6}|black|silver|gray|white|maroon|red|purple|fuchsia|green|lime|olive|yellow|navy|blue|teal|aqua)/i;

}

=pod

---++ StaticMethod createWeb( $session )
=create_web= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Create a new web. Parameters defining the new web are
in the query.

=cut

sub createWeb {
    my $session = shift;

    my $topicName = $session->{topicName};
    my $webName = $session->{webName};
    my $query = $session->{cgiQuery};
    my $user = $session->{user};

    my $newWeb = $query->param( 'newweb' ) || '';
    my $newTopic = $query->param( 'newtopic' ) || '';
    my $baseWeb = $query->param( 'baseweb' ) || '';
    my $webBGColor = $query->param( 'webbgcolor' ) || '';
    my $siteMapWhat = $query->param( 'sitemapwhat' ) || '';
    my $siteMapUseTo = $query->param( 'sitemapuseto' ) || '';
    my $noSearchAll = $query->param( 'nosearchall' ) || '';
    my $theUrl = $query->url;

    # check permission, user authorized to create webs?
    TWiki::UI::checkAccess( $session, $webName, $topicName,
                            'changewebs', $session->{user} );

    unless( $newWeb ) {
        throw TWiki::OopsException( 'attention', def => 'web_missing' );
    }

    unless ( TWiki::isValidWebName( $newWeb, 1 )) {
        throw TWiki::OopsException
          ( 'attention', def =>'invalid_web_name', params => $newWeb );
    }

    if( $session->{store}->webExists( $newWeb )) {
        throw TWiki::OopsException
          ( 'attention', def => 'web_exists', params => $newWeb );
    }

    $baseWeb =~ s/$TWiki::cfg{NameFilter}//go;
    $baseWeb = TWiki::Sandbox::untaintUnchecked( $baseWeb );

    unless( $session->{store}->webExists( $baseWeb )) {
        throw TWiki::OopsException
          ( 'attention', def => 'base_web_missing',
            params => $baseWeb );
    }
    unless( _isValidHTMLColor( $webBGColor )) {
        throw TWiki::OopsException
          ( 'attention', def => 'invalid_web_color',
            params => $webBGColor );
    }

    # create the empty web
    my $opts =
      {
       WEBBGCOLOR => $webBGColor,
       SITEMAPWHAT => $siteMapWhat,
       SITEMAPUSETO => $siteMapUseTo,
       NOSEARCHALL => $noSearchAll,
      };
    $opts->{SITEMAPLIST} = 'on' if( $siteMapWhat );

    my $err = $session->{store}->createWeb( $user, $newWeb, $baseWeb, $opts );
    if( $err ) {
        throw TWiki::OopsException
          ( 'attention', def => 'web_creation_error',
            params => [ $newWeb, $err ] );
    }

    # everything OK, redirect to last message
    $newTopic = $TWiki::cfg{HomeTopicName} unless( $newTopic );

    throw TWiki::OopsException
      ( 'attention',
        web => $newWeb,
        topic => $newTopic,
        def => 'created_web' );
}

=pod

---++ StaticMethod rename( $session )
=rename= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Rename the given topic. Details of the new topic name are passed in CGI
parameters:

| =skin= | skin(s) to use |
| =newweb= | new web name |
| =newtopic= | new topic name |
| =breaklock= | |
| =attachment= | |
| =confirm= | if defined, requires a second level of confirmation |
| =currentwebonly= | if defined, searches current web only for links to this topic |
| =nonwikiword= | if defined, a non-wikiword is acceptable for the new topic name |

=cut

sub rename {
    my $session = shift;

    my $oldTopic = $session->{topicName};
    my $oldWeb = $session->{webName};
    my $query = $session->{cgiQuery};

    my $newWeb = $query->param( 'newweb' ) || '';
    my $newTopic = $query->param( 'newtopic' ) || '';
    my $theUrl = $query->url;
    my $lockFailure = '';
    my $breakLock = $query->param( 'breaklock' );
    my $theAttachment = $query->param( 'attachment' );
    my $confirm = $query->param( 'confirm' );
    my $doAllowNonWikiWord = $query->param( 'nonwikiword' ) || '';
    my $store = $session->{store};

    $newTopic =~ s/\s//go;
    $newTopic =~ s/$TWiki::cfg{NameFilter}//go;

    $theAttachment ||= '';

    TWiki::UI::checkWebExists( $session, $oldWeb, $oldTopic, 'rename' );
    TWiki::UI::checkTopicExists( $session, $oldWeb, $oldTopic, 'rename');

    if( $newTopic && !TWiki::isValidWikiWord( $newTopic ) ) {
        unless( $doAllowNonWikiWord ) {
            throw TWiki::OopsException( 'attention',
                                        web => $oldWeb,
                                        topic => $oldTopic,
                                        def => 'rename_not_wikiword',
                                        [ $newTopic ] );
        }
        # Filter out dangerous characters (. and / may cause
        # issues with pathnames
        $newTopic =~ s![./]!_!g;
        $newTopic =~ s/($TWiki::cfg{NameFilter})//go;
    }

    if ( $theAttachment) {
        # Does old attachment exist?
        unless( $store->attachmentExists( $oldWeb, $oldTopic,
                                          $theAttachment )) {
            throw TWiki::OopsException( 'attention',
                                        web => $oldWeb,
                                        topic => $oldTopic,
                                        def => 'move_err',
                                        params => $theAttachment );
        }
        # does new attachment already exist?
        if( $store->attachmentExists( $newWeb, $newTopic,
                                      $theAttachment )) {
            throw TWiki::OopsException( 'attention',
                                        def => 'move_err',
                                        web => $newWeb,
                                        topic => $newTopic,
                                        params => $theAttachment );
        }
        # SMELL: what about if the target topic doesn't exist?
    } elsif( $newTopic ) {
        ( $newWeb, $newTopic ) =
          $session->normalizeWebTopicName( $newWeb, $newTopic );
        TWiki::UI::checkWebExists( $session, $newWeb, $newTopic, 'rename' );
        if( $store->topicExists( $newWeb, $newTopic)) {
            throw TWiki::OopsException( 'attention',
                                        def => 'rename_topic_exists',
                                        web => $oldWeb,
                                        topic => $oldTopic,
                                        params => [ $newWeb, $newTopic ] );
        }
    }

    TWiki::UI::checkAccess( $session, $oldWeb, $oldTopic,
                            'rename', $session->{user} );

    # Has user selected new name yet?
    if( ! $newTopic || $confirm ) {
        _newTopicScreen( $session,
                         $oldWeb, $oldTopic,
                         $newWeb, $newTopic,
                         $theAttachment,
                         $confirm, $doAllowNonWikiWord );
        return;
    }

    # Update references in referring pages - not applicable to attachments.
    my $refs;
    unless( $theAttachment ) {
        $refs = _getReferringTopicsListFromURL
          ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic );
    }

    move( $session, $oldWeb, $oldTopic, $newWeb, $newTopic,
          $theAttachment, $refs );

    my $new_url = '';
    if ( $newWeb eq $TWiki::cfg{TrashWebName} &&
         $oldWeb ne $TWiki::cfg{TrashWebName} ) {
        if( $theAttachment ) {
            # go back to old topic after deleting an attachment
            $new_url = $session->getScriptUrl( $oldWeb, $oldTopic, 'view' );
        } else {
            # redirect to parent: ending in Trash is not the expected way
            my $meta = '';
            my $text = '';
            ( $meta, $text ) =
              $store->readTopic( undef, $newWeb, $newTopic, undef );
            my $parent = $meta->get( 'TOPICPARENT' );
            if( $parent && $parent->{name} &&
                $parent->{name} ne $oldTopic &&
                $store->topicExists( $session->normalizeWebTopicName( '', $parent->{name} ) ) ) {
		# SMELL: probably would prefer some sort of normalizeWebTopicName() call here instead
                if ( $parent->{name} =~ /([^.]+)[.]([^.]+)/ ) {
                    $new_url = $session->getScriptUrl( $1, $2, 'view' );
                } else {
                    $new_url =
                      $session->getScriptUrl( $oldWeb, $parent->{name}, 'view' );
                }
            } else {
                $new_url = $session->getScriptUrl( $oldWeb, $TWiki::cfg{HomeTopicName}, 'view' );
            }
        }
    } else {
        #redirect to new topic
        $new_url = $session->getScriptUrl( $newWeb, $newTopic, 'view' );
    }

    $session->redirect( $new_url );
}

=pod

---++ StaticMethod renameweb( $session )
=rename= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Rename the given web. Details of the new web name are passed in CGI
parameters:

| =skin= | skin(s) to use |
| =newsubweb= | new web name |
| =newparentweb= | new parent web name |
| =breaklock= | |
| =confirm= | if defined, requires a second level of confirmation |
| =nonwikiword= | if defined, a non-wikiword is acceptable for the new web name (not currently used) |

=cut


sub renameweb {
    my $session = shift;

    my $oldWeb = $session->{webName};
    my $oldTopic = $TWiki::cfg{HomeTopicName};
    my $query = $session->{cgiQuery};

    my $newParentWeb = $query->param( 'newparentweb' ) || '';
    my $newSubWeb = $query->param( 'newsubweb' ) || '';;
    my $newWeb;
    if($newSubWeb) {
      if($newParentWeb) {
	$newWeb="$newParentWeb/$newSubWeb";
      } else {
	$newWeb=$newSubWeb;
      }
    }
    my (@tmp)=split(/[\/\.]/,$oldWeb);
    pop(@tmp);
    my $oldParentWeb=join("/",@tmp);
    my $newTopic;
    my $theUrl = $query->url;
    my $lockFailure = '';
    my $breakLock = $query->param( 'breaklock' );
    my $confirm = $query->param( 'confirm' );
    my $doAllowNonWikiWord = $query->param( 'nonwikiword' ) || '';
    my $store = $session->{store};

    TWiki::UI::checkWebExists( $session, $oldWeb, $TWiki::cfg{WebPrefsTopicName}, 'renameweb' );


    if( $newWeb ) {
        ( $newWeb, $newTopic ) =
          $session->normalizeWebTopicName( $newWeb, $TWiki::cfg{WebPrefsTopicName} );
	if($newParentWeb) {
	  TWiki::UI::checkWebExists( $session, $newParentWeb, $TWiki::cfg{WebPrefsTopicName}, 'rename' );
	}
        if( $store->topicExists( $newWeb, $TWiki::cfg{WebPrefsTopicName})) {
            throw TWiki::OopsException( 'attention',
                                        def => 'rename_web_exists',
                                        web => $oldWeb,
                                        topic => $TWiki::cfg{WebPrefsTopicName},
                                        params => [ $newWeb, $TWiki::cfg{WebPrefsTopicName} ] );
        }
    }

    TWiki::UI::checkAccess( $session, $oldWeb, $TWiki::cfg{WebPrefsTopicName},
                            'rename', $session->{user} );

    # Has user selected new name yet?
    if( ! $newWeb || $confirm ) {
        _newWebScreen( $session,
                         $oldWeb,
                         $newWeb,
                         $confirm );
        return;
    }

    # Update references in referring pages 
    my $refs = _getReferringTopicsListFromURL
          ( $session, $oldWeb, $TWiki::cfg{HomeTopicName},  $newWeb, $TWiki::cfg{HomeTopicName} );

    moveWeb( $session, $oldWeb, $newWeb, $refs );

    my $new_url = '';
    if ( $newWeb =~ /^$TWiki::cfg{TrashWebName}\// &&
         $oldWeb !~ /^$TWiki::cfg{TrashWebName}\// ) {
	# redirect to parent: ending in Trash is not the expected way
        if($oldParentWeb) {
	    $new_url = $session->getScriptUrl( $oldParentWeb, $TWiki::cfg{HomeTopicName}, 'view' );
	} else {
	    $new_url = $session->getScriptUrl( $TWiki::cfg{UsersWebName}, $TWiki::cfg{HomeTopicName}, 'view' );
	}


    } else {
        #redirect to new topic
        $new_url = $session->getScriptUrl( $newWeb, $TWiki::cfg{HomeTopicName}, 'view' );
    }

    $session->redirect( $new_url );
}

=pod

---++ StaticMethod move($session, $oldWeb, $oldTopic, $newWeb, $newTopic, $attachment, \@refs )

Move the given topic, or an attachment in the topic, correcting refs to the topic in the topic itself, and
in the list of topics (specified as web.topic pairs) in the \@refs array.

   * =$session= - reference to session object
   * =$oldWeb= - name of old web
   * =$oldTopic= - name of old topic
   * =$newWeb= - name of new web
   * =$newTopic= - name of new topic
   * =$attachment= - name of the attachment to move (from oldtopic to newtopic) (undef to move the topic)
   * =\@refs= - array of webg.topics that must have refs to this topic converted
Will throw TWiki::OopsException on an error.

=cut

sub move {
    my( $session, $oldWeb, $oldTopic,
        $newWeb, $newTopic, $attachment, $refs ) = @_;
    my $store = $session->{store};

    if( $attachment ) {
        my $error = 
          $store->moveAttachment( $oldWeb, $oldTopic, $newWeb, $newTopic,
                                  $attachment, $session->{user} );

        if( $error ) {
            throw TWiki::OopsException( 'attention',
                                        web => $oldWeb,
                                        topic => $oldTopic,
                                        def => 'move_err',
                                        params => [ $newWeb, $newTopic,
                                                    $attachment,
                                                    $error ] );
        }
        return;
    }

    my $error = $store->moveTopic( $oldWeb, $oldTopic, $newWeb, $newTopic,
                                       $session->{user} );

    if( $error ) {
        throw TWiki::OopsException( 'attention',
                                    web => $oldWeb,
                                    topic => $oldTopic,
                                    def => 'rename_err',
                                    params => [ $error, $newWeb,
                                                $newTopic ] );
    }

    my( $meta, $text ) = $store->readTopic( undef, $newWeb, $newTopic );

    if( $oldWeb ne $newWeb ) {
        # If the web changed, replace local refs to the topics
        # in $oldWeb with full $oldWeb.topic references so that
        # they still work.
        my $renderer = $session->{renderer};
        $renderer->replaceWebInternalReferences( \$text, $meta,
                                                 $oldWeb, $oldTopic, $newWeb, $newTopic );
    } 
    # Ok, now let's replace all self-referential links:
    my $options =
      {
       oldWeb => $newWeb,
       oldTopic => $oldTopic,
       newTopic => $newTopic,
       newWeb => $newWeb,
       inWeb => $newWeb,
       fullPaths => 0,
       spacedTopic => TWiki::spaceOutWikiWord( $oldTopic )
      };
    $options->{spacedTopic} =~ s/ / */g;
    $text = $session->{renderer}->forEachLine( $text, \&TWiki::Render::replaceTopicReferences, $options );




    $meta->put( 'TOPICMOVED',
                {
                 from => $oldWeb.'.'.$oldTopic,
                 to   => $newWeb.'.'.$newTopic,
                 date => time(),
                 # SMELL: surely this should be webDotWikiname?
                 by   => $session->{user}->wikiName(),
                } );

    $store->saveTopic( $session->{user}, $newWeb, $newTopic, $text, $meta,
                       { minor => 1, comment => 'rename' } );

    # update referrers - but _not_ including the moved topic
    _updateReferringTopics( $session, $oldWeb, $oldTopic,
                            $newWeb, $newTopic, $refs );
}

# Display screen so user can decide on new web and topic.
sub _newTopicScreen {
    my( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment,
        $confirm, $doAllowNonWikiWord ) = @_;

    my $query = $session->{cgiQuery};
    my $tmpl = '';
    my $skin = $session->getSkin();
    my $currentWebOnly = $query->param( 'currentwebonly' ) || '';

    $newTopic = $oldTopic unless ( $newTopic );
    $newWeb = $oldWeb unless ( $newWeb );
    my $nonWikiWordFlag = '';
    $nonWikiWordFlag = 'checked="checked"' if( $doAllowNonWikiWord );

    if( $theAttachment ) {
        $tmpl = $session->{templates}->readTemplate( 'moveattachment', $skin );
        $tmpl =~ s/%FILENAME%/$theAttachment/go;
    } elsif( $confirm ) {
        $tmpl = $session->{templates}->readTemplate( 'renameconfirm', $skin );
    } elsif( $newWeb eq $TWiki::cfg{TrashWebName} ) {
        $tmpl = $session->{templates}->readTemplate( 'renamedelete', $skin );
    } else {
        $tmpl = $session->{templates}->readTemplate( 'rename', $skin );
    }

    # Trashing a topic; look for a non-conflicting name
    if( $newWeb eq $TWiki::cfg{TrashWebName} ) {
        $newTopic = $oldWeb.$newTopic;
        my $n = 1;
        my $base = $newTopic;
        while( $session->{store}->topicExists( $newWeb, $newTopic)) {
            $newTopic = $base.$n;
            $n++;
        }
    }

    $tmpl =~ s/%NEW_WEB%/$newWeb/go;
    $tmpl =~ s/%NEW_TOPIC%/$newTopic/go;
    $tmpl =~ s/%NONWIKIWORDFLAG%/$nonWikiWordFlag/go;

    my $refs;
    my %attributes;
    my %labels;
    my @keys;
    my $search = '';
    if( $currentWebOnly ) {
        $search = '(skipped)';
    } else {
        $refs = getReferringTopics( $session, $oldWeb, $oldTopic, 1 );
        @keys = sort keys %$refs;
        foreach my $entry ( @keys ) {
            $search .= CGI::Tr
              (CGI::td
               ( { class => 'twikiTopRow' },
                 CGI::input( { type => 'checkbox',
                               class => 'twikiCheckBox',
                               name => 'referring_topics',
                               value => $entry,
                               checked => 'checked' },
                             " $entry " ) ).
               CGI::td( { class => 'twikiSummary twikiGrayText' },
                        $refs->{$entry} ));
        }
        unless( $search ) {
            $search = '(none)';
        } else {
            $search = CGI::start_table().$search.CGI::end_table();
        }
    }
    $tmpl =~ s/%GLOBAL_SEARCH%/$search/o;

    $refs = getReferringTopics( $session, $oldWeb, $oldTopic, 0 );
    @keys = sort keys %$refs;
    $search = '';;
    foreach my $entry ( @keys ) {
        $search .= CGI::Tr
          (CGI::td
           ( { class => 'twikiTopRow' },
             CGI::input( { type => 'checkbox',
                           class => 'twikiCheckBox',
                           name => 'referring_topics',
                           value => $entry,
                           checked => 'checked' },
                         " $entry " ) ).
           CGI::td( { class => 'twikiSummary twikiGrayText' },
                    $refs->{$entry} ));
    }
    unless( $search ) {
        $search = '(none)';
    } else {
        $search = CGI::start_table().$search.CGI::end_table();
    }
    $tmpl =~ s/%LOCAL_SEARCH%/$search/go;

    $tmpl = $session->handleCommonTags( $tmpl, $oldWeb, $oldTopic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $oldWeb, $oldTopic );
    $session->writeCompletePage( $tmpl );
}


=pod

---++ StaticMethod moveWeb($session, $oldWeb,  $newWeb, \@refs )

Move the given web, correcting refs to the web in the web itself, and
in the list of topics (specified as web.topic pairs) in the \@refs array.

   * =$session= - reference to session object
   * =$oldWeb= - name of old web
   * =$newWeb= - name of new web
   * =\@refs= - array of webg.topics that must have refs to this topic converted
Will throw TWiki::OopsException on an error.

=cut

sub moveWeb {
    my( $session, $oldWeb,
        $newWeb, $refs ) = @_;
    my $store = $session->{store};

    my $error = $store->canMoveWeb( $oldWeb, $newWeb,
                                       $session->{user} );

    if( $error ) {
        throw TWiki::OopsException( 'attention',
                                    web => $oldWeb,
                                    topic => '',
                                    def => 'rename_err',
                                    params => [ $error, $newWeb, '' ] );
    }

    # update referrers.  We need to do this before moving, 
    # because there might be topics inside the newWeb which need updating. 
    _updateWebReferringTopics( $session, $oldWeb,
                            $newWeb, $refs );

    $error = $store->moveWeb( $oldWeb, $newWeb,
                                       $session->{user} );

    if( $error ) {
        throw TWiki::OopsException( 'attention',
                                    web => $oldWeb,
                                    topic => '',
                                    def => 'rename_err',
                                    params => [ $error, $newWeb, '' ] );
    }


}

# Display screen so user can decide on new web.
sub _newWebScreen {
    my( $session, $oldWeb, $newWeb,
        $confirm ) = @_;

    my $query = $session->{cgiQuery};
    my $tmpl = '';
    my $skin = $session->getSkin();

    $newWeb = $oldWeb unless ( $newWeb );

    my @newParentPath=split(/\//,$newWeb);
    my $newSubWeb=pop(@newParentPath);
    my $newParent=join("/",@newParentPath);
    my $accessCheckWeb=$newParent;
    my $accessCheckTopic=$TWiki::cfg{WebPrefsTopicName};

    if( $confirm ) {
        $tmpl = $session->{templates}->readTemplate( 'renamewebconfirm', $skin );
    } elsif( $newWeb eq $TWiki::cfg{TrashWebName} ) {
        $tmpl = $session->{templates}->readTemplate( 'renamewebdelete', $skin );
    } else {
        $tmpl = $session->{templates}->readTemplate( 'renameweb', $skin );
    }

    # Trashing a web; look for a non-conflicting name
    if( $newWeb eq $TWiki::cfg{TrashWebName} ) {
        $newWeb = "$TWiki::cfg{TrashWebName}/$oldWeb";
        my $n = 1;
        my $base = $newWeb;
        while( $session->{store}->webExists( $newWeb )) {
            $newWeb = $base.$n;
            $n++;
        }
    }

    $tmpl =~ s/%NEW_PARENTWEB%/$newParent/go;
    $tmpl =~ s/%NEW_SUBWEB%/$newSubWeb/go;
    $tmpl =~ s/%TOPIC%/$TWiki::cfg{HomeTopicName}/go;

    my $refs;
    my %attributes;
    my %labels;
    my @keys;
    my $search = '';

    $refs = getReferringTopics( $session, $oldWeb, undef, 1 );
    @keys = sort keys %$refs;
    foreach my $entry ( @keys ) {
	$search .= CGI::Tr
	  (CGI::td
	   ( { class => 'twikiTopRow' },
	     CGI::input( { type => 'checkbox',
			   class => 'twikiCheckBox',
			   name => 'referring_topics',
			   value => $entry,
			   checked => 'checked' },
			 " $entry " ) ).
	   CGI::td( { class => 'twikiSummary twikiGrayText' },
		    $refs->{$entry} ));
    }
    unless( $search ) {
	$search = '(none)';
    } else {
	$search = CGI::start_table().$search.CGI::end_table();
    }
    $tmpl =~ s/%GLOBAL_SEARCH%/$search/o;

    $refs = getReferringTopics( $session, $oldWeb, undef, 0 );
    @keys = sort keys %$refs;
    $search = '';;
    foreach my $entry ( @keys ) {
        $search .= CGI::Tr
          (CGI::td
           ( { class => 'twikiTopRow' },
             CGI::input( { type => 'checkbox',
                           class => 'twikiCheckBox',
                           name => 'referring_topics',
                           value => $entry,
                           checked => 'checked' },
                         " $entry " ) ).
           CGI::td( { class => 'twikiSummary twikiGrayText' },
                    $refs->{$entry} ));
    }
    unless( $search ) {
        $search = '(none)';
    } else {
        $search = CGI::start_table().$search.CGI::end_table();
    }
    $tmpl =~ s/%LOCAL_SEARCH%/$search/go;

    $tmpl = $session->handleCommonTags( $tmpl, $oldWeb, $TWiki::cfg{HomeTopicName} );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $oldWeb, $TWiki::cfg{HomeTopicName} );
    $session->writeCompletePage( $tmpl );
}

# Returns the list of topics that have been found that refer
# to the renamed topic. Returns a list of topics.
sub _getReferringTopicsListFromURL {
    my( $session, $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;

    my $query = $session->{cgiQuery};
    my @result;
    foreach my $topic ( $query->param( 'referring_topics' ) ) {
        push @result, $topic;
    }
    return \@result;
}

=pod

---++ StaticMethod getReferringTopics($session, $web, $topic, $allWebs) -> \%matches
   * =$session= - the session
   * =$web= - web to search for
   * =$topic= - topic to search for
   * =$allWebs= - 0 to search $web only. 1 to search all webs _except_ $web.
Returns a hash that maps the web.topic name to a summary of the lines that matched. Will _not_ return $web.$topic in the list

=cut

sub getReferringTopics {
    my( $session, $web, $topic, $allWebs, $details ) = @_;
    my $store = $session->{store};
    my $renderer = $session->{renderer};
    $web =~ s#\.#/#go;
    my @webs = ( $web );

    if( $allWebs ) {
        @webs = $store->getListOfWebs();
    }

    my %results;
    foreach my $searchWeb ( @webs ) {
        next if( $allWebs && $searchWeb eq $web );
        my @topicList = $store->getTopicNames( $searchWeb );
        my $searchString = $topic;

 	my $webString=$web;
 	$webString =~ s#[\./]#[\\.\\/]#go;
 
 	if(defined($topic)) {
 	  $searchString = $webString.'.'.$topic unless ( $searchWeb eq $web );
 	} else {
 	  $searchString = $webString;
 	}
        # Note use of \< and \> to match the empty string at the edges of a word.
        my $matches = $store->searchInWebContent
          ( '\<'.$searchString.'\>',
            $searchWeb, \@topicList,
            { casesensitive => 0, type => 'regex' } );

        foreach my $searchTopic ( keys %$matches ) {
            next if( $searchWeb eq $web && $searchTopic eq $topic );
            my $t = join( '...', @{$matches->{$searchTopic}});
            $t = $renderer->TML2PlainText( $t, $searchWeb, $searchTopic,
                                           "showvar;showmeta" );
            $t =~ s/^\s+//;
            if( length( $t ) > 100 ) {
                $t =~ s/^(.{100}).*$/$1/;
            }
            $results{$searchWeb.'.'.$searchTopic} = $t;
        };
    }
    return \%results;
}

# Update pages that refer to a page that is being renamed/moved.
sub _updateReferringTopics {
    my ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $refs ) = @_;
    my $store = $session->{store};
    my $renderer = $session->{renderer};
    my $user = $session->{user};
    my $options =
      {
       pre => 1, # process lines in PRE blocks
       oldWeb => $oldWeb,
       oldTopic => $oldTopic,
       newWeb => $newWeb,
       newTopic => $newTopic,
       spacedTopic => TWiki::spaceOutWikiWord( $oldTopic )
      };
    $options->{spacedTopic} =~ s/ / */g;

    foreach my $item ( @$refs ) {
        my( $itemWeb, $itemTopic ) =
          $session->normalizeWebTopicName( '', $item );

        if ( $store->topicExists($itemWeb, $itemTopic) ) {
            $store->lockTopic( $user, $itemWeb, $itemTopic );
            try {
                my( $meta, $text ) =
                  $store->readTopic( undef, $itemWeb, $itemTopic, undef );
                $options->{inWeb} = $itemWeb;

                $text = $renderer->forEachLine
                  ( $text, \&TWiki::Render::replaceTopicReferences, $options );
                $meta->forEachSelectedValue
                  ( qw/^(FIELD|FORM|TOPICPARENT)$/, undef,
                    \&TWiki::Render::replaceTopicReferences, $options );

                $store->saveTopic( $user, $itemWeb, $itemTopic,
                                   $text, $meta,
                                   { minor => 1 } );
            } catch TWiki::AccessControlException with {
                my $e = shift;
                $session->writeWarning( $e->stringify() );
            } otherwise {
                $store->unlockTopic( $user, $itemWeb, $itemTopic );
            };
        }
    }
}

# Update pages that refer to a web that is being renamed/moved.
sub _updateWebReferringTopics {
    my ( $session, $oldWeb, $newWeb, $refs ) = @_;
    my $store = $session->{store};
    my $renderer = $session->{renderer};
    my $user = $session->{user};
    my $options =
      {
       oldWeb => $oldWeb,
       newWeb => $newWeb
      };
    $options->{spacedTopic} =~ s/ / */g;

    foreach my $item ( @$refs ) {
        my( $itemWeb, $itemTopic ) =
          $session->normalizeWebTopicName( '', $item );

        if ( $store->topicExists($itemWeb, $itemTopic) ) {
            $store->lockTopic( $user, $itemWeb, $itemTopic );
            try {
                my( $meta, $text ) =
                  $store->readTopic( undef, $itemWeb, $itemTopic, undef );
                $options->{inWeb} = $itemWeb;

                $text = $renderer->forEachLine
                  ( $text, \&TWiki::Render::replaceWebReferences, $options );
                $meta->forEachSelectedValue
                  ( qw/^(FIELD|FORM|TOPICPARENT)$/, undef,
                    \&TWiki::Render::replaceWebReferences, $options );

                $store->saveTopic( $user, $itemWeb, $itemTopic,
                                   $text, $meta,
                                   { minor => 1 } );
            } catch TWiki::AccessControlException with {
                my $e = shift;
                $session->writeWarning( $e->stringify() );
            } otherwise {
                $store->unlockTopic( $user, $itemWeb, $itemTopic );
            };
        }
    }
}

=pod

---++ StaticMethod editSettings( $session )
=settings= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Rename the given topic. Details of the new topic name are passed in CGI
parameters, if any:

=cut

sub editSettings {
    my $session = shift;
    my $topic = $session->{topicName};
    my $web = $session->{webName};

    my( $meta, $text ) =
      $session->{store}->readTopic( $session->{user}, $web, $topic, undef );
    my ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();

    my $settings = "";

    my @fields = $meta->find( 'PREFERENCE' );
    foreach my $field ( @fields ) {
       my $name  = $field->{name};
       my $value = $field->{value};
       $settings .= "   * Set $name = $value\n";
    }

    my $skin = $session->getSkin();
    my $tmpl = $session->{templates}->readTemplate( 'settings', $skin );
    $tmpl = $session->handleCommonTags( $tmpl, $web, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $web, $topic );

    $tmpl =~ s/%TEXT%/$settings/o;
    $tmpl =~ s/%ORIGINALREV%/$orgRev/g;

    $session->writeCompletePage( $tmpl );

}

sub saveSettings {
    my $session = shift;
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $user = $session->{user};

    # set up editing session
    my ( $currMeta, $currText ) =
      $session->{store}->readTopic( undef, $web, $topic, undef );
    my $newMeta = new TWiki::Meta( $session, $web, $topic );
    $newMeta->copyFrom( $currMeta );

    my $query = $session->{cgiQuery};
    my $settings = $query->param( 'text' );
    my $originalrev = $query->param( 'originalrev' );

    $newMeta->remove( 'PREFERENCE' );  # delete previous settings
    $settings =~ s/$TWiki::regex{setVarRegex}/&handleSave($web, $topic, $1, $2, $newMeta)/mgeo;

    my $saveOpts = {};
    $saveOpts->{minor} = 1;            # don't notify
    $saveOpts->{forcenewrevision} = 1; # always new revision

    # Merge changes in meta data
    if ( $originalrev ) {
        my ( $date, $author, $rev ) = $newMeta->getRevisionInfo();
        # If the last save was by me, don't merge
        if ( $rev ne $originalrev && !$author->equals( $user )) {
            $newMeta->merge( $currMeta );
        }
    }

    my $error =
      $session->{store}->saveTopic( $user, $web, $topic,
                                    $currText, $newMeta, $saveOpts );

    if( $error ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'save_error',
                                    web => $web,
                                    topic => $topic,
                                    params => $error );
    }
    my $viewURL = $session->getScriptUrl( $web, $topic, 'view' );
    $session->redirect( $viewURL );
    return;

}

sub handleSave {
  my( $web, $topic, $name, $value ) = @_;

  $value =~ s/^\s*(.*?)\s*$/$1/ge;

  my $args =
    {
     name =>  $name,
     title => $name,
     value => $value
    };
  $_[4]->putKeyed( 'PREFERENCE', $args );
  return "";

}

1;
