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
use URI;

use vars qw ( $VERSION $RELEASE $verbose );
# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


=pod

---++ StaticMethod mailNotify($webs, $session, $verbose)
   * =$webs= - filter list of names webs to process. Wildcards (*) may be used.
   * =$session= - optional session object. If not given, will use a local object.
   * =$verbose= - true to get verbose (debug) output

Main entry point.

Process the Web<nop>Notify topics in each web and generate and issue
notification mails. Designed to be invoked from the command line; should
only be called by =mailnotify= scripts.

=cut

sub mailNotify {
    my( $webs, $twiki, $noisy ) = @_;

    $verbose = $noisy;

    my $webstr;
    if ( defined( $webs )) {
        $webstr = join( "|", @{$webs} );
    }
    $webstr = '*' unless ( $webstr );
    $webstr =~ s/\*/\.\*/g;

    $twiki ||= new TWiki( $TWiki::cfg{DefaultUserLogin} );

    # absolute URL context for email generation
    $twiki->enterContext( 'absolute_urls' );

    my $report = '';
    foreach my $web ( grep( /$webstr/o,
                            $twiki->{store}->getListOfWebs( 'user ') )) {
        $report .= _processWeb( $twiki, $web );
    }

    $twiki->leaveContext( 'absolute_urls' );

    return $report;
}

# PRIVATE: Read the webnotify, and notify changes
sub _processWeb {
    my( $twiki, $web) = @_;

    if( ! $twiki->{store}->webExists( $web ) ) {
        print STDERR "**** ERROR mailnotifier cannot find web $web\n";
        return '';
    }

    print "Processing $web\n" if $verbose;

    # Read the webnotify and load subscriptions
    my $wn = new TWiki::Contrib::MailerContrib::WebNotify( $twiki, $web );
    my $report = '';
    if ( $wn->isEmpty() ) {
        print "\t$web has no subscribers\n" if $verbose;
    } else {
        # create a DB object for parent pointers
        print $wn->stringify() if $verbose;
        my $db = new TWiki::Contrib::MailerContrib::UpData( $twiki, $web );
        $report .= _processChanges( $twiki, $web, $wn, $db );
    }
    return $report;
}

sub _processChanges {
    my ( $twiki, $web, $notify, $db ) = @_;

    my $timeOfLastNotify =
      $twiki->{store}->readMetaData( $web, 'mailnotify' ) || 0;
    my $timeOfLastChange = '';

    if ( $verbose ) {
        print "\tLast notification was at " .
          TWiki::Time::formatTime( $timeOfLastNotify ). "\n";
    }

    my %changeset;
    # hash indexed on email address, each entry contains a hash
    # of topics already processed in the change set for this email.
    # Each subhash maps the topic name to the index of the change
    # record for this topic in the array of Change objects for this
    # email in %changeset.
    my %seenset;

    my $changes = $twiki->{store}->readMetaData( $web, 'changes' );

    unless ( $changes ) {
        print "No changes\n" if ( $verbose );
        return '';
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

    $twiki->{store}->saveMetaData( $web, 'mailnotify', $timeOfLastChange );

    return $report;
}

# PRIVATE generate and send an email for each user
sub _generateEmails {
    my ( $twiki, $web, $changeset, $lastTime ) = @_;
    my $report = '';

    my $skin = $twiki->{prefs}->getPreferencesValue( 'SKIN' );
    my $template = $twiki->{templates}->readTemplate( 'mailnotify', $skin );

    my $homeTopic = $TWiki::cfg{HomeTopicName};

    my $before_html = $twiki->{templates}->expandTemplate( 'HTML:before' );
    my $middle_html = $twiki->{templates}->expandTemplate( 'HTML:middle' );
    my $after_html = $twiki->{templates}->expandTemplate( 'HTML:after' );

    my $before_plain = $twiki->{templates}->expandTemplate( 'PLAIN:before' );
    my $middle_plain = $twiki->{templates}->expandTemplate( 'PLAIN:middle' );
    my $after_plain = $twiki->{templates}->expandTemplate( 'PLAIN:after' );

    my $mailtmpl = $twiki->{templates}->expandTemplate( 'MailNotifyBody' );
    $mailtmpl = $twiki->handleCommonTags( $mailtmpl, $web, $homeTopic );
    if( $TWiki::cfg{RemoveImgInMailnotify} ) {
        # change images to [alt] text if there, else remove image
        $mailtmpl =~ s/<img\s[^>]*\balt=\"([^\"]+)[^>]*>/[$1]/goi;
        $mailtmpl =~ s/<img src=.*?[^>]>//goi;
    }

    my $sentMails = 0;

    foreach my $email ( keys %{$changeset} ) {
        my $html = '';
        my $plain = '';

        foreach my $change (sort { $a->{TIME} cmp $b->{TIME} }
                            @{$changeset->{$email}} ) {

            $html .= $change->expandHTML( $middle_html );
            $plain .= $change->expandPlain( $middle_plain );
        }

        $plain =~ s/\($TWiki::cfg{UsersWebName}\./\(/go;

        my $mail = $mailtmpl;

        $mail =~ s/%EMAILTO%/$email/go;
        $mail =~ s/%HTML_TEXT%/$before_html$html$after_html/go;
        $mail =~ s/%PLAIN_TEXT%/$before_plain$plain$after_plain/go;
        $mail =~ s/%LASTDATE%/$lastTime/geo;
        $mail = $twiki->handleCommonTags( $mail, $web, $homeTopic );

        my $url = $TWiki::cfg{ScriptUrlPath};
        my $base = $TWiki::cfg{DefaultUrlHost} . $url;
        $mail =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/goei;
        $mail =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/goei;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        my $error;

        $error = $twiki->{net}->sendEmail( $mail, 5 );

        $sentMails++ unless $error;
    }
    $report .= "\t$sentMails change notifications\n";

    return $report;
}

sub relativeURL {
    my( $base, $link ) = @_;
    return URI->new_abs( $link, URI->new($base) )->as_string;
}

1;
