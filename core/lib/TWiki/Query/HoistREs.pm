# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2013 Peter Thoeny, peter[at]thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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
#
# Author: Crawford Currie http://c-dot.co.uk

=pod

---+ package TWiki::Query::HoistREs

Static functions to extract regular expressions from queries. The REs can
be used in caching stores that use the TWiki standard inline meta-data
representation to pre-filter topic lists for more efficient query matching.

See =Store/RcsFile.pm= for an example of usage.

=cut

package TWiki::Query::HoistREs;

use strict;

use TWiki::Infix::Node;
use TWiki::Query::Node;

# Try to optimise a query by hoisting regular expression searches
# out of the query
#
# patterns we need to look for:
#
# top level is defined by a sequence of AND and OR conjunctions
# second level, = and ~
# second level LHS is a field access
# second level RHS is a static string or number

sub MONITOR_HOIST { 0 }

=pod

---++ ObjectMethod hoist($query) -> @res

Extract useful filter REs from the given query. The list returned is a list
of filter expressions that can be used with a cache search to refine the
list of topics. The full query should still be applied to topics that remain
after the filter match has been applied; this is purely an optimisation.

=cut

sub hoist {
    my $node = shift;

    return () unless ref($node->{op});

    if ($node->{op}->{name} eq '(') {
        return hoist($node->{params}[0]);
    }

    print STDERR "hoist ",$node->stringify(),"\n" if MONITOR_HOIST;
    if ($node->{op}->{name} eq 'and') {
        my @lhs = hoist($node->{params}[0]);
        my $rhs = _hoistOR($node->{params}[1]);
        if (scalar(@lhs) && $rhs) {
            return ( @lhs, $rhs );
        } elsif (scalar(@lhs)) {
            return @lhs;
        } elsif ($rhs) {
            return ( $rhs );
        }
    } else {
        my $or = _hoistOR($node);
        return ( $or ) if $or;
    }

    print STDERR "\tFAILED\n" if MONITOR_HOIST;
    return ();
}

# depth 1; we can handle a sequence of ORs
sub _hoistOR {
    my $node = shift;

    return undef unless ref($node->{op});

    if ($node->{op}->{name} eq '(') {
        return _hoistOR($node->{params}[0]);
    }

    print STDERR "hoistOR ",$node->stringify(),"\n" if MONITOR_HOIST;

    if ($node->{op}->{name} eq 'or') {
        my $lhs = _hoistOR($node->{params}[0]);
        my $rhs = _hoistEQ($node->{params}[1]);
        if ($lhs && $rhs) {
            return "$lhs|$rhs";
        }
    } else {
        return _hoistEQ($node);
    }

    print STDERR "\tFAILED\n" if MONITOR_HOIST;
    return undef;
}

# depth 2: can handle = and ~ expressions
sub _hoistEQ {
    my $node = shift;

    return undef unless ref($node->{op});

    if ($node->{op}->{name} eq '(') {
        return _hoistEQ($node->{params}[0]);
    }

    print STDERR "hoistEQ ",$node->stringify(),"\n" if MONITOR_HOIST;
    # \000RHS\001 is a placholder for the RHS term
    if ($node->{op}->{name} eq '=') {
        my $lhs = _hoistDOT($node->{params}[0]);
        my $rhs = _hoistConstant($node->{params}[1]);
        if ($lhs && $rhs) {
            $rhs = quotemeta($rhs);
            $lhs =~ s/\000RHS\001/$rhs/g;
            return $lhs;
        }
        # = is symmetric, so try the other order
        $lhs = _hoistDOT($node->{params}[1]);
        $rhs = _hoistConstant($node->{params}[0]);
        if ($lhs && $rhs) {
            $rhs = quotemeta($rhs);
            $lhs =~ s/\000RHS\001/$rhs/g;
            return $lhs;
        }
    } elsif ($node->{op}->{name} eq '~') {
        my $lhs = _hoistDOT($node->{params}[0]);
        my $rhs = _hoistConstant($node->{params}[1]);
        if ($lhs && $rhs) {
            $rhs = quotemeta($rhs);
            $rhs =~ s/\\\?/./g;
            $rhs =~ s/\\\*/.*/g;
            $lhs =~ s/\000RHS\001/$rhs/g;
            return $lhs;
        }
    }

    print STDERR "\tFAILED\n" if MONITOR_HOIST;
    return undef;
}

# Expecting a (root level) field access expression. This must be of the form
# <name>
# or
# <rootfield>.<name>
# <rootfield> may be aliased
sub _hoistDOT {
    my $node = shift;

    if (ref($node->{op}) && $node->{op}->{name} eq '(') {
        return _hoistDOT($node->{params}[0]);
    }

    print STDERR "hoistDOT ",$node->stringify(),"\n" if MONITOR_HOIST;
    if (ref($node->{op}) && $node->{op}->{name} eq '.') {
        my $lhs = $node->{params}[0];
        my $rhs = $node->{params}[1];
        if (!ref($lhs->{op}) && !ref($rhs->{op}) &&
              $lhs->{op} eq $TWiki::Infix::Node::NAME &&
                $rhs->{op} eq $TWiki::Infix::Node::NAME) {
            $lhs = $lhs->{params}[0];
            $rhs = $rhs->{params}[0];
            if ($TWiki::Query::Node::aliases{$lhs}) {
                $lhs = $TWiki::Query::Node::aliases{$lhs};
            }
            if ($lhs =~ /^META:/) {
                # \000RHS\001 is a placholder for the RHS term
                return '^%'.$lhs.'{.*\\b'.$rhs."=\\\"\000RHS\001\\\"";
            }
            # Otherwise assume the term before the dot is the form name
            if ($rhs eq 'text') {
                # Special case for the text body
                return "\000RHS\001";
            } else {
                return "^%META:FIELD{name=\\\"$rhs\\\".*\\bvalue=\\\"\000RHS\001\\\"";
            }

        }
    } elsif (!ref($node->{op}) && $node->{op} eq $TWiki::Infix::Node::NAME) {
        if ($node->{params}[0] eq 'name') {
            # Special case for the topic name
	    return undef;
        } elsif ($node->{params}[0] eq 'web') {
            # Special case for the web name
	    return undef;
        } elsif ($node->{params}[0] eq 'text') {
            # Special case for the text body
            return "\000RHS\001";
        } else {
            return "^%META:FIELD{name=\\\"$node->{params}[0]\\\".*\\bvalue=\\\"\0RHS\1\\\"";
        }
    }

    print STDERR "\tFAILED\n" if MONITOR_HOIST;
    return undef;
}

# Expecting a constant
sub _hoistConstant {
    my $node = shift;

    if (!ref($node->{op}) &&
          ($node->{op} eq $TWiki::Infix::Node::STRING ||
             $node->{op} eq $TWiki::Infix::Node::NUMBER)) {
        return $node->{params}[0];
    }
    return undef;
}

1;
