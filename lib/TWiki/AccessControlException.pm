# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Crawford Currie http://c-dot.co.uk
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

=pod twiki

---+ package TWiki::AccessControlException

Exception used raise an access control violation.

=cut

package TWiki::AccessControlException;

use strict;
use Error;

@TWiki::AccessControlException::ISA = qw(Error);

=pod

---+ ClassMethod new($mode, $user, $web, $topic, $reason)

   * =$mode= - mode of access (view, change etc)
   * =$user= - user object doing the accessing
   * =$web= - web being accessed
   * =$topic= - topic being accessed
   * =$reason= - string reason for failure

All the above fields are accessible from the object in a catch clause
in the usual way e.g. =$e->{-web}= and =$e->{-reason}=

=cut

sub new {
    my ( $class, $mode, $user, $web, $topic, $reason ) = @_;

    return $class->SUPER::new(
                              -web => $web,
                              -topic => $topic,
                              -user => $user->wikiName(),
                              -mode => $mode,
                              -reason => $reason,
                             );
}

=pod

---++ ObjectMethod stringify() -> $string

Generate a summary string

=cut

sub stringify {
    my $self = shift;
    return "AccessControlException: Access to $self->{-mode} $self->{-web}.$self->{-topic} for $self->{-user} is denied. $self->{-reason}";
}

1;
