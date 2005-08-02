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
use Email::MIME;
use Time::ParseDate;
use Error qw( :try );
use vars qw ( $VERSION );
use Carp;

$VERSION = 1.101;

my $comment = 'Saved by mailincron';

BEGIN {
    $SIG{__DIE__} = sub { Carp::confess $_[0] };
}

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
            '', "mailincron" ) || 0;
    } else {
        $this->{lastMailIn} = TWiki::Store::readFile(
            "$TWiki::dataDir/.mailincron" ) || 0;
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
        $this->{lastMailIn} = TWiki::Store::saveFile(
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

    print "Process $box->{folder}\n" if $this->{debug};
    my $folder = new Email::Folder( $box->{folder} );
    my $user;
    if( defined $this->{session} ) {
        $user = $this->{session}->{users}->findUser( $box->{user}, undef, 1);
        unless( $user ) {
            die "User $box->{user} unknown!";
        }
    } else {
        $user = $box->{user};
    }
    my %kill;

    print "Scanning $box->{folder}\n" if $this->{debug};
    my $mail; # an Email::Simple object
    while( ($mail = $folder->next_message()) ) {
        $mail = new Email::MIME( $mail->as_string() );
        # If the subject line is a valid TWiki Web.WikiName, then we want
        # to process it.
        my( $web, $topic );
        if( $mail->header('Subject') =~
                /^\s*($TWiki::regex{webNameRegex})\.($TWiki::regex{wikiWordRegex})\s*$/i ) {
            ( $web, $topic ) = ( $1, $2 );
        } elsif( $box->{spambox} && $box->{spambox} =~ /^(.*)\.(.*)$/ ) {
            ( $web, $topic ) = ( $1, $2 );
        } else {
            print $mail->header('Subject')," ignored\n" if $this->{debug};
            next;
        }

        print "Message ",$mail->header('Subject'),"\n" if $this->{debug};
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
            my $sender = $mail->header( 'From' ) || 'unknown';

            my @attachments = ();
            my $body = '';
            _extract( $mail, \$body, \@attachments );

            print "Received mail from $sender for $web.$topic\n$body";
            $body .= "\n\n-- <em>${sender} $received</em>\n";

            my $err = $this->_saveTopic( $user, $web, $topic, $body );

            foreach my $att ( @attachments ) {
                $err .= $this->_saveAttachment( $user, $web, $topic, $att );
            }

            if( $err ) {
                $this->fail( $box, $mail, $err );
            } elsif( $box->{replyonsuccess} ) {
                $this->reply( $box,
                    $mail, 'Thank you for your successful submission');
            }
            $kill{$mail->header( 'Message-ID' )} = 1;
        }
    }

    if( $box->{delete} || $box->{deleteall} ) {
        eval 'use Email::Delete';
        unless( $@ ) {
            Email::Delete::delete_message
                ( from => $box->{folder},
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
}

# Extract plain text and attachments from the MIME
sub _extract {
    my( $mime, $text, $attach ) = @_;

    foreach my $part ( $mime->parts() ) {
        my $ct = $part->content_type || 'text/plain';
        my $dp = $part->header('Content-Disposition') || 'inline';

        if( $ct =~ m[text/plain] && $dp =~ /inline/ ) {
            $$text .= $part->body();
        } elsif ( $part->filename()) {
            push( @$attach,
                  {
                      payload => $part->body(),
                      filename => $part->filename()
                  } );
        } elsif( $part != $mime ) {
            _extract( $part, $text, $attach );
        }
    }
}

sub _saveTopic {
    my( $this, $user, $web, $topic, $body ) = @_;
    my $err;

    if( $this->{debug} ) {
        print "Save topic $web.$topic\n";
    } elsif( $this->{session} ) {
        try {
            my( $meta, $text ) =
              $this->{session}->{store}->readTopic
                ( $user, $web, $topic );
            $this->{session}->{store}->saveTopic
              ( $user, $web, $topic, $text . "\n\n" . $body, $meta,
                { comment => $comment } );
        } catch TWiki::AccessControlException with {
            my $e = shift;
            $err = $e->stringify();
        } catch Error::Simple with {
            my $e = shift;
            $err = $e->stringify();
        };
    } else {
        $body =~ s/   /\t/g;
        my( $meta, $text ) = TWiki::Store::readTopic( $web, $topic );
        $err = TWiki::Store::saveTopic(
            $web, $topic, $text . "\n\n" . $body, $meta, '', 1, 0, 0 );
    }
    return $err;
}

sub _saveAttachment {
    my( $this, $user, $web, $topic, $attachment ) = @_;
    my $filename = $attachment->{filename};
    my $payload = $attachment->{payload};

    if( $this->{debug} ) {
        print "Save attachment $filename\n";
        return '';
    }

    my $tmpfile = $web.'_'.$topic.'_'.$filename;
    if( $this->{session} ) {
        $tmpfile = $TWiki::cfg{PubDir}.'/'.$tmpfile;
    } else {
        $tmpfile = $TWiki::pubDir.'/'.$tmpfile;
    }

    $tmpfile .= 'X' while -e $tmpfile;
    open( TF, ">$tmpfile" ) || return 'Could not write '.$tmpfile;
    print TF $attachment->{payload};
    close( TF );

    my $err = '';
    if( $this->{session} ) {
        $this->{session}->{store}->saveAttachment(
            $web, $topic, $filename, { comment => $comment,
                                       file => $tmpfile });
    } else {
        $err = TWiki::Store::saveAttachment( $web, $topic, '', '',
                                      $filename, 0, 1,
                                      0, $comment, $tmpfile );
        return $err if $err;

        my( $meta, $text ) = TWiki::Store::readTopic( $web, $topic );

        my @stats = stat $tmpfile;
        my $fileSize = $stats[7];
        my $fileDate = $stats[9];

        my $fileVersion = TWiki::Store::getRevisionNumber( $web, $topic,
                                                           $filename );
        TWiki::Attach::updateAttachment( $fileVersion, $filename, $filename,
                                         $fileSize,
                                         $fileDate, $user, $comment,
                                         0, $meta );
        $err = TWiki::Store::saveTopic( $web, $topic, $text, $meta, '', 1 );
    }
    unlink( $tmpfile );
    return $err;
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
