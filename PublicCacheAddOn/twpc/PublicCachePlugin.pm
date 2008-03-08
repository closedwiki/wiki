# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 Colas Nahaboo http://colas.nahaboo.net
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

# This plugin is part of the TWPC, TWiki Public Cache Addon.
# It is used to track changes in the state of the TWiki contents, and call
# proper cache updating modules.

# =========================
package TWiki::Plugins::PublicCachePlugin;

$debug = 0;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION  $RELEASE $pluginName
        $debug 
    );

# This should always be $Rev: 15564 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15564 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'v3';

$pluginName = 'PublicCachePlugin';  # Name of this Plugin

sub debug { TWiki::Func::writeDebug(@_) if $debug; }

sub warning {
    TWiki::Func::writeWarning(@_);
    debug( "WARNING" . $_[0], @_[ 1 .. $#_ ] );
}

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.020 ) {
        warning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }
    TWiki::Func::registerTagHandler( 'PCACHEEXPTIME', \&_PCACHEEXPTIME );
    return 1;
}

# The function handles the %PCACHEEXPTIME{...}% variable
# You would have one of these for each variable you want to process.
sub _PCACHEEXPTIME {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable
    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
    
    eval "require File::Path;";
    my $exptime = $params->{_DEFAULT} || XXXexptimeXXX;
    #debug("- $pluginName: %PCACHEEXPTIME{$exptime}%");
    if ($exptime == 0) {
       File::Path::mkpath("XXXcacheXXX/$theWeb", 0, 0777);
      if( open( FILE, ">>XXXcacheXXX/$theWeb/$theTopic.nc" ) ) {
	close( FILE ); # just create an empty file
      }
    } else {
       File::Path::mkpath("XXXcacheXXX/_expire/$theWeb", 0, 0777);
      if( open( FILE, ">>XXXcacheXXX/_expire/$theWeb/$theTopic" ) ) {
	close( FILE ); # just create an empty file
	my $fileexptime = time() + $exptime;
	utime($fileexptime, $fileexptime, "XXXcacheXXX/_expire/$theWeb/$theTopic");
      } else {
	warning("Error writing XXXcacheXXX/_expire/$theWeb/$theTopic");
      }
    }
    return '';
}

=pod

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a TWiki::Meta object 
This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

*Since:* TWiki::Plugins::VERSION 1.020

=cut

sub afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;
    #         0      1       2     3       4
    if ($_[3]) {
        debug("- $pluginName: Unsuccessful save, not notifying...");
        return;
    }
    # immediately clear cache for cleargrace null
    if (XXXcleargraceXXX == 0) {
        eval "require  LWP::Simple;";
        my $response =  LWP::Simple::get("XXXbinurlXXX/pcad?action=clear");
	if (! defined $response) {
	    warning("Error in clearing cache");
        }
        return 1;
    }

    # untaint var, see: http://www.perlmeme.org/howtos/secure_code/taint.html
    my $ip_tainted = $ENV{REMOTE_ADDR};
    if ( $ip_tainted =~ m/^([0-9\.]+)$/ ) {
        my $ip = "$1";

        if( open( FILE, ">>XXXcacheXXX/_changers/$ip" ) ) {
            close( FILE ); # just create an empty file
        } else {
	    # retry once
	    eval "require File::Path;";
	     File::Path::mkpath("XXXcacheXXX/_changers", 0, 0777);
	    if( open( FILE, ">>XXXcacheXXX/_changers/$ip" ) ) {
                close( FILE ); # just create an empty file
	    } else {
                # dont complain: it means the cache system was not in
                # place yet, so no need to bypass it anyways at this time
                debug("PublicCachePlugin: could not write XXXcacheXXX/_changers/$ip");
	    }
        }
    } else {
        warning("Bad IP address in REMOTE_ADDR: $ENV{REMOTE_ADDR}");
    }

   return 1;
}

1;
