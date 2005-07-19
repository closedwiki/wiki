# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
#
# =========================
#
# This WeatherPlugin (C) 2004 Andre Bonhote, COLT Telecom <andre@colt.net>
#



# =========================
package TWiki::Plugins::WeatherPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $partnerId $license
    );


use Weather::Com;

$VERSION = '0.002';
$pluginName = 'WeatherPlugin';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $partnerId = TWiki::Func::getPluginPreferencesValue( "PARTNERID" );
    $license = TWiki::Func::getPluginPreferencesValue( "LICENSE" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub DISABLE_earlyInitPlugin
{
### Remove DISABLE_ for a plugin that requires early initialization, that is expects to have
### initializeUserHandler called before initPlugin, giving the plugin a chance to set the user
### See SessionPlugin for an example of this.
    return 1;
}


# =========================
sub DISABLE_initializeUserHandler
{
### my ( $loginName, $url, $pathInfo ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set the username based on cookies. Called by TWiki::initialize.
    # Return the user name, or "guest" if not logged in.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_registrationHandler
{
### my ( $web, $wikiName, $loginName ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set a cookie at time of user registration.
    # Called by the register script.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Called at the beginning of TWiki::handleCommonTags (for cache Plugins use only)
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%


		$_[0] =~ s:%WEATHER{(.*?)}%:&_handleWeatherTag($1,$2):geo;
}

# =========================
sub DISABLE_afterCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Called at the end of TWiki::handleCommonTags (for cache Plugins use only)
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines inside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

}

# =========================
sub DISABLE_beforeEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_afterEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the preview script just before presenting the text.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_afterSaveHandler
{
### my ( $text, $topic, $web, $error ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just after the save action.
    # New hook in TWiki::Plugins $VERSION = '1.020'

}

# =========================
sub DISABLE_writeHeaderHandler
{
### my ( $query ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::writeHeaderHandler( query )" ) if $debug;

    # This handler is called by TWiki::writeHeader, just prior to writing header. 
    # Return a single result: A string containing HTTP headers, delimited by CR/LF
    # and with no blank lines. Plugin generated headers may be modified by core
    # code before they are output, to fix bugs or manage caching. Plugins should no
    # longer write headers to standard output.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_redirectCgiQueryHandler
{
### my ( $query, $url ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;

    # This handler is called by TWiki::redirect. Use it to overload TWiki's internal redirect.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_getSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;

    # This handler is called by TWiki::getSessionValue. Return the value of a key.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_setSessionValueHandler
{
### my ( $key, $value ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;

    # This handler is called by TWiki::setSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================

sub _handleWeatherTag {
	my ($city) = @_;
	my $return = "";

	my %params = (
		'current'			=> 1,
		'partner_id'	=> $partnerId,
		'license'			=> $license,
	);

  TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName} - $city" ) if $debug;

	BLOCK: {
		unless($city) {
      TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName} - No city given" ) if $debug;
			last BLOCK;
		}
		my $request = new Weather::Com(%params);



		if ($city =~ /^[A-Z]{4}[0-9]{4}$/) {
			my $weather = $request->get_weather($city);
      my $temp = $weather->{cc}->{tmp} . " " . $weather->{head}->{ut};
      my $humi = $weather->{cc}->{hmid};
      my $icon = $weather->{cc}->{icon};
      my $ccity = $weather->{loc}->{dnam};
   
      $return .=qq(
<div><table bgcolor="#eeeeee">
  <tr><td align='center'><em>$ccity</em></td></tr>
  <tr><td align='center'><img src="/images/weather/32/$icon.png" alt="icon"></td></tr>
  <tr><td align='center'>$temp / $humi%</td></tr>
</table></div>
);


		} else {
  		my $location = $request->search($city);

  		foreach (keys %{$location}) {
  			my $weather = $request->get_weather($_);
  		  my $temp = $weather->{cc}->{tmp} . " " . $weather->{head}->{ut};
    		my $humi = $weather->{cc}->{hmid};
    		my $icon = $weather->{cc}->{icon};
  			my $ccity = $weather->{loc}->{dnam};
			
			$return .=qq(
<div><table bgcolor="#eeeeee">
  <tr><td align='center'><em>$ccity</em></td></tr>
  <tr><td align='center'><img src="/images/weather/32/$icon.png" alt="icon"></td></tr>
  <tr><td align='center'>$temp / $humi%</td></tr>
</table></div>
);

  		}
		}
	}

	return $return;
		

}
 

1;
