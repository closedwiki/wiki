#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
# NOTE: Please extend that file, not this notice.
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
use strict;

package TWiki::Contrib::MailInContrib;

use TWiki;

use Email::Folder;
use Email::FolderType::Net;
use Time::ParseDate;
use Error qw( :try );
use vars qw ( $VERSION );

$VERSION = 1.000;

=pod

---++ ClassMethod new( $session )
   * =$session= - ref to a TWiki object
Construct a new inbox processor.

=cut

sub new {
    my( $class, $session, $debug ) = @_;
    my $this = bless({}, $class);
    $this->{session} = $session;
    $this->{debug} = $debug;

    # Find out when we last processed mail
    if( defined $this->{session} ) {
        $this->{lastMailIn} = $session->{store}->readMetaData(
            $TWiki::cfg{SystemWebName}, "mailincron" ) || 0;
    } else {
        $this->{lastMailIn} = $TWiki::Store::readFile(
            "$TWiki::dataDir/TWiki/.mailincron" ) || 0;
    }

    return $this;
}

=pod

---++ ObjectMethod wrapUp( $box )
Clean up after processing inboxes, setting the time-stamp
indicating when the processor was last run.

=cut

#SMELL: could this be done in a DESTROY?
sub wrapUp {
    my $this = shift;

    return if $this->{debug};

    # re-stamp

    if( defined $this->{session} ) {
        $this->{session}->{store}->saveMetaData
          ($TWiki::cfg{SystemWebName}, "mailincron", time() );
    } else {
        $this->{lastMailIn} = $TWiki::Store::saveFile(
            "$TWiki::dataDir/TWiki/.mailincron", time() );
    }
}

=pod

---++ ObjectMethod processInbox( $box )
   * =$box= - hash describing the box
Scan messages in the box that have been received since the last run,
and process them for inclusion in TWiki topics.

=cut

sub processInbox {
    my( $this, $box ) = @_;

    my $folder = new Email::Folder( $box->{folder} );
    my $user;
    if( defined $this->{session} ) {
        $user = $this->{session}->{users}->findUser( $box->{user}, undef, 1);
        unless( $user ) {
            die "User $box->{user} unknown!";
        }
    }
    my %kill;

    my $mail; # an Email::Simple object
    while( ($mail = $folder->next_message()) ) {
        # If the subject line is a valid TWiki Web.WikiName, then we want
        # to process it.
        if( $mail->header('Subject') =~
            /^\s*($TWiki::regex{webNameRegex})\.($TWiki::regex{wikiWordRegex})\s*$/i ) {

            my $web = $1;
            my $topic = $2;

            # scalar context gives first in list
            my $received = $mail->header('Received');
            $received =~ s/^.*; (.*?)$/$1/;
            my $secs = Time::ParseDate::parsedate( $received );

            if( $secs && $secs > $this->{lastMailIn} ) {
                if( defined $this->{session} ) {
                    unless( $this->{session}->{store}->webExists( $web )) {
                        $this->fail( $box, $mail, "Web $web does not exist" );
                        next;
                    }
                } else {
                    unless( TWiki::Store::webExists( $web )) {
                        $this->fail( $box, $mail, "Web $web does not exist" );
                        next;
                    }
                }
                my $body = $mail->body();
                my $sender = $mail->header( 'From' );
                $body = "<i>By mail from ${sender} $received</i>\n\n$body";
                print "Received mail from $sender for $web.$topic\n";
                print $mail->header( 'Message-ID' ),"\n" if $this->{debug};
                try {
                    my( $meta, $text );
                    unless( $this->{debug} ) {
                        if( $this->{session} ) {
                            ( $meta, $text ) =
                              $this->{session}->{store}->readTopic
                                ( $user, $web, $topic );
                            $body = $this->{session}->{store}->saveTopic
                              ( $user, $web, $topic, $text . $body, $meta,
                                { comment => "Saved by mailincron" } );
                        } else {
                            ( $meta, $text ) =
                              TWiki::Store::readTopic( $web, $topic );
                            $body = $this->{session}->{store}->saveTopic
                              ( $user, $web, $topic, $text . $body, $meta,
                                '', 1, 0, 0 );
                        }
                    }
                    if ( $body ) {
                        $this->fail( $box, $mail, $body );
                    } elsif( $box->{replyonsuccess} ) {
                        $this->reply( $mail, "Thank you for your successful submission" );
                    }
                } catch TWiki::AccessControlException with {
                    my $e = shift;
                    $this->fail( $box, $mail, $e->stringify() );
                } catch Error::Simple with {
                    my $e = shift;
                    $this->fail( $box, $mail, $e->stringify() );
                };

                $kill{$mail->header( 'Message-ID' )} = 1;
            }
        }
    }

    if( $box->{delete} || $box->{deleteall} ) {
        require Email::Delete;
        Email::Delete::delete_message
            ( from => $box,
              matching =>
              sub {
                  my $test = shift;
                  if( $box->{deleteall} ||
                      $kill{$mail->header('Message-ID')} ) {
                      print "Delete ",$mail->header('Message-ID'),"\n";
                      return 1 unless $this->{debug};
                  }
                  return 0;
              } );
    }
}

# we had a problem; reply or record a warning.
sub fail {
    my( $this, $box, $mail, $body ) = @_;
    if( $box->{replyonerror} ) {
        $this->reply( $box, $mail, $body );
    } else {
        if( defined $this->{session} ) {
            $this->{session}->writeWarning( "mailincron: $body" );
        } else {
            TWiki::writeWarning( "mailincron: $body" );
        }
    }
}

# Reply to a mail
sub reply {
    my( $this, $box, $mail, $body ) = @_;
    my $addressee = $mail->header('Reply-To') ||
      $mail->header('From');
    my $message =
      "To: $addressee" .
        "\nFrom: $box->{user}" .
          "\nSubject: RE: your TWiki submission to ".$mail->header('Subject').
              "\n\n$body\n";
    if( $this->{debug} ) {
        print STDERR "SEND EMAIL:\n$message";
    } else {
        if( defined $this->{session} ) {
            $this->{session}->{net}->sendEmail( $message, 5 );
        } else {
            # SMELL: no retry
            TWiki::Net::sendEmail( $message );
        }
    }
}

1;
