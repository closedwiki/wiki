# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
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

---+ TWiki::UI::Manage

UI functions for web, topic and user management

=cut

package TWiki::UI::Manage;

use strict;
use TWiki;
use TWiki::UI;
use TWiki::User;

=pod

---+++ removeUser( $web, $topic, $userToRemove, $query )
Renames the user's topic (with renaming all links)
removes user entry from passwords. CGI parameters:
| =password= | |

=cut

sub removeUser {
    my( $webName, $topic, $wikiName, $query ) = @_;

    my $password = $query->param( 'password' );

    # check if user entry exists
    #TODO: need to handle the NoPasswdUser case (userPasswordExists will retun false here)
    if(  ( $wikiName )  && (! $TWiki::T->{users}->userPasswordExists( $wikiName ) ) ) {
        TWiki::UI::oops( $webName, $topic, "notwikiuser", $wikiName );
        return;
    }

    #check to see it the user we are trying to remove is a memebr of a group.
    #initially we refuse to delete the user
    #in a later implementation we will remove the from the group (if Access.pm implements it..)
    my @groups =  $TWiki::T->{security}->getGroupsUserIsIn( $wikiName );
    my $numberOfGroups =  $#groups;
    if ( $numberOfGroups > -1 ) { 
        TWiki::UI::oops( $webName, $topic, "genericerror");
        return;
    }

    my $pw = $TWiki::T->{users}->checkUserPasswd( $wikiName, $password );
    if( ! $pw ) {
        # NO - wrong old password
        TWiki::UI::oops( $webName, $topic, "wrongpassword");
        return;
    }

    #TODO: need to add GetUniqueTopicName
    #   # appends a unique number to the requested topicname
    #    my $newTopicName = TWiki::getUniqueTopicName("AnonymousContributor");
    #
    #   my $renameError = $TWiki::T->{store}->renameTopic( $TWiki::mainWebname, $wikiName, $TWiki::mainWebname, $newTopicName, "relink" );
    #
    #   if ( $renameError ) {
    #TODO: add better error message for rname failed
    #         TWiki::UI::oops( $webName, $topic, "renameerr");
    #         return;
    #     }
    #
    #    # Update references in referring pages - not applicable to attachments.
    #    my @refs = $TWiki::T->{store}->findReferringPages( $oldWeb, $oldTopic );
    #    my $problems;
    #    ( $lockFailure, $problems ) = 
    #       $TWiki::T->{store}->updateReferringPages( $oldWeb, $oldTopic, $wikiUserName, $newWeb, $newTopic, @refs );

    $TWiki::T->{users}->removeUser($wikiName);

    TWiki::UI::oops( $webName, $topic, "removeuserdone", $wikiName);
    return;
}

=pod

---+++ changePassword( $webName, $topic, $query )
Change the user's password. Details of the user and password
are passed in CGI parameters.
| =username= | |
| =password= | |
| =passwordA= | |
| =TopicName= | |

=cut

sub changePassword {
    my( $webName, $topic, $query ) = @_;

    my $wikiName = $query->param( 'username' );
    my $passwordA = $query->param( 'password' );
    my $passwordB = $query->param( 'passwordA' );

    # check if required fields are filled in
    if( ! $wikiName || ! $passwordA ) {
        TWiki::UI::oops( $webName, $topic, "regrequ", );
        return;
    }

    # check if user entry exists
    #TODO: need to handle the NoPasswdUser case (userPasswordExists will retun false here)
    if(  ( $wikiName )  && (! $TWiki::T->{users}->userPasswordExists( $wikiName ) ) ) {
        TWiki::UI::oops( $webName, $topic, "notwikiuser", $wikiName );
        return;
    }

    # check if passwords are identical
    if( $passwordA ne $passwordB ) {
        TWiki::UI::oops( $webName, $topic, "regpasswd" );
        return;
    }

    # c h a n g e
    my $oldpassword = $query->param( 'oldpassword' );

    # check if required fields are filled in
    if( ! $oldpassword ) {
        TWiki::UI::oops( $webName, $topic, "regrequ" );
        return;
    }

    my $pw = $TWiki::T->{users}->checkUserPasswd( $wikiName, $oldpassword );
    if( ! $pw ) {
        # NO - wrong old password
        TWiki::UI::oops( $webName, $topic, "wrongpassword");
        return;
    }

    # OK - password may be changed
    $TWiki::T->{users}->updateUserPassword($wikiName,  $oldpassword, $passwordA );

    # OK - password changed
    TWiki::UI::oops( $webName, $topic, "changepasswd" );
}

