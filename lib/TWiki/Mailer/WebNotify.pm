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

use TWiki::Mailer::Subscriber;
use TWiki::Mailer::Subscription;

=begin text

---
---++ package TWiki::Mailer::WebNotify
Object that represents the contents of a %NOTIFYTOPIC% topic in a TWiki web

=cut

package  TWiki::Mailer::WebNotify;

use vars qw( $WWRE $EMRE $MWRE $guestUser $WEBNOTIFYTOPIC );

BEGIN {
    $WEBNOTIFYTOPIC = $TWiki::notifyTopicname;

    # Allow %MAINWEB% as well as 'Main' in front of users/groups
    $MWRE = qr/(?:$TWiki::mainWebname|%MAINWEB%)/;
    $WWRE = $TWiki::regex{wikiWordRegex};
    $EMRE = $TWiki::regex{emailAddrRegex};

    # SMELL: This should be defined in the configuration
    $guestUser = 'TWikiGuest';
}

=begin text

---+++ sub new($web)
Create a new object by parsing the content of the webnotify topic in the
given web. This is the normal way to load a %NOTIFYTOPIC% topic. If the
topic does not exist, it will create an empty object.

=cut

sub new {
    my ( $class, $session, $web ) = @_;

    my $this = bless( {}, $class );

    $this->{session} = $session;
    $this->{web} = $web;
    $this->{text} = "";

    if ( $session->{store}->topicExists( $web, $WEBNOTIFYTOPIC )) {
        $this->_load( );
    }

    return $this;
}

=begin text

---+++ sub writeWebNotify()
Write the object to the %NOTIFYTOPIC% topic it was read from.
If there is a problem writing the topic (e.g. it is locked),
the method will return an error message. If everything is ok
it will return undef.

=cut

sub writeWebNotify {
    my $this = shift;
    return $this->{session}->{store}->saveTopic( $this->{web},
                                    $this->{topic_name},
                                    $this->{text} . $this->toString(),
                                    undef,
                                    1,  # unlock
                                    1); # dontNotify
}

=begin text

---+++ sub getSubscriber($name, $noAdd)
| =$name= | Name of subscriber (wikiname with no web or email address) |
| =$noAdd= | If false or undef, a new subscriber will be created for this name |
Get a subscriber from the list of subscribers, and return a reference
to the Subscriber object. If $noAdd is true, and the subscriber is not
found, undef will be returned. Otherwise a new Subscriber object will
be added if necessary.

=cut

sub getSubscriber {
    my ( $this, $name, $noAdd ) = @_;

    my $subscriber = $this->{subscribers}{$name};
    unless ( $noAdd || defined( $subscriber )) {
        $subscriber = new TWiki::Mailer::Subscriber( $this->{session}, $name );
        $this->{subscribers}{$name} = $subscriber;
    }
    return $subscriber;
}

=begin text

---+++ sub getSubscribers()
Get a list of all subscriber names (unsorted)

=cut

sub getSubscribers {
    my ( $this ) = @_;

    return keys %{$this->{subscribers}};
}

=begin text

---+++ sub subscribe($name, $topics, $depth)
| =$name= | Name of subscriber (wikiname with no web or email address) |
| =$topics= | wildcard expression giving topics to subscribe to |
| =$depth= | Child depth to scan (default 0) |
Add a subscription, adding the subscriber if necessary.

=cut

sub subscribe {
    my ( $this, $name, $topics, $depth ) = @_;

    my $subscriber = $this->getSubscriber( $name );
    my $sub = new TWiki::Mailer::Subscription( $this->{session}, $topics, $depth );
    $subscriber->subscribe( $sub );
}

=begin text

---+++ sub unsubscribe($name, $topics, $depth)
| =$name= | Name of subscriber (wikiname with no web or email address) |
| =$topics= | wildcard expression giving topics to subscribe to |
| =$depth= | Child depth to scan (default 0) |
Add an unsubscription, adding the subscriber if necessary. An unsubscription
is a specific request to ignore notifications for a topic for this
particular subscriber.

=cut

sub unsubscribe {
    my ( $this, $name, $topics, $depth ) = @_;

    my $subscriber = $this->getSubscriber( $name );
    my $sub = new TWiki::Mailer::Subscription( $this->{session}, $topics, $depth );
    $subscriber->unsubscribe( $sub );
}

=begin text

