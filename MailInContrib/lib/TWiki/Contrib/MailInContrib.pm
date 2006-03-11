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
use TWiki::Contrib::FuncUsersContrib;
use Error qw( :try );
use vars qw ( $VERSION $RELEASE );
use Carp;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

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
    $this->{lastMailIn} = $session->{store}->readMetaData(
        '', 'mailincron' ) || 0;

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

    # re-stamp

    $this->{session}->{store}->saveMetaData
      ('', 'mailincron', time() );
}

=pod

---++ ObjectMethod processInbox( $box )
   * =$box= - hash describing the box
Scan messages in the box that have been received since the last run,
and process them for inclusion in TWiki topics.

=cut

sub processInbox {
    my( $this, $box ) = @_;

    $TWiki::Plugins::SESSION = $this->{session};

    die "No folder specification" unless $box->{folder};

    my $ftype = Email::FolderType::folder_type($box->{folder});
    print STDERR "Process $ftype folder $box->{folder}\n" if $this->{debug};

    my $folder = new Email::Folder( $box->{folder} );
    my $user;
    my %kill;

    # Set defaults if necessary
    $box->{topicPath} ||= 'subject';
    $box->{defaultWeb} ||= '';
    $box->{onNoTopic} ||= 'error';
    $box->{onError} ||= 'log';
    $box->{onSuccess} ||= 'log';

    # Load the file of mail templates
    my $templates = TWiki::Func::loadTemplate( 'MailInContrib' );

    print STDERR "Scanning $box->{folder}\n" if $this->{debug};
    my $mail; # an Email::Simple object
    my $num = -1; # message number
    while( ($mail = $folder->next_message()) ) {
        $num++;
        $mail = new Email::MIME( $mail->as_string() );
        # Try to get the target topic by
        #    1. examining the "To" address to see if it is a valid web.wikiname (if
        #       enabled in config)
        #    2. if the subject line starts with a valid TWiki Web.WikiName (if optionally
        #       followed by a colon, the rest of the subject line will be ignored)
        #    3. Routing the comment to the spambox if it is enabled
        #    4. Otherwise replying to the user to say "no thanks" if replyonnotopic
        my( $web, $topic, $user );

        my $subject = $mail->header('Subject');

        print STDERR "Message ",$mail->header('Subject'),"\n" if $this->{debug};

        my $from = $mail->header('From');
        $from =~ s/^.*<(.*)>.*$/$1/;
        $user = TWiki::Contrib::FuncUsersContrib::lookupUser( email => $from );

        my $to = $mail->header('To');
        $to =~ s/^.*<(.*)>.*$/$1/;

        unless( $user ) {
            unless( $box->{user} &&
                      ($user = $TWiki::Plugins::SESSION->findUser( $box->{user} ))) {
                $this->_onError(
                    $box, $mail, 'Could not determine submitters WikiName from'.
                      "\nFrom: $from\nand there is no valid default username",
                    \%kill, $num );
                next;
            }
        }

        print STDERR "User ",$user->stringify(),"\n" if( $user && $this->{debug} );

        if( $box->{topicPath} =~ /\bto\b/ &&
              $to =~ /^(?:($TWiki::regex{webNameRegex})\.)($TWiki::regex{wikiWordRegex})@/i) {
            ( $web, $topic ) = ( $1, $2 );
        }
        if( !$topic && $box->{topicPath} =~ /\bsubject\b/ &&
          $subject =~
            s/^\s*(?:($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex})(:\s*|\s*$)// ) {
            ( $web, $topic ) = ( $1, $2 );
        }

        $web ||= $box->{defaultWeb};

        print STDERR "Topic $web.",$topic||'',"\n" if $this->{debug};

        unless( TWiki::Func::webExists( $web )) {
            $topic = '';
        }

        if( !$topic ) {
            if( $box->{onNoTopic} =~ /\berror\b/ ) {
                $this->_onError(
                    $box, $mail,
                    'Could not add your submission; no valid web.topic found in'.
                      "\nTo: ".$mail->header('To').
                        "\nSubject: ".$subject,
                    \%kill, $num );
            }
            if( $box->{onNoTopic} =~ /\bspam\b/ ) {
                if( $box->{spambox} && $box->{spambox} =~ /^(.*)\.(.*)$/ ) {
                    ( $web, $topic ) = ( $1, $2 );
                }
            }
            print STDERR "Skipping; no topic\n" if( $this->{debug} );
            next unless $topic;
        }

        # scalar context gives first in list
        my $received = $mail->header('Received');
        if( $received ) {
            $received =~ s/^.*; (.*?)$/$1/;
            $received = Time::ParseDate::parsedate( $received ) || time();
        } else {
            $received = time();
        }
        if( $received > $this->{lastMailIn} ) {
            my $err = '';
            unless( $this->{session}->{store}->webExists( $web )) {
                $err = "Web $web does not exist";
            } else {
                my $sender = $mail->header( 'From' ) || 'unknown';

                my @attachments = ();
                my $body = '';
                _extract( $mail, \$body, \@attachments );

                print "Received mail from $sender for $web.$topic\n";

                $err = $this->_saveTopic( $user, $web, $topic, $body, $subject );
                foreach my $att ( @attachments ) {
                    $err .= $this->_saveAttachment( $user, $web, $topic, $att );
                }
            }
            if( $err ) {
                $this->_onError(
                    $box, $mail,
                    "TWiki encountered an error while adding your mail to $web.$topic: $err", \%kill, $num );
            } else {
                if( $box->{onSuccess} =~ /\breply\b/ ) {
                    $this->_reply(
                        $box, $mail,
                        "Thank you for your successful submission to $web.$topic");
                }
                if( $box->{onSuccess} =~ /\bdelete\b/ ) {
                    $kill{$mail->header( 'Message-ID' )} = $num;
                }
            }
        } elsif( $this->{debug} ) {
            print STDERR "Skipping; late: $received <= $this->{lastMailIn}\n";
        }
    }

    if( $ftype eq 'POP3' ) {
        # HACK to overcome lack of Email::Delete::POP3 - it would be smarter
        # to give CPAN an impl of Email::Delete::POP3, but this is quicker.
        # It's a hack because _folder is Not public.
        foreach my $id ( reverse sort values %kill ) {
            $folder->{_folder}->{_server}->delete( $id );
        }
        # must quit, otherwise the object will go out of scope and the
        # folder will be reset before the connection is closed.
        $folder->{_folder}->{_server}->quit();
        $folder->{_folder}->{_server} = undef; # to reopen if needed again
    } else {
        eval 'use Email::Delete';
        if( $@ ) {
            TWiki::writeWarning( "Cannot delete from inbox: $@\n" );
        } else {
            # fall back to Email::Delete (which doesn't support POP3)
            Email::Delete::delete_message
                ( from => $box->{folder},
                  matching =>
                    sub {
                        my $test = shift;
                        if( defined $kill{$test->header('Message-ID')} ) {
                            print STDERR "Delete ",$test->header('Message-ID'),"\n"
                              if $this->{debug};
                            return 1;
                        }
                        return 0;
                    } );
        }
    }
}