# PRIVATE Prepare a template var for expansion in a message
sub _template {
    my $theTmplVar = shift;
    return "%TMPL:P{\"$theTmplVar\"}%";
}

=pod

---++ createWeb( $web, $topic, $user, $query )
Create a new web. Parameters defining the new web are passed
in a CGI query.

| =newweb= | Name of new web |
| =baseweb= | Name of web to copy to create newweb |
| =webbgcolor= | background color for new web |
| =sitemapwhat= | |
| =sitemapuseto= | |
| =nosearchall= | |

=cut

sub createWeb {
    my( $webName, $topicName, $userName, $query ) = @_;

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
    my $wikiUserName = $TWiki::T->{users}->userToWikiName( $userName );
    return unless TWiki::UI::isAccessPermitted( $webName, $topicName,
                                                "manage", $wikiUserName );

    if( $newWeb =~ /^_[a-zA-Z0-9_]+$/ ) {
        # valid template web name, untaint
        $newWeb =~ /(.*)/;
        $newWeb = $1;
    } elsif( TWiki::isValidWebName( $newWeb ) ) {
        # valid web name, untaint
        $newWeb =~ /(.*)/;
        $newWeb = $1;
    } elsif( $newWeb ) {
        TWiki::UI::oops( "", "", $oopsTmpl, _template("msg_web_name") );
        return;
    } else {
        TWiki::UI::oops( "", "", $oopsTmpl, _template("msg_web_missing") );
        return;
    }

    if( $TWiki::T->{store}->topicExists( $newWeb, $TWiki::mainTopicname ) ) {
        TWiki::UI::oops( "", "", $oopsTmpl,
                         _template("msg_web_exist"), $newWeb );
        return;
    }

    $baseWeb =~ s/$TWiki::securityFilter//go;
    $baseWeb =~ /(.*)/;
    $baseWeb = $1;

    unless( $TWiki::T->{store}->topicExists( $baseWeb, $TWiki::mainTopicname ) ) {
        TWiki::UI::oops( "", "", $oopsTmpl, _template("msg_base_web"), $baseWeb );
        return;
    }

    unless( $webBgColor =~ /\#[0-9a-f]{6}/i ) {
        TWiki::UI::oops( "", "", $oopsTmpl, _template("msg_web_color") );
        return;
    }

    # create the empty web
    my $err = _createEmptyWeb( $newWeb );
    if( $err ) {
        TWiki::UI::oops( "", "", $oopsTmpl, _template("msg_web_create"), $err );
        return;
    }

    # copy needed topics from base web
    $err = _copyWebTopics( $baseWeb, $newWeb );
    if( $err ) {
        TWiki::UI::oops( $newWeb, "", $oopsTmpl, _template("msg_web_copy_topics"), $err );
        return;
    }

    # patch WebPreferences
    $err = _patchWebPreferences( $newWeb, $TWiki::webPrefsTopicname, $webBgColor,
                                 $siteMapWhat, $siteMapUseTo, $noSearchAll );
    if( $err ) {
        TWiki::UI::oops( $newWeb, $TWiki::webPrefsTopicname, $oopsTmpl, _template("msg_patch_webpreferences"), $err );
        return;
    }

    # everything OK, redirect to last message
    $newTopic = $TWiki::mainTopicname unless( $newTopic );
    TWiki::UI::oops( $newWeb, $newTopic, $oopsTmpl, _template("msg_create_web_ok") );
    return;
}

# CODE_SMELL: Surely this should be done by Store?
sub _createEmptyWeb {
    my ( $theWeb ) = @_;

    my $dir = "$TWiki::dataDir/$theWeb";
    umask( 0 );
    unless( mkdir( $dir, 0775 ) ) {
        return( "Could not create $dir, error: $!" );
    }

    if ( $TWiki::useRcsDir ) {
        unless( mkdir( "$dir/RCS", 0775 ) ) {
            return( "Could not create $dir/RCS, error: $!" );
        }
    }

    unless( open( FILE, ">$dir/.changes" ) ) {
        return( "Could not create changes file $dir/.changes, error: $!" );
    }
    print FILE "";  # empty file
    close( FILE );

    unless( open( FILE, ">$dir/.mailnotify" ) ) {
        return( "Could not create mailnotify timestamp file $dir/.mailnotify, error: $!" );
    }
    print FILE "";  # empty file
    close( FILE );
    return "";
}

