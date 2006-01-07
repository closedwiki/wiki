# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
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

use strict;
use Algorithm::Diff;

=pod

---+ package TWiki::Merge

Support for 3-way merging of strings. Similar to Merge.pm, except that:
  a) it's considers the ancestor revision of the string, and
  b) it works. :-P

=cut

package TWiki::Merge3;

use Assert;

sub equal {
    my ($a, $b) = @_;
    return 1 if( !defined($a) && !defined($b) );
    return 0 if( !defined($a) || !defined($b) );
    return "$a" eq "$b";
}

=pod

---++ StaticMethod merge( $a, $b, $c, $arev, $brev, $crev, $sep,
                          $writeConflict, @info )

Perform a merge of two versions (b and c) of the same text, using
HTML tags to mark conflicts. a is the common ancestor.

The granularity of the merge depends on the setting of $sep.
For example, if it is ="\\r?\\n"=, a line-by-line merge will be done.

Where conflicts exist, they are labeled using the provided revision
numbers. If a $writeConflict method is passed, then that's called
to override the built-in conflict formatting. Non-conflicting content
is not labeled.

Here's a little picture of a 3-way merge:
    
      a   <- ancestor
     / \
    b   c <- revisions
     \ /
      d   <- merged result, returned.

call it like this:
    
    my ( $ancestorMeta, $ancestorText ) =
        $store->readTopic( undef, $webName, $topic, $originalrev );
    $newText = TWiki::Merge3::merge(
        $ancestorText, $prevText, $newText,
        $originalrev, $rev, "new",
        '\r?\n' );

=cut

sub merge {
    my ( $ia, $ib, $ic, $arev, $brev, $crev, $sep, $writeConflict, @info ) = @_;

    $sep = "\r?\n" if (!defined($sep));
    $writeConflict = \&writeConflict if(!defined($writeConflict));
    
    my @a = split( /(.+?$sep)/, $ia );
    my @b = split( /(.+?$sep)/, $ib );
    my @c = split( /(.+?$sep)/, $ic );
    
    my @bdiffs = Algorithm::Diff::sdiff( \@a, \@b );
    my @cdiffs = Algorithm::Diff::sdiff( \@a, \@c );
    
    my $ai = 0; # index into a
    my $bdi = 0; # index into bdiffs
    my $cdi = 0; # index into bdiffs
    my $na = scalar(@a);
    my $nbd = scalar(@bdiffs);
    my $ncd = scalar(@cdiffs);
    my $done = 0;
    my (@achunk, @bchunk, @cchunk);
    my @diffs; # (a, b, c)
    
    # diffs are of the form [ [ modifier, b_elem, c_elem ] ... ]
    # where modifiers is one of:
    #   '+': element (b or c) added
    #   '-': element (from a) removed
    #   'u': element unmodified
    #   'c': element changed (a to b/c)

    # first, collate the diffs.
    
    while(!$done) {
        my $bop = ($bdi < $nbd) ? $bdiffs[$bdi][0] : 'x';
        if($bop eq '+') {
            push @bchunk, $bdiffs[$bdi++][2];
            next;
        }
        my $cop = ($cdi < $ncd) ? $cdiffs[$cdi][0] : 'x';
        if($cop eq '+') {
            push @cchunk, $cdiffs[$cdi++][2];
            next;
        }
        while(scalar(@bchunk) || scalar(@cchunk)) {
            push @diffs, [shift @achunk, shift @bchunk, shift @cchunk];
        }
        if(scalar(@achunk)) {
            @achunk = ();
        }
        last if($bop eq 'x' || $cop eq 'x');
        
        # now that weve dealt with '+' and 'x', the only remaining
        # operations are '-', 'u', and 'c', which all consume an
        # element of a, so we should increment them together.
        my $aline = $bdiffs[$bdi][1];
        my $bline = $bdiffs[$bdi][2];
        my $cline = $cdiffs[$cdi][2];
        push @diffs, [$aline, $bline, $cline];
        $bdi++;
        $cdi++;
    }
    
    # at this point, both lists should be consumed, unless theres a bug in
    # Algorithm::Diff. well consume whatevers left if necessary though.
    
    while($bdi < $nbd) {
        push @diffs, [$bdiffs[$bdi][1], undef, $bdiffs[$bdi][2]];
        $bdi++;
    }
    while($cdi < $ncd) {
        push @diffs, [$cdiffs[$cdi][1], undef, $cdiffs[$cdi][2]];
        $cdi++;
    }

    my (@aconf, @bconf, @cconf, @merged);
    my $conflict = 0;
    my @out;
    my ($aline, $bline, $cline);
    
    for my $diff (@diffs) {
        ($aline, $bline, $cline) = @$diff;
        my $ab = equal($aline, $bline);
        my $ac = equal($aline, $cline);
        my $bc = equal($bline, $cline);
        my $dline = undef;
        
        if($bc) {
            $dline = $bline;
        } elsif($ab) {
            $dline = $cline;
        } elsif($ac) {
            $dline = $bline;
        } else {
            $conflict = 1;
        }

        if($conflict) {
            push @aconf, $aline;
            push @bconf, $bline;
            push @cconf, $cline;
        }
        
        if(defined($dline)) {
            if($conflict) {
                push @merged, $dline;
                if(@merged > 3) {
                    for my $i ( 0 .. $#merged ) {
                        pop @aconf;
                        pop @bconf;
                        pop @cconf;
                    }
                    &$writeConflict(\@out, \@aconf, \@bconf, \@cconf,
                                    $arev, $brev, $crev, $sep, @info);
                    $conflict = 0;
                    push @out, @merged;
                    @merged = ();
                }
            } else {
                push @out, $dline;
            }
        } elsif(@merged) {
            @merged = ();
        }
    }
    
    if($conflict) {
        for my $i ( 0 .. $#merged ) {
            pop @aconf;
            pop @bconf;
            pop @cconf;
        }
        
        &$writeConflict(\@out, \@aconf, \@bconf, \@cconf,
                        $arev, $brev, $crev, $sep, @info);
    }
    push @out, @merged;
    @merged = ();

    #foreach ( @out ) { print STDERR (defined($_) ? $_ : "undefined") . "\n"; }
    
    return join('', @out);
}

sub writeConflict {
    my($out, $aconf, $bconf, $cconf, $arev, $brev, $crev, $sep) = @_;
    my( @a, @b, @c );
    
    @a = grep( $_, @$aconf );
    @b = grep( $_, @$bconf );
    @c = grep( $_, @$cconf );
    if(@a) {
        push @$out, "<div class=\"twikiConflict\"><b>CONFLICT</b> original $arev:</div>\n";
        push @$out, @a;
    }
    if(@b) {
        push @$out, "<div class=\"twikiConflict\"><b>CONFLICT</b> version $brev:</div>\n";
        push @$out, @b;
    }
    if(@c) {
        push @$out, "<div class=\"twikiConflict\"><b>CONFLICT</b> version $crev:</div>\n";
        push @$out, @c;
    }
    push @$out, "<div class=\"twikiConflict\"><b>CONFLICT</b> end</div>\n";
}

1;
