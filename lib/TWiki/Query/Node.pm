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

package TWiki::Query::Node;
use base 'TWiki::Infix::Node';

use Assert;
use Error qw( :try );

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

sub lookupNames {
    return 1;
}

# $data is the indexed object
# $field is the scalar being used to index the object
sub _getField {
    my( $this, $data, $field ) = @_;

    my $result;
    if (UNIVERSAL::isa($data, 'TWiki::Meta')) {
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
            return $data->topic();
        } elsif ($realField eq 'text') {
            # Special accessor to compensate for lack of the topic text
            # name anywhere in the saved fields of meta
            return $data->text();
        } elsif ($realField eq 'web') {
            # Special accessor to compensate for lack of a web
            # name anywhere in the saved fields of meta
            return $data->web();
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
    } elsif (UNIVERSAL::isa($a, 'TWiki::Meta')) {
        return $a->stringify();
    } elsif (ref($a) eq 'HASH') {
        return '{'.join(',', map { "$_=>".toString($a->{$_}) } keys %$a).'}'
    } else {
        return $a;
    }
}

my $ind = 0;
# </DEBUG SUPPORT>

# Evalute this node by invoking the operator function named in the 'exec'
# field of the operator. The return result is either an array ref (for many
# results) or a scalar (for a single result)
sub evaluate {
    my $this = shift;
    ASSERT( scalar(@_) % 2 == 0);
    my $result;

    print STDERR ('-' x $ind).$this->stringify() if MONITOR_EVAL;

    if (!ref( $this->{op})) {
        my %domain = @_;
        if ($this->{op} == $TWiki::Infix::Node::NAME &&
            defined $domain{data}) {
            # a name; look it up in clientData
            $result = $this->_getField( $domain{data}, $this->{params}[0]);
        } else {
            $result = $this->{params}[0];
        }
    } else {
        print STDERR " {\n" if MONITOR_EVAL;
        $ind++ if MONITOR_EVAL;
        my $fn = $this->{op}->{exec};
        $result = $this->$fn( @_ );
        $ind-- if MONITOR_EVAL;
        print STDERR ('-' x $ind).'}' if MONITOR_EVAL;
    }
    print STDERR ' -> ',toString($result),"\n" if MONITOR_EVAL;

    return $result;
}

