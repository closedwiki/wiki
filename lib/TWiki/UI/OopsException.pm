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

=cut

package TWiki::UI::OopsException;

use strict;
use Error;

@TWiki::UI::OopsException::ISA = qw(Error);

=pod

---++ ClassMethod new($web, $topic, $template, ...)

   * =$web= - web
   * =$topic= - topic
   * =$template= - name of the oops template (without the oops prefix)
   * The remaining N parameters will be taken as param1..paramN

=cut

sub new {
    my $class = shift;
    my @params;
    push( @params, -web => shift );
    push( @params, -topic => shift );
    push( @params, -template => shift );
    push( @params, -text => "OopsException(" . join(",", @_) .")");
    push( @params, -params => [ @_ ] );

    $class->SUPER::new( @params );
}

=pod

---++ ObjectMethod stringify() -> $string

=cut

sub stringify {
    my $self = shift;
    return "$self->{-text}:\n" . $self->stacktrace();
}

1;
