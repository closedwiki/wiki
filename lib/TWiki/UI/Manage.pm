# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2001 Sven Dowideit, svenud@ozemail.com.au
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

---+ package TWiki::UI::Manage

UI functions for web, topic and user management

=cut

package TWiki::UI::Manage;

use strict;
use TWiki;
use TWiki::UI;
use TWiki::User;
use TWiki::Sandbox;
use Error qw( :try );
use TWiki::UI::OopsException;

=pod

---++ StaticMethod manage( $session )
=manage= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

=cut

sub manage {
    my $session = shift;

    my $action = $session->{cgiQuery}->param( 'action' );

    if( $action eq "createweb" ) {
        TWiki::UI::Manage::createWeb( $session );
    } elsif( $action eq "changePassword" ) {
        TWiki::UI::Register::changePassword( $session );
    } elsif ($action eq 'bulkRegister') {
        TWiki::UI::Register::bulkRegister( $session );
    } elsif( $action eq "deleteUserAccount" ) {
        TWiki::UI::Manage::removeUser( $session );
    } elsif( $action ) {
        throw TWiki::UI::OopsException( "", "", "manage",
                                        _template("msg_unrecognized_action"),
                                        $action );
    } else {
        throw TWiki::UI::OopsException( "", "", "manage",
                                        _template("msg_missing_action") );
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
    #TODO: need to handle the NoPasswdUser case (userPasswordExists will retun false here)
    if( $user && !$user->passwordExists()) {
        throw TWiki::UI::OopsException( $webName, $topic,
                                        "notwikiuser", $user->stringify() );
    }

    #check to see it the user we are trying to remove is a memebr of a group.
    #initially we refuse to delete the user
    #in a later implementation we will remove the from the group (if Access.pm implements it..)
    my @groups = $user->getGroups();
    my $numberOfGroups =  $#groups;
    if ( $numberOfGroups > -1 ) { 
        throw TWiki::UI::OopsException( $webName, $topic, "genericerror");
    }

    unless( $user->checkPasswd( $password ) ) {
        throw TWiki::UI::OopsException( $webName, $topic, "wrongpassword");
    }

    #TODO: need to add GetUniqueTopicName
    #   # appends a unique number to the requested topicname
    #    my $newTopicName = TWiki::getUniqueTopicName("AnonymousContributor");
    #
    #   my $renameError = $session->{store}->renameTopic( $TWiki::cfg{UsersWebName}, $wikiName, $TWiki::cfg{UsersWebName}, $newTopicName, "relink" );
    #
    #   if ( $renameError ) {
    #TODO: add better error message for rname failed
    #         throw TWiki::UI::OopsException( $webName, $topic, "renameerr");
    #     }
    #
    #    # Update references in referring pages - not applicable to attachments.
    #    my @refs = $session->{store}->findReferringPages( $oldWeb, $oldTopic );
    #    my $problems;
    #    ( $lockFailure, $problems ) = 
    #       $session->{store}->updateReferringPages( $oldWeb, $oldTopic, $user, $newWeb, $newTopic, @refs );

    $user->remove();

    throw TWiki::UI::OopsException( $webName, $topic, "removeuserdone",
                                    $user->stringify() );
}

#changePassword is now in register (belongs in User.pm though)

# PRIVATE Prepare a template var for expansion in a message
sub _template {
    my $theTmplVar = shift;
    return "%TMPL:P{\"$theTmplVar\"}%";
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

    my $newWeb = $query->param( 'newweb' ) || "";
    my $newTopic = $query->param( 'newtopic' ) || "";
    my $baseWeb = $query->param( 'baseweb' ) || "";
    my $webBgColor = $query->param( 'webbgcolor' ) || "";
    my $siteMapWhat = $query->param( 'sitemapwhat' ) || "";
    my $siteMapUseTo = $query->param( 'sitemapuseto' ) || "";
    my $noSearchAll = $query->param( 'nosearchall' ) || "";
    my $theUrl = $query->url;
    my $oopsTmpl = "mngcreateweb";

    # check permission, user authorized to create webs?
    TWiki::UI::checkAccess( $session, $webName, $topicName,
                            "manage", $session->{user} );

    unless( $newWeb ) {
        throw TWiki::UI::OopsException
          ( "", "", $oopsTmpl, _template("msg_web_missing") );
    }

    unless ( TWiki::isValidWebName( $newWeb, 1 )) {
        throw TWiki::UI::OopsException
          ( "", "", $oopsTmpl, _template( "msg_web_name" ));
    }

    if( $session->{store}->isKnownWeb( $newWeb )) {
        throw TWiki::UI::OopsException( "", "", $oopsTmpl,
                                        _template("msg_web_exist"), $newWeb );
    }

    $baseWeb =~ s/$TWiki::cfg{NameFilter}//go;
    $baseWeb = TWiki::Sandbox::untaintUnchecked( $baseWeb );

    unless( $session->{store}->isKnownWeb( $baseWeb )) {
        throw TWiki::UI::OopsException( "", "", $oopsTmpl,
                                        _template("msg_base_web"), $baseWeb );
    }

    unless( $webBgColor =~ /\#[0-9a-f]{6}/i ) {
        throw TWiki::UI::OopsException( "", "", $oopsTmpl,
                                        _template("msg_web_color") );
    }

    # create the empty web
    my $opts =
      {
       WEBBGCOLOR => $webBgColor,
       SITEMAPWHAT => $siteMapWhat,
       SITEMAPUSETO => $siteMapUseTo,
       NOSEARCHALL => $noSearchAll,
      };
    $opts->{SITEMAPLIST} = "on" if( $siteMapWhat );

    my $err = $session->{store}->createWeb( $newWeb, $baseWeb, $opts );
    if( $err ) {
        throw TWiki::UI::OopsException( "", "", $oopsTmpl,
                                        _template("msg_web_create"), $err );
    }

    # everything OK, redirect to last message
    $newTopic = $TWiki::cfg{HomeTopicName} unless( $newTopic );
    throw TWiki::UI::OopsException( $newWeb, $newTopic, $oopsTmpl,
                                    _template("msg_create_web_ok") );
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

    my $newWeb = $query->param( 'newweb' ) || "";
    my $newTopic = $query->param( 'newtopic' ) || "";
    my $theUrl = $query->url;
    my $lockFailure = "";
    my $breakLock = $query->param( 'breaklock' );
    my $theAttachment = $query->param( 'attachment' );
    my $confirm = $query->param( 'confirm' );
    my $currentWebOnly = $query->param( 'currentwebonly' ) || "";
    my $doAllowNonWikiWord = $query->param( 'nonwikiword' ) || "";
    my $justChangeRefs = $query->param( 'changeRefs' ) || "";

    my $skin = $session->getSkin();

    $newTopic =~ s/\s//go;
    $newTopic =~ s/$TWiki::cfg{NameFilter}//go;

    if( ! $theAttachment ) {
        $theAttachment = "";
    }

    # justChangeRefs will be true when some topics that had links to $oldTopic
    # still need updating, previous update being prevented by a lock.

    unless ( $justChangeRefs ) {
        TWiki::UI::checkWebExists( $session, $oldWeb, $oldTopic );
        TWiki::UI::checkTopicExists( $session, $oldWeb, $oldTopic, "rename");
        TWiki::UI::checkWebExists( $session, $newWeb, $newTopic );

        if ( $theAttachment) {
            # Does old attachment exist?
            unless( $session->{store}->attachmentExists( $oldWeb, $oldTopic,
                                                         $theAttachment )) {
                throw TWiki::UI::OopsException( $oldWeb, $oldTopic,
                                                "moveerr", $theAttachment );
            }
            # does new attachment already exist?
            if( $session->{store}->attachmentExists( $newWeb, $newTopic,
                                                     $theAttachment )) {
                throw TWiki::UI::OopsException( $newWeb, $newTopic,
                                                "moverr", $theAttachment );
            }
        } else {
            # Check new topic doesn't exist
            if( $newTopic &&
                $session->{store}->topicExists( $newWeb, $newTopic)) {
                # Unless moving an attachment, new topic should not exist
                throw TWiki::UI::OopsException( $newWeb, $newTopic,
                                                "topicexists" );
            }
        }

        TWiki::UI::checkAccess( $session, $oldWeb, $oldTopic,
                                "rename", $session->{user} );
    }

    # Has user selected new name yet?
    if( ! $newTopic || $confirm ) {
        _newTopicScreen( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment,
                         $confirm, $currentWebOnly, $doAllowNonWikiWord, $skin );
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
                throw TWiki::UI::OopsException( $newWeb, $newTopic,
                                                "moveerr",
                                                $theAttachment,
                                                $moveError );
            }
        } else {
            unless( TWiki::isValidWikiWord( $newTopic ) ) {
                unless( $doAllowNonWikiWord ) {
                    throw TWiki::UI::OopsException( $newWeb, $newTopic,
                                                    "renamenotwikiword" );
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
                throw TWiki::UI::OopsException( $oldWeb, $oldTopic,
                                                "renameerr",
                                                $renameError, $newWeb,
                                                $newTopic );
            }
        }
    }

    # Update references in referring pages - not applicable to attachments.
    if( ! $theAttachment ) {
        my @refs = _getReferringTopicsListFromURL( $session, $oldWeb, $oldTopic, $newWeb, $newTopic );

        my $problems =
          $session->{store}->updateReferringPages( $oldWeb, $oldTopic,
                                                   $session->{user},
                                                   $newWeb, $newTopic, @refs );
    }
    my $new_url = "";
    if ( $newWeb eq "Trash" && $oldWeb ne "Trash" ) {
        if( $theAttachment ) {
            # go back to old topic after deleting an attachment
            $new_url = $session->getScriptUrl( $oldWeb, $oldTopic, "view" );
        } else {
            # redirect to parent: ending in Trash is not the expected way
            my $meta = "";
            my $text = "";
            ( $meta, $text ) =
              $session->{store}->readTopic( undef, $newWeb, $newTopic, undef );
            my $parent = $meta->get( "TOPICPARENT" );
            if( $parent && $parent->{"name"} &&
                $parent->{"name"} ne $oldTopic ) {
                if ( $parent->{"name"} =~ /([^.]+)[.]([^.]+)/ ) {
                    $new_url = $session->getScriptUrl( $1, $2, "view" );
                } else {
                    $new_url =
                      $session->getScriptUrl( $oldWeb, $parent->{"name"}, "view" );
                }
            } else {
                $new_url = $session->getScriptUrl( $oldWeb, $TWiki::cfg{HomeTopicName}, "view" );
            }
        }
    } else {
        #redirect to new topic
        $new_url = $session->getScriptUrl( $newWeb, $newTopic, "view" );
    }

    $session->redirect( $new_url );
}