sub _copyWebTopics
{
    my ( $theBaseWeb, $theNewWeb ) = @_;

    my $err = "";
    my @topicList = $TWiki::T->{store}->getTopicNames( $theBaseWeb );
    unless( $theBaseWeb =~ /^_/ ) {
        # not a template web, so filter for only Web* topics
        @topicList = grep { /^Web/ } @topicList;
    }
    foreach my $topic ( @topicList ) {
        $topic =~ s/$TWiki::securityFilter//go;
        $topic =~ /(.*)/;
        $topic = $1;
        $err = $TWiki::T->{store}->copyTopicBetweenWebs( $theBaseWeb,
                                                    $topic, $theNewWeb );
        return( $err ) if( $err );
    }
    return "";
}

sub _patchWebPreferences
{
    my ( $theWeb, $theTopic, $theWebBgColor, $theSiteMapWhat, $theSiteMapUseTo, $doNoSearchAll ) = @_;

    my( $meta, $text ) =
      $TWiki::T->{store}->readTopic( Wikiusername(),
                                $theWeb, $theTopic, undef, 1 );

    my $siteMapList = "";
    $siteMapList = "on" if( $theSiteMapWhat );
    $text =~ s/(\s\* Set WEBBGCOLOR =)[^\n\r]*/$1 $theWebBgColor/os;
    $text =~ s/(\s\* Set SITEMAPLIST =)[^\n\r]*/$1 $siteMapList/os;
    $text =~ s/(\s\* Set SITEMAPWHAT =)[^\n\r]*/$1 $theSiteMapWhat/os;
    $text =~ s/(\s\* Set SITEMAPUSETO =)[^\n\r]*/$1 $theSiteMapUseTo/os;
    $text =~ s/(\s\* Set NOSEARCHALL =)[^\n\r]*/$1 $doNoSearchAll/os;

    my $err = $TWiki::T->{store}->saveTopic( Username(), $theWeb, $theTopic, $text, $meta );

    return $err;
}

=pod

---+++ rename( $web, $topic, $user, $query )
Rename the given topic. Details of the new topic name are passed in CGI
paremeters:
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
    my ( $oldWeb, $oldTopic, $userName, $query ) = @_;

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

    my $skin = TWiki::getSkin();

    $newTopic =~ s/\s//go;
    $newTopic =~ s/$TWiki::securityFilter//go;

    if( ! $theAttachment ) {
        $theAttachment = "";
    }

    my $wikiUserName = $TWiki::T->{users}->userToWikiName( $userName );

    # justChangeRefs will be true when some topics that had links to $oldTopic
    # still need updating, previous update being prevented by a lock.

    unless ( $justChangeRefs ||
             _checkExist( $oldWeb, $oldTopic, $newWeb, $newTopic,
                          $theAttachment ) &&
             TWiki::UI::isAccessPermitted( $oldWeb, $oldTopic,
                                           "change", $wikiUserName ) &&
             TWiki::UI::isAccessPermitted( $oldWeb, $oldTopic,
                                           "rename", $wikiUserName )
           ) {
        return;
    }

    # Has user selected new name yet?
    if( ! $newTopic || $confirm ) {
        _newTopicScreen( $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment,
                         $confirm, $currentWebOnly, $doAllowNonWikiWord, $skin );
        return;
  }

    if( ! $justChangeRefs ) {
        if( ! _getLocks( $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment, $breakLock, $skin ) ) {
            return;
        }
    }

    if( ! $justChangeRefs ) {
        if( $theAttachment ) {
            my $moveError = 
              $TWiki::T->{store}->moveAttachment( $oldWeb, $oldTopic,
                                             $newWeb, $newTopic,
                                             $theAttachment,
                                             $userName );

            if( $moveError ) {
                TWiki::UI::oops( $newWeb, $newTopic, "moveerr",
                                 $theAttachment, $moveError );
                return;
            }
        } else {
            if( ! $doAllowNonWikiWord &&
                ! TWiki::isValidWikiWord( $newTopic ) ) {
                TWiki::UI::oops( $newWeb, $newTopic, "renamenotwikiword" );
                return;
            }

            my $renameError =
              $TWiki::T->{store}->renameTopic( $oldWeb, $oldTopic, $newWeb,
                                          $newTopic, 1, $userName );
            if( $renameError ) {
                TWiki::UI::oops( $oldWeb, $oldTopic, "renameerr",
                                 $renameError, $newWeb, $newTopic );
                return;
            }
        }
    }

    # Update references in referring pages - not applicable to attachments.
    if( ! $theAttachment ) {
        my @refs = _getReferringTopicsListFromURL( $oldWeb, $oldTopic, $newWeb, $newTopic );

        my $problems;
        ( $lockFailure, $problems ) = 
          $TWiki::T->{store}->updateReferringPages( $oldWeb, $oldTopic, $wikiUserName, $newWeb, $newTopic, @refs );
    }

    my $new_url = "";
    if( $lockFailure ) {
        _moreRefsToChange( $oldWeb, $oldTopic, $newWeb, $newTopic, $skin );
        return;
    } elsif ( "$newWeb" eq "Trash" && "$oldWeb" ne "Trash" ) {
        if( $theAttachment ) {
            # go back to old topic after deleting an attachment
            $new_url = &TWiki::getViewUrl( $oldWeb, $oldTopic );
        } else {
            # redirect to parent: ending in Trash is not the expected way
            my $meta = "";
            my $text = "";
            ( $meta, $text ) =
              $TWiki::T->{store}->readTopic( $wikiUserName, $newWeb, $newTopic,
                                        undef, 1 );
            my %parent = $meta->findOne( "TOPICPARENT" );
            if( %parent && $parent{"name"} &&
                $parent{"name"} ne $oldTopic ) {
                if ( $parent{"name"} =~ /([^.]+)[.]([^.]+)/ ) {
                    $new_url = TWiki::getViewUrl( $1, $2 );
                } else {
                    $new_url =
                      TWiki::getViewUrl( $oldWeb, $parent{"name"} );
                }
            } else {
                $new_url = TWiki::getViewUrl( $oldWeb, $TWiki::mainTopicname );
            }
        }
    } else {
        #redirect to new topic
        $new_url = TWiki::getViewUrl( $newWeb, $newTopic );
    }

    TWiki::UI::redirect( $new_url );
    return;
}

