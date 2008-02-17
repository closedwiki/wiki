# See bottom of file for copyright and license details

=pod

---+ package TWiki::If::Parser

Support for the conditions in %IF{} statements.

=cut

package TWiki::If::Parser;
use base 'TWiki::Query::Parser';

use strict;
use Assert;
use TWiki::If::Node;

sub new {
    my( $class ) = @_;

    my $this = $class->SUPER::new({
        nodeClass => 'TWiki::If::Node',
        words => qr/([A-Za-z][\w:]+|({\w+})+)/});

    # See TWiki::Query::Parser.pm for an explanation of 'exec'
    $this->addOperator(
        name => 'context',
        prec => 600, arity => 1, casematters => 0,
        exec => 'OP_context',
       );
    $this->addOperator(
        name => 'allows',
        prec => 600, arity => 2, casematters => 0,
        exec => 'OP_allows',
       );
    $this->addOperator(
        name => '$',
        prec => 600, arity => 1,
        exec => 'OP_dollar',
       );
    $this->addOperator(
        name => 'defined',
        prec => 600, arity => 1, casematters => 0,
        exec => 'OP_defined',
       );
    $this->addOperator(
        name => 'istopic',
        prec => 600, arity => 1, casematters => 0,
        exec => 'OP_istopic',
       );
    $this->addOperator(
        name => 'isweb',
        prec => 600, arity => 1, casematters => 0,
        exec => 'OP_isweb',
       );
    $this->addOperator(
        name => 'ingroup',
        prec => 600, arity => 2, casematters => 1,
        exec => 'OP_ingroup',
       );       

    return $this;
}

1;

__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