# Determine if a string represents a valid number
sub _isNumber {
    return shift =~ m/^[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?$/;
}

# Apply a comparison function to two data, tolerant of whether they are
# numeric or not
sub _cmp {
    my ($a, $b, $sub) = @_;
    if (_isNumber($a) && _isNumber($b)) {
        return &$sub($a <=> $b);
    } else {
        return &$sub($a cmp $b);
    }
}

# Evaluate a node using the comparison function passed in. Extra parameters
# are passed on to the comparison function.
sub _evalTest {
    my $this = shift;
    my $clientData = shift;
    my $sub = shift;
    my $a = $this->{params}[0];
    my $b = $this->{params}[1];
    my $ea = $a->evaluate( @{$clientData} ) || '';
    my $eb = $b->evaluate( @{$clientData} ) || '';
    if (ref($ea) eq 'ARRAY') {
        my @res;
        foreach my $lhs (@$ea) {
            push(@res, $lhs) if &$sub($lhs, $eb, @_);
        }
        if (scalar(@res) == 0) {
            return undef;
        } elsif (scalar(@res) == 1) {
            return $res[0];
        }
        return \@res;
    } else {
        return &$sub($ea, $eb, @_);
    }
}

sub _evalUnary {
    my $this = shift;
    my $sub = shift;
    my $a = $this->{params}[0];
    my $val = $a->evaluate( @_ ) || '';
    if (ref($val) eq 'ARRAY') {
        my @res = map { &$sub($_) } @$val;
        return \@res;
    } else {
        return &$sub( $val );
    }
}

sub OP_lc {
    my $this = shift;
    return $this->_evalUnary( sub { lc( shift ) }, @_ );
}

sub OP_uc {
    my $this = shift;
    return $this->_evalUnary( sub { uc( shift ) }, @_ );
}

sub OP_d2n {
    my $this = shift;
    return $this->_evalUnary(
        sub {
            my $date = shift;
            eval {
                require TWiki::Time;
                $date = TWiki::Time::parseTime( $date, 1);
            };
            # ignore $@
            return $date;
        },
        @_ );
}

sub OP_length {
    my $this = shift;
    my $a = $this->{params}[0];
    my $val = $a->evaluate( @_ ) || '';
    if (ref($val) eq 'ARRAY') {
        return scalar( @$val );
    }
    return 1;
}

sub OP_eq {
    my $this = shift;
    return $this->_evalTest( \@_, \&_cmp, sub { $_[0] == 0 ? 1 : 0 });
}

sub OP_like {
    my $this = shift;
    return $this->_evalTest(
        \@_,
        sub {
            my $expr = quotemeta($_[1]);
            # quotemeta will have escapes * and ? wildcards
            $expr =~ s/\\\?/./g;
            $expr =~ s/\\\*/.*/g;
            defined($_[0]) && defined($_[1]) &&
              $_[0] =~ m/$expr/ ? 1 : 0;
        } );
}

sub OP_ne {
    my $this = shift;
    return $this->_evalTest( \@_, \&_cmp, sub { $_[0] != 0 ? 1 : 0 });
}

sub OP_lte {
    my $this = shift;
    return $this->_evalTest( \@_, \&_cmp, sub { $_[0] <= 0 ? 1 : 0 });
}


sub OP_gte {
    my $this = shift;
    return $this->_evalTest( \@_, \&_cmp, sub { $_[0] >= 0 ? 1 : 0 });
}

sub OP_gt {
    my $this = shift;
    return $this->_evalTest( \@_, \&_cmp, sub { $_[0] > 0 ? 1 : 0 });
}

sub OP_lt {
    my $this = shift;
    return $this->_evalTest( \@_, \&_cmp, sub { $_[0] < 0 ? 1 : 0 });
}

sub OP_and {
    my $this = shift;
    my $a = $this->{params}[0];
    return 0 unless $a->evaluate( @_ );
    my $b = $this->{params}[1];
    return $b->evaluate( @_ );
}

sub OP_or {
    my $this = shift;
    my $a = $this->{params}[0];
    return 1 if $a->evaluate( @_ );
    my $b = $this->{params}[1];
    return $b->evaluate( @_ );
}

sub OP_not {
    my $this = shift;
    my $a = $this->{params}[0];
    return $a->evaluate( @_ ) ? 0 : 1;
}

sub OP_ob {
    my $this = shift;
    my $a = $this->{params}[0];
    return $a->evaluate( @_ );
}

sub OP_dot {
    my $this = shift;
    my %domain = @_;
    my $a = $this->{params}[0];
    my $lval = $a->evaluate( @_ );
    my $b = $this->{params}[1];
    my $res = $b->evaluate( data=>$lval, tom=>$domain{tom} );
    if (ref($res) eq 'ARRAY' && scalar(@$res) == 1) {
        return $res->[0];
    }
    return $res;
}

sub OP_ref {
    my $this = shift;
    my %domain = @_;

    my $session = $domain{tom}->session;
    my $topic = $domain{tom}->topic;

    my $a = $this->{params}[0];
    my $node = $a->evaluate( @_ );
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
            my $submeta = $domain{tom}->getMetaFor( $w, $t );
            my $b = $this->{params}[1];
            my $res = $b->evaluate( tom=>$submeta, data=>$submeta );
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
}

sub OP_where {
    my $this = shift;
    my %domain = @_;
    my $a = $this->{params}[0];
    my $lval = $a->evaluate( @_ );
    my $b = $this->{params}[1];
    if (ref($lval) eq 'ARRAY') {
        my @res;
        foreach my $el (@$lval) {
            if ($b->evaluate( data=>$el, tom=>$domain{tom} )) {
                push(@res, $el);
            }
        }
        return undef unless scalar( @res );
        return \@res;
    } else {
        return $b->evaluate( data=>$lval, tom=>$domain{tom} );
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
