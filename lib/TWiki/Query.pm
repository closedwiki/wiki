# See bottom of file for copyright and license details

=pod

---+ package TWiki::Query

A Query object is a representation of a query over the TWiki database.

Fields are given by name, and values by strings or numbers. Strings should always be surrounded by 'single-quotes'. Numbers can be signed integers or decimals. Single quotes in values may be escaped using backslash (\).

See TWiki.QuerySearch for details of the query language. At the time of writing
only a subset of the entire query language is supported, for use in searching.

A query object implements the =evaluate= method as its general
contract with the rest of the world. This method does a "hard work" evaluation
of the parser tree. Of course, smarter Store implementations should be
able to do it better....

=cut

package TWiki::Query;
use base 'TWiki::InfixParser::Node';

use Assert;

# 1 for debug
sub MONITOR_EVAL { 0 };

=pod

---++ PUBLIC $aliases
A hash mapping short aliases for META: entry names. For example, this hash
maps 'form' to 'META:FORM'. Published so extensions can extend the range
of supported types.

---++ PUBLIC %isArrayType
Maps META: entry type names to true if the type is an array type (such as
FIELD, ATTACHMENT or PREFERENCE). Published so extensions can extend the range
or supported types. The type name should be given without the leading 'META:'

=cut

use vars qw ( %aliases %isArrayType );

%aliases = (
    attachments => 'META:FILEATTACHMENT',
    fields      => 'META:FIELD',
    form        => 'META:FORM',
    info        => 'META:TOPICINFO',
    moved       => 'META:TOPICMOVED',
    parent      => 'META:TOPICPARENT',
    preferences => 'META:PREFERENCE',
   );

%isArrayType =
  map { $_ => 1 } qw( FILEATTACHMENT FIELD PREFERENCE );

# $data is the indexed object
# $field is the scalar being used to index the object
sub _getField {
    my( $this, $data, $field ) = @_;

    my $result;
    if (ref($data) eq 'TWiki::Meta') {
        # The object being indexed is a TWiki::Meta object, so
        # we have to use a different approach to treating it
        # as an associative array. The first thing to do is to
        # apply our "alias" shortcuts.
        my $realField = $field;
        if( $aliases{$field} ) {
            $realField = $aliases{$field};
        }
        if ($realField =~ s/^META://) {
            if ($isArrayType{$realField}) {
                # Array type, have to use find
                my @e = $data->find( $realField );
                $result = \@e;
            } else {
                $result = $data->get( $realField );
            }
        } elsif ($realField eq 'name') {
            # Special accessor to compensate for lack of a topic
            # name anywhere in the saved fields of meta
            return $data->{_topic};
        } elsif ($realField eq 'web') {
            # Special accessor to compensate for lack of a web
            # name anywhere in the saved fields of meta
            return $data->{_web};
        } else {
            # The field name isn't an alias, check to see if it's
            # the form name
            my $form = $data->get( 'FORM' );
            if( $form && $field eq $form->{name}) {
                # SHORTCUT;it's the form name, so give me the fields
                # as if the 'field' keyword had been used.
                # TODO: This is where multiple form support needs to reside.
                # Return the array of FIELD for further indexing.
                my @e = $data->find( 'FIELD' );
                return \@e;
            } else {
                # SHORTCUT; not a predefined name; assume it's a field
                # 'name' instead.
                # SMELL: Needs to error out if there are multiple forms -
                # or perhaps have a heuristic that gives access to the
                # uniquely named field.
                $result = $data->get( 'FIELD', $field );
                $result = $result->{value} if $result;
            }
        }
    } elsif( ref( $data ) eq 'ARRAY' ) {
        # Indexing an array object. The index will be one of:
        # 1. An integer, which is an implicit index='x' query
        # 2. A name, which is an implicit name='x' query
        if( $field =~ /^\d+$/ ) {
            # Integer index
            $result = $data->[$field];
        } else {
            # String index
            my @res;
            # Get all array entries that match the field
            foreach my $f ( @$data ) {
                my $val = $this->_getField( $f, $field );
                push( @res, $val ) if defined( $val );
            }
            if (scalar( @res )) {
                $result = \@res;
            } else {
                # The field name wasn't explicitly seen in any of the records.
                # Try again, this time matching 'name' and returning 'value'
                foreach my $f ( @$data ) {
                    next unless ref($f) eq 'HASH';
                    if ($f->{name} && $f->{name} eq $field
                          && defined $f->{value}) {
                        push( @res, $f->{value} );
                    }
                }
                if (scalar( @res )) {
                    $result = \@res;
                }
            }
        }
    } elsif( ref( $data ) eq 'HASH' ) {
        $result = $data->{$this->{params}[0]};
    } else {
        $result = $this->{params}[0];
    }
    return $result;
}

# <DEBUG SUPPORT>
sub toString {
    my ($a) = @_;
    return 'undef' unless defined($a);
    if (ref($a) eq 'ARRAY') {
        return '['.join(',', map { toString($_) } @$a).']'
    } elsif (ref($a) eq 'TWiki::Meta') {
        return $a->stringify();
    } elsif (ref($a) eq 'HASH') {
        return '{'.join(',', map { "$_=>".toString($a->{$_}) } keys %$a).'}'
    } else {
        return $a;
    }
}

