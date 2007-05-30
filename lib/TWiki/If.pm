# See bottom of file for copyright and license details

=pod

---+ package TWiki::If

Support for the conditions in %IF{} statements.

| *Precedence* | *Operator* |
| 100  | or |
| 200  | and |
| 300  | not |
| 400  | > < >= <= |
| 500  | = != ~ |
| 600  | lc uc context defined $ |
| 1000 | ( |

=cut

package TWiki::If;
use TWiki::Query;
use base 'TWiki::QueryParser';

use strict;
use Assert;

sub new {
    my( $class ) = @_;

    my $this = $class->SUPER::new({
        nodeClass => 'TWiki::IfNode',
        words => qr/([A-Za-z][\w:]+|({\w+})+)/});
    $this->addOperator({
        name => 'context',
        prec => 600,
        arity => 1, # unary
        casematters => 0,
        exec => sub {
            my( $domain, $a ) = @_;
            my $text = $a->evaluate([undef, undef]) || '';
            my $session = $domain->[1]->{_session};
            throw Error::Simple('No context in which to evaluate "'.
                                  $a->stringify().'"') unless $session;
            return $session->inContext($text) || 0;
        }
       });
    $this->addOperator({
        name => '$',
        prec => 600,
        arity => 1, # unary
        exec => sub {
            my( $domain, $a ) = @_;
            my $session = $domain->[1]->{_session};
            throw Error::Simple('No context in which to evaluate "'.
                                  $a->stringify().'"') unless $session;
            my $text = $a->evaluate([undef, undef]) || '';
            if( $text && defined( $session->{cgiQuery}->param( $text ))) {
                return $session->{cgiQuery}->param( $text );
            }
            $text = "%$text%";
            TWiki::expandAllTags($session, \$text,
                                 $session->{topicName},
                                 $session->{webName});
            return $text || '';
        },
       });
    $this->addOperator({
        name => 'defined',
        prec => 600,
        arity => 1, # unary
        casematters => 0,
        exec => sub {
            my( $domain, $a ) = @_;
            my $session = $domain->[1]->{_session};
            throw Error::Simple('No context in which to evaluate "'.
                                  $a->stringify().'"') unless $session;
            my $eval =  $a->evaluate([undef, undef]);
            return 0 unless $eval;
            return 1 if( defined( $session->{cgiQuery}->param( $eval )));
            return 1 if( defined(
                $session->{prefs}->getPreferencesValue( $eval )));
            return 1 if( defined( $session->{SESSION_TAGS}{$eval} ));
            return 0;
        },
       });

    return $this;
}

# Private subclass specialised to handle {} syntax
package TWiki::IfNode;
use base 'TWiki::Query';

sub newLeaf {
    my( $class, $val, $type ) = @_;
    if( $type == $TWiki::InfixParser::NAME && $val =~ /^({\w+})+$/) {
        eval '$val = $TWiki::cfg'.$val;
        return $class->SUPER::newLeaf($val, $TWiki::InfixParser::STRING);
    } else {
        return $class->SUPER::newLeaf($val, $type);
    }
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
