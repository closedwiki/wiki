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

---+ package TWiki::UI::Backlinks

UI delegate for backlinks function

=cut

package TWiki::UI::Backlinks;

use strict;
use TWiki;

=pod

---++ StaticMethod backlinks($session)

=backlinks= command handler.
This method is designed to be invoked via the =TWiki::UI::run= method.
CGI parameters:
| =template= | name of template to use |
| =paramN= | Parameter for expansion of template |
%PARAMn% tags will be expanded in the template using the 'paramN'
values in the query.

=cut

sub backlinks {
    my $session = shift;
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $query = $session->{cgiQuery};
    
    my $skin = $session->getSkin();
    my $action = $session->{cgiQuery}->param( 'action' );
    
    my $tmplName;
    if ( $action eq 'web' ) {
		$tmplName = 'backlinksweb';
    }
    if ( $action eq 'allwebs' ) {
    	$tmplName = 'backlinksallwebs';
    }
    
    my $tmplData = $session->{templates}->readTemplate( $tmplName, $skin );
    
    if( ! $tmplData ) {
        $tmplData = CGI::start_html()
          . CGI::h1('TWiki Installation Error')
            . 'Template file '.$tmplName
               . '.tmpl not found or template directory '
                 . $TWiki::cfg{TemplateDir}.' not found.'.CGI::p()
                   . 'Check the configuration setting for TemplateDir.'
                     .CGI::end_html();
    } else {
        my $def = $query->param( 'def' );
        if( defined $def ) {
            # if a def is specified, instantiate that def
            $tmplData =~ s/%INSTANTIATE%/%TMPL:P{"$def"}%/;
        }
        $tmplData = $session->handleCommonTags( $tmplData, $web, $topic );
        my $param;
        my $n = 1;
        while( $param = $query->param( 'param'.$n ) ) {
            $tmplData =~ s/%PARAM$n%/$param/g;
            $n++;
        }
        $tmplData = $session->{renderer}->getRenderedVersion( $tmplData, $web, $topic );
    }
    
    $session->writeCompletePage( $tmplData );
}

1;
