#
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

---+ TWiki::UI::Save

UI delegate for save function

=cut

package TWiki::UI::Save;

use strict;
use TWiki;
use TWiki::UI;
use TWiki::UI::Preview;
use Error qw( :try );
use TWiki::UI::OopsException;

# Private - do not call outside this module!
# Returns 1 if caller should redirect to view when done
# 0 otherwise (redirect has already been handled)
sub _save {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    TWiki::UI::checkMirror( $session, $webName, $topic );
    TWiki::UI::checkWebExists( $session, $webName, $topic );

    my $topicExists  = $session->{store}->topicExists( $webName, $topic );

    # Prevent saving existing topic?
    my $onlyNewTopic = $query->param( 'onlynewtopic' ) || "";
    if( $onlyNewTopic && $topicExists ) {
        # Topic exists and user requested oops if it exists
        throw TWiki::UI::OopsException( $webName, $topic, "createnewtopic" );
    }

    # prevent non-Wiki names?
    my $onlyWikiName = $query->param( 'onlywikiname' ) || "";
    if( ( $onlyWikiName )
        && ( ! $topicExists )
        && ( ! TWiki::isValidTopicName( $topic ) ) ) {
        # do not allow non-wikinames, redirect to view topic
        # SMELL: this should be an oops, shouldn't it?
        $session->redirect( $session->getScriptUrl( $webName, $topic, "view" ) );
        return 0;
    }

    my $userName = $session->{userName};
    my $wikiUserName = $session->{wikiUserName};

    TWiki::UI::checkAccess( $session, $webName, $topic,
                            "change", $wikiUserName );

    my $saveCmd = $query->param( "cmd" );
    if ( $saveCmd ) {
         # check permission for undocumented cmd=... parameter
        TWiki::UI::checkAdmin( $session, $webName, $topic, $wikiUserName );
    }

    if( $saveCmd eq "delRev" ) {
        # delete top revision
        my $error =
          $session->{store}->delRev( $userName, $webName, $topic );
        if( $error ) {
            throw TWiki::UI::OopsException( $webName, $topic,
                                            "saveerr", $error );
        }

        return 1;
    }

    if( $query->param( 'submitchangeform' )) {
        $session->{form}->changeForm( $webName, $topic );
        # return 0 to prevent extra redirect
        return 0;
    }

    my( $meta, $text );

    # A template was requested; read it, and expand URLPARAMs within the
    # template using our CGI record
    my $templatetopic = $query->param( "templatetopic");
    if ($templatetopic) {
        ($meta, $text) =
          $session->{store}->readTopic( $wikiUserName, $webName,
                                        $templatetopic, undef, 0 );
        $text = $session->expandVariablesOnTopicCreation( $text );
    } else {
        $text = $query->param( "text" );
    }
	
    if( ! ( defined $text ) ) {
        throw TWiki::UI::OopsException( $webName, $topic, "save" );
    } elsif( ! $text ) {
        # empty topic not allowed
        throw TWiki::UI::OopsException( $webName, $topic, "empty" );
    }

    $text = TWiki::decodeSpecialChars( $text );
    $text =~ s/ {3}/\t/go;

    my $saveOpts = {};
    $saveOpts->{unlock} = 1 if $query->param( "unlock" );
    $saveOpts->{dontnotify} = 1 if $query->param( "dontnotify" );
    $saveOpts->{forcenewrevision} = 1 if $query->param( "forcenewrevision" );

    if( $saveCmd eq "repRev" ) {
        $text =~ s/%__(.)__%/%_$1_%/go;
        $meta = $session->{store}->extractMetaData( $webName, $topic, \$text );
        # replace top revision with this text
        my $error =
          $session->{store}->repRev( $userName, $webName, $topic,
                                     $text, $meta, $saveOpts );
        if( $error ) {
            throw TWiki::UI::OopsException( $webName, $topic,
                                            "saveerr", $error );
        }

        return 1;
    }

    my $tmp;
    # read meta (if not already read when reading template)
    ( $meta, $tmp ) =
      $session->{store}->readTopic( $wikiUserName, $webName, $topic, undef, 0 ) unless $meta;

    my $theParent = $query->param( 'topicparent' ) || "";

    # parent setting
    if( $theParent eq "none" ) {
        $meta->remove( "TOPICPARENT" );
    } elsif( $theParent ) {
        $meta->put( "TOPICPARENT", ( "name" => $theParent ) );
    }

    my $formTemplate = $query->param( "formtemplate" );
    if( $formTemplate ) {
        $meta->remove( "FORM" );
        $meta->put( "FORM", ( name => $formTemplate ) ) if( $formTemplate ne "none" );
    }

    # Expand field variables, unless this new page is templated
    $session->{form}->fieldVars2Meta( $webName, $query, $meta ) unless $templatetopic;
    $meta->updateSets( \$text );

    my $error =
      $session->{store}->saveTopic( $userName, $webName, $topic,
                                    $text, $meta, $saveOpts );

    if( $error ) {
        throw TWiki::UI::OopsException( $webName, $topic, "saveerr", $error );
    }

    return 1;
}

=pod

---++ save( )
Command handler for save command. Some parameters are passed in CGI:
| =action= | savemulti overrides, everything else is passed on the normal =save= |
action values are:
| =save= | save, unlock topic, return to view, dontnotify is OFF |
| =quietsave= | save, unlock topic,  return to view, dontnotify is ON |
| =checkpoint= | save and continue editing, dontnotify is ON |
| =cancel= | exit without save, unlock topic, return to view (does _not_ undo Checkpoint saves) |
| =preview= | preview edit text; same as before |
This function can replace "save" eventually.

=cut

sub save {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $userName = $session->{userName};

    my $redirecturl = $session->getScriptUrl( $session->normalizeWebTopicName($webName, $topic), "view" );

    my $saveaction = lc($query->param( 'action' ));
    if ( $saveaction eq "checkpoint" ) {
        $query->param( -name=>"dontnotify", -value=>"checked" );
        $query->param( -name=>"unlock", -value=>'0' );
        my $editURL = $session->getScriptUrl( $webName, $topic, "edit" );
        my $randompart = randomURL();
        $redirecturl = "$editURL|$randompart";
    } elsif ( $saveaction eq "quietsave" ) {
        $query->param( -name=>"dontnotify", -value=>"checked" );
    } elsif ( $saveaction eq "cancel" ) {
        my $viewURL = $session->getScriptUrl( $webName, $topic, "view" );
        $session->redirect( "$viewURL?unlock=on" );
        return;
    } elsif( $saveaction eq "preview" ) {
        TWiki::UI::Preview::preview( $webName, $topic, $userName, $query );
        return;
    }

    # save called by preview
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

