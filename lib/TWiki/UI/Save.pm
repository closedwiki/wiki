# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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

---+ package TWiki::UI::Save

UI delegate for save function

=cut

package TWiki::UI::Save;

use strict;
use TWiki;
use TWiki::UI;
use TWiki::UI::Preview;
use Error qw( :try );
use TWiki::UI::OopsException;
use TWiki::Merge;
use Assert;

# Private - do not call outside this module!
# Returns 1 if caller should redirect to view when done
# 0 otherwise (redirect has already been handled)
sub _save {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    TWiki::UI::checkMirror( $session, $webName, $topic );
    TWiki::UI::checkWebExists( $session, $webName, $topic, 'save' );

    my $topicExists  = $session->{store}->topicExists( $webName, $topic );
    # Prevent saving existing topic?
    my $onlyNewTopic = $query->param( 'onlynewtopic' ) || '';
    if( $onlyNewTopic && $topicExists ) {
        # Topic exists and user requested oops if it exists
        throw TWiki::UI::OopsException( $webName, $topic, 'createnewtopic' );
    }

    # prevent non-Wiki names?
    my $onlyWikiName = $query->param( 'onlywikiname' ) || '';
    if( ( $onlyWikiName )
        && ( ! $topicExists )
        && ( ! TWiki::isValidTopicName( $topic ) ) ) {
        # do not allow non-wikinames, redirect to view topic
        # SMELL: this should be an oops, shouldn't it?
        $session->redirect( $session->getScriptUrl( $webName, $topic, 'view' ) );
        return 0;
    }

    my $user = $session->{user};
    TWiki::UI::checkAccess( $session, $webName, $topic,
                            'change', $user );

    my $saveCmd = $query->param( 'cmd' ) || 0;
    if ( $saveCmd && ! $session->{user}->isAdmin()) {
        throw TWiki::UI::OopsException( $webName, $topic, 'accessgroup',
                                        "$TWiki::cfg{UsersWebName}.$TWiki::cfg{SuperAdminGroup}" );
    }

    if( $saveCmd eq 'delRev' ) {
        # delete top revision
        my $error =
          $session->{store}->delRev( $user, $webName, $topic );
        if( $error ) {
            throw TWiki::UI::OopsException( $webName, $topic,
                                            'saveerr', $error );
        }

        return 1;
    }

    if( $query->param( 'submitChangeForm' )) {
        $session->writeCompletePage
          ( TWiki::UI::generateChangeFormPage( $session, $webName, $topic ) );
        # return 0 to prevent extra redirect
        return 0;
    }

    my ( $newText, $newMeta );   # new topic info being saved
    my ( $currText, $currMeta ); # current head (if any)
    my $originalrev; # rev edit started on

    # A template was requested; read it, and expand URLPARAMs within the
    # template using our CGI record
    my $templatetopic = $query->param( 'templatetopic');
    if ($templatetopic) {
        ( $newMeta, $newText ) =
          $session->{store}->readTopic( $session->{user}, $webName,
                                        $templatetopic, undef );
        $newText = $session->expandVariablesOnTopicCreation( $newText );
        # topic creation, make sure there is no original rev
        $originalrev = 0;
    } else {
        $originalrev = $query->param( 'originalrev' );
        $newText = $query->param( 'text' );
    }

    my $saveOpts = {};
    $saveOpts->{minor} = 1 if $query->param( 'dontnotify' );
    # note: always force a new rev if the topic is empty, in case this
    # is a mistake.
    $saveOpts->{forcenewrevision} = 1
      if( $query->param( 'forcenewrevision' ) || !$newText );

    $newText ||= '';

    if( $saveCmd eq 'repRev' ) {
        $newText =~ s/%__(.)__%/%_$1_%/go;
        $newMeta = $session->{store}->extractMetaData( $webName, $topic, \$newText );
        # replace top revision with this text, trying to make it look as
        # much like the original as possible
        $saveOpts->{timetravel} = 1;
        my $error =
          $session->{store}->repRev( $user, $webName, $topic,
                                     $newText, $newMeta, $saveOpts );
        if( $error ) {
            throw TWiki::UI::OopsException( $webName, $topic,
                                            'saveerr', $error );
        }

        return 1;
    }

    if ( ! $templatetopic ) {
        ( $currMeta, $currText ) =
          $session->{store}->readTopic( undef, $webName, $topic, undef );
        $newMeta = new TWiki::Meta( $session, $webName, $topic );
        $newMeta->copyFrom( $currMeta );
    }

    my $theParent = $query->param( 'topicparent' ) || '';

    # parent setting
    if( $theParent eq 'none' ) {
        $newMeta->remove( 'TOPICPARENT' );
    } elsif( $theParent ) {
        $newMeta->put( 'TOPICPARENT', { 'name' => $theParent } );
    }

    my $formTemplate = $query->param( 'formtemplate' );
    if( $formTemplate ) {
        $newMeta->remove( 'FORM' );
        $newMeta->put( 'FORM', { name => $formTemplate } ) if( $formTemplate ne 'none' );
    }

    # Expand field variables.
    $session->{form}->fieldVars2Meta( $webName, $query, $newMeta );
    $newMeta->updateSets( \$newText );

    # assumes rev numbers start at 1
    if ( $originalrev ) {
        my ( $date, $author, $rev ) = $newMeta->getRevisionInfo();
        # If the last save was by me, don't merge
        if ( $rev ne $originalrev && !$author->equals( $user )) {
            $newText = TWiki::Merge::insDelMerge( $currText, $newText, "\\r?\\n" );
            $newMeta->merge( $currMeta );
            $newText .= "\n\nMERGED " . $author->stringify() .
              ' and ' . $user->stringify() . " original $originalrev current $rev\n";
        }
    }

    my $error =
      $session->{store}->saveTopic( $user, $webName, $topic,
                                    $newText, $newMeta, $saveOpts );

    if( $error ) {
        throw TWiki::UI::OopsException( $webName, $topic, 'saveerr', $error );
    }

    return 1;
}

