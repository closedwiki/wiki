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

# SMELL: Forced to use TWiki::Net and TWiki::Store;these due to
# unexported entry points
use TWiki::Net;
use TWiki::Store;

use TWiki::Contrib::MailerContrib::WebNotify;
use TWiki::Contrib::MailerContrib::Change;
use TWiki::Contrib::MailerContrib::UpData;

=begin text

---++ package TWiki::Contrib::Mailer

Package of support for extended Web<nop>Notify notification, supporting per-topic notification and notification of changes to children.

Also supported is a simple API that can be used to change the Web<nop>Notify topic from other code.

=cut

package TWiki::Contrib::Mailer;

use vars qw ( $VERSION $sendmail $verbose );

$VERSION = 1.002;

=begin text

---+++ sub mailNotify($sendmail)
| $sendmail | If true, will send mails. If false, will print to STDOUT |

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

    TWiki::basicInitialize();

    # SMELL: have to getAllWebs, because getPublicWebList only returns public
    # webs.
    foreach my $web ( grep( /$webstr/o, TWiki::Store::getAllWebs() )) {
        _processWeb( $web );
    }
}

# PRIVATE: Read the webnotify, and notify changes
sub _processWeb {
    my( $web) = @_;

    my ( $topic, $webName, $dummy, $userName, $dataDir) =
      TWiki::initialize( "/$web", "nobody" );

    if( ! TWiki::Func::webExists( $web ) ) {
        print "**** ERROR mailnotifier cannot find web $webName\n";
        return;
    }

    print "Processing $web\n" if $verbose;

    # Read the webnotify and load subscriptions
    my $wn = new TWiki::Contrib::MailerContrib::WebNotify( $web );

    if ( $wn->isEmpty() ) {
        print "\t$web has no subscribers\n" if $verbose;
    } else {
        # create a DB object for parent pointers
        my $db = new TWiki::Contrib::MailerContrib::UpData( $web );

        _processChanges( $web, $wn, $db );
    }
}

sub _processChanges {
    my ( $web, $notify, $db ) = @_;

    my $wroot =  TWiki::Func::getDataDir() . "/$web";
    my $prevLastmodify = TWiki::Func::readFile( "$wroot/.mailnotify" ) || 0;
    my $currLastmodify = "";

    # hash indexed on email address, each entry of which contains an
    # array of MailerContrib::Change objects
    my %changeset;
    # hash indexed on email address, each entry contains a hash
    # of topics already processed in the change set for this email.
    # Each subhash maps the topic name to the index of the change
    # record for this topic in the array of Change objects for this
    # email in %changeset.
    my %seenset;
    my $changes = TWiki::Func::readFile("$wroot/.changes" );

    return unless ( $changes );

    foreach( reverse split( /\n/, $changes ) ) {
        # Parse lines from .changes:
        # <topic>	<user>		<change time>	<revision>
        # WebHome	FredBloggs	1014591347	21
        my ($topicName, $userName, $changeTime, $revision) = split( /\t/);

        next unless TWiki::Func::topicExists( $web, $topicName );

        # First formulate a change record, irrespective of
        # whether any subscriber is interested
        if( ! $currLastmodify ) {
            # newest entry
            my $time = TWiki::Func::formatTime( $prevLastmodify );
            if( $prevLastmodify eq $changeTime ) {
                # newest entry is same as at time of previous notification
                return;
            }
            $currLastmodify = $changeTime;
        }

        if( $prevLastmodify >= $changeTime ) {
            #print "Date: found item of last notification\n";
            # found item of last notification
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

        my $change =
          new TWiki::Contrib::MailerContrib::Change
            ( $web,
              $topicName,
              TWiki::Func::userToWikiName( $userName, 0 ),
              TWiki::Func::formatTime( $changeTime ),
              $frev,
              # SMELL: Call to TWiki::makeTopicSummary is unavoidable
              TWiki::makeTopicSummary
              (TWiki::Func::readTopicText($web, $topicName),
               $topicName,
               $web ));

        # Now, find subscribers to this change and extend the change set
        $notify->processChange( $change, $db, \%changeset, \%seenset );
    }

    # Now generate emails for each recipient
    _generateEmails( $web,
                     \%changeset,
                     TWiki::Func::formatTime($prevLastmodify) );

    # Only update the memory topic if mails were sent
    if ( $sendmail ) {
        TWiki::Func::saveFile( "$wroot/.mailnotify", $currLastmodify );
    }
}

# PRIVATE generate and send an email for each user
sub _generateEmails {
    my ( $web, $changeset, $lastTime ) = @_;

    my $skin = TWiki::Func::getPreferencesValue( "SKIN" );

    my $template = TWiki::Func::readTemplate( "changes", $skin );

    $template = TWiki::Func::expandCommonVariables( $template, $web, "" );
    $template =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

    # SMELL: unexported function call TWiki:: doRemoveImgInMailnotify
    # STINK: preferences like this should be exported from TWiki.cfg
    if( $TWiki::doRemoveImgInMailnotify ) {
        # change images to [alt] text if there, else remove image
        $template =~ s/<img src=.*?alt=\"([^\"]+)[^>]*>/[$1]/goi;
        $template =~ s/<img src=.*?[^>]>//goi;
    }

    my ( $before, $middle, $after) = split( /%REPEAT%/, $template );
    $before = TWiki::Func::renderText( $before );
    $after = TWiki::Func::renderText( $after );
    $middle =~ s/%LOCKED%//go; # SMELL: Legacy?

    my $mailtmpl = TWiki::Func::readTemplate( "mailnotify", $skin );

    my $sentMails = 0;

    foreach my $email ( keys %{$changeset} ) {
        my $html = "";
        my $plain = "";

        foreach my $change (sort { $a->{TOPIC} cmp $b->{TOPIC} }
                            @{$changeset->{$email}} ) {

            $html .= $change->expandHTML( $middle );
            $plain .= $change->expandPlain( $web );
        }

        my $mw = TWiki::Func::getMainWebname();
        $plain =~ s/\($mw\./\(/go;

        my $from = TWiki::Func::getPreferencesValue("WIKIWEBMASTER");

        my $mail = $mailtmpl;

        $mail =~ s/%EMAILFROM%/$from/go;
        $mail =~ s/%EMAILTO%/$email/go;
        $mail =~ s/%EMAILBODY%/$before$html$after/go;
        $mail =~ s/%TOPICLIST%/$plain/go;
        $mail =~ s/%LASTDATE%/$lastTime/geo;
        $mail = TWiki::Func::expandCommonVariables( $mail, $web, "" );

        my $url = "%SCRIPTURLPATH%";
        $url = TWiki::Func::expandCommonVariables( $url, $web, "" );

        # Inherited from mailnotify
        # SMELL: assumes Content-Base is set in the mail template,
        # and assumes it is set to the web hometopic.
        $mail =~ s/(href=\")$url/$1..\/../goi;
        $mail =~ s/(action=\")$url/$1..\/../goi;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        if ( $sendmail ) {
            my $error = TWiki::Net::sendEmail( $mail );
            if( $error ) {
                print "**** ERROR :Mail send failed: $error\n";
            }
        } elsif ( $verbose ) {
            print "Please tell $email about the following changes:\n";
            print $plain;
        }
        $sentMails++;
    }
    print "\t$sentMails change notifications\n";
}

1;