#| Description:           | returns the list of topics that have been found that refer to the renamed topic |
#| Parameter: =$oldWeb=   |   |
#| Parameter: =$oldTopic= |   |
#| Parameter: =$newWeb=   |   |
#| Parameter: =$newTopic= |   |
#| Return: =@refs=        |   |
#| TODO: | docco what the return list means |
sub _getReferringTopicsListFromURL {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my ( $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;

    my @result = ();

    # Go through parameters finding all topics for change
    my @types = qw\local global\;
    foreach my $type ( @types ) {
        my $count = 1;
        while( $query->param( "TOPIC$type$count" ) ) {
            my $checked = $query->param( "RENAME$type$count" );
            if ($checked) {
                push @result, $type;
                my $topic = $query->param( "TOPIC$type$count" );
                if ($topic =~ /^$oldWeb.$oldTopic$/ ) {
                    $topic = "$newWeb.$newTopic";
                }
                push @result, $topic;
            }
            $count++;
        }
    }
    return @result;
}

# Display screen so user can decide on new web and topic.
sub _newTopicScreen {
    my( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment,
        $confirm, $currentWebOnly, $doAllowNonWikiWord, $skin ) = @_;

    my $query = $session->{cgiQuery};
    my $tmpl = "";

    $newTopic = $oldTopic unless ( $newTopic );
    $newWeb = $oldWeb unless ( $newWeb );
    my $nonWikiWordFlag = "";
    $nonWikiWordFlag = 'checked="checked"' if( $doAllowNonWikiWord );

    if( $theAttachment ) {
        $tmpl = $session->{templates}->readTemplate( "moveattachment", $skin );
        $tmpl =~ s/%FILENAME%/$theAttachment/go;
    } elsif( $confirm ) {
        $tmpl = $session->{templates}->readTemplate( "renameconfirm", $skin );
    } elsif( $newWeb eq "Trash" ) {
        $tmpl = $session->{templates}->readTemplate( "renamedelete", $skin );
    } else {
        $tmpl = $session->{templates}->readTemplate( "rename", $skin );
    }

    $tmpl = _setVars( $tmpl, $oldTopic, $newWeb, $newTopic, $nonWikiWordFlag );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl );
    if( $currentWebOnly ) {
        $tmpl =~ s/%RESEARCH\{.*?web=\"all\".*\}%/(skipped)/o; # Remove search all web search
    }
    $tmpl =~ s/%RESEARCH/%SEARCH/go; # Pre search result from being rendered
    $tmpl = $session->handleCommonTags( $tmpl, $oldTopic, $oldWeb );
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags

    $session->writeCompletePage( $tmpl );
}

sub _setVars {
    my( $tmpl, $oldTopic, $newWeb, $newTopic, $nonWikiWordFlag ) = @_;
    $tmpl =~ s/%NEW_WEB%/$newWeb/go;
    $tmpl =~ s/%NEW_TOPIC%/$newTopic/go;
    $tmpl =~ s/%NONWIKIWORDFLAG%/$nonWikiWordFlag/go;
    return $tmpl;
}

1;
