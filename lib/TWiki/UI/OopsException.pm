# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
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

---+ package TWiki::UI::OopsException

Exception used by UI methods to raise a request to redirect to an Oops URL.
The following named parameters are required to the exception:
   * -web
   * -topic
   * -template (without the oops prefix)
   * -text
Optional parameters are:
   * -param1 through -param4
=cut

package TWiki::UI::OopsException;

use strict;
use Error;

@TWiki::UI::OopsException::ISA = qw(Error);

sub new {
    my ( $self, $web, $topic, $template, $p1, $p2, $p3, $p4 ) = @_;
    $p1 = "" unless $p1;
    $p2 = "" unless $p2;
    $p3 = "" unless $p3;
    $p4 = "" unless $p4;
    $self->SUPER::new( -web=>$web,
                       -topic=>$topic,
                       -template=>$template,
                       -text=>
                       "OopsException($web,$topic,$template,$p1,$p2,$p3,$p4",
                       -param1=>$p1,
                       -param2=>$p2,
                       -param3=>$p3,
                       -param4=>$p4 );
}

sub stringify {
    my $self = shift;
    return "$self->{-text}:\n" . $self->stacktrace();
}

1;
