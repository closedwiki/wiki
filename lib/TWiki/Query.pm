# See bottom of file for copyright and license details

=pod

---+ package TWiki::Query

A Query object is a representation of a SEARCH query over the form fields
and other meta-data of a topic.

Fields are given by name, and values by strings or numbers. Strings should always be surrounded by 'single-quotes'. Strings which are regular expressions (RHS of =, != ~ operators) use 'perl' regular expression syntax (google for =perlre= for help). Numbers can be signed integers or decimals. Single quotes in values may be escaped using backslash (\).

See TWiki.QuerySearch for details of the query language.

A query object implements the =evaluate= method as its general
contract with the rest of the world.

=cut

package TWiki::Query;
use base 'TWiki::InfixParser::Node';

use Assert;

# 1 for debug
sub MONITOR_EVAL { 0 };

# map of reserved names to their meta-data type
my %simpleNames = (
    attachments => 'FILEATTACHMENT',
    field => 'FIELD',
    info => 'TOPICINFO',
    parent => 'TOPICPARENT',
    moved => 'TOPICMOVED',
    form => 'FORM',
   );

sub _getField {
    my( $this, $data, $field ) = @_;

    my $result;
    if (ref($data) eq 'TWiki::Meta') {
        if( $simpleNames{$field} ) {
            $field = $simpleNames{$field};
            if ($field eq 'FILEATTACHMENT' || $field eq 'FIELD') {
                # Array type, have to use find
                my @e = $data->find( $field );
                $result = \@e;
            } else {
                $result = $data->get( $field );
            }
        } else {
            # Shortcut; not a predefined name; grope in the fields instead
            $result = $data->get( 'FIELD', $field );
            $result = $result->{value} if $result;
        }
    } elsif( ref( $data ) eq 'ARRAY' ) {
        my @res;
        foreach my $f ( @$data ) {
            my $val = $this->_getField( $f, $field );
            push( @res, $val ) if defined( $val );
        }
        if (scalar( @res )) {
            $result = \@res;
        }
    } elsif( ref( $data ) eq 'HASH' ) {
        $result = $data->{$this->{params}[0]};
    } else {
        $result = $this->{params}[0];
    }
    return $result;
}

my $ind = 0;

sub evaluate {
    my( $this, $clientData ) = @_;
    my $result;

    print STDERR ('-' x $ind).$this->stringify()," {\n" if MONITOR_EVAL;

    if (!ref( $this->{op})) {
        if ($this->{op} == 1) {
            # a name; look it up in clientData
            $result = $this->_getField( $clientData->[0], $this->{params}[0]);
        } else {
            $result = $this->{params}[0];
        }
    } else {
        $ind++ if MONITOR_EVAL;
        my $fn = $this->{op}->{exec};
        $result = &$fn( $clientData, @{$this->{params}} );
        $ind-- if MONITOR_EVAL;
    }
    print STDERR ('-' x $ind).'} -> ',(defined($result)?$result:'undef'),"\n"
      if MONITOR_EVAL;

    return $result;
}

package TWiki::QueryParser;
use base 'TWiki::InfixParser';

use strict;
use Assert;
use Error qw( :try );
use TWiki::If; # for comparison ops

# Operators
# In the follow, exec is a function that evaluates the node. The $domain
# is a reference to a two element array; the first element contains the
# data being operated on, and the second a reference to the meta-data of
# the topic being worked on. The data being operated on can be a Meta object,
# a reference to an array (such as attachments), a reference to a hash (such
# as TOPICINFO) or a scalar. Arrays can contain other arrays and hashes.
# Operators that only take a subset of these types must check the data type.
my @operators = (
    {
        name => '.',
        prec => 800,
        arity => 2,
        exec => sub {
            my( $domain, $a, $b ) = @_;
            my $lval = $a->evaluate( $domain );
            return $b->evaluate( [ $lval, $domain->[1] ]);
        },
    },
    {
        name => ':',
        prec => 700,
        arity => 2,
        exec => sub {
            my( $domain, $a, $b ) = @_;
            # SMELL: private fields in meta
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
            return \@result;
        },
    },
    {
        name => '[?',
        prec => 800,
        arity => 2,
        close => ']',
        exec => sub {
            my( $domain, $a, $b ) = @_;
            my $lval = $a->evaluate( $domain );
            return $b->evaluate( [ $lval, $domain->[1] ] );
        },
    },
    {
        name => '[',
        prec => 800,
        arity => 2,
        close => ']',
        exec => sub {
            my( $domain, $a, $b ) = @_;
            my $lval = $a->evaluate( $domain );
            my $rval = $b->evaluate( $domain );
            if( ref($lval) eq 'ARRAY' ) {
                if( ref($rval) || $rval !~ /^\d+$/) {
                    #die "$rval is not a valid index";
                } elsif( $rval >= scalar(@$lval)) {
                    #die "Index $rval out of bounds 0..".scalar(@$lval);
                }
                return $lval->[$rval];
            } elsif( ref($lval) ) {
                # Attempt to index a HASH or Meta
            } elsif( $rval =~ /^0+$/) {
                return $lval;
            }
            return undef;
        },
    },
    # Comparison ops, shared with %IF
    @TWiki::If::cmpOps,
   );

sub new {
    my( $class ) = @_;

    my $this = $class->SUPER::new(
        'TWiki::Query', \@operators,
        words => qr/\w+/);
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