sub _onError {
    my( $this, $box, $mail, $mess, $kill, $num ) = @_;

    $this->{error} = $mess; # used by the tests

    print STDERR "ERROR: $mess\n" if( $this->{debug} );

    if( $box->{onError} =~ /\blog\b/ ) {
        TWiki::Func::writeWarning( $mess );
    }
    if( $box->{onError} =~ /\breply\b/ ) {
        $this->_reply( $box, $mail,
                       "TWiki found an error in your e-mail submission\n\n$mess\n\n".
                      $mail->as_string());
    }
    if( $box->{onError} =~ /\bdelete\b/ ) {
        $kill->{$mail->header( 'Message-ID' )} = $num;
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
    my( $this, $user, $web, $topic, $body, $subject ) = @_;
    my $err;

    try {
        my( $meta, $text ) = $this->{session}->{store}->readTopic(
            $user, $web, $topic );

        my $opts;
        if( $text =~ /<!--MAIL(?:{(.*?)})?-->/ ) {
            $opts = new TWiki::Attrs( $1 );
        } else {
            $opts = new TWiki::Attrs( "" );
        }
        $opts->{template} ||= 'normal';
        $opts->{where} ||= 'bottom';
        my $insert = TWiki::Func::expandTemplate( 'MAILIN:'.$opts->{template} );
        $insert ||= "   * *%SUBJECT%*: %TEXT% _%WIKIUSERNAME% @ %SERVERTIME%_\n";
        $insert =~ s/%SUBJECT%/$subject/g;
        $body =~ s/\r//g;
        $body =~ s/^\n*(.*?)\n*$/$1/;
        $insert =~ s/%TEXT%/$body/g;
        my $curUser = $TWiki::Plugins::SESSION->{user};
        $TWiki::Plugins::SESSION->{user} = $user;
        $insert = TWiki::Func::expandVariablesOnTopicCreation($insert);
        $TWiki::Plugins::SESSION->{user} = $curUser;

        if( $opts->{where} eq 'top' ) {
            $text = $insert.$text;
        } elsif( $opts->{where} eq 'bottom' ) {
            $text .= $insert;
        } elsif( $opts->{where} eq 'above' ) {
            $text =~ s/(<!--MAIL(?:{.*?})?-->)/$insert$1/;
        } elsif( $opts->{where} eq 'below' ) {
            $text =~ s/(<!--MAIL(?:{.*?})?-->)/$1$insert/;
        }

        print STDERR "Save topic $web.$topic:\n$text\n" if( $this->{debug} );

        $this->{session}->{store}->saveTopic(
            $user, $web, $topic, $text, $meta,
            { comment => "Submitted by e-mail" } );

    } catch TWiki::AccessControlException with {
        my $e = shift;
        $err = $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        $err = $e->stringify();
    };
    return $err;
}

sub _saveAttachment {
    my( $this, $user, $web, $topic, $attachment ) = @_;
    my $filename = $attachment->{filename};
    my $payload = $attachment->{payload};

    print STDERR "Save attachment $filename\n" if( $this->{debug} );

    my $tmpfile = $web.'_'.$topic.'_'.$filename;
    $tmpfile = $TWiki::cfg{PubDir}.'/'.$tmpfile;

    $tmpfile .= 'X' while -e $tmpfile;
    open( TF, ">$tmpfile" ) || return 'Could not write '.$tmpfile;
    print TF $attachment->{payload};
    close( TF );

    my $err = '';
    $this->{session}->{store}->saveAttachment(
        $web, $topic, $filename, $user,
        { comment => "Submitted by e-mail", file => $tmpfile });
    unlink( $tmpfile );
    return $err;
}

# Reply to a mail
sub _reply {
    my( $this, $box, $mail, $body ) = @_;
    my $addressee = $mail->header('Reply-To') ||
      $mail->header('From');
    my $message =
      "To: $addressee" .
        "\nFrom: ".$mail->header('To').
          "\nSubject: RE: your TWiki submission to ".$mail->header('Subject').
              "\n\n$body\n";
    $TWiki::Plugins::SESSION->{net}->sendEmail( $message, 5 );
}

1;
