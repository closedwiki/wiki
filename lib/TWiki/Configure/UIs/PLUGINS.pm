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
use strict;

package TWiki::Configure::UIs::PLUGINS;

use TWiki::Configure::UIs::Section;

use base 'TWiki::Configure::UIs::Section';

sub close_html {
    my ($this, $section) = @_;

    my $button = <<HERE;
Click here to consult the online plugins repository for
new plugins. <b>Warning:</b>Unsaved changes will be lost!
HERE
    my $final_row =
      CGI::Tr(CGI::td($button),
              CGI::td(CGI::submit(-name => 'action',
                                  -class=>'twikiSubmit',
                                  -value=>'Find More Extensions',
                                  -accesskey=>'P')));
    return $final_row.$this->SUPER::close_html($section);
}

1;
