# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
use strict;
use Algorithm::Diff;

=pod

---+ package TWiki::Merge

Support for merging strings

=cut

package TWiki::Merge;

=pod

---++ StaticMethod insDelerge( $a, $b, $sep )

Perform a merge of two versions of the same text, using
HTML tags to mark conflicts.

The granularity of the merge depends on the setting of $sep.
For example, if it is ="\\n"=, a line-by-line merge will be done.

Where conflicts exist, they are marked using HTML &lt;del> and
&lt;ins> tags. &lt;del> marks content from $a while &lt;ins>
marks content from $b.

Non-conflicting content (insertions from either set) are not
marked.

=cut

sub insDelMerge {
    my ( $ia, $ib, $sep ) = @_;

    my @a = split( /($sep)/, $ia );
    my @b = split( /($sep)/, $ib );

    my @out;
    Algorithm::Diff::traverse_balanced( \@a, \@b,
                                        {
                                         MATCH => \&_acceptA,
                                         DISCARD_A => \&_acceptA,
                                         DISCARD_B => \&_acceptB,
                                         CHANGE => \&_change
                                        },
                                        undef,
                                        \@out,
                                        \@a,
                                        \@b );
    return join( "", @out);
}

sub _acceptA {
    my ( $a, $b, $out, $ai, $bi ) = @_;

    push( @$out, $ai->[$a] );
}

sub _acceptB {
    my ( $a, $b, $out, $ai, $bi ) = @_;

    push( @$out, $bi->[$b] );
}

sub _change {
    my ( $a, $b, $out, $ai, $bi ) = @_;
    my $simpleInsert = 0;

    # Diff isn't terribly smart sometimes; it will generate changes
    # with a or b empty, which I would have thought should have
    # been accepts.
    if( $ai->[$a] =~ /\S/ ) {
        # there is some non-white text to delete
        push( @$out, "<del>$ai->[$a]</del>" );
    } else {
        # otherwise this insert is not replacing anything
        $simpleInsert = 1;
    }

    if( !$simpleInsert && $bi->[$b] =~ /\S/ ) {
        # this insert is replacing something with something
        push( @$out, "<ins>$bi->[$b]</ins>" );
    } else {
        # otherwise it is replacing nothing, or is whitespace or null
        push( @$out, $bi->[$b] );
    }
}

=pod

---++ StaticMethod simpleMerge( $a, $b, $sep ) -> \@arr

Perform a merge of two versions of the same text, returning
and array of strings representing the blocks in the merged context
where each string starts with one of "+", "-" or " " depending on
whether it is an insertion, a deletion, or just text. Insertions
and deletions alway happen in pairs, as text taken in from either
version that does not replace text in the other version will simply
be accepted.

The granularity of the merge depends on the setting of $sep.
For example, if it is ="\\n"=, a line-by-line merge will be done.
$sep characters are retained in the outout.

=cut

sub simpleMerge {
    my ( $ia, $ib, $sep ) = @_;

    my @a = split( /($sep)/, $ia );
    my @b = split( /($sep)/, $ib );

    my $out = [];
    Algorithm::Diff::traverse_balanced( \@a, \@b,
                                        {
                                         MATCH => \&_sAcceptA,
                                         DISCARD_A => \&_sAcceptA,
                                         DISCARD_B => \&_sAcceptB,
                                         CHANGE => \&_sChange
                                        },
                                        undef,
                                        $out,
                                        \@a,
                                        \@b );
    return $out;
}

sub _sAcceptA {
    my ( $a, $b, $out, $ai, $bi ) = @_;

    push( @$out, " $ai->[$a]" );
}

sub _sAcceptB {
    my ( $a, $b, $out, $ai, $bi ) = @_;

    push( @$out, " $bi->[$b]" );
}

sub _sChange {
    my ( $a, $b, $out, $ai, $bi ) = @_;
    my $simpleInsert = 0;

    if( $ai->[$a] =~ /\S/ ) {
        # there is some non-white text to delete
        push( @$out, "-$ai->[$a]" );
    } else {
        # otherwise this insert is not replacing anything
        $simpleInsert = 1;
    }

    if( !$simpleInsert && $bi->[$b] =~ /\S/ ) {
        # this insert is replacing something with something
        push( @$out, "+$bi->[$b]" );
    } else {
        # otherwise it is replacing nothing, or is whitespace or null
        push( @$out, " $bi->[$b]" );
    }
}

1;
