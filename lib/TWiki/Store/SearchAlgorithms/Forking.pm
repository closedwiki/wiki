# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
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

package TWiki::Store::SearchAlgorithms::Forking;

use strict;

=pod

---+ package TWiki::Store::SearchAlgorithms::Forking

Forking implementation of the RCS cache search.

---++ search($searchString, $topics, $options, $sDir) -> \%seen
Search .txt files in $dir for $string. See RcsFile::searchInWebContent
for details.

=cut

sub search {
    my( $searchString, $topics, $options, $sDir, $sandbox ) = @_;

    # Default (Forking) search

    # I18N: 'grep' must use locales if needed,
    # for case-insensitive searching.
    my $program = '';

    # FIXME: For Cygwin grep, do something about -E and -F switches
    # - best to strip off any switches after first space in
    # EgrepCmd etc and apply those as argument 1.
    if( $options->{type} && $options->{type} eq 'regex' ) {
        $program = $TWiki::cfg{RCS}{EgrepCmd};
    } else {
        $program = $TWiki::cfg{RCS}{FgrepCmd};
    }

    $program =~ s/%CS{(.*?)\|(.*?)}%/$options->{casesensitive}?$1:$2/ge;
    $program =~ s/%DET{(.*?)\|(.*?)}%/$options->{files_without_match}?$2:$1/ge;
    # process topics in sets, fix for Codev.ArgumentListIsTooLongForSearch
    my $maxTopicsInSet = 512; # max number of topics for a grep call
    my @take = @$topics;
    my @set = splice( @take, 0, $maxTopicsInSet );
    my $matches = '';

    while( @set ) {
        @set = map { "$sDir/$_.txt" } @set;
        my ($m, $exit ) = $sandbox->sysCommand(
            $program,
            TOKEN => $searchString,
            FILES => \@set);
        # SMELL: had to comment this out because getting exit code of
        # 1 from a perfectly valid grep, on d.t.o :-(
        #throw Error::Simple("$program failed: $m") if $exit;
        $matches .= $m;
        @set = splice( @take, 0, $maxTopicsInSet );
    }
    my %seen;
    # Note use of / and \ as dir separators, to support
    # Winblows
    $matches =~ s/([^\/\\]*)\.txt(:(.*))?$/push( @{$seen{$1}}, $3 ); ''/gem;

    return \%seen;
}

1;
