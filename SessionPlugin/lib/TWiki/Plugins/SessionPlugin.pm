# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# This Plugin is meant to improve upon SessionPlugin. Do not install
# them both at the same time. However, never fear, this plugin has
# absorbed all of the functionality of SessionPlugin. It simply
# has been implemented more cleanly and does not require silly
# things like logon scripts (though they are certainly still
# supported).
#

# =========================
package TWiki::Plugins::SessionPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $SESSIONVAR
        $debug $useTransSessionId $stickSkinVar $stickSkinOffValue
        $query $session $sessionId $authUser $doSessionIpMatching $useTransSID
        $sessionIsAuthenticated
        $authUserSessionVar $stickskin $sessionLogonUrl $sessionLogonUrlPath
    );

#use strict;

# Use CGI::Session to handle session information.
#
# Considered using Apache::Session or PHP::Session, but CGI::Session
# seemed the "most" platform independent. :)
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!! For %DO_SESSION_IP_MATCHING% support !!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!! To turn it in, uncomment the use line  !!!
# !!! that includes CGI::Session with        !!!
# !!! qw/-ip_match/ turned on and comment    !!!
# !!! out the other line. If you want this   !!!
# !!! feature turned on, comment out the     !!!
# !!! qw/ip_match/ line and uncomment the    !!!
# !!! one without qw/ip_match/.              !!!
# !!!                                        !!!
# !!! IT IS RECOMMENDED TO LEAVE IP MATCHING !!!
# !!! ON! THIS IS AN IMPORTANT SECURITY      !!!
# !!! FEATURE! See SessionPlugin's           !!!
# !!! documentation for details, or even     !!!
# !!! see CGI::Session's documentation on    !!!
# !!! CPAN for further recommendations on    !!!
# !!! using this feature.                    !!!
# !!!                                        !!!
# !!! At the moment it is not possible to    !!!
# !!! turn this on in the normal way, which  !!!
# !!! is why you have to edit                !!!
# !!! SessionPlugin.pm directly. This is     !!!
# !!! because TWikiVariables that setup      !!!
# !!! module settings are not initialized    !!!
# !!! in the preferences data structures     !!!
# !!! early enough to be used for the        !!!
# !!! sessions to start their authentication !!!
# !!! magic. Authentication happens so early !!!
# !!! and yet module configuration happens   !!!
# !!! so late. :( (partly because            !!!
# !!! preferences configuration depends upon !!!
# !!! knowing the user so it can set user    !!!
# !!! preferences.                           !!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!! For %DO_SESSION_IP_MATCHING% support !!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#use CGI::Session;			# Uncomment to turn off IP MATCHING (not recommended!!)
use CGI::Session qw/-ip_match/;		# Uncomment to turn ON IP MATCHING (default! recommended!)

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!! For %AUTHUSER_SESSIONVAR% support !!!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!                                        !!!
# !!! For similar reasons as the IP_MATCHING !!!
# !!! stuff above, AUTHUSER_SESSIONVAR must  !!!
# !!! be hard coded for the moment. Maybe    !!!
# !!! someday this can be provided in the    !!!
# !!! SessionPlugin.txt file instead...      !!! 
# !!!                                        !!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!! For %AUTHUSER_SESSIONVAR% support !!!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
BEGIN
{
    $authUserSessionVar = "AUTHUSER";

    ###### IMPORTANT NOTE: Another **TWO** BEGINS BELOW !!  #######
    ###                                                         ###
    ### LOOK BELOW for two other BEGIN sections that run        ###
    ### all necessary private initializations and a few other   ###
    ### items                                                   ###
    ###                                                         ###
    ###### IMPORTANT NOTE: Another **TWO** BEGIN BELOW !!  ########
}

# =========================

##
## This really is uglier than I wanted it to be. I didn't realize I was going to need to run
## so much so early due to the way TWiki initializes its preferences and sets up information
## that is dependent on already having the user logged in.
##
## I've done my best to salvage something that's at least not entirely unclean.
## I welcome modifications, improvements, etc. 
##
## Good luck!
##
## -- Main.TedPavlic - 22 Jul 2003
##

