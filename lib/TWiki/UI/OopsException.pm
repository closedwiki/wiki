# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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
