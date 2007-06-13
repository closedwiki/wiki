# See bottom of file for copyright and license details

=pod

---+ package TWiki::Query::Parser

Parser for queries

=cut

package TWiki::Query::Parser;
use base 'TWiki::Infix::Parser';

use TWiki::Query::Node;

use strict;

# Operators
#
# In the following, the standard InfixParser node structure is extended by
# one field, 'exec'.
#
# exec is the name of a member function of the 'Query' class that evaluates
# the node. It is called on the node and is passed a $domain. The $domain
# is a reference to a hash that contains the data being operated on, and a
# reference to the meta-data of the topic being worked on (this is
# effectively the "topic object"). The data being operated on can be a
# Meta object, a reference to an array (such as attachments), a reference 
# to a hash (such as TOPICINFO) or a scalar. Arrays can contain other arrays
# and hashes.

sub new {
    my( $class, $options ) = @_;

    $options->{words} ||= qr/[A-Z][A-Z0-9_:]*/i;
    $options->{nodeClass} ||= 'TWiki::Query::Node';
    my $this = $class->SUPER::new($options);
    $this->addOperator(
            name => 'lc',
            prec => 600, arity => 1, casematters => 0,
            exec => 'OP_lc',
        );
    $this->addOperator(
            name => 'uc',
            prec => 600, arity => 1, casematters => 0,
            exec => 'OP_uc',
        );
    $this->addOperator(
            name => 'd2n',
            prec => 600, arity => 1, casematters => 0,
            exec => 'OP_d2n',
        );
    $this->addOperator(
            name => 'length',
            prec => 600, arity => 1, casematters => 0,
            exec => 'OP_length',
        );
    $this->addOperator(
            name => '=',
            prec => 500, arity => 2,
            exec => 'OP_eq',
        );
    $this->addOperator(
            name => '~', # LIKE
            prec => 500, arity => 2,
            exec => 'OP_like',
        );
    $this->addOperator(
            name => '!=',
            prec => 500, arity => 2,
            exec => 'OP_ne',
        );
    $this->addOperator(
            name => '>=',
            prec => 400, arity => 2,
            exec => 'OP_gte',
        );
    $this->addOperator(
            name => '<=',
            prec => 400, arity => 2,
            exec => 'OP_lte',
        );
    $this->addOperator(
            name => '>',
            prec => 400, arity => 2,
            exec => 'OP_gt',
        );
    $this->addOperator(
            name => '<',
            prec => 400, arity => 2,
            exec => 'OP_lt',
        );
    $this->addOperator(
            name => 'not',
            prec => 300, arity => 1, casematters => 0,
            exec => 'OP_not',
        );
    $this->addOperator(
            name => 'and',
            prec => 200, arity => 2, casematters => 0,
            exec => 'OP_and',
        );
    $this->addOperator(
            name => 'or',
            prec => 100, arity => 2, casematters => 0,
            exec => 'OP_or',
        );
    $this->addOperator(
            name => '(', close => ')',
            prec => 1000, arity => 1,
            exec => 'OP_ob',
        );
    $this->addOperator(
            name => '.',
            prec => 800, arity => 2,
            exec => 'OP_dot',
        );
    $this->addOperator(
            name => '/',
            prec => 700, arity => 2,
            exec => 'OP_ref',
        );
    $this->addOperator(
            name => '[', close => ']',
            prec => 800, arity => 2,
            exec => 'OP_where',
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