=pod

---++ _getReferringTopicsListFromURL ( $oldWeb, $oldTopic, $newWeb, $newTopic ) ==> @refs
| Description:           | returns the list of topics that have been found that refer to the renamed topic |
| Parameter: =$oldWeb=   |   |
| Parameter: =$oldTopic= |   |
| Parameter: =$newWeb=   |   |
| Parameter: =$newTopic= |   |
| Return: =@refs=        |   |
| TODO: | docco what the return list means |

=cut

sub _getReferringTopicsListFromURL {
    my $query = TWiki::getCgiQuery();
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

# Check that various webs and topics exist or don't exist as required
sub _checkExist {
    my( $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment ) = @_;

    my $ret = 0;
    my $query = TWiki::getCgiQuery();

    $ret = 1 unless TWiki::UI::webExists( $oldWeb, $oldTopic );
    $ret = 1 unless TWiki::UI::webExists( $newWeb, $newTopic );

    if ( $theAttachment) {
        # Does old attachment exist?
        unless( $TWiki::T->{store}->attachmentExists( $oldWeb, $oldTopic,
                                                 $theAttachment )) {
            TWiki::UI::oops( $oldWeb, $oldTopic, "moveerr", $theAttachment );
            $ret = 1;
        }
        # does new attachment already exist?
        if( $TWiki::T->{store}->attachmentExists( $newWeb, $newTopic,
                                             $theAttachment )) {
            TWiki::UI::oops( $newWeb, $newTopic, "moverr", $theAttachment );
            $ret = 1;
        }
    } else {
        # Check new topic doesn't exist
        if( $newTopic && $TWiki::T->{store}->topicExists( $newWeb, $newTopic)) {
            # Unless moving an attachment, new topic should not already exist
            TWiki::UI::oops( $newWeb, $newTopic, "topicexists" );
            $ret = 1;
        }
    }

    return $ret;
}


# Return 1 if can't get lock, otherwise 0
sub _getLocks {
    my( $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment, $breakLock, $skin ) = @_;

    my( $oldLockUser, $oldLockTime, $newLockUser, $newLockTime );
    my $query = TWiki::getCgiQuery();

    if( ! $breakLock ) {
        # Check for lock - at present the lock can't be broken
        ( $oldLockUser, $oldLockTime ) =
          $TWiki::T->{store}->topicIsLockedBy( $oldWeb, $oldTopic );
        if( $oldLockUser ) {
            $oldLockUser = $TWiki::T->{users}->userToWikiName( $oldLockUser );
            use integer;
            $oldLockTime = ( $oldLockTime / 60 ) + 1; # convert to minutes
        }

        if( $theAttachment ) {
            ( $newLockUser, $newLockTime ) =
              $TWiki::T->{store}->topicIsLockedBy( $newWeb, $newTopic );
            if( $newLockUser ) {
                $newLockUser = $TWiki::T->{users}->userToWikiName( $newLockUser );
                use integer;
                $newLockTime = ( $newLockTime / 60 ) + 1; # convert to minutes
                my $editLock = $TWiki::editLockTime / 60;
            }
        }
    }

    if( $oldLockUser || $newLockUser ) {
        my $tmpl = $TWiki::T->{templates}->readTemplate( "oopslockedrename", $skin );
        my $editLock = $TWiki::editLockTime / 60;
        if( $oldLockUser ) {
            $tmpl =~ s/%OLD_LOCK%/Source topic $oldWeb.$oldTopic is locked by $oldLockUser, lock expires in $oldLockTime minutes.<br \/>/go;
        } else {
            $tmpl =~ s/%OLD_LOCK%//go;
        }
        if( $newLockUser ) {
            $tmpl =~ s/%NEW_LOCK%/Destination topic $newWeb.$newTopic is locked by $newLockUser, lock expires in $newLockTime minutes.<br \/>/go;
        } else {
            $tmpl =~ s/%NEW_LOCK%//go;
        }
        $tmpl =~ s/%NEW_WEB%/$newWeb/go;
        $tmpl =~ s/%NEW_TOPIC%/$newTopic/go;
        $tmpl =~ s/%ATTACHMENT%/$theAttachment/go;
        $tmpl = &TWiki::handleCommonTags( $tmpl, $oldTopic, $oldWeb );
        $tmpl = $TWiki::T->{renderer}->getRenderedVersion( $tmpl, $oldWeb );
        $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
        # SMELL: this is a redirect!
        TWiki::writeHeader( $query, length( $tmpl ));
        print $tmpl;
        return 0;
    } else {
        $TWiki::T->{store}->lockTopic( $oldWeb, $oldTopic );
    }

    return 1;
}

# Display screen so user can decide on new web and topic.
sub _newTopicScreen {
    my( $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment,
        $confirm, $currentWebOnly, $doAllowNonWikiWord, $skin ) = @_;

    my $query = TWiki::getCgiQuery();
    my $tmpl = "";

    $newTopic = $oldTopic unless ( $newTopic );
    $newWeb = $oldWeb unless ( $newWeb );
    my $nonWikiWordFlag = "";
    $nonWikiWordFlag = 'checked="checked"' if( $doAllowNonWikiWord );

    if( $theAttachment ) {
        $tmpl = $TWiki::T->{templates}->readTemplate( "moveattachment", $skin );
        $tmpl =~ s/%FILENAME%/$theAttachment/go;
    } elsif( $confirm ) {
        $tmpl = $TWiki::T->{templates}->readTemplate( "renameconfirm", $skin );
    } elsif( $newWeb eq "Trash" ) {
        $tmpl = $TWiki::T->{templates}->readTemplate( "renamedelete", $skin );
    } else {
        $tmpl = $TWiki::T->{templates}->readTemplate( "rename", $skin );
    }

    $tmpl = _setVars( $tmpl, $oldTopic, $newWeb, $newTopic, $nonWikiWordFlag );
    $tmpl = &TWiki::handleCommonTags( $tmpl, $oldTopic, $oldWeb );
    $tmpl = $TWiki::T->{renderer}->getRenderedVersion( $tmpl );
    if( $currentWebOnly ) {
        $tmpl =~ s/%RESEARCH\{.*?web=\"all\".*\}%/(skipped)/o; # Remove search all web search
    }
    $tmpl =~ s/%RESEARCH/%SEARCH/go; # Pre search result from being rendered
    $tmpl = &TWiki::handleCommonTags( $tmpl, $oldTopic, $oldWeb );   
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags

    TWiki::writeHeader( $query, length( $tmpl ));
    print $tmpl;
}

sub _setVars {
    my( $tmpl, $oldTopic, $newWeb, $newTopic, $nonWikiWordFlag ) = @_;
    $tmpl =~ s/%NEW_WEB%/$newWeb/go;
    $tmpl =~ s/%NEW_TOPIC%/$newTopic/go;
    $tmpl =~ s/%NONWIKIWORDFLAG%/$nonWikiWordFlag/go;
    return $tmpl;
}

sub _moreRefsToChange {
    my( $oldWeb, $oldTopic, $newWeb, $newTopic, $skin ) = @_;
    my $query = TWiki::getCgiQuery();

    my $tmpl = $TWiki::T->{templates}->readTemplate( "renamerefs", $skin );
    $tmpl = _setVars( $tmpl, $oldTopic, $newWeb, $newTopic );
    $tmpl = $TWiki::T->{renderer}->getRenderedVersion( $tmpl );
    $tmpl =~ s/%RESEARCH/%SEARCH/go; # Pre search result from being rendered
    $tmpl = TWiki::handleCommonTags( $tmpl, $oldTopic, $oldWeb );
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags

    TWiki::writeHeader( $query, length( $tmpl ));
    print $tmpl;
}

1;