---+++ sub toString() -> string
Return a string representation of this object, in %NOTIFYTOPIC% format.

=cut

sub toString {
    my $this = shift;

    my $page = $this->{text};

    foreach my $name ( sort keys %{$this->{subscribers}} ) {
        my $subscriber = $this->{subscribers}{$name};
        $page .= $subscriber->toString() . "\n";
    }

    return $page;
}

=begin text

---+++ sub processChange($change, $web, $changeSet, $seenSet)
| =$change= | ref of a TWiki::Mailer::Change |
| =$web= | web containing the changes |
| =$changeSet= | ref of a hash mapping emails to sets of changes |
| =$seenSet= | ref of a hash recording indices of topics already seen |
Find all subscribers that are interested in the given change, and
add their email expansions to the changeset with pointers to the
change. Only the most recent change listed in the .changes file is
retained. This method does _not_ change this object.

=cut

sub processChange {
    my ( $this, $change, $web, $changeSet, $seenSet ) = @_;

    my $topic = $change->{TOPIC};
    foreach my $name ( keys %{$this->{subscribers}} ) {
        my $subscriber = $this->{subscribers}{$name};
        if ( $subscriber->isSubscribedTo( $web, $topic ) &&
             !$subscriber->isUnsubscribedFrom( $web, $topic)) {
            my @emails = $subscriber->getEmailAddresses();
            foreach my $email ( @emails ) {
                my $at = $seenSet->{$email}{$topic};
                if ( $at ) {
                    $changeSet->{$email}[$at - 1] = $change;
                } else {
                    $seenSet->{$email}{$topic} =
                      push( @{$changeSet->{$email}}, $change );
                }
            }
        }
    }
}

=begin text

---+++ sub isEmpty() -> boolean
Return true if there are no subscribers

=cut

sub isEmpty {
    my $this = shift;
    return ( scalar( keys %{$this->{subscribers}} ) == 0 );
}

# PRIVATE parse a topic extracting formatted lines
sub _load {
    my ( $this ) = @_;

    my ( $meta, $text ) =
      $this->{session}->{store}->readTopic( $this->{session}->{wikiUserName},
                                 $this->{web}, $WEBNOTIFYTOPIC, undef, 0 );
    $this->{meta} = $meta;

    # join \ terminated lines
    $text =~ s/\\\r?\n//gs;

    foreach my $line ( split ( /\n/, $text )) {
        if ( $line =~ /^\s+\*\s(?:$MWRE\.)?($WWRE)\s+\-\s+($EMRE)/o ) {
            # * Main.WikiName - email@domain
            # * %MAINWEB%.WikiName - email@domain
            if ( $1 ne $guestUser ) {
                # Add email address to list if non-guest and non-duplicate
                $this->subscribe( $2, '*', 0 );
            }
        } elsif ( $line =~ /^\s+\*\s(?:$MWRE\.)?($WWRE)\s*$/o ) {
            # * Main.WikiName
            # %MAINWEB%.WikiName
            # WikiName
            $this->subscribe($1, '*', 0 );
        } elsif ( $line =~ /^\s+\*\s($EMRE)\s*$/o ) {
            # * email@domain
            $this->subscribe($1, '*', 0 );
        } elsif ( $line =~ /^\s+\*\s($EMRE):(.*)$/o ) {
            # * email@domain: topics
            $this->_parsePages( $1, $3 );
        } elsif ( $line =~ /^\s+\*\s(?:$MWRE\.)?($WWRE):(.*)$/o ) {
            # * Main.WikiName: topics
            # * %MAINWEB%.WikiName: topics
            if ( $2 ne $guestUser ) {
                $this->_parsePages( $1, $2 );
            }
        } else {
            $this->{text} .= "$line\n";
        }
    }
}

# PRIVATE parse a pages list, adding subscriptions as appropriate
sub _parsePages {
    my ( $this, $who, $spec ) = @_;
    my $ospec = $spec;
    $spec =~ s/,/ /g;
    while ( $spec =~ s/^\s*([+-])?\s*([\w\*]+)\s*(?:\((\d+)\))?// ) {
        my $kids = $3 or 0;
        if ( $1 && $1 eq '-' ) {
            $this->unsubscribe( $who, $2, $kids );
        } else {
            $this->subscribe( $who, $2, $kids );
        }
    }
    if ( $spec =~ m/\S/ ) {
        print STDERR "Badly formatted subscription list $ospec";
    }
}

1;
