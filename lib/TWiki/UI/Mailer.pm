#
# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
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
use strict;
use TWiki;

use TWiki::Net;
use TWiki::Store;

use TWiki::Mailer::WebNotify;
use TWiki::Mailer::Change;

=begin text

---++ package TWiki::Contrib::Mailer

Package of support for extended Web<nop>Notify notification, supporting per-topic notification and notification of changes to children.

Also supported is a simple API that can be used to change the Web<nop>Notify topic from other code.

=cut

package TWiki::UI::Mailer;

=begin text

---+++ sub notify( $session )

Process the Web<nop>Notify topics in each web and generate and issue
notification mails. Designed to be invoked from the command line; should
only be called by =mailnotify= script.

=cut

sub notify {
    my $session = shift;

    my $query = $session->{cgiQuery};

    # If true, will send mails. If false, will print to STDOUT
    my $sendmail = $query->param( "sendmail" );
    my $verbose = $query->param( "verbose" );
    my $webstr = $query->param( "webs" );

    my @webs = ( '*' );
    @webs = split(/[,\s]+/, $webstr) if $webstr;

    my $webRE = join( "|", @webs );
    $webRE =~ s/\*/\.\*/g;

    # SMELL: have to getAllWebs, because getPublicWebList only returns public
    # webs.
    foreach my $web ( grep( /$webRE/o, $session->{store}->getAllWebs() )) {
        if ( TWiki::isValidWebName( $web )) {
            _processWeb( $session, $web, $sendmail, $verbose );
        }
    }
}

# PRIVATE: Read the webnotify, and notify changes
sub _processWeb {
    my( $session, $web, $sendmail, $verbose ) = @_;

    $session = new TWiki( "/$web", "nobody" );

    if( ! $session->{store}->webExists( $web ) ) {
        print "**** ERROR mailnotifier cannot find web $web\n";
        return;
    }

    print "Processing $web\n" if $verbose;

    # Read the webnotify and load subscriptions
    my $wn = new TWiki::Mailer::WebNotify( $session, $web );

    if ( $wn->isEmpty() ) {
        print "\t$web has no subscribers\n" if $verbose;
    } else {
        _processChanges( $session, $web, $wn, $sendmail, $verbose );
    }
}

sub _processChanges {
    my ( $session, $web, $notify, $sendmail, $verbose ) = @_;

    my $prevLastmodify =
      $session->{store}->readMetaData( $web, "mailnotify" ) || 0;
    my $currLastmodify = "";

    if ( $verbose ) {
        print "\tLast notification was at " .
          TWiki::formatTime( $prevLastmodify ). "\n";
    }

    # hash indexed on email address, each entry of which contains an
    # array of MailerContrib::Change objects
    my %changeset;
    # hash indexed on email address, each entry contains a hash
    # of topics already processed in the change set for this email.
    # Each subhash maps the topic name to the index of the change
    # record for this topic in the array of Change objects for this
    # email in %changeset.
    my %seenset;
    my $changes = $session->{store}->readMetaData($web, "changes" );

    unless ( $changes ) {
        print "No changes\n" if ( $verbose );
        return;
    }

    foreach( reverse split( /\n/, $changes ) ) {
        # Parse lines from .changes:
        # <topic>	<user>		<change time>	<revision>
        # WebHome	FredBloggs	1014591347	21
        my ($topicName, $userName, $changeTime, $revision) = split( /\t/);

        next unless $session->{store}->topicExists( $web, $topicName );

        # First formulate a change record, irrespective of
        # whether any subscriber is interested
        if( ! $currLastmodify ) {
            if( $prevLastmodify eq $changeTime ) {
                # newest entry is same as at time of previous notification
                return;
            }
            $currLastmodify = $changeTime;
        }

        if( $prevLastmodify >= $changeTime ) {
            # found last notification
            last;
        }
        my $frev = "";
        if( $revision ) {
            if( $revision > 1 ) {
                $frev = "r1.$revision";
            } else {
                $frev = "<b>NEW</b>";
            }
        }

        print "\tFound change to $topicName\n" if ( $verbose );

        my $change =
          new TWiki::Mailer::Change
            ( $web,
              $topicName,
              $session->{users}->userToWikiName( $userName, 0 ),
              TWiki::formatTime( $changeTime ),
              $frev,
              # SMELL: Call to TWiki::makeTopicSummary is unavoidable
              $session->{renderer}->makeTopicSummary
              ( $session->{store}->readTopicRaw( $session->{wikiUserName},
                                           $web, $topicName, undef, 1 ),
                $topicName, $web ));

        # Now, find subscribers to this change and extend the change set
        $notify->processChange( $change, $web, \%changeset, \%seenset );
    }

    # Now generate emails for each recipient
    _generateEmails( $session, $web,
                     \%changeset,
                     TWiki::formatTime($prevLastmodify),
                   $sendmail, $verbose );

    # Only update the memory topic if mails were sent
    if ( $sendmail ) {
        $session->{store}->saveMetaData( $web, "mailnotify", $currLastmodify );
    }
}