# =========================

# This BEGIN sets up simple stuff. See the BEGIN below that
# runs private initialization stuff WAY earlier than usual
#
# (We run stuff way early to make sure authentication works)
BEGIN {

    $VERSION = '2.9';
    $pluginName = 'SessionPlugin';  	# Name of this Plugin

    ###### IMPORTANT NOTE: Another BEGIN BELOW !!  #######
    ###                                                ###
    ### LOOK BELOW for other BEGIN section that runs   ###
    ### all necessary private initializations          ###
    ###                                                ###
    ###### IMPORTANT NOTE: Another BEGIN BELOW !!  #######

} # end initial initialization . . . 


sub earlyInitPlugin 
{
    _init_authuser();
}


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Make absolutely sure _init_globals() has been run. If it has, it will
    # return immediately. 
    #
    # As of BeijingRelease, initializeUserHandler is called *before* 
    # initPlugin. If initPlugin is ever called BEFORE initializeUserHandler,
    # then these being here will be important. However, because 
    # initializeUserHandler needs globals and authuser to work, they are
    # also called there.
    #
    # Once called though, these will return immediately, so it is not that
    # important that they only get called once.
    # _init_globals() or return 0;	# Important globals ($session,...)
    # _init_authuser() or return 0;	# Setup authentication stuff

    # Get the plugin preferences to configure this plugin
    _init_preferences() or return 0;
 
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin using sessionId = $sessionId" ) if $debug;

    # Now finish off setting globals which are affected by this
    # current $web and $topic
    #
    # Get the path to pass the user for location of logon
    $sessionLogonUrl = TWiki::Func::getScriptUrl( $web, $topic, "logon" ); 
    $sessionLogonUrlPath = $sessionLogonUrl;
    $sessionLogonUrlPath =~ s@.*?//.*?/@/@;

    # And now setup any explicit session variables specified via CGI
    _init_cgi_set_and_clear_session_variables() or return 0;

    # Now that we're configured, reconfigure our SKIN with stickskin information
    _init_stickskin() or return 0;

    # Plugin correctly initialized (finally)
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub initializeUserHandler
{
### my ( $loginName, $url, $pathInfo ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;
    # Allows a plugin to set the username based on sessions. Called by TWiki::initialize.
    # Return the user name, or "guest" if not logged in.
    # New hook in TWiki::Plugins $VERSION = '1.010'

    #
    # As of BeijingRelease, this plugin handler is called BEFORE
    # initPlugin. That means that some initialization that is
    # required to make authentication work needs to happen here.
    #
    # These functions are called once, remember that they are called,
    # and then return immediately every other time they are called.
    # This plugin takes advantage of that by putting them both here
    # and in initPlugin. That way it shouldn't matter which one of 
    # these is called first.
    #
    # The catch is that in order to make this work nicely with modperl,
    # SpeedyCGI, etc., it is required that these DO NOT immediately
    # return here. We need to FORCE their execution ALWAYS during this
    # function so that every new modperl, SpeedyCGI, etc. instance will
    # get a new user name. 
    #
    # In other words, THIS IS A HORRIBLE HACK AND I HATE IT.
    #
    
    _clear_init_function_history();	# Allows all _inits to run again
    
    _init_globals() or return 0;	# Important globals ($session,...)
    _init_authuser() or return 0;	# Setup authentication stuff

    return $authUser;

}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    # Get and set session variables
    #
    # Do GET first so that previous values can be known before setting new values. This way
    # values can be swapped or old values simply moved. GETs can be used within SETs this way.
    #
    # If using BeijingRelease, it is important that TWiki:Codev/SessionVariablesOverrideFinalPreferences
    # is applied (a patch is included) to Prefs.pm to prevent users from circumventing
    # FINALPREFERENCES settings.
    #
    $_[0] =~ s/%LOGON_OR_WELCOME%/%SESSION_IF_AUTHENTICATED% *[[TWiki.WelcomeGuest][Welcome]]* %WIKIUSERNAME% %SESSION_ELSE% [[TWiki.TWikiRegistration][Register]] or %SESSIONLOGON% %SESSION_ENDIF%/go;

    $_[0] =~ s/%GET_SESSION_VARIABLE{\s*(.*?)\s*}%/@{[ &getSessionValueHandler( $1 ) ? &getSessionValueHandler( $1 ) : "" ]}/go;
    $_[0] =~ s/%SET_SESSION_VARIABLE{\s*(.*?)\s*,\s*(.*?)\s*}%/@{[ setSessionValueHandler( $1, $2 ) ? "" : "" ]}/go;
    $_[0] =~ s/%CLEAR_SESSION_VARIABLE{\s*(.*?)\s*}%/@{[ &clearSessionValueHandler( $1 ) ? "" : "" ]}/go;

    # Handle conditional authentication tags
    $_[0] =~ s/%SESSION_IF_AUTHENTICATED%(.*?)%SESSION_ELSE%(.*?)%SESSION_ENDIF%/@{ [ $sessionIsAuthenticated ? $1 : $2 ] }/go if defined( $sessionIsAuthenticated );
    $_[0] =~ s/%SESSION_IF_NOT_AUTHENTICATED%(.*?)%SESSION_ELSE%(.*?)%SESSION_ENDIF%/@{ [ $sessionIsAuthenticated ? $2 : $1 ] }/go if defined( $sessionIsAuthenticated );
    $_[0] =~ s/%SESSION_IF_AUTHENTICATED%(.*?)%SESSION_ENDIF%/@{ [ $sessionIsAuthenticated ? $1 : "" ] }/go if defined( $sessionIsAuthenticated );
    $_[0] =~ s/%SESSION_IF_NOT_AUTHENTICATED%(.*?)%SESSION_ENDIF%/@{ [ $sessionIsAuthenticated ? "" : $1 ] }/go if defined( $sessionIsAuthenticated );

    $_[0] =~ s/%SESSIONLOGONURL%/$sessionLogonUrl/geo if defined( $sessionLogonUrl );
    $_[0] =~ s/%SESSIONLOGONURLPATH%/$sessionLogonUrlPath/geo if defined( $sessionLogonUrlPath );

    $_[0] =~ s/%SESSIONID%/$sessionId/geo if defined( $sessionId );
    $_[0] =~ s/%SESSIONVAR%/$SESSIONVAR/geo if defined( $SESSIONVAR );
    $_[0] =~ s/%SESSION_IS_AUTHENTICATED%/$sessionIsAuthenticated/geo if defined( $sessionIsAuthenticated );
    $_[0] =~ s/%STICKSKIN%/$stickskin/geo if defined($stickskin);

    $_[0] =~ s/%AUTHUSER_SESSIONVAR%/$authUserSessionVar/geo if defined( $authUserSessionVar );

    $_[0] =~ s/%DO_SESSION_IP_MATCHING%/$doSessionIpMatching/geo if defined( $doSessionIpMatching );
    $_[0] =~ s/%USE_TRANS_SESSIONID%/$useTransSessionId/geo if defined( $useTransSessionId );
    $_[0] =~ s/%STICKSKINVAR%/$stickSkinVar/geo if defined( $stickSkinVar );
    $_[0] =~ s/%STICKSKINOFFVALUE%/$stickSkinOffValue/geo if defined( $stickSkinOffValue );

}

