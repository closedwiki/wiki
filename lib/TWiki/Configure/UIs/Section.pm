#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
# A UI for a collection object, designed so the objects can be twisted.
# The UI is implemented by visiting the nodes of the configuration and
# invoking the open-html and close_html methods for each node. The
# layout of a configuration page is depth-sensitive, so we have slightly
# different behaviours for each of level 0 (the root), level 1 (twisty
# sections) and level > 1 (subsection).
use strict;

package TWiki::Configure::UIs::Section;

use TWiki::Configure::UI;

use base 'TWiki::Configure::UI';

# depth == 1 is the root
# depth == 2 are twisty sections
# depth > 2 are subsections
sub open_html {
    my ($this, $section, $valuer) = @_;

    my $depth = $section->getDepth();

    if ($depth > 2) {
        # A running section has no subtable, just a header row
        my $fn = 'CGI::h'.$depth;
        no strict 'refs';
        my $head = &$fn($section->{headline});
        use strict 'refs';
        $head .= $section->{desc} if $section->{desc};
        return '<tr><td colspan=2>'.$head.'</td></tr>';
    }

    my $id = $this->_makeAnchor( $section->{headline} );
    my $linkId = 'blockLink'.$id;
    my $linkAnchor = $id.'link';

    my $warnings = $section->{warnings} || 0;
    my $errors = $section->{errors} || 0;
    my $errorsMess = $errors . ' error'. (($errors > 1) ? 's' : '');
    my $warningsMess = $warnings . ' warning'. (($warnings > 1) ? 's' : '');
    my $mess = '';
    $mess .= CGI::span({class=>'error'}, $errorsMess) if $errors;
    $mess .= '&nbsp;' if ($errors && $warnings);
    $mess .= CGI::span({class=>'warn'}, $warningsMess) if $warnings;

    my $guts = "<!-- $depth $section->{headline} -->";
    if ($depth == 2) {
        # Open row
        $guts .= '<tr><td colspan=2>';
        $guts .= CGI::a({ name => $linkAnchor });

        # Open twisty div
        $guts .= CGI::a(
            {id => $linkId,
             class => 'blockLink blockLinkOff',
             href => '#'.$linkAnchor,
             rel => 'nofollow',
             onclick => 'foldBlock(\'' . $id . '\'); return false;'},
            $section->{headline}.$mess);

        $guts .= "<div id='$id' class='foldableBlock foldableBlockClosed'>";

        $guts .= CGI::div({class=>'tipsOfTheDay'}, $section->{desc})
          if $section->{desc};
    }

    # Open subtable
    $guts .=
      CGI::start_table(
          { width => '100%', -border => 1, -cellspacing => 0,
            -cellpadding => 0, -cols => 2})."\n";

    return $guts;
}

sub close_html {
    my ($this, $section) = @_;
    my $depth = $section->getDepth();
    my $end = '';
    if ($depth <= 2) {
        # Close subtable
        $end = "\n</table>";
        if ($depth == 2) {
            # Close twisty div
            $end .= '</div>';
            # Close row
            $end .= '</td></tr>';
        }
    }
    return "$end<!-- /$depth $section->{headline} -->\n";
}

1;

