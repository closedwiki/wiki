# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 20005-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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
#
# Author: Rafael Alvarez (http://www.soronthar.com)

=begin twiki

---+ package TWiki::If::OP_isempty

=cut

package TWiki::If::OP_isempty;
use base 'TWiki::Query::UnaryOP';

use strict;

sub new {
    my $class = shift;
    return $class->SUPER::new( name => 'isempty', prec => 600 );
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    my $a = $node->{params}->[0];
    my %domain = @_;
    my $session = $domain{tom}->session;
    throw Error::Simple('No context in which to evaluate "'.
                          $a->stringify().'"') unless $session;
    my $eval =  $a->_evaluate(@_);
    return 1 unless $eval;
    return 0 if( $session->{request}->param( $eval ));
    return 0 if( $session->{prefs}->getPreferencesValue( $eval ));
    return 0 if( $session->{SESSION_TAGS}{$eval} );
    return 1;
}

1;