# =========================
sub endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

    # If cookies are not turned on and transparent CGI session IDs are,
    # grab every URL that is an internal link and pass a CGI variable 
    # with the session ID
    if( $useTransSID )
    {
        # Internal links are specified by forms, hrefs, or onclicks that either
        # point to a link with no colons in it or links that match links that
        # would bve returned by getScriptUrl. Internal links are additionally
        # specified by forms that have no target.

        # Gather the URLs one would expect to be returned by getScriptUrl if a URL
        # was inside of quotes (A) or outside of quotes (B) or inside of single quotes 
        # for javascript (C).
        #
        # Use these later in all the regex's below.
        my $myScriptUrlA = quotemeta(TWiki::Func::getScriptUrl( "ZZZZ", "ZZZZ", "ZZZZ" ));
        my $myScriptUrlB = $myScriptUrlA;
        my $myScriptUrlC = $myScriptUrlA;
        $myScriptUrlA =~ s/ZZZZ/[^"#]*?/g;
        $myScriptUrlB =~ s/ZZZZ/[^\\s#>]*?/g;
        $myScriptUrlC =~ s/ZZZZ/[^'#>]*?/g;

        #
        # NOTE: Lots of the defined's here are to quiet down the highly overrated perl -w
        #

        # Catch hyperlinks with targets containing no colon
        $_[0] =~ s/(<a\s[^>]*?(?<=\s)href=)(?:(")([^:]*?)([#"])|([^:]*?(?=[#\s>])))/@{[ defined($5) ? "$1$5" : "$1$2$3" ]}@{[ ( (defined($3) && ($3=~m!\?!))||(defined($5) && ($5=~m!\?!)) ) ? "&" : "?" ]}$SESSIONVAR=$sessionId@{[defined($4) ? "$4" : ""]}/goi;

        # Catch hyperlinks with targets that could be returned by getScriptUrl
        $_[0] =~ s/(<a\s[^>]*?(?<=\s)href=)(?:(")((?-i:$myScriptUrlA[^"#]*?))([#"])|((?-i:$myScriptUrlB[^\s#>]*?).*?(?=[#\s>])))/@{[ defined($5) ? "$1$5" : "$1$2$3"]}@{[( (defined($3) && ($3=~m!\?!))||(defined($5) && ($5=~m!\?!)) )? "&" : "?" ]}$SESSIONVAR=$sessionId@{[ defined($4) ? "$4" : ""]}/goi;

        # Catch onclicks that trigger changes of location.href to targets with no colon
        $_[0] =~ s/(<[^>]*?\sonclick=(?:"[^"]*?|)(?=(?:javascript:|))location\.href=)(')([^:]*?)([#'])/$1$2$3@{[ ($3=~m!\?!) ? "&" :"?" ]}$SESSIONVAR=$sessionId$4/goi;

        # Catch onclicks that trigger changes of location.href to targets that could be returned by getScriptUrl
        $_[0] =~ s/(<[^>]*?\sonclick=(?:"[^"]*?|)(?=(?:javascript:|))location\.href=)(')((?-i:$myScriptUrlC[^'#]*?))([#'])/$1$2$3@{[ ($3=~m!\?!) ? "&" : "?" ]}$SESSIONVAR=$sessionId$4/goi;


        # Catch all FORM elements and add a hidden Session ID variable 
        #
        # Only do this if the form is pointing to an internal link. This occurs if there are no
        # colons in its target, if it has no target, or if its target matches a getScriptUrl URL.
        #
        $_[0] =~ s%(<form[^>]*?>)%@{ [ "$1" . ( ( $1 =~ /^<form(?:(?!.*?\saction=).*?>|\s.*?(?<=\s)action=(?:"(?:[^:]*?|(?-i:$myScriptUrlA))"|(?:[^:"\s]*?|(?-i:$myScriptUrlB))(?:\s|>)))/ ) ? "\n<input type=\"hidden\" name=\"$SESSIONVAR\" value=\"$sessionId\" />" : "") ] }%gio;

    }

    # And, finally, the logon stuff
    # this MUST render after TigerSkinPlugin commonTagsHandler does TIGERLOGON
    $_[0] =~ s/%SESSIONLOGON%/&_dispLogon()/geo;
    $_[0] =~ s/%SKINSELECT%/&_skinSelect()/geo;

}

# =========================
sub writeHeaderHandler
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

# This is the ideal solution, but the autoloaded header.al
# file has a hard time being found. This wouldn't be a problem
# on machines where CGI::Session is installed in the standard
# Perl directories or if PERL5LIB was set, but in the default
# TWiki environment where twiki/lib could be the only interesting
# Perl library around, it makes things more complicated.
#    return $session->header();

# So instead we just do exactly what $session->header() does
# internally. (and be sure we set path correctly)
    my $cookie = new CGI::Cookie(-name=>$SESSIONVAR, -value=>$session->id, -path=>"/");
    return $query->header(-cookie=>$cookie);

}

# =========================
sub redirectCgiQueryHandler
{
### my ( $query, $url ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;

    # This handler is called by TWiki::redirect. Use it to overload TWiki's internal redirect.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

    if( $useTransSID && $_[1] !~ m/\?$SESSIONVAR=/ )
    {
        # Work should be done on moving the next part into one big if, then
        # getting rid of this nested if... For a number of odd reasons, 
        # I left things like this. Since it's a redirect, it hopefully
        # shouldn't be used much anyway... So the performance drop should
        # be fairly minimal.

        # If it has no colon in it, it must be an internal URL
        if( $_[1] !~ /:/ )
        {

            # Does it already have CGI parameters passed?
            if( $_[1] =~ m/\?/ )
            {
                my @urlparts = split( $_[1], /\?/, 2 );
                $_[1] = $urlparts[0] . "?$SESSIONVAR=$sessionId&" . $urlparts[1];
            }
            # Does it have any anchors passed?
            elsif( $_[1] =~ m/#/ )
            {
                my @urlparts = split( $_[1], /#/, 2 );
                $_[1] = $urlparts[0] . "?$SESSIONVAR=$sessionId#" . $urlparts[1];
            }
            # Otherwise, we're the first CGI parameter
            else
            {
                $_[1] .= "?$SESSIONVAR=$sessionId";
            }

        }
        # It MAY be an external URL
        else
        {
            # This could be better. This could be integrated into the above...
            # This could use split instead of regex's... 
    
            # Remember our scriptUrl form to match internal URLs that are referred
            # to like external URLs
            my $myScriptUrl = quotemeta(TWiki::Func::getScriptUrl( "XXXX", "YYYY", "ZZZZ" ));
            $myScriptUrl =~ s@XXXX@[^/]*?@g;
            $myScriptUrl =~ s@YYYY@[^#\?/]*@g;
            $myScriptUrl =~ s@ZZZZ@[^/]*?@g;
            #$myScriptUrl =~ s@XXXX@.*?@g;
            #$myScriptUrl =~ s@YYYY@.*?@g;
            #$myScriptUrl =~ s@ZZZZ@.*?@g;

            # If we start with our internal URL....
            if( $_[1] =~ /(^$myScriptUrl)/o )
            {
                # Only ask Perl to do that work once; save what we already have
                my $theScript = $1;

                # Are there other CGI parameters?
                if( $_[1] =~ /(?:^$theScript)(?:\?)(.*)/ )
                {
                    $_[1] = $theScript . '?' . $SESSIONVAR . '=' . $sessionId . '&' . $1; 
                }
                # Are there any anchors?
                elsif( $_[1] =~ /(?:^$theScript)(#.*)/ )
                {
                    $_[1] = $theScript . '?' . $SESSIONVAR . '=' . $sessionId . $1; 
                }
                # Otherwise, we're the first CGI parameter
                else
                {
                    $_[1] = $theScript . '?' . $SESSIONVAR . '=' . $sessionId;
                }
            }
        }
    }

    # This usually won't be important, but just incase they haven't
    # yet received the cookie and happen to be redirecting, be sure
    # they have the cookie. (this is a lot more important with
    # transparent CGI session IDs, because the session DIES when those
    # people go across a redirect without a ?CGISESSID= in it... But
    # EVEN in that case, they should be redirecting to a URL that already
    # *HAS* a sessionID in it... Maybe...) 
    #
    # So this is just a big fact precaution, just like the rest of this
    # whole handler.
    my $cookie = new CGI::Cookie(-name=>$SESSIONVAR, -value=>$session->id, -path=>"/");
    print $_[0]->redirect( -url=>$_[1], -cookie=>$cookie );

    return 1;

}

# =========================
sub getSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;

    # This handler is called by TWiki::getSessionValue. Return the value of a key.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

    return $session->param( $_[0] );

}

# =========================
sub setSessionValueHandler
{
### my ( $key, $value ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;

    # This handler is called by TWiki::setSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

    #
    # We do not allow setting of $authUserSessionVar. That's one session variable
    # that can only be played with by this plugin. Users cannot set it themselves.
    # If they could, it could allow them to circumvent read security.
    #
    if( ( $_[0] ne $authUserSessionVar ) && defined( $session->param( $_[0], $_[1] ) ) )
    {
        return 1;
    }

    return undef;

}

# =========================

sub clearSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::clearSessionValueHandler( $_[0] )" ) if $debug;

    # This handler may one day be called by TWiki::clearSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = 'SOME FUTURE RELEASE'

    #
    # We do not allow clearing of $authUserSessionVar. That's one session variable
    # that can only be played with by this plugin. Users cannot clear it themselves.
    # If they could, it could allow them to be overly annoying.
    #
    if( ( $_[0] ne $authUserSessionVar ) && defined( $session->param( $_[0] ) ) )
    {
        $session->clear( [ $_[0] ] );

        return 1;
    }

    return undef;

}


# ============= "private" member functions

#
# Create static scope for initialization routines. This lets them
# remember if they've been run already.
#
# Also run private initialization scripts which need to run extremely
# early (like the authentication initialization).
#
BEGIN
{

    # These initialization routines are run in initPlugin and
    # initializeUserHandler. 

# =========================

    # Static variables used to prevent multiple runs of a number
    # of initialization routines.
    my $done_init_globals;
    my $done_init_authuser;
    my $done_init_preferences;
    my $done_init_stickskin;
    my $done_init_cgi_set_and_clear_session_variables;

    # Calling this sub forces a run of all initialization
    # routines the next time they are called, regardless 
    # of whether they have been called before.
    #
    # Calling this from initializeUserHandler makes 
    # SpeedyCGI, modperl, etc. start working with this
    # plugin.
    sub _clear_init_function_history
    {

        # Undefine them all to get them back to an initial state
        undef( $done_init_globals );
        undef( $done_init_authuser );
        undef( $done_init_preferences );
        undef( $done_init_stickskin );
        undef( $done_init_cgi_set_and_clear_session_variables );

    } # end sub _clear_init_function_history

# =========================

    # This sets up all globals SessionPlugin needs
    # This includes setting up debug information as well as
    # whether or not to turn on IP_MATCH in CGI::Session
    sub _init_globals
    {
        return 1 if( $done_init_globals );

        $query = TWiki::Func::getCgiQuery();
        return 0 if( ! $query );

        $done_init_globals = 1;

        # The cookie variable name that CGI::Session uses
        #   (i.e. $CGI::Session::NAME)
        $SESSIONVAR = CGI::Session->name();

        return 1;
    
    } # end sub _init_globals

# =========================

    # This ensures user stays authenticated if session indicates
    # that they previously were. 
    #
    # This needs to run extremely early, which is why it is
    # run outside of the init handler (and is protected from
    # running multiple times).
    sub _init_authuser
    {
        return 1 if( $done_init_authuser );
        return 0 if( ! $done_init_globals );   # need globals first
    
        $done_init_authuser = 1;
    
        #
        # Initialize the session (you may wish to change this directory, but /tmp is probably best)
        #
        # Borrowing from the previous version of TWiki, perhaps using:
        #   TWiki::Func::getDataDir() . '/.session'
        # would work well for you. Just be sure to create data/.session and make it
        # writable by the webserver.
        #
        # Another experiment might be to change your serializer. Storable is a good
        # option. See CGI::Session on http://search.cpan.org/ for more information
        # on adding ';initializer:Storable' after the 'driver:File' below (other serializers
        # are available as well).
        #
        #$session = new CGI::Session("driver:File", $query, {Directory=>TWiki::Func::getDataDir . '/.session'});
        $session = new CGI::Session("driver:File", $query, {Directory=>'/tmp'});
    
        # Get the sessionId
        $sessionId = $session->id();
    
        # For added security, every time Apache logs a user in and gives us a remote_user
        # to check, verify that the remote_user we're about to flush to the session file
        # is the same as the remote user already stored in the session file.
        #
        # If there is another valid username stored in the session file, then someone has
        # somehow just borrowed a session ID from someone else. To prevent further havoc,
        # clear this session ID (perhaps in the future it'd be better just to dispatch
        # a new session ID to this user; however, if they already have the session ID
        # of another user, it's probably best to get rid of it since it has been
        # compromised).
        #
        # All these defined's are here to quiet down the highly overrated perl -w.
        #
        $session->clear() if( defined($session) && defined($session->param) && 
                              defined($query) && defined( $query->remote_user() ) &&
                              defined($authUserSessionVar) &&
                              "" ne $query->remote_user() && 
                              "" ne $session->param( $authUserSessionVar ) &&
                              $query->remote_user() ne $session->param( $authUserSessionVar ) );

        # See whether the user was logged in (first webserver, then session, then default)
        $authUser = $query->remote_user() ||
                    $session->param( $authUserSessionVar ) ||
                    TWiki::Func::getDefaultUserName(); 

        $sessionIsAuthenticated = defined( $session->param( $authUserSessionVar ) ) ? 1 : 0;

#        if ( $ENV{'REDIRECT_STATUS'} eq '401' ) {
#	    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::_init_authuser Invalidating session due to 401 status" ) if ($debug);
#	      $session->clear();
#	      $sessionIsAuthenticated = 0;
#	      return 1;
#        }

        # Save the user's information again if they do not appear to be a guest 
        if( TWiki::Func::getDefaultUserName() ne $authUser )
        {
            $session->param( $authUserSessionVar, $authUser ) if defined( $authUserSessionVar );
        }

        return 1;

    } # end of _init_authuser

# =========================

    # This sets up the user-defined preferences from the
    # plugin file. It is called from initPlugin and
    # cannot be run until then.
    sub _init_preferences
    {
        return 1 if( $done_init_preferences );
        return 0 if( ! $done_init_authuser );
        $done_init_preferences = 1;


        # Get plugin debug flag
        $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

        ###
        ### IN THE FUTURE this might be possible . . .
        ### See the note at the top of the script for a description of why
        ### this is not yet easily configurable via SessionPlugin.txt.
        ###
        ### # Get whether or not CGI::Session should do IP_MATCH checking too
        ### $doSessionIpMatching = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DO_SESSION_IP_MATCHING" );
        ###
        ### # This will only allow a session to be used if the IP of the 
        ### # client matches the IP of the client that created the session
        ### $CGI::Session::IP_MATCH = $doSessionIpMatching;

        ###
        ### IN THE MEANWHILE, see what was "hard coded" set up top
        ###
        $doSessionIpMatching = $CGI::Session::IP_MATCH ? 1 : 0;

        ###
        ### IN THE FUTURE this might be possible . . .
        ### See the note at the top of the script for a description of why
        ### this is not yet easily configurable via SessionPlugin.txt.
        ###
        ### # Get what the session variable for the user name should be
        ### $authUserSessionVar = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_AUTHUSER_SESSIONVAR" );
        ### 
 
        ###
        ### IN THE MEANWHILE, use the hard coded "constant" from up top
        ###

        # Get whether or not URLs should have sessions tagged onto the end of them (this turns off if cookies work)
        $useTransSessionId = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_USE_TRANS_SESSIONID" );
    
        # $useTransSID is effective value of whether or not to use
        #   transparent CGI session IDs. If cookies are working, turn
        #   this off. Otherwise, set it to whatever the user set in
        #   $useTransSessionId. Still report to the user though that
        #   %USE_TRANS_SESSIONID% is set to $useTransSessionId
        $useTransSID = $query->cookie( $SESSIONVAR ) ? 0 : $useTransSessionId;
    
        # Get CGI variable to use for sticky skins
        $stickSkinVar = TWiki::Func::getPreferencesValue( "\U$pluginName\E_STICKSKINVAR" ) || "stickskin";
    
        # Get value to set STICKSKINVAR variable to in order to "unstick" skins
        $stickSkinOffValue = TWiki::Func::getPreferencesValue( "\U$pluginName\E_STICKSKINOFFVALUE" ) || "default";
    
        return 1;

    } # end sub _init_preferences

# =========================

    # Sets up SKIN corresponding to requested sticky skin (if any)
    #
    # This can (and MUST) be completed in init right after configuration.
    # That is, it requires values from user configuration to figure out
    # which CGI variable to look at.
    sub _init_stickskin()
    {
        return 1 if $done_init_stickskin;
        return 0 if ! $done_init_globals; # need globals to continue

        $done_init_stickskin = 1;

        # See whether user has decided to set a stickskin
        $stickskin = $query->param( $stickSkinVar );

        # If a stickskin has been selected, save it in the session
        if( $stickskin ) {

            if( $stickSkinOffValue ne $stickskin ) {
                setSessionValueHandler( "SKIN", $stickskin );
            }
            else {
                clearSessionValueHandler( "SKIN" );
                $stickskin = "";
            }

        }
        else
        {
            $stickskin = getSessionValueHandler( "SKIN" ) || "";
        }

        return 1;

    } # end of sub _init_stickskin

# =========================

    # Handles the mangling of session variables specified over CGI.
    # In particular, will set and clear them from CGI.
    #
    # This can be completed any time after the session is setup. It
    # should be called in init though to act before any of the parsing
    # handlers run.
    sub _init_cgi_set_and_clear_session_variables
    {
        return 1 if $done_init_cgi_set_and_clear_session_variables;
        return 0 if ! $done_init_globals; # need globals to continue

        $done_init_cgi_set_and_clear_session_variables = 1;

        # Handle set string
        my $set_sess_var_string = $query->param( "set_session_variable" ); 
        if( defined( $set_sess_var_string ) )
        {
            # Strip trailing and leading spaces
            $set_sess_var_string =~ s/^\s*(.*?)\s*$/$1/;

            # Split up each key-value pair
            foreach( split( /\s*,\s*/, $set_sess_var_string ) )
            {
                # Pick off the key and value
                $_ =~ m/^(.*?)\s*=\s*(.*?)$/;

                # Set the session variable
                setSessionValueHandler( $1, $2 );
            }

        }

        # Handle clear string
        my $clear_sess_var_string = $query->param( "clear_session_variable" ); 
        if( defined( $clear_sess_var_string ) )
        {
            # Strip trailing and leading spaces
            $clear_sess_var_string =~ s/^\s*(.*?)\s*$/$1/;

            # Split up each key
            foreach( split( /\s*,\s*/, $clear_sess_var_string ) )
            {
                # Clear each key
                clearSessionValueHandler( $_ );
            }

        }

        return 1;

    } # end of sub _init_cgi_set_and_clear_session_variables

} # end of initialization's private static scope

# =========================


##### Other private functions (that mainly implement SessionPlugin 1.0 functionality)

# =========================
sub _dispLogon
{
    my $urlToUse = $sessionLogonUrlPath;

    $urlToUse .= ( '?' . $SESSIONVAR . '=' . $sessionId ) if $useTransSID;

    my $logon = "<a class=warning href=\"" .
                $urlToUse .
                "\">Logon</a>";

    return $logon;
}

# =========================
sub _skinSelect
{
    my $html = "<select name=\"$stickSkinVar\">\n";
    my $skins = &TWiki::Func::getPreferencesValue( "SKINS" );
    my $skin = &TWiki::Func::getSkin();
    my @skins = split( /,/, $skins );
    unshift @skins, $stickSkinOffValue;
    foreach my $askin ( @skins ) {
        $askin =~ s/\s//go;
        my $selection = "";
        $selection = "selected" if( $askin eq $skin );
        my $name = $askin;
        $name = "." if( $name eq $stickSkinOffValue );
        $html .= "   <option $selection name=\"$askin\">$askin</option>\n";
    }
    $html .= "</select>\n";
    return $html;
}

# =========================

1;
