# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 TWiki:Main.StephaneLenclud
# Copyright (C) 2008-2011 TWiki Contributorsi. All Rights Reserved.
#
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

=pod

---+ package TWiki::Plugins::HttpsRedirectPlugin

=cut


package TWiki::Plugins::HttpsRedirectPlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '2011-01-21';

$SHORTDESCRIPTION = 'Redirect authenticated users to HTTPS url.';
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'HttpsRedirectPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{HttpsRedirectPlugin}{Debug} || 0;

    if (TWiki::Func::isGuest) 
    	{
		#If we are guest, force HTTPS on login
		if (TWiki::Func::getContext()->{'login'}) #If we are on the login script
			{							
			#Build up our URL			
			my $query=&TWiki::Func::getCgiQuery();	
			my $url=$query->url() . $query->path_info();
			if ($query->query_string())
				{
				$url.= '?' . $query->query_string();	
				}

				
			unless ($url=~/^https/) #Unless we are already using HTTPS
				{
				#Redirect to HTTPS URL and quite				
				$url=~s/^http/https/;				
				TWiki::Func::writeDebug("HTTPS redirect to: $url" ) if ($debug);
				TWiki::Func::redirectCgiQuery($query, $url);							
				#$TWiki::Plugins::SESSION->finish();				
				#exit(0);
				}
			}	    	    

    	}
	else
		{
		#If the user is no guest always force HTTPS
	
		#Get our URL			
		my $query=&TWiki::Func::getCgiQuery();	
		my $url=$query->url() . $query->path_info();
		if ($query->query_string())
			{
			$url.= '?' . $query->query_string();	
			}

				
		unless ($url=~/^https/) #Unless we are already using HTTPS
			{
			#Redirect to HTTPS URL and quite				
			$url=~s/^http/https/;				
			TWiki::Func::writeDebug("HTTPS redirect to: $url" ) if ($debug);
			TWiki::Func::redirectCgiQuery($query, $url);							
			#$TWiki::Plugins::SESSION->finish();				
			#exit(0);
			}	    	    
		}
    
    return 1;
}

1;
