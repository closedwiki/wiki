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

sub new {
    my ( $class, $mode, $user, $web, $topic ) = @_;

    return $class->SUPER::new(
                              -web => $web,
                              -topic => $topic,
                              -user => $user->wikiName(),
                              -mode => $mode,
                             );
}

sub stringify {
    my $self = shift;
    return "AccessControlException: $self->{-mode} access to $self->{-web}.$self->{-topic} denied for $self->{-user}";
}

1;
