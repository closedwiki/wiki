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
    } elsif( $action ) {
        throw TWiki::OopsException( 'managebad',
                                    def => 'unrecognized_action',
                                    params => $action );
    } else {
        throw TWiki::OopsException( 'managebad', def => 'missing_action' );
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
        throw TWiki::OopsException( 'managebad',
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
        throw TWiki::OopsException( 'managebad',
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
        throw TWiki::OopsException( 'managebad',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'wrong_password');
    }

    #TODO: need to add GetUniqueTopicName
    #   # appends a unique number to the requested topicname
    #    my $newTopicName = TWiki::getUniqueTopicName('AnonymousContributor');
    #
    #   my $renameError = $session->{store}->renameTopic( $TWiki::cfg{UsersWebName}, $wikiName, $TWiki::cfg{UsersWebName}, $newTopicName, 'relink' );
    #
    #   if ( $renameError ) {
    #TODO: add better error message for rname failed
    #     }
    #
    #    # Update references in referring pages - not applicable to attachments.
    #    my $refs = TWiki::UI::Manage::getReferringTopics( $session, $oldWeb, $oldTopic );
    #    TWiki::UI::Manage::updateReferringTopics( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $refs );

    $user->remove();

    throw TWiki::OopsException( 'manageok',
                                web => $webName,
                                topic => $topic,
                                def => 'remove_user_done',
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
        throw TWiki::OopsException( 'managebad', def => 'web_missing' );
    }

    unless ( TWiki::isValidWebName( $newWeb, 1 )) {
        throw TWiki::OopsException
          ( 'managebad', def =>'invalid_web_name', params => $newWeb );
    }

    if( $session->{store}->isKnownWeb( $newWeb )) {
        throw TWiki::OopsException
          ( 'managebad', def => 'web_exists', params => $newWeb );
    }

    $baseWeb =~ s/$TWiki::cfg{NameFilter}//go;
    $baseWeb = TWiki::Sandbox::untaintUnchecked( $baseWeb );

    unless( $session->{store}->isKnownWeb( $baseWeb )) {
        throw TWiki::OopsException
          ( 'managebad', def => 'base_web_missing',
            params => $baseWeb );
    }
    unless( _isValidHTMLColor( $webBGColor )) {
        throw TWiki::OopsException
          ( 'managebad', def => 'invalid_web_color',
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

    my $err = $session->{store}->createWeb( $newWeb, $baseWeb, $opts );
    if( $err ) {
        throw TWiki::OopsException
          ( 'managebad', def => 'web_creation_error',
            params => [ $newWeb, $err ] );
    }

    # everything OK, redirect to last message
    $newTopic = $TWiki::cfg{HomeTopicName} unless( $newTopic );

    throw TWiki::OopsException
      ( 'manageok', web => $newWeb, topic => $newTopic,
        def => 'created_web' );
}

=pod

---++ StaticMethod rename( $session )
=rename= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Rename the given topic. Details of the new topic name are passed in CGI
parameters:

| =skin= | skin to use for derivative topics |
| =newweb= | new web name |
| =newtopic= | new topic name |
| =breaklock= | |
| =attachment= | |
| =confirm= | if defined, requires a second level of confirmation |
| =currentwebonly= | if defined, searches current web only for links to this topic |
| =nonwikiword= | if defined, a non-wikiword is acceptable for the new topic name |
| =changerefs= | |

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
    my $justChangeRefs = $query->param( 'changeRefs' ) || '';

    $newTopic =~ s/\s//go;
    $newTopic =~ s/$TWiki::cfg{NameFilter}//go;

    $theAttachment ||= '';

    # justChangeRefs will be true when some topics that had links to $oldTopic
    # still need updating, previous update being prevented by a lock.

    unless ( $justChangeRefs ) {
        TWiki::UI::checkWebExists( $session, $oldWeb, $oldTopic, 'rename' );
        TWiki::UI::checkTopicExists( $session, $oldWeb, $oldTopic, 'rename');
        TWiki::UI::checkWebExists( $session, $newWeb, $newTopic, 'rename' );

        if ( $theAttachment) {
            # Does old attachment exist?
            unless( $session->{store}->attachmentExists( $oldWeb, $oldTopic,
                                                         $theAttachment )) {
                throw TWiki::OopsException( 'managebad',
                                            web => $oldWeb,
                                            topic => $oldTopic,
                                            def => 'move_err',
                                            params => $theAttachment );
            }
            # does new attachment already exist?
            if( $session->{store}->attachmentExists( $newWeb, $newTopic,
                                                     $theAttachment )) {
                throw TWiki::OopsException( 'managebad',
                                            web => $newWeb,
                                            topic => $newTopic,
                                            def => 'move_err',
                                            params => $theAttachment );
            }
        } else {
            # Check new topic doesn't exist
            if( $newTopic &&
                $session->{store}->topicExists( $newWeb, $newTopic)) {
                # Unless moving an attachment, new topic should not exist
                throw TWiki::OopsException( 'managebad',
                                            web => $oldWeb,
                                            topic => $oldTopic,
                                            def => 'topic_exists',
                                            params => [ $newWeb, $newTopic ] );
            }
        }

        TWiki::UI::checkAccess( $session, $oldWeb, $oldTopic,
                                'rename', $session->{user} );
    }

    # Has user selected new name yet?
    if( ! $newTopic || $confirm ) {
        _newTopicScreen( $session,
                         $oldWeb, $oldTopic,
                         $newWeb, $newTopic,
                         $theAttachment,
                         $confirm, $doAllowNonWikiWord );
        return;
    }

    if( ! $justChangeRefs ) {
        if( $theAttachment ) {
            my $moveError = 
              $session->{store}->moveAttachment( $oldWeb, $oldTopic,
                                                 $newWeb, $newTopic,
                                                 $theAttachment,
                                                 $session->{user} );

            if( $moveError ) {
                throw TWiki::OopsException( 'managebad',
                                            web => $oldWeb,
                                            topic => $oldTopic,
                                            def => 'move_err',
                                            params => [ $newWeb, $newTopic,
                                                        $theAttachment,
                                                        $moveError ] );
            }
        } else {
            unless( TWiki::isValidWikiWord( $newTopic ) ) {
                unless( $doAllowNonWikiWord ) {
                    throw TWiki::OopsException( 'managebad',
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

            my $renameError =
              $session->{store}->renameTopic( $oldWeb, $oldTopic, $newWeb,
                                          $newTopic, 1, $session->{user} );
            if( $renameError ) {
                throw TWiki::OopsException( 'managebad',
                                            web => $oldWeb,
                                            topic => $oldTopic,
                                            def => 'rename_err',
                                            params => [ $renameError,
                                                        $newWeb,
                                                        $newTopic ] );
            }
        }
    }

    # Update references in referring pages - not applicable to attachments.
    if( ! $theAttachment ) {
        my $refs = _getReferringTopicsListFromURL
          ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic );

        updateReferringTopics( $session, $oldWeb, $oldTopic,
                               $newWeb, $newTopic, $refs );
    }
    my $new_url = '';
    if ( $newWeb eq 'Trash' && $oldWeb ne 'Trash' ) {
        if( $theAttachment ) {
            # go back to old topic after deleting an attachment
            $new_url = $session->getScriptUrl( $oldWeb, $oldTopic, 'view' );
        } else {
            # redirect to parent: ending in Trash is not the expected way
            my $meta = '';
            my $text = '';
            ( $meta, $text ) =
              $session->{store}->readTopic( undef, $newWeb, $newTopic, undef );
            my $parent = $meta->get( 'TOPICPARENT' );
            if( $parent && $parent->{name} &&
                $parent->{name} ne $oldTopic ) {
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
    } elsif( $newWeb eq 'Trash' ) {
        $tmpl = $session->{templates}->readTemplate( 'renamedelete', $skin );
    } else {
        $tmpl = $session->{templates}->readTemplate( 'rename', $skin );
    }

    $tmpl = _setVars( $tmpl, $oldTopic, $newWeb, $newTopic, $nonWikiWordFlag );

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
                               name => 'local_topics',
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
                           name => 'local_topics',
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

sub _setVars {
    my( $tmpl, $oldTopic, $newWeb, $newTopic, $nonWikiWordFlag ) = @_;
    $tmpl =~ s/%NEW_WEB%/$newWeb/go;
    $tmpl =~ s/%NEW_TOPIC%/$newTopic/go;
    $tmpl =~ s/%NONWIKIWORDFLAG%/$nonWikiWordFlag/go;
    return $tmpl;
}

# Returns the list of topics that have been found that refer
# to the renamed topic. Returns a list of topics.
sub _getReferringTopicsListFromURL {
    my( $session, $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;

    my $query = $session->{cgiQuery};
    my @result;
    foreach my $scope qw( local global ) {
        foreach my $topic ( $query->param( $scope.'_topics' ) ) {
            if ($topic eq $oldWeb.'.'.$oldTopic ) {
                $topic = $newWeb.'.'.$newTopic;
            }
            push @result, $topic;
        }
    }
    return \@result;
}

=pod

---++ StaticMethod getReferringTopics($session, $oldWeb, $oldTopic, $allWebs) -> \%matches
   * =$session= - the session
   * =$oldWeb= - web to search for
   * =$oldTopic= - topic to search for
   * =$allWebs= - 1 if it's a global search, 0 to search $oldWeb only
   * =$details= - if true, will return a list of matched lines with each key
Returns a hash of web.topic names that each map to a list of lines in the topic that matched.

SMELL: does not hide NOSEARCHALL webs.
SMELL: does not necessarily return the same result as the %SEARCH used
to generate the list of topics in the rename view, because that search
is driven off a template where the parameters may be different. Ho hum.

=cut

sub getReferringTopics {
    my( $session, $oldWeb, $oldTopic, $allWebs, $details ) = @_;
    my $store = $session->{store};
    my $renderer = $session->{renderer};
    my @webs = ( $oldWeb );

    if( $allWebs ) {
        @webs = $store->getListOfWebs();
    }

    my %results;
    foreach my $web ( @webs ) {
        next if( $allWebs && $web eq $oldWeb );
        my @topicList = $store->getTopicNames( $web );
        my $searchString = $oldTopic;
        $searchString = $oldWeb.'\.'.$searchString unless $web eq $oldWeb;

        my $matches = $store->searchInWebContent
          ( $searchString, $web, \@topicList,
            { casesensitive => 0 } );

        foreach my $key ( keys %$matches ) {
            my $t = join( '...', @{$matches->{$key}});
            $t =~ s/%META:/%/g;
            $t = $renderer->TML2PlainText( $t, $web, $key, "showvar" );
            $t =~ s/^\s+//;
            if( length( $t ) > 100 ) {
                $t =~ s/^(.{100}).*$/$1/;
            }
            $results{$web.'.'.$key} = $t;
        };
    }
    return \%results;
}

=pod

---++ StaticMethod updateReferringTopics( $session, $oldWeb, $oldTopic, $user, $newWeb, $newTopic, \@refs  )

Update pages that refer to a page that is being renamed/moved.

=cut

sub updateReferringTopics {
    my ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $refs ) = @_;
    ASSERT(ref($session) eq 'TWiki') if DEBUG;

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

                foreach my $mType qw( FIELD TOPICPARENT ) {
                    my $data = $meta->{$mType};
                    next unless $data;
                    foreach my $datum ( @$data ) {
                        foreach my $key ( keys %$datum ) {
                            $datum->{$key} = $renderer->forEachLine
                                  ( $datum->{$key},
                                    \&TWiki::Render::replaceTopicReferences,
                                    $options );
                        }
                    }
                }
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

1;
