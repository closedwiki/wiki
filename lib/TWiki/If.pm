# See bottom of file for copyright and license details
use strict;
use Assert;

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
use base 'TWiki::InfixParser';

sub _isNumber {
    return shift =~ m/^[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?$/;
}

sub _cmp {
    my ($a, $b, $sub) = @_;
    if (_isNumber($a) && _isNumber($b)) {
        return &$sub($a <=> $b);
    } else {
        return &$sub($a cmp $b);
    }
}

sub _evalTest {
    my $a = shift;
    my $b = shift;
    my $sub = shift;

    if (ref($a) eq 'ARRAY') {
        my @res;
        foreach my $lhs (@$a) {
            push(@res, $lhs) if &$sub($lhs, $b, @_);
        }
        if (scalar(@res) == 0) {
            return undef;
        } elsif (scalar(@res) == 1) {
            return $res[0];
        }
        return \@res;
    } else {
        return &$sub($a, $b, @_);
    }

}

# Export cmpOps for use in other modules
use vars qw( @cmpOps );

@cmpOps = (
    {
        name => 'lc',
        prec => 600,
        arity => 1,
        casematters => 0,
        exec => sub {
            my( $clientData, $a ) = @_;
            my $val = $a->evaluate($clientData) || '';
            if (ref($val) eq 'ARRAY') {
                my @res = map { lc($_) } @$val;
                return \@res;
            }
            return lc( $val );
        },
    },
    {
        name => 'uc',
        prec => 600,
        arity => 1,
        casematters => 0,
        exec => sub {
            my( $clientData, $a ) = @_;
            my $val = $a->evaluate($clientData) || '';
            if (ref($val) eq 'ARRAY') {
                my @res = map { uc($_) } @$val;
                return \@res;
            }
            return uc( $val );
        },
    },
    {
        name => 'd2n',
        prec => 600,
        arity => 1,
        casematters => 0,
        exec => sub {
            my( $clientData, $a ) = @_;
            my $val = $a->evaluate($clientData) || '';
            if (ref($val) eq 'ARRAY') {
                my @res = map { _d2n($_) } @$val;
                return \@res;
            }
            return _d2n( $val );
        },
    },
    {
        name => '=',
        prec => 500,
        arity => 2, # binary
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            my $ea = $a->evaluate($clientData) || '';
            my $eb = $b->evaluate($clientData) || '';
            return _evalTest($ea, $eb, \&_cmp, sub { $_[0] == 0 ? 1 : 0 });
        },
    },
    {
        name => '~', # LIKE
        prec => 500,
        arity => 2,
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            my $ea = $a->evaluate($clientData) || '';
            my $eb = $b->evaluate($clientData) || '';
            return _evalTest($ea, $eb,
                          sub {
                              my $expr = quotemeta($_[1]);
                              # quotemeta will have escapes * and ? wildcards
                              $expr =~ s/\\\?/./g;
                              $expr =~ s/\\\*/.*/g;
                              defined($_[0]) && defined($_[1]) &&
                                $_[0] =~ m/$expr/ ? 1 : 0
                            });
        },
    },
    {
        name => '!=',
        prec => 500,
        arity => 2, # binary
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            my $ea = $a->evaluate($clientData) || '';
            my $eb = $b->evaluate($clientData) || '';
            return _evalTest($ea, $eb, \&_cmp, sub { $_[0] != 0 ? 1 : 0 });
        },
    },
    {
        name => '>=',
        prec => 400,
        arity => 2, # binary
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            my $ea = $a->evaluate($clientData) || 0;
            my $eb = $b->evaluate($clientData) || 0;
            return _evalTest($ea, $eb, \&_cmp, sub { $_[0] >= 0 ? 1 : 0 });
        },
    },
    {
        name => '<=',
        prec => 400,
        arity => 2, # binary
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            my $ea = $a->evaluate($clientData) || 0;
            my $eb = $b->evaluate($clientData) || 0;
            return _evalTest($ea, $eb, \&_cmp, sub { $_[0] <= 0 ? 1 : 0 });
        },
    },
    {
        name => '>',
        prec => 400,
        arity => 2, # binary
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            my $ea = $a->evaluate($clientData) || 0;
            my $eb = $b->evaluate($clientData) || 0;
            return _evalTest($ea, $eb, \&_cmp, sub { $_[0] > 0 ? 1 : 0 });
        },
    },
    {
        name => '<',
        prec => 400,
        arity => 2, # binary
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            my $ea = $a->evaluate($clientData) || 0;
            my $eb = $b->evaluate($clientData) || 0;
            return _evalTest($ea, $eb, \&_cmp, sub { $_[0] < 0 ? 1 : 0 });
        },
    },
    {
        name => 'not',
        prec => 300,
        arity => 1, # unary
        casematters => 0,
        exec => sub {
            my( $clientData, $a ) = @_;
            return $a->evaluate($clientData) ? 0 : 1;
        },
    },
    {
        name => 'and',
        prec => 200,
        arity => 2, # binary
        casematters => 0,
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            return 0 unless $a->evaluate($clientData);
            return $b->evaluate($clientData);
        },
    },
    {
        name => 'or',
        prec => 100,
        arity => 2, # binary
        casematters => 0,
        exec => sub {
            my( $clientData, $a, $b ) = @_;
            return 1 if $a->evaluate($clientData);
            return $b->evaluate($clientData);
        },
    },
    {
        name => '(',
        arity => 1,
        prec => 1000,
        close => ')',
        exec => sub {
            my( $clientData, $a ) = @_;
            return $a->evaluate( $clientData );
        },
    },
   );

my @operators = (
    {
        name => 'context',
        prec => 600,
        arity => 1, # unary
        casematters => 0,
        exec => sub {
            my( $session, $a ) = @_;
            return $session->inContext($a->evaluate($session)) || 0;
        },
    },
    {
        name => '$',
        prec => 600,
        arity => 1, # unary
        exec => sub {
            my( $session, $a ) = @_;
            my $text = $a->evaluate($session) || '';
            if( $text && defined( $session->{cgiQuery}->param( $text ))) {
                return $session->{cgiQuery}->param( $text );
            }
            $text = "%$text%";
            TWiki::expandAllTags($session, \$text,
                                 $session->{topicName},
                                 $session->{webName});
            return $text || '';
        },
    },
    {
        name => 'defined',
        prec => 600,
        arity => 1, # unary
        casematters => 0,
        exec => sub {
            my( $session, $a ) = @_;
            my $eval =  $a->evaluate($session);
            return 0 unless $eval;
            return 1 if( defined( $session->{cgiQuery}->param( $eval )));
            return 1 if( defined(
                $session->{prefs}->getPreferencesValue( $eval )));
            return 1 if( defined( $session->{SESSION_TAGS}{$eval} ));
            return 0;
        },
    },
    @cmpOps,
   );

sub new {
    my( $class ) = @_;

    my $this = $class->SUPER::new(
        'TWiki::IfNode', \@operators,
        words => qr/(\w+|({\w+})+)/);
    return $this;
}

# Private static wrapper around TWiki::parseTime
sub _d2n {
    my $date = shift;
    eval {
        $date = TWiki::Time::parseTime( $date, 1);
    };
    # ignore $@
    return $date;
}

# Private subclass specialised to handle {} syntax
package TWiki::IfNode;
use base 'TWiki::InfixParser::Node';

sub newLeaf {
    my( $class, $val, $type ) = @_;
    if( $type == 1 && $val =~ /^({\w+})+$/) {
        eval '$val = $TWiki::cfg'.$val;
    }
    return $class->SUPER::newLeaf($val, $type);
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