=pod

---++ StaticMethod save($session)

Command handler for =save= command.
This method is designed to be
invoked via the =TWiki::UI::run= method.

Some parameters are passed in CGI:

| =cmd= | DEPRECATED optionally delRev or repRev, which trigger those actions. |
| =dontnotify= | if defined, suppress change notification |
| =submitChangeForm= | |
| =topicparent= | |
| =formtemplate= | if defined, use the named template for the form |
| =action= | savemulti overrides, everything else is passed on the normal =save= |

action values are:

| =save= | save, return to view, dontnotify is OFF |
| =quietsave= | save, return to view, dontnotify is ON |
| =checkpoint= | save and continue editing, dontnotify is ON |
| =cancel= | exit without save, return to view (does _not_ undo Checkpoint saves) |
| =preview= | preview edit text; same as before |

=cmd= has been deprecated in favour of =action=. It will be deleted at
some point.

=cut

sub save {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    my $redirecturl = $session->getScriptUrl( $session->normalizeWebTopicName($webName, $topic), 'view' );

    my $saveaction = lc($query->param( 'action' ));

    if ( $saveaction eq 'checkpoint' ) {
        $query->param( -name=>'dontnotify', -value=>'checked' );
        my $editURL = $session->getScriptUrl( $webName, $topic, 'edit' );
        my $randompart = randomURL();
        $redirecturl = $editURL.'|'.$randompart;
    } elsif ( $saveaction eq 'quietsave' ) {
        $query->param( -name=>'dontnotify', -value=>'checked' );
    } elsif ( $saveaction eq 'cancel' ) {
        my $viewURL = $session->getScriptUrl( $webName, $topic, 'view' );
        $session->redirect( $viewURL );
        return;
    } elsif( $saveaction eq 'preview' ) {
        TWiki::UI::Preview::preview( $session );
        return;
    } elsif( $saveaction =~ /^(del|rep)Rev$/ ) {
        $query->param( -name => 'cmd', -value => $saveaction );
    }

    if ( _save( $session )) {
        $session->redirect( $redirecturl );
    }
}

## Random URL:
# returns 4 random bytes in 0x01-0x1f range in %xx form
# =========================
sub randomURL
{
    my (@hc) = (qw (01 02 03 04 05 06 07 08 09 0b 0c 0d 0e 0f 10
                    11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f));
    #  srand; # needed only for perl < 5.004
    return "%$hc[rand(30)]%$hc[rand(30)]%$hc[rand(30)]%$hc[rand(30)]";
}

1;