my $ind = 0;
# </DEBUG SUPPORT>

sub evaluate {
    my( $this, $clientData ) = @_;
    my $result;

    if (MONITOR_EVAL && $ind == 0 && ref($clientData) eq 'TWiki::Meta') {
        print STDERR "$clientData->{_topic} ";
    }
    print STDERR ('-' x $ind).$this->stringify() if MONITOR_EVAL;

    if (!ref( $this->{op})) {
        if ($this->{op} == $TWiki::InfixParser::NAME &&
              defined $clientData->[0]) {
            # a name; look it up in clientData
            $result = $this->_getField( $clientData->[0], $this->{params}[0]);
        } else {
            $result = $this->{params}[0];
        }
    } else {
        print STDERR " {\n" if MONITOR_EVAL;
        $ind++ if MONITOR_EVAL;
        my $fn = $this->{op}->{exec};
        $result = &$fn( $clientData, @{$this->{params}} );
        $ind-- if MONITOR_EVAL;
        print STDERR ('-' x $ind).'}' if MONITOR_EVAL;
    }
    print STDERR ' -> ',toString($result),"\n" if MONITOR_EVAL;

    return $result;
}

package TWiki::QueryParser;
use base 'TWiki::InfixParser';

use strict;
use Assert;
use Error qw( :try );

# Operators
# In the follow, exec is a function that evaluates the node. The $domain
# is a reference to a two element array; the first element contains the
# data being operated on, and the second a reference to the meta-data of
# the topic being worked on. The data being operated on can be a Meta object,
# a reference to an array (such as attachments), a reference to a hash (such
# as TOPICINFO) or a scalar. Arrays can contain other arrays and hashes.
# Operators that only take a subset of these types must check the data type.

# Export operators for use in other derivative syntaxes
use vars qw( @operators );

@operators = (
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
        name => 'length',
        prec => 600,
        arity => 1,
        casematters => 0,
        exec => sub {
            my( $clientData, $a ) = @_;
            my $val = $a->evaluate($clientData) || '';
            if (ref($val) eq 'ARRAY') {
                return scalar( @$val );
            }
            return 1;
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
    {
        name => '.',
        prec => 800,
        arity => 2,
        exec => sub {
            my( $domain, $a, $b ) = @_;
            my $lval = $a->evaluate( $domain );
            my $res = $b->evaluate( [ $lval, $domain->[1] ]);
            if (ref($res) eq 'ARRAY' && scalar(@$res) == 1) {
                return $res->[0];
            }
            return $res;
        },
    },
    {
        name => '/',
        prec => 700,
        arity => 2,
        exec => sub {
            my( $domain, $a, $b ) = @_;
            # SMELL: accessing private fields in meta
            my $session = $domain->[1]->{_session};
            my $topic = $domain->[1]->{_topic};

            my $node = $a->evaluate( $domain );
            return undef unless defined $node;
            if( ref($node) eq 'HASH') {
                return undef;
            }
            if( !( ref($node) eq 'ARRAY' )) {
                $node = [ $node ];
            }
            my @result;
            foreach my $v (@$node) {
                next if $v !~ /^($TWiki::regex{webNameRegex}\.)*$TWiki::regex{wikiWordRegex}$/;

                # Has to be relative to the web of the topic we are querying
                my( $w, $t ) = $session->normalizeWebTopicName(
                    $session->{webName}, $v );
                my $result = undef;
                try {
                    my( $submeta, $subtext ) = $session->{store}->readTopic(
                        undef, $w, $t );
                    my $res = $b->evaluate( [ $submeta, $submeta ] );
                    if( ref($res) eq 'ARRAY') {
                        push(@result, @$res);
                    } else {
                        push(@result, $res);
                    }
                } catch Error::Simple with {
                };
            }
            return undef unless scalar( @result );
            return $result[0] if scalar(@result) == 1;
            return \@result;
        },
    },
    {
        name => '[',
        prec => 800,
        arity => 2,
        close => ']',
        exec => \&_where,
    },
   );

sub new {
    my( $class, $options ) = @_;

    $options->{words} ||= qr/[A-Z][A-Z0-9_:]*/i;
    $options->{nodeClass} ||= 'TWiki::Query';
    my $this = $class->SUPER::new($options);
    foreach my $op ( @operators ) {
        $this->addOperator( $op );
    }
    return $this;
}

sub _isNumber {
    return shift =~ m/^[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?$/;
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

sub _where {
    my( $domain, $a, $b ) = @_;
    my $lval = $a->evaluate( $domain );
    if (ref($lval) eq 'ARRAY') {
        my @res;
        foreach my $el (@$lval) {
            if ($b->evaluate( [ $el, $domain->[1] ])) {
                push(@res, $el);
            }
        }
        return undef unless scalar( @res );
        return \@res;
    } else {
        return $b->evaluate( [ $lval, $domain->[1] ] );
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
