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

=begin text

---++ package TWiki::Contrib::MailerContrib::Subscriber
Object that represents a subscriber to notification. A subscriber is
a name (which may be a wikiName or an email address) and a list of
subscriptions which describe the topis subscribed to. The subscriber
name may also be a group, so it may expand to many email addresses.

=cut

package TWiki::Contrib::MailerContrib::Subscriber;

=begin text

---+++ sub new($name)
| $name | Wikiname, with no web, or email address. of user targeted for notification |
Create a new user.

=cut

sub new {
    my ( $class, $name ) = @_;
    my $this = bless( {}, $class );

    $this->{name} = $name;
    my $EMRE = TWiki::Func::getRegularExpression('emailAddrRegex');
    if ( $name =~ /^$EMRE$/o ) {
        $this->{emails} = [ $name ];
    }

    return $this;
}

=begin text

---+++ sub getEmailAddresses() -> list
Get a list of email addresses for the user(s) represented by this
subscription

=cut

sub getEmailAddresses {
    my $this = shift;

    unless ( defined( $this->{emails} )) {
        # temporary; use unpublished function
        my @mails = TWiki::getEmailOfUser( $this->{name} );
        $this->{emails} = \@mails;
    }

    return @{$this->{emails}};
}

=begin text

---+++ sub subscribe($subs) -> void
| $subs | Subscription object |
Add a new subscription to this subscriber object.
The subscription will always be added, even if there is
a wildcard overlap with an existing subscription.

=cut

sub subscribe {
    my ( $this, $subs ) = @_;

    push( @{$this->{subscriptions}}, $subs );
}

=begin text

---+++ sub unsubscribe($subs)
| $subs | Subscription object |
Remove all subscription records where the subscribed topics lexically
match the given topic. Wildcards are _not_ used.

=cut

sub unsubscribe {
   my ( $this, $topic ) = @_;

   my $i = $#{$this->{subscriptions}};
   while ( $i >= 0 ) {
       my $subscription = $this->{subscriptions}[$i];
       if ( $subscription->{topics} eq $topic ) {
           splice( @{$this->{subscriptions}}, $i, 1 );
       }
       $i--;
   }
}


=begin text

---+++ sub isSubscribedTo($topic) -> boolean
| $topic | Topic object we are checking |
| $db | Database of parents |
Check if we have a subscription to the given topic.

=cut

sub isSubscribedTo {
   my ( $this, $topic, $db ) = @_;

   foreach my $subscription ( @{$this->{subscriptions}} ) {
       if ( $subscription->matches( $topic, $db )) {
           return 1;
       }
   }

   return 0;
}

=begin text

---+++ sub toString() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub toString {
    my $this = shift;

    return "   * " . $this->{name} . ": " .
      join( ", ", @{$this->{subscriptions}} );
}

1;
