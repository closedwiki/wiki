# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Peter Thoeny, peter@thoeny.org
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
This method is designed to be invoked via the =TWiki::UI::run= method. 
It'll lookup in the dispatch table for a function associated with
the given subject and verb, and execute it if one is found.
 
=cut
sub gateway {
    my $session = shift;
    $session->enterContext( 'rest' );
    
    my $query = $session->{cgiQuery};
    my $web = $session->{webName};
    my $topic = $session->{topicName};
    
    my $endPoint = $query->param( 'endPoint' );

    my $verb= $topic;
    my $subject = $web;
    
    $session->writeLog( 'rest', $web.'.'.$topic );
    
    if (TWiki::isValidWikiWord($subject)) {
        my $function=TWiki::restDispatch($subject,$verb);
        if (defined($function)) {
            no strict 'refs';
            local $TWiki::Plugins::SESSION=$session;
            my $result='';
            $result=&$function($session,$subject,$verb);
            use strict 'refs';
            if (defined($endPoint)) {
                $session->redirect($session->getScriptUrl( 1, 'view', '', $endPoint ));
            } else {
                $session->writeCompletePage( $result );
            }
        } else {
            $session->writeCompletePage( 'Unknown Action '.$subject.'/'.$verb);
        }
    } else {
        $session->writeCompletePage( 'Invalid Command '.$subject);
    }
    
    $session->leaveContext( 'rest' );
}

1;
