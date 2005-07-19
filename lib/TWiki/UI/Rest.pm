# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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

=pod

---+ package TWiki::UI::Rest

Rest delegate for view function

=cut

package TWiki::UI::Rest;

use strict;
use integer;

use TWiki;
use TWiki::User;
use TWiki::UI;
use TWiki::Time;

=pod

---++ StaticMethod gateway( $session, $pluginName, $,methodName, $scriptUrl, $query )
=rest= command handler.
This method is designed to be invoked via the =TWiki::UI::run= method, 
and will invoke a method in a plugin. 

It'll print the result directly to the stream unless the =endPoint= parameter is specified 
(via que $query object), in which case the control is redirected to the given topic.


Additional parameters can be queries using the $query object.

---+++ Invocation Examples:

=http://my.host/bin/rest/EmptyPlugin/testRest=

Will invoke =TWiki::Plugin::EmptyPlugin::testRest=, and print the result directly to the stream.

=http://my.host/bin/rest/EmptyPlugin/testRest?endPoint=SomeWeb.SomeTopic=

Will invoke =TWiki::Plugin::EmptyPlugin::testRest=, and redirect the control to <nop>SomeWeb.SomeTopic

=cut
sub gateway {
   my $session = shift;
   $session->enterContext( 'rest' );

   my $query = $session->{cgiQuery};
   my $web = $session->{webName};
   my $topic = $session->{topicName};

    my $endPoint = $query->param( 'endPoint' );
    
	
    my $method = $topic;
    my $plugin = $web;

	 
    if (TWiki::isValidWikiWord($plugin)) {
      my $class = TWiki::Sandbox::untaintUnchecked('TWiki::Plugins::'.$plugin);
   
      my $m = TWiki::Sandbox::untaintUnchecked($class.'::'.$method);
      eval "use $class";
      if( $@ ) {
         die "$class compile failed: $@";
      }
    
		if (defined(&$m)) {
			no strict 'refs';
			local $TWiki::Plugins::SESSION=$session;
			my $result='';
			$result=&$m($session);
			use strict 'refs';
			if (defined($endPoint)) {
				$session->redirect($session->getScriptUrl( '', $endPoint, 'view' ));
			}
         $session->writeCompletePage( $result );
		} else {
			$session->writeCompletePage( 'Unknown Command'.$plugin.'::'.$method);
		}
   } else {
      $session->writeCompletePage( 'Invalid Command'.$plugin.'::'.$method);
   }

   $session->leaveContext( 'rest' );
}

1;
