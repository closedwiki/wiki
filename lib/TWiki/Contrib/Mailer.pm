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
#
use strict;
use TWiki;

use TWiki::Contrib::MailerContrib::WebNotify;
use TWiki::Contrib::MailerContrib::Change;
use TWiki::Contrib::MailerContrib::UpData;

=pod

---+ package TWiki::Contrib::Mailer

Package of support for extended Web<nop>Notify notification, supporting per-topic notification and notification of changes to children.

Also supported is a simple API that can be used to change the Web<nop>Notify topic from other code.

=cut

package TWiki::Contrib::Mailer;

use vars qw ( $VERSION $sendmail $verbose );

$VERSION = 1.010;

=pod

---++ StaticMethod mailNotify($sendmail, $verbose, $webs)
   * =$sendmail= - If true, will send mails. If false, will print to STDOUT
   * =$verbose= - true to get verbose (debug) output
   * =$webs= - filter list of names webs to process. Wildcards (*) may be used.

Main entry point.

Process the Web<nop>Notify topics in each web and generate and issue
notification mails. Designed to be invoked from the command line; should
only be called by =mailnotify= scripts.

=cut

sub mailNotify {
    my $webs;

    ( $sendmail, $verbose, $webs ) = @_;

    my $webstr;
    if ( defined( $webs )) {
        $webstr = join( "|", @{$webs} );
    }
    $webstr = '*' unless ( $webstr );
    $webstr =~ s/\*/\.\*/g;

    my $twiki =
      new TWiki( "", $TWiki::cfg{DefaultUserLogin}, "", "" );

    my $report = "";
    foreach my $web ( grep( /$webstr/o,
                            $twiki->{store}->getListOfWebs( "user ") )) {
        $report .= _processWeb( $twiki, $web );
    }
    return $report;
}

# PRIVATE: Read the webnotify, and notify changes
sub _processWeb {
    my( $twiki, $web) = @_;

    if( ! $twiki->{store}->webExists( $web ) ) {
        print STDERR "**** ERROR mailnotifier cannot find web $web\n";
        return "";
    }

    print "Processing $web\n" if $verbose;

    # Read the webnotify and load subscriptions
    my $wn = new TWiki::Contrib::MailerContrib::WebNotify( $twiki, $web );
    my $report = "";
    if ( $wn->isEmpty() ) {
        print "\t$web has no subscribers\n" if $verbose;
    } else {
        # create a DB object for parent pointers
        my $db = new TWiki::Contrib::MailerContrib::UpData( $twiki, $web );

        $report .= _processChanges( $twiki, $web, $wn, $db );
    }
    return $report;
}

sub _processChanges {
    my ( $twiki, $web, $notify, $db ) = @_;

    my $wroot =  $TWiki::cfg{DataDir} . "/$web";
    my $timeOfLastNotify =
      $twiki->{store}->readMetaData( $web, "mailnotify" ) || 0;
    my $timeOfLastChange = "";

    if ( $verbose ) {
        print "\tLast notification was at " .
          TWiki::Time::formatTime( $timeOfLastNotify ). "\n";
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

    my $changes = $twiki->{store}->readMetaData( $web, "changes" );

    unless ( $changes ) {
        print "No changes\n" if ( $verbose );
        return "";
    }

    foreach my $line ( reverse split( /\n/, $changes ) ) {
        # Parse lines from .changes:
        # <topic>	<user>		<change time>	<revision>
        # WebHome	FredBloggs	1014591347	21
        next if $line =~ /minor$/;
        my ($topicName, $userName, $changeTime, $revision) =
          split( /\t/, $line);

        next unless $twiki->{store}->topicExists( $web, $topicName );

        $timeOfLastChange = $changeTime unless( $timeOfLastChange );

        # found last interesting change?
        last if( $changeTime <= $timeOfLastNotify );

        print "\tFound change to $topicName\n" if ( $verbose );

        # Formulate a change record, irrespective of
        # whether any subscriber is interested
        my $change = new TWiki::Contrib::MailerContrib::Change
          ( $twiki, $web, $topicName, $userName, $changeTime, $revision );

        # Now, find subscribers to this change and extend the change set
        $notify->processChange( $change, $db, \%changeset, \%seenset );
    }

    # Now generate emails for each recipient
    my $report = _generateEmails( $twiki, $web,
                                  \%changeset,
                                  TWiki::Time::formatTime($timeOfLastNotify) );

    # Only update the memory topic if mails were sent
    if ( $sendmail ) {
        $twiki->{store}->saveMetaData( $web, "mailnotify", $timeOfLastChange );
    }
    return $report;
}

# PRIVATE generate and send an email for each user
sub _generateEmails {
    my ( $twiki, $web, $changeset, $lastTime ) = @_;
    my $report = "";

    my $skin = $twiki->{prefs}->getPreferencesValue( "SKIN" );
    my $template = $twiki->{templates}->readTemplate( "changes", $skin );
    my $from = $twiki->{prefs}->getPreferencesValue("WIKIWEBMASTER");
    my $homeTopic = $TWiki::cfg{HomeTopicName};

    $template = $twiki->handleCommonTags( $template, $web, $homeTopic );
    $template =~ s/%META{.*?}%//go;

    if( $TWiki::cfg{RemoveImgInMailnotify} ) {
        # change images to [alt] text if there, else remove image
        $template =~ s/<img\s[^>]*\balt=\"([^\"]+)[^>]*>/[$1]/goi;
        $template =~ s/<img src=.*?[^>]>//goi;
    }

    my ( $before, $middle, $after) = split( /%REPEAT%/, $template );
    $before = $twiki->{renderer}->getRenderedVersion( $before, $web,
                                                      $homeTopic );
    $after = $twiki->{renderer}->getRenderedVersion( $after, $web,
                                                     $homeTopic );

    my $mailtmpl = $twiki->{templates}->readTemplate( "mailnotify", $skin );

    my $sentMails = 0;

    foreach my $email ( keys %{$changeset} ) {
        my $html = "";
        my $plain = "";

        foreach my $change (sort { $a->{TOPIC} cmp $b->{TOPIC} }
                            @{$changeset->{$email}} ) {

            $html .= $change->expandHTML( $middle );
            $plain .= $change->expandPlain( $web );
        }

        $plain =~ s/\($TWiki::cfg{UsersWebName}\./\(/go;

        my $mail = $mailtmpl;

        $mail =~ s/%EMAILFROM%/$from/go;
        $mail =~ s/%EMAILTO%/$email/go;
        $mail =~ s/%EMAILBODY%/$before$html$after/go;
        $mail =~ s/%TOPICLIST%/$plain/go;
        $mail =~ s/%LASTDATE%/$lastTime/geo;
        $mail = $twiki->handleCommonTags( $mail, $web, $homeTopic );

        my $url = "%SCRIPTURLPATH%";
        $url = $twiki->handleCommonTags( $url, $web, $homeTopic );

        # Inherited from mailnotify
        # SMELL: assumes Content-Base is set in the mail template,
        # and assumes it is set to the web hometopic.
        $mail =~ s/(href=\")$url/$1..\/../goi;
        $mail =~ s/(action=\")$url/$1..\/../goi;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        my $error = "";
        if ( $sendmail ) {
            $error = $twiki->{net}->sendEmail( $mail, 5 );
        } else {
            $report .= "Please tell $email about the following changes:\n";
            $report .= $plain;
        }
        $sentMails++ unless $error;
    }
    $report .= "\t$sentMails change notifications\n";

    return $report;
}

1;
