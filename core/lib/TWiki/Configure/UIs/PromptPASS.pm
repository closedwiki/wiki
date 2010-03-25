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
package TWiki::Configure::UIs::PromptPASS;

use strict;

use TWiki::Configure::UI;

use base 'TWiki::Configure::UI';

my %nonos = (
    cfgAccess => 1,
    newCfgP   => 1,
    confCfgP  => 1,
);

sub ui {
    my ( $this, $canChangePW, $actionMess ) = @_;
    my $output = '';

    my @script     = File::Spec->splitdir( $ENV{SCRIPT_NAME} );
    my $scriptName = pop(@script);
    $scriptName =~ s/.*[\/\\]//;    # Fix for Item3511, on Win XP

    $output .= CGI::start_form( { action => $scriptName, method => 'post' } );

    # Pass URL params through, except those below
    foreach my $param ( $TWiki::query->param ) {
        next if ( $nonos{$param} );
        $output .= $this->hidden( $param, $TWiki::query->param($param) );
        $output .= "\n";
    }

    # and add a few more
    $output .= "<div id ='twikiPassword'><div class='twikiFormSteps'>\n";

    $output .= CGI::div( { class => 'twikiFormStep' },
        CGI::h3('Enter the configuration password') );

    $output .= CGI::div(
        { class => 'twikiFormStep' },
        CGI::h3( CGI::strong("Your Password:") )
          . CGI::p(
                CGI::password_field( 'cfgAccess', '', 20, 80 ) 
              . '&nbsp;'
              . CGI::submit(
                -name => 'action',
                -class => 'twikiSubmit',
                -value => $actionMess
              )
          )
    );

    $output .= '</div><!--/twikiFormSteps--></div><!--/twikiPassword-->';

    if ($canChangePW) {
        $output .=
          "<div id='twikiPasswordChange'><div class='twikiFormSteps'>\n";
        $output .= '<div class="explanation">';
        $output .= CGI::img(
            {
                width  => '16',
                height => '16',
                src    => $scriptName
                  . '?action=image;image=warning.gif;type=image/gif',
                alt => ''
            }
        );
        $output .= '&nbsp;'
          . CGI::span( { class => 'twikiAlert' },
            CGI::strong('Notes on Security') );
        $output .= <<HERE;
<ul>
 <li>
  If you don't set a password, or the password is cracked, then
  <code>configure</code> could be used to do <strong>very</strong> nasty
  things to your server.
 </li>
 <li>
  If you are running TWiki on a public website, you are
  <strong>strongly</strong> advised to totally disable saving from
  <code>configure</code> by making <code>lib/LocalSite.cfg</code> readonly once
  you are happy with your configuration.
 </li>
</ul>
</div><!--expanation-->
HERE

    }

    return $output . CGI::end_form();
}

1;