# PRIVATE generate and send an email for each user
sub _generateEmails {
    my ( $session, $web, $changeset, $lastTime, $sendmail, $verbose ) = @_;

    my $skin = $session->{prefs}->getPreferencesValue( "SKIN" );

    my $template = $session->{templates}->readTemplate( "changes", $skin );

    $template = $session->handleCommonTags( $template, $session->{topicName},
                                            $web );
    $template =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

    # SMELL: unexported function call TWiki:: doRemoveImgInMailnotify
    # STINK: preferences like this should be exported from TWiki.cfg
    if( $TWiki::doRemoveImgInMailnotify ) {
        # change images to [alt] text if there, else remove image
        $template =~ s/<img src=.*?alt=\"([^\"]+)[^>]*>/[$1]/goi;
        $template =~ s/<img src=.*?[^>]>//goi;
    }

    my ( $before, $middle, $after) = split( /%REPEAT%/, $template );
    $before = $session->{renderer}->getRenderedVersion( $before );
    $after = $session->{renderer}->getRenderedVersion( $after );
    $middle =~ s/%LOCKED%//go; # SMELL: Legacy?

    my $mailtmpl = $session->{templates}->readTemplate( "mailnotify", $skin );

    my $sentMails = 0;

    foreach my $email ( keys %{$changeset} ) {
        my $html = "";
        my $plain = "";

        foreach my $change (sort { $a->{TOPIC} cmp $b->{TOPIC} }
                            @{$changeset->{$email}} ) {

            $html .= $change->expandHTML( $session, $middle );
            $plain .= $change->expandPlain( $session, $web );
        }

        my $mw = $TWiki::mainWebname;
        $plain =~ s/\($mw\./\(/go;

        my $from = $session->{prefs}->getPreferencesValue("WIKIWEBMASTER");

        my $mail = $mailtmpl;

        $mail =~ s/%EMAILFROM%/$from/go;
        $mail =~ s/%EMAILTO%/$email/go;
        $mail =~ s/%EMAILBODY%/$before$html$after/go;
        $mail =~ s/%TOPICLIST%/$plain/go;
        $mail =~ s/%LASTDATE%/$lastTime/geo;
        $mail = $session->handleCommonTags( $mail, $session->{topicName},
                                            $web );

        my $url = "%SCRIPTURLPATH%";
        $url = $session->handleCommonTags( $url, $session->{topicName}, $web );

        # Inherited from mailnotify
        # SMELL: assumes Content-Base is set in the mail template,
        # and assumes it is set to the web hometopic.
        $mail =~ s/(href=\")$url/$1..\/../goi;
        $mail =~ s/(action=\")$url/$1..\/../goi;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        if ( $sendmail ) {
            # SMELL: this retry strategy should be in TWiki::Net::sendEmail, not here.
            my $retries = 5;
                my $error = $session->{net}->sendEmail( $mail, 5 );
        } elsif ( $verbose ) {
            print "Please tell $email about the following changes:\n";
            print $plain;
        }
        $sentMails++;
    }
    print "\t$sentMails change notifications\n";
}

1;
