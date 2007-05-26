# See bottom of file for copyright and license details

=pod

---+ package TWiki::Query

A Query object is a representation of a SEARCH query over the form fields
and other meta-data of a topic.

Fields are given by name, and values by strings or numbers. Strings should always be surrounded by 'single-quotes'. Numbers can be signed integers or decimals. Single quotes in values may be escaped using backslash (\).

See TWiki.QuerySearch for details of the query language.

A query object implements the =evaluate= method as its general
contract with the rest of the world. This method does a "hard work" evaluation
of the parser tree. Of course, smarter Store implementations should be
able to do it better....

=cut

package TWiki::Query;
use base 'TWiki::InfixParser::Node';

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

sub _getField {
    my( $this, $data, $field ) = @_;

    my $result;
    if (ref($data) eq 'TWiki::Meta') {
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
        } else {
            my $form = $data->get( 'FORM' );
            if( $form && $field eq $form->{name}) {
                # SHORTCUT; is it the form name? If so, give me the fields
                # as if the 'field' keyword had been used.
                # TODO: This is where multiple form support needs to reside.
                # Return the array of fields
                my @e = $data->find( 'FIELD' );
                return \@e;
            } else {
                # SHORTCUT; not a predefined name; grope in the fields instead.
                # TODO: Needs to error out if there are multiple forms.
                $result = $data->get( 'FIELD', $field );
                $result = $result->{value} if $result;
            }
        }
    } elsif( ref( $data ) eq 'ARRAY' ) {
        my @res;
        foreach my $f ( @$data ) {
            my $val = $this->_getField( $f, $field );
            push( @res, $val ) if defined( $val );
        }
        if (scalar( @res )) {
            $result = \@res;
        } else {
            # SHORTCUT; The field name wasn't seen in any of the records.
            # try again, this time matching 'name' and returning 'value'
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
    } elsif( ref( $data ) eq 'HASH' ) {
        $result = $data->{$this->{params}[0]};
    } else {
        $result = $this->{params}[0];
    }
    return $result;
}

# <DEBUG SUPPORT>
my $ind = 0;
sub _blat {
    my $a = shift;
    return 'undef' unless defined($a);
    if (ref($a) eq 'ARRAY') {
        return '['.join(',', map { _blat($_) } @$a).']'
    } elsif (ref($a) eq 'TWiki::Meta') {
        return $a->stringify();
    } elsif (ref($a) eq 'HASH') {
        return '{'.join(',', map { "$_=>"._blat($a->{$_}) } keys %$a).'}'
    } else {
        return $a;
    }
}
# </DEBUG SUPPORT>

sub evaluate {
    my( $this, $clientData ) = @_;
    my $result;

    if (MONITOR_EVAL && $ind == 0 && ref($clientData) eq 'TWiki::Meta') {
        print STDERR "$clientData->{_topic} ";
    }
    print STDERR ('-' x $ind).$this->stringify() if MONITOR_EVAL;

    if (!ref( $this->{op})) {
        if ($this->{op} == 1) {
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
    print STDERR ' -> ',_blat($result),"\n" if MONITOR_EVAL;

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
    # Comparison ops, shared with %IF
    @TWiki::If::cmpOps,
   );

sub new {
    my( $class ) = @_;

    my $this = $class->SUPER::new(
        'TWiki::Query', \@operators,
        words => qr/[A-Z][A-Z0-9_:]*/i);
    return $this;
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
