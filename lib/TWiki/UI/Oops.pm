# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

=begin twiki

---+ package TWiki::UI::Oops

UI delegate for oops function

=cut

package TWiki::UI::Oops;

use strict;
use TWiki;

=pod

---++ StaticMethod oops_cgi($session)

=oops= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
CGI parameters:
| =template= | name of template to use |
| =param1= | Parameter for expansion of template |
| =param2= | Parameter for expansion of template |
| =param3= | Parameter for expansion of template |
| =param4= | Parameter for expansion of template |

=cut

sub oops_cgi {
    my $session = shift;
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $query = $session->{cgiQuery};

    my $tmplName = $query->param( 'template' ) || 'oops';
    my $skin = $session->getSkin();

    my $tmplData = $session->{templates}->readTemplate( $tmplName, $skin );
    if( ! $tmplData ) {
        $tmplData = CGI::start_html()
          . CGI::h1('TWiki Installation Error')
            . 'Template file'.$tmplName
               . '.tmpl not found or template directory '
                 . $TWiki::cfg{TemplateDir}.' not found.'.CGI::p()
                   . 'Check the configuration setting for TemplateDir.'
                     .end_html();
    } else {
        my $param = $query->param( 'param1' ) || '';
        $tmplData =~ s/%PARAM1%/$param/go;
        $param = $query->param( 'param2' ) || '';
        $tmplData =~ s/%PARAM2%/$param/go;
        $param = $query->param( 'param3' ) || '';
        $tmplData =~ s/%PARAM3%/$param/go;
        $param = $query->param( 'param4' ) || '';
        $tmplData =~ s/%PARAM4%/$param/go;

        $tmplData = $session->handleCommonTags( $tmplData, $web, $topic );
        $tmplData = $session->{renderer}->getRenderedVersion( $tmplData, $web, $topic );
    }

    $session->writeCompletePage( $tmplData );
}

1;
