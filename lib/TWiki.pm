# Main Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
#
# For licensing info read license.txt file in the TWiki root.
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
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
# - Optionally create a new plugin or customize DefaultPlugin.pm for
#   custom rendering rules.
# - Upgrading TWiki is easy as long as you only customize DefaultPlugin.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log

=begin twiki

---+ TWiki Package
This package stores all TWiki subroutines that haven't been modularized
into any of the others.

=cut

package TWiki;

use strict;

require 5.005;		# For regex objects and internationalisation

# TWiki config variables from TWiki.cfg:
use vars qw(
        $defaultUserName $wikiHomeUrl $defaultUrlHost
        $scriptUrlPath $pubUrlPath $pubDir $templateDir $dataDir $logDir
        $siteWebTopicName $wikiToolName $securityFilter $uploadFilter
        $debugFilename $warningFilename $htpasswdFilename
        $logFilename $remoteUserFilename $wikiUsersTopicname
        $userListFilename $doMapUserToWikiName
        $twikiWebname $mainWebname $mainTopicname $notifyTopicname
        $wikiPrefsTopicname $webPrefsTopicname
        $statisticsTopicname $statsTopViews $statsTopContrib $doDebugStatistics
        $numberOfRevisions $editLockTime $scriptSuffix
        $safeEnvPath $mailProgram $noSpamPadding $mimeTypesFilename
        $doKeepRevIfEditLock $doGetScriptUrlFromCgi $doRemovePortNumber
        $doRemoveImgInMailnotify $doRememberRemoteUser $doPluralToSingular
        $doHidePasswdInRegistration $doSecureInclude
        $doLogTopicView $doLogTopicEdit $doLogTopicSave $doLogRename
        $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff
        $doLogTopicChanges $doLogTopicSearch $doLogRegistration
        $superAdminGroup $doSuperAdminGroup $OS
        $disableAllPlugins $attachAsciiPath $displayTimeValues
        $dispScriptUrlPath $dispViewPath
    );

# Internationalisation (I18N) config from TWiki.cfg:
use vars qw(
	$useLocale $localeRegexes $siteLocale $siteCharsetOverride 
	$upperNational $lowerNational
    );

# TWiki::Store config from TWiki.cfg
use vars qw(
        $rcsDir $rcsArg $nullDev $endRcsCmd $storeTopicImpl $keywordMode
        $storeImpl @storeSettings
    );

# TWiki::Search config from TWiki.cfg
use vars qw(
        $cmdQuote $lsCmd $egrepCmd $fgrepCmd
    );

# Global variables

# Refactoring Note: these are split up by "site" globals and "request"
# globals so that the latter may latter be placed inside a Perl object
# instead of being globals as now.

# ---------------------------
# Site-Wide Global Variables

# Misc. Globals
use vars qw(
            @isoMonth @weekDay $wikiversion
            $TranslationToken $twikiLibDir $formatVersion
            @publicWebList
            %regex
            %staticInternalTags
            %dynamicInternalTags
           );

# Internationalisation (I18N) setup:
use vars qw(
            $siteCharset $useUnicode $siteLang $siteFullLang $urlCharEncoding
           );

# Per-Request "Global" Variables
use vars qw(
            $webName $topicName
            $userName $wikiName $wikiUserName $urlHost
            $debugUserTime $debugSystemTime $script
            $readTopicPermissionFailed $cgiQuery $basicInitDone
            %sessionInternalTags
            %preferencesTags
           );

# Key Global variables
$wikiversion = '20 Oct 2004 $Rev$';
# (new variables must be declared in "use vars qw(..)" above)
@isoMonth = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
@weekDay = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");

# Run-time locale setup - If $useLocale is set, this function parses
# $siteLocale from TWiki.cfg and passes it to the POSIX::setLocale
#  function to change TWiki's operating environment.
#
# SMELL: mod_perl compatibility note: If TWiki is running under Apache,
# won't this play with the Apache process's locale settings too?
# What effects would this have?
#
# Note that 'use locale' must be done in BEGIN block for regexes and sorting to
# work properly, although regexes can still work without this in
# 'non-locale regexes' mode (see _setupRegexes).

sub _setupLocale {
    $siteCharset = 'ISO-8859-1';	# Default values if locale mis-configured
    $siteLang = 'en';
    $siteFullLang = 'en-us';

    if ( $useLocale ) {
        if ( not defined $siteLocale or $siteLocale !~ /[a-z]/i ) {
            die "\$useLocale set but \$siteLocale $siteLocale unset or has no alphabetic characters";
        }
        # Extract the character set from locale and use in HTML templates
        # and HTTP headers
        $siteLocale =~ m/\.([a-z0-9_-]+)$/i;
        $siteCharset = $1 if defined $1;
        $siteCharset =~ s/^utf8$/utf-8/i;	# For convenience, avoid overrides
        $siteCharset =~ s/^eucjp$/euc-jp/i;

        # Override charset - used when locale charset not supported by Perl
        # conversion modules
        $siteCharset = $siteCharsetOverride || $siteCharset;
        $siteCharset = lc $siteCharset;

        # Extract the default site language - ignores '@euro' part of
        # 'fr_BE@euro' type locales.
        $siteLocale =~ m/^([a-z]+)_([a-z]+)/i;
        $siteLang = (lc $1) if defined $1;	# Not including country part
        $siteFullLang = (lc "$1-$2" ) 		# Including country part
          if defined $1 and defined $2;

        # Set environment variables for grep 
        $ENV{'LC_CTYPE'}= $siteLocale;

        # Load POSIX for I18N support. Eval because otherwise
        # it gets compiled even if we don't have a locale
        eval 'require POSIX; import POSIX qw( locale_h LC_CTYPE );';

        # Set new locale
        my $locale = setlocale(&LC_CTYPE, $siteLocale);
    }
    $staticInternalTags{CHARSET} = $siteCharset;
    $staticInternalTags{SHORTLANG} = $siteLang;
    $staticInternalTags{LANG} = $siteFullLang;
}

# Set up pre-compiled regexes for use in rendering.  All regexes with
# unchanging variables in match should use the '/o' option, even if not in a
# loop.
sub _setupRegexes { 
    $regex{linkProtocolPattern} = "(file|ftp|gopher|https|http|irc|news|nntp|telnet)";

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $regex{headerPatternDa} = '^---+(\++|\#+)\s*(.+)\s*$';
    # '   ++ Header', '   + Header'
    $regex{headerPatternSp} = '^\t(\++|\#+)\s*(.+)\s*$';
    # '<h6>Header</h6>
    $regex{headerPatternHt} = '^<h([1-6])>\s*(.+?)\s*</h[1-6]>';
    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # Build up character class components for use in regexes.
    # Depends on locale mode and Perl version, and finally on
    # whether locale-based regexes are turned off.
    my ( $ua, $la, $num, $ma );
    if ( not $useLocale or $] < 5.006 or not $localeRegexes ) {
        # No locales needed/working, or Perl 5.005_03 or lower, so just use
        # any additional national characters defined in TWiki.cfg
        $ua = "A-Z$upperNational";
        $la = "a-z$lowerNational";
        $num = '\d';
        $ma = "$ua$la";
    } else {
        # Perl 5.006 or higher with working locales
        $ua = "[:upper:]";
        $la = "[:lower:]";
        $num = "[:digit:]";
        $ma = "[:alpha:]";
    }
    $regex{upperAlpha} = $ua;
    $regex{lowerAlpha} = $la;
    $regex{numeric} = $num;
    $regex{mixedAlpha} = $ma;

    my $man = "$ma$num";
    $regex{mixedAlphaNum} = $man;
    my $lan = "$la$num";
    $regex{lowerAlphaNum} = $lan;
    my $uan = "$ua$num";
    $regex{upperAlphaNum} = $uan;

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/. 

    # TWiki concept regexes
    $regex{wikiWordRegex} = qr/[$ua]+[$la]+[$ua]+[$man]*/o;
    $regex{webNameRegex} = qr/[$ua]+[$man]*/o;
    $regex{defaultWebNameRegex} = qr/_[${man}_]+/o;
    $regex{anchorRegex} = qr/\#[${man}_]+/o;
    $regex{abbrevRegex} = qr/[$ua]{3,}s?\b/o;

    # Simplistic email regex, e.g. for WebNotify processing - no i18n
    # characters allowed
    $regex{emailAddrRegex} = qr/([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/;

    # Filename regex, for attachments
    $regex{filenameRegex} = qr/[$man\.]+/o;

    # Multi-character alpha-based regexes
    $regex{mixedAlphaNumRegex} = qr/[$man]*/o;

    # Character encoding regexes

    # 7-bit ASCII only
    $regex{validAsciiStringRegex} = qr/^[\x00-\x7F]+$/o;

    # Regex to match only a valid UTF-8 character, taking care to avoid
    # security holes due to overlong encodings by excluding the relevant
    # gaps in UTF-8 encoding space - see 'perldoc perlunicode', Unicode
    # Encodings section.  Tested against Markus Kuhn's UTF-8 test file
    # at http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.
    $regex{validUtf8CharRegex} = qr{
				# Single byte - ASCII
				[\x00-\x7F] 
				|

				# 2 bytes
				[\xC2-\xDF][\x80-\xBF] 
				|

				# 3 bytes

				    # Avoid illegal codepoints - negative lookahead
				    (?!\xEF\xBF[\xBE\xBF])	

				    # Match valid codepoints
				    (?:
					([\xE0][\xA0-\xBF])|
					([\xE1-\xEC\xEE-\xEF][\x80-\xBF])|
					([\xED][\x80-\x9F])
				    )
				    [\x80-\xBF]
				|

				# 4 bytes 
				    (?:
					([\xF0][\x90-\xBF])|
					([\xF1-\xF3][\x80-\xBF])|
					([\xF4][\x80-\x8F])
				    )
				    [\x80-\xBF][\x80-\xBF]
			    }xo;

    $regex{validUtf8StringRegex} =
      qr/^ (?: $regex{validUtf8CharRegex} )+ $/xo;

}

sub _setupHandlerMaps {
    # When processTags matches a tag it looks up the
    # tag in the tables below, and either does a literal
    # expansion or calls the relevant _handle method for
    # the tag.
    %staticInternalTags =
      (
       ENDSECTION      => "",
       HOMETOPIC       => $mainTopicname,
       MAINWEB         => $mainWebname,
       NOTIFYTOPIC     => $notifyTopicname,
       PUBURLPATH      => $pubUrlPath,
       SCRIPTSUFFIX    => $scriptSuffix,
       SCRIPTURLPATH   => $dispScriptUrlPath,
       SECTION         => "",
       STARTINCLUDE    => "",
       STATISTICSTOPIC => $statisticsTopicname,
       STOPINCLUDE     => "",
       TWIKIWEB        => $twikiWebname,
       WEBPREFSTOPIC   => $webPrefsTopicname,
       WIKIHOMEURL     => $wikiHomeUrl,
       WIKIPREFSTOPIC  => $wikiPrefsTopicname,
       WIKITOOLNAME    => $wikiToolName,
       WIKIUSERSTOPIC  => $wikiUsersTopicname,
       WIKIVERSION     => '20 Oct 2004 $Rev$',
      );

    %dynamicInternalTags =
      (
       ATTACHURLPATH     => \&_handleATTACHURLPATH,
       DATE              => \&_handleDATE,
       DISPLAYTIME       => \&_handleDISPLAYTIME,
       ENCODE            => \&_handleENCODE,
       FORMFIELD         => \&_handleFORMFIELD,,
       GMTIME            => \&_handleGMTIME,
       HTTP_HOST         => \&_handleHTTP_HOST,
       ICON              => \&_handleICON,
       INCLUDE           => \&_handleINCLUDE,
       INTURLENCODE      => \&_handleINTURLENCODE,
       METASEARCH        => \&_handleMETASEARCH,
       PLUGINVERSION     => \&_handlePLUGINVERSION,
       RELATIVETOPICPATH => \&_handleRELATIVETOPICPATH,
       REMOTE_ADDR       => \&_handleREMOTE_ADDR,
       REMOTE_PORT       => \&_handleREMOTE_PORT,
       REMOTE_USER       => \&_handleREMOTE_USER,
       REVINFO           => \&_handleREVINFO,
       SEARCH            => \&_handleSEARCH,
       SERVERTIME        => \&_handleSERVERTIME,
       SPACEDTOPIC       => \&_handleSPACEDTOPIC,
       "TMPL:P"          => \&_handleTMPLP,,
       TOPICLIST         => \&_handleTOPICLIST,
       URLENCODE         => \&_handleENCODE,
       URLPARAM          => \&_handleURLPARAM,
       VAR               => \&_handleVAR,
       WEBLIST           => \&_handleWEBLIST,
      );
}

BEGIN {
    # Read the configuration file at compile time in order to set locale
    do "TWiki.cfg";

    if( $useLocale ) {
        eval 'require locale; import locale ();';
    }

    _setupHandlerMaps();
    _setupLocale();
    _setupRegexes();
}

use TWiki::Prefs;     # preferences
use TWiki::Access;    # access control
use TWiki::Store;     # file I/O and rcs related functions
use TWiki::Plugins;   # plugins handler
use TWiki::User;
use TWiki::Render;    # HTML generation
use TWiki::Templates; # TWiki template language

# Other Global variables

# Token character that must not occur in any normal text - converted
# to a flag character if it ever does occur (very unlikely)
$TranslationToken= "\0";	# Null not allowed in charsets used with TWiki

# The following are also initialized in initialize, here for cases where
# initialize not called.
$cgiQuery = 0;
@publicWebList = ();

$debugUserTime   = 0;
$debugSystemTime = 0;

$formatVersion = "1.0";

$basicInitDone = 0;		# basicInitialize not yet done

# Concatenates date, time, and $text to a log file.
# The logfilename can optionally use a %DATE% variable to support
# logs that are rotated once a month.
# | =$log= | Base filename for log file |
# | =$message= | Message to print |
sub _writeReport {
    my ( $log, $message ) = @_;

    if ( $log ) {
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
        my $yearmonth = sprintf( "%.4u%.2u", $year, $mon+1 );
        $log =~ s/%DATE%/$yearmonth/go;

        my( $tmon) = $isoMonth[$mon];
        $year = sprintf( "%.4u", $year + 1900 );
        my $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u",
                            $mday, $year, $hour, $min );

        if( open( FILE, ">>$log" ) ) {
            print FILE "| $time | $message\n";
            close( FILE );
        } else {
            print STDERR "Couldn't write \"$message\" to $log: $!\n";
        }
    }
}

=pod

---++ sub writeLog (  $action, $webTopic, $extra, $user  )

Write the log for an event to the logfile

=cut

sub writeLog
{
    my( $action, $webTopic, $extra, $user ) = @_;

    my $wuserName = $user || $userName;
    $wuserName = TWiki::User::userToWikiName( $wuserName );
    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";
    my $text = "$wuserName | $action | $webTopic | $extra | $remoteAddr |";

    _writeReport( $logFilename, $text );
}

=pod

---++ writeWarning( $text )

Prints date, time, and contents $text to $warningFilename, typically
'warnings.txt'. Use for warnings and errors that may require admin
intervention. Use this for defensive programming warnings (e.g. assertions).

=cut

sub writeWarning {
    _writeReport( $warningFilename, @_ );
}

=pod

---++ writeDebug( $text )

Prints date, time, and contents of $text to $debugFilename, typically
'debug.txt'.  Use for debugging messages.

=cut

sub writeDebug {
    _writeReport( $debugFilename, @_ );
}

=pod

---++ initialize( $pathInfo, $remoteUser, $topic, $url, $query )
Return value: ( $topicName, $webName, $scriptUrlPath, $userName, $dataDir )

Per-web initialization of all aspects of TWiki.  Initializes the
Store, User, Access, and Prefs modules.  Contains two plugin
initialization hooks: 'initialize1' to allow plugins to interact
for authentication, and 'initialize2' once the authenticated username
is available.

Also parses $theTopic to determine whether it's a URI, a "Web.Topic"
pair, a "Web." WebHome shorthand, or just a topic name.  Note that
if $pathInfo is set, this overrides $theTopic.

=cut

sub initialize {
    my ( $thePathInfo, $theRemoteUser, $theTopic, $theUrl, $theQuery ) = @_;

    basicInitialize() unless( $basicInitDone );

    $cgiQuery = $theQuery;

    # Initialise per-session vars here rather than at start of module,
    # so compatible with modPerl
    @publicWebList = ();
    TWiki::Store::initialize();
    TWiki::User::initialize();

    # Make %ENV safer, preventing hijack of the search path
    if( $safeEnvPath ) {
        $ENV{'PATH'} = $safeEnvPath;
    }
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    # initialize lib directory early because of later 'cd's
    getTWikiLibDir();

    # initialize access control
    TWiki::Access::initializeAccess();
    $readTopicPermissionFailed = ""; # Will be set to name(s) of topic(s) that can't be read

    # initialize $webName and $topicName from URL
    $topicName = "";
    $webName   = "";
    if( $theTopic ) {
        if(( $theTopic =~ /^$regex{linkProtocolPattern}\:\/\//o ) && ( $cgiQuery ) ) {
            # redirect to URI
            print $cgiQuery->redirect( $theTopic );
            return; # should never return here
        } elsif( $theTopic =~ /(.*)[\.\/](.*)/ ) {
            # is "bin/script?topic=Webname.SomeTopic"
            $webName   = $1 || "";
            $topicName = $2 || "";
            # jump to WebHome if ""bin/script?topic=Webname."
            $topicName = $mainTopicname if( $webName && ( ! $topicName ) );
        } else {
            # assume "bin/script/Webname?topic=SomeTopic"
            $topicName = $theTopic;
        }
    }

    # Clean up PATH_INFO problems, e.g.  Support.CobaltRaqInstall.  A valid
    # PATH_INFO is '/Main/WebHome', i.e. the text after the script name;
    # invalid PATH_INFO is often a full path starting with '/cgi-bin/...'.
    my $cgiScriptName = $ENV{'SCRIPT_NAME'} || "";
    $thePathInfo =~ s!$cgiScriptName/!/!i;

    # Get the web and topic names from PATH_INFO
    if( $thePathInfo =~ /\/(.*)[\.\/](.*)/ ) {
        # is "bin/script/Webname/SomeTopic" or "bin/script/Webname/"
        $webName   = $1 || "" if( ! $webName );
        $topicName = $2 || "" if( ! $topicName );
    } elsif( $thePathInfo =~ /\/(.*)/ ) {
        # is "bin/script/Webname" or "bin/script/"
        $webName   = $1 || "" if( ! $webName );
    }
    ( $topicName =~ /\.\./ ) && ( $topicName = $mainTopicname );

    # Refuse to work with character sets that allow TWiki syntax
    # to be recognised within multi-byte characters.  Only allow 'oops'
    # page to be displayed (redirect causes this code to be re-executed).
    if ( _invalidSiteCharset() and $theUrl !~ m!$scriptUrlPath/oops! ) {  
        writeWarning( "Cannot use this multi-byte encoding ('$siteCharset') as site character encoding" );
        writeWarning( "Please set a different character encoding in the \$siteLocale setting in TWiki.cfg." );
        my $url = TWiki::getOopsUrl( $webName, $topicName, "oopsbadcharset" );
        print $cgiQuery->redirect( $url );
        return;
    }

    # Convert UTF-8 web and topic name from URL into site charset 
    # if necessary - no effect if URL is not in UTF-8
    ( $webName, $topicName ) = convertUtf8URLtoSiteCharset ( $webName, $topicName );

    # Filter out dangerous or unwanted characters
    $topicName =~ s/$securityFilter//go;
    $topicName =~ /(.*)/;
    $topicName = $1 || $mainTopicname;  # untaint variable
    $webName   =~ s/$securityFilter//go;
    $webName   =~ /(.*)/;
    $webName   = $1 || $mainWebname;  # untaint variable

    # initialize $urlHost and $scriptUrlPath 
    if( ( $theUrl ) && ( $theUrl =~ m!^([^:]*://[^/]*)(.*)/.*$! ) && ( $2 ) ) {
        if( $doGetScriptUrlFromCgi ) {
            $scriptUrlPath = $2;
        }
        $urlHost = $1;
        if( $doRemovePortNumber ) {
            $urlHost =~ s/\:[0-9]+$//;
        }
    } else {
        $urlHost = $defaultUrlHost;
    }

    # initialize preferences, first part for site and web level
    TWiki::Prefs::initializePrefs( $webName );

    if( !$disableAllPlugins ) {
        # Early plugin initialization, allow plugins like SessionPlugin
	    # to set the user.  This must be done before preferences are set,
	    # as we need to get user preferences
        $userName = TWiki::Plugins::initialize1( $topicName, $webName, $theRemoteUser, $theUrl, $thePathInfo );
    }
    $wikiName     = TWiki::User::userToWikiName( $userName, 1 );      # i.e. "JonDoe"
    $wikiUserName = TWiki::User::userToWikiName( $userName );         # i.e. "Main.JonDoe"

    $sessionInternalTags{USERNAME} = $userName;
    $sessionInternalTags{WIKINAME} = $wikiName;
    $sessionInternalTags{WIKIUSERNAME} = $wikiUserName;
    $sessionInternalTags{BASEWEB} = $webName;
    $sessionInternalTags{BASETOPIC} = $topicName;
    $sessionInternalTags{INCLUDINGTOPIC} = $topicName;
    $sessionInternalTags{INCLUDINGWEB} = $webName;
    $sessionInternalTags{ATTACHURL} = "$urlHost%ATTACHURLPATH%";
    $sessionInternalTags{PUBURL} = "$urlHost$pubUrlPath";
    $sessionInternalTags{SCRIPTURL} = "$urlHost$dispScriptUrlPath";

    # initialize preferences, second part for user level
    TWiki::Prefs::initializeUserPrefs( $wikiUserName );

    TWiki::Render::initialize();

    if( !$disableAllPlugins ) {
        # Normal plugin initialization - userName is known and preferences available
        TWiki::Plugins::initialize2( $topicName, $webName, $userName );
    }

    # Assumes all preferences values are set by now, which may well be false!
    # It would be better to get the Prefs module to maintain this
    # hash.
    TWiki::Prefs::loadHash( \%preferencesTags );

    return ( $topicName, $webName, $scriptUrlPath, $userName, $dataDir );
}

=pod

---++ basicInitialize()

Sets up basic stuff - for use from scripts
that require the BEGIN block of this class to be
executed e.g. mailnotify and need regexes or
isWebName/isValidWikiWord to work before the per-web initialize() is called.
Also called from initialize() if not necessary beforehand.

=cut

sub basicInitialize() {
    $basicInitDone = 1;
}

# Return value: boolean $isCharsetInvalid
# Check for unusable multi-byte encodings as site character set
# - anything that enables a single ASCII character such as '[' to be
# matched within a multi-byte character cannot be used for TWiki.
sub _invalidSiteCharset {
    # FIXME: match other problematic multi-byte character sets 
    return ( $siteCharset =~ /^(?:iso-2022-?|hz-?|.*big5|.*shift_?jis|ms.kanji)/i );
}

=pod

---++ convertUtf8URLtoSiteCharset( $webName, $topicName )
Return value: ( string $convertedWebName, string $convertedTopicName)
Auto-detect UTF-8 vs. site charset in URL, and convert UTF-8 into site charset.

TODO: remove dependence on webname and topicname.

=cut

sub convertUtf8URLtoSiteCharset {
    my ( $webName, $topicName ) = @_;

    my $fullTopicName = "$webName.$topicName";
    my $charEncoding;

    # Detect character encoding of the full topic name from URL
    if ( $fullTopicName =~ $regex{validAsciiStringRegex} ) {
        $urlCharEncoding = 'ASCII';
    } elsif ( $fullTopicName =~ $regex{validUtf8StringRegex} ) {
        $urlCharEncoding = 'UTF-8';

        # Convert into ISO-8859-1 if it is the site charset
        if ( $siteCharset =~ /^iso-?8859-?1$/i ) {
            # ISO-8859-1 maps onto first 256 codepoints of Unicode
            # (conversion from 'perldoc perluniintro')
            $fullTopicName =~ s/ ([\xC2\xC3]) ([\x80-\xBF]) / 
              chr( ord($1) << 6 & 0xC0 | ord($2) & 0x3F )
                /egx;
        } elsif ( $siteCharset eq "utf-8" ) {
            # Convert into internal Unicode characters if on Perl 5.8 or higher.
            if( $] >= 5.008 ) {
                require Encode;			# Perl 5.8 or higher only
                $fullTopicName = Encode::decode("utf8", $fullTopicName);	# 'decode' into UTF-8
            } else {
                writeWarning( "UTF-8 not supported on Perl $] - use Perl 5.8 or higher." );
            }
            writeWarning( "UTF-8 not yet supported as site charset - TWiki is likely to have problems" );
        } else {
            # Convert from UTF-8 into some other site charset
            writeDebug( "Converting from UTF-8 to $siteCharset" );

            # Use conversion modules depending on Perl version
            if( $] >= 5.008 ) {
                require Encode;			# Perl 5.8 or higher only
                import Encode qw(:fallbacks);
                # Map $siteCharset into real encoding name
                $charEncoding = Encode::resolve_alias( $siteCharset );
                if( not $charEncoding ) {
                    writeWarning( "Conversion to \$siteCharset '$siteCharset' not supported, or name not recognised - check 'perldoc Encode::Supported'" );
                } else {
                    ##writeDebug "Converting with Encode, valid 'to' encoding is '$charEncoding'";
                    # Convert text using Encode:
                    # - first, convert from UTF8 bytes into internal (UTF-8) characters
                    $fullTopicName = Encode::decode("utf8", $fullTopicName);	
                    # - then convert into site charset from internal UTF-8,
                    # inserting \x{NNNN} for characters that can't be converted
                    $fullTopicName = Encode::encode( $charEncoding, $fullTopicName, &FB_PERLQQ() );
                    ##writeDebug "Encode result is $fullTopicName";
                }
            } else {
                require Unicode::MapUTF8;	# Pre-5.8 Perl versions
                $charEncoding = $siteCharset;
                if( not Unicode::MapUTF8::utf8_supported_charset($charEncoding) ) {
                    writeWarning( "Conversion to \$siteCharset '$siteCharset' not supported, or name not recognised - check 'perldoc Unicode::MapUTF8'" );
                } else {
                    # Convert text
                    ##writeDebug "Converting with Unicode::MapUTF8, valid encoding is '$charEncoding'";
                    $fullTopicName = Unicode::MapUTF8::from_utf8({ 
                                                                  -string => $fullTopicName, 
                                                                  -charset => $charEncoding });
                    # FIXME: Check for failed conversion?
                }
            }
        }
        ($webName, $topicName) = split /\./, $fullTopicName;
    } else {
        # Non-ASCII and non-UTF-8 - assume in site character set, 
        # no conversion required
        $urlCharEncoding = 'Native';
        $charEncoding = $siteCharset;
    }
    ##writeDebug "Final web and topic are $webName $topicName ($urlCharEncoding URL -> $siteCharset)";

    return ($webName, $topicName);
}

=pod

---++ writeHeader ( $query )

Simple header setup for most scripts.  Calls writeHeaderFull, assuming
'basic' type and 'text/html' content-type.

=cut

sub writeHeader {
    my( $query, $contentLength ) = @_;

    # Pass real content-length to make persistent connections work
    # in HTTP/1.1 (performance improvement for browsers and servers)
    $contentLength = 0 unless defined( $contentLength );

    # Just write a basic content-type header for text/html
    writeHeaderFull( $query, 'basic', 'text/html', $contentLength);
}

=pod

---++ writeHeaderFull( $query, $pageType, $contentType, $contentLength )

Builds and outputs HTTP headers.  $pageType should (currently) be either
"edit" or "basic".  $query is the object from the CGI module, not the actual
query string.

"edit" will cause headers to be generated that force caching for 24 hours, to
prevent Codev.BackFromPreviewLosesText bug, which caused data loss with IE5 and
IE6.

"basic" will cause only the Content-Type header to be set (from the
parameter), plus any headers set by plugins.  Hopefully, further types will
be used to improve cacheability for other pages in future.

Implements the post-Dec2001 release plugin API, which requires the
writeHeaderHandler in plugin to return a string of HTTP headers, CR/LF
delimited.  Filters out headers that the core code needs to generate for
whatever reason, and any illegal headers.

=cut

sub writeHeaderFull {
    my( $query, $pageType, $contentType, $contentLength ) = @_;

    # Handle Edit pages - future versions will extend to caching
    # of other types of page, with expiry time driven by page type.
    my( $pluginHeaders, $coreHeaders );


    $contentType .= "; charset=$siteCharset";

    if ($pageType eq 'edit') {
	# Get time now in HTTP header format
	my $lastModifiedString = formatTime(time, '\$http', "gmtime");

	# Expiry time is set high to avoid any data loss.  Each instance of 
	# Edit page has a unique URL with time-string suffix (fix for 
	# RefreshEditPage), so this long expiry time simply means that the 
	# browser Back button always works.  The next Edit on this page 
	# will use another URL and therefore won't use any cached 
	# version of this Edit page.
	my $expireHours = 24;
	my $expireSeconds = $expireHours * 60 * 60;

	# Set content length, to enable HTTP/1.1 persistent connections 
	# (aka HTTP keepalive), and cache control headers, to ensure edit page 
	# is cached until required expiry time.
	$coreHeaders = $query->header(
			    -content_type => $contentType,
			    -content_length => $contentLength,
			    -last_modified => $lastModifiedString,
			    -expires => "+${expireHours}h",
			    -cache_control => "max-age=$expireSeconds",
			 );
    } elsif ($pageType eq 'basic') {
	$coreHeaders = $query->header(
	    		    -content_type => $contentType,
			 );
    } else {
	writeWarning( "Invalid page type in TWiki.pm, writeHeaderFull(): $pageType" );
    }

    # Delete extra CR/LF to allow suffixing more headers
    $coreHeaders =~ s/\r\n\r\n$/\r\n/s;

    # Wiki Plugin Hook - get additional headers from plugin
    $pluginHeaders = TWiki::Plugins::writeHeaderHandler( $query ) || '';

    # Delete any trailing blank line
    $pluginHeaders =~ s/\r\n\r\n$/\r\n/s;

    # Add headers supplied by plugin, omitting any already in core headers
    my $finalHeaders = $coreHeaders;
    if( $pluginHeaders ) {
	# Build hash of all core header names, lower-cased
	my ($headerLine, $headerName, %coreHeaderSeen);
	for $headerLine (split /\r\n/, $coreHeaders) {
	    $headerLine =~ m/^([^ ]+): /i;		# Get header name
	    $headerName = lc($1);
	    $coreHeaderSeen{$headerName}++;
	}
	# Append plugin headers if legal and not seen in core headers
	for $headerLine (split /\r\n/, $pluginHeaders) {
	    $headerLine =~ m/^([^ ]+): /i;		# Get header name
	    $headerName = lc($1);
	    if ( $headerName =~ m/[\-a-z]+/io ) {	# Skip bad headers
		$finalHeaders .= $headerLine . "\r\n"
		    unless $coreHeaderSeen{$headerName};
	    }

	}
    }
    $finalHeaders .= "\r\n" if ( $finalHeaders);

    print $finalHeaders;
}

=pod

---++ getCgiQuery()
Return value: string $query

Returns the CGI query object for the current request. See =perldoc CGI=

=cut

sub getCgiQuery {
    return $cgiQuery;
}

=pod

---++ redirect( $query, $url )

Redirects the request to $url, via the CGI module object $query unless
overridden by a plugin declaring a =redirectCgiQueryHandler=.

=cut

sub redirect {
    my( $query, $url ) = @_;
    if( ! TWiki::Plugins::redirectCgiQueryHandler( $query, $url ) ) {
        print $query->redirect( $url );
    }
}

=pod

---++ isValidWikiWord (  $name  )
Check for a valid WikiWord or WikiName

=cut

sub isValidWikiWord {
    my( $name ) = @_;

    $name ||= "";	# Default value if undef
    return ( $name =~ m/^$regex{wikiWordRegex}$/o )
}

=pod

---++ isValidTopicName (  $name  )
Check for a valid topic name

=cut

sub isValidTopicName {
    my( $name ) = @_;

    return isValidWikiWord( @_ ) || isValidAbbrev( @_ );
}

=pod

---++ isValidAbbrev (  $name  )
Check for a valid ABBREV (acronym)

=cut

sub isValidAbbrev {
    my( $name ) = @_;

    $name ||= "";	# Default value if undef
    return ( $name =~ m/^$regex{abbrevRegex}$/o )
}

=pod

---++ isValidWebName (  $name  )

Check for a valid web name

=cut

sub isValidWebName {
    my( $name ) = @_;

    $name ||= "";	# Default value if undef
    return ( $name =~ m/^$regex{webNameRegex}$/o )
}

=pod

---++ readOnlyMirrorWeb (  $theWeb  )

If this is a mirrored web, return information about the mirror. The info
is returned in a quadruple:
| site name | URL | link | note |

=cut

sub readOnlyMirrorWeb {
    my( $theWeb ) = @_;

    my @mirrorInfo = ( "", "", "", "" );
    if( $siteWebTopicName ) {
        my $mirrorSiteName = TWiki::Prefs::getPreferencesValue( "MIRRORSITENAME", $theWeb );
        if( $mirrorSiteName && $mirrorSiteName ne $siteWebTopicName ) {
            my $mirrorViewURL  = TWiki::Prefs::getPreferencesValue( "MIRRORVIEWURL", $theWeb );
            my $mirrorLink = TWiki::Store::readTemplate( "mirrorlink" );
            $mirrorLink =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorLink =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorLink =~ s/\s*$//g;
            my $mirrorNote = TWiki::Store::readTemplate( "mirrornote" );
            $mirrorNote =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorNote =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorNote = TWiki::Render::getRenderedVersion( $mirrorNote, $theWeb );
            $mirrorNote =~ s/\s*$//g;
            @mirrorInfo = ( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote );
        }
    }
    return @mirrorInfo;
}

=pod

---++ getTWikiLibDir()

If necessary, finds the full path of the directory containing TWiki.pm,
and sets the variable $twikiLibDir so that this process is only performed
once per invocation.  (mod_perl safe: lib dir doesn't change.)

=cut

sub getTWikiLibDir {
    if( $twikiLibDir ) {
        return $twikiLibDir;
    }

    # FIXME: Should just use $INC{"TWiki.pm"} to get path used to load this
    # module.
    my $dir = "";
    foreach $dir ( @INC ) {
        if( -e "$dir/TWiki.pm" ) {
            $twikiLibDir = $dir;
            last;
        }
    }

    # fix path relative to location of called script
    if( $twikiLibDir =~ /^\./ ) {
        writeWarning( "TWiki lib path is relative; you should make it absolute, otherwise some scripts may not run from the command line." );
        my $bin;
        if( $ENV{"SCRIPT_FILENAME"} &&
            $ENV{"SCRIPT_FILENAME"} =~ /^(.+)\/[^\/]+$/ ) {
            # CGI script name
            $bin = $1;
        } elsif ( $0 =~ /^(.*)\/.*?$/ ) {
            # program name
            $bin = $1;
        } else {
            # last ditch; relative to current directory.
            eval 'use Cwd qw( cwd ); $bin = cwd();';
        }
        $twikiLibDir = "$bin/$twikiLibDir/";
        # normalize "/../" and "/./"
        while ( $twikiLibDir =~ s|([\\/])[^\\/]+[\\/]\.\.[\\/]|$1| ) {
        };
        $twikiLibDir =~ s|([\\/])\.[\\/]|$1|g;
    }
    $twikiLibDir =~ s|([\\/])[\\/]*|$1|g; # reduce "//" to "/"
    $twikiLibDir =~ s|[\\/]$||;           # cut trailing "/"

    return $twikiLibDir;
}

=pod

---++ getSkin ()

Get the name of the currently requested skin

=cut

sub getSkin {
    my $skin = "";
    $skin = $cgiQuery->param( 'skin' ) if( $cgiQuery );
    $skin = TWiki::Prefs::getPreferencesValue( "SKIN" ) unless( $skin );
    return $skin;
}

=pod

---++ getViewUrl (  $web, $topic  )

Returns a fully-qualified URL to the specified topic.

=cut

sub getViewUrl {
    my( $theWeb, $theTopic ) = @_;

    $theTopic =~ s/\s*//gs; # Illegal URL, remove space

    return "$urlHost$dispScriptUrlPath$dispViewPath$scriptSuffix/$theWeb/$theTopic";
}

=pod

---++ getScriptURL( $web, $topic, $script )
Return value: $absoluteScriptURL

Returns the absolute URL to a TWiki script, providing the wub and topic as
"path info" parameters.  The result looks something like this:
"http://host/twiki/bin/$script/$web/$topic"

=cut

sub getScriptUrl {
    my( $theWeb, $theTopic, $theScript ) = @_;
    
    my $url = "$urlHost$dispScriptUrlPath/$theScript$scriptSuffix/$theWeb/$theTopic";

    # FIXME consider a plugin call here - useful for certificated logon environment
    
    return $url;
}

=pod

---++ getOopsUrl( $web, $topic, $template, @scriptParams )
Return Value: $absoluteOopsURL

Composes a URL for an "oops" error page.  The last parameters depend on the
specific oops template in use, and are passed in the URL as 'param1..paramN'.

The returned URL ends up looking something like:
"http://host/twiki/bin/oops/$web/$topic?template=$template&param1=$scriptParams[0]..."

=cut

sub getOopsUrl {
    my( $theWeb, $theTopic, $theTemplate,
        $theParam1, $theParam2, $theParam3, $theParam4 ) = @_;
    my $web = $webName;  # current web
    if( $theWeb ) {
        $web = $theWeb;
    }
    my $url = "";
    # $urlHost is needed, see Codev.PageRedirectionNotWorking
    $url = getScriptUrl( $web, $theTopic, "oops" );
    $url .= "\?template=$theTemplate";
    $url .= "\&amp;param1=" . _urlEncode( $theParam1 ) if ( $theParam1 );
    $url .= "\&amp;param2=" . _urlEncode( $theParam2 ) if ( $theParam2 );
    $url .= "\&amp;param3=" . _urlEncode( $theParam3 ) if ( $theParam3 );
    $url .= "\&amp;param4=" . _urlEncode( $theParam4 ) if ( $theParam4 );

    return $url;
}

=pod

---++ normalizeWebTopicName (  $theWeb, $theTopic  )

Normalize a Web.TopicName
<pre>
Input:                      Return:
  ( "Web",  "Topic" )         ( "Web",  "Topic" )
  ( "",     "Topic" )         ( "Main", "Topic" )
  ( "",     "" )              ( "Main", "WebHome" )
  ( "",     "Web/Topic" )     ( "Web",  "Topic" )
  ( "",     "Web.Topic" )     ( "Web",  "Topic" )
  ( "Web1", "Web2.Topic" )    ( "Web2", "Topic" )
</pre>
Note: Function renamed from getWebTopic

=cut

sub normalizeWebTopicName {
   my( $theWeb, $theTopic ) = @_;

   if( $theTopic =~ m|^([^.]+)[\.\/](.*)$| ) {
       $theWeb = $1;
       $theTopic = $2;
   }
   $theWeb = $TWiki::webName unless( $theWeb );
   $theTopic = $TWiki::topicName unless( $theTopic );

   return( $theWeb, $theTopic );
}

=pod

---++ extractParameters (  $str )

Extracts parameters from a variable string and returns a hash with all parameters.
The nameless parameter key is _DEFAULT.

   * Example variable: %TEST{ "nameless" name1="val1" name2="val2" }%
   * First extract text between {...} to get: "nameless" name1="val1" name2="val2"
   * Then call this on the text:
   * =my %params = TWiki::Func::extractParameters( $text );=
   * The hash contains now: <br />
     _DEFAULT => "nameless" <br />
     name1 => "val1" <br />
     name2 => "val2"

=cut

sub extractParameters {
    my( $str ) = @_;

    my %params = ();
    return %params unless defined $str;
    $str =~ s/\\\"/\\$TranslationToken/g;  # escape \"

    if( $str =~ s/^\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/$2/ ) {
        # is: %VAR{ "value" }%
        # or: %VAR{ "value" param="etc" ... }%
        # Note: "value" may contain embedded double quotes
        $params{"_DEFAULT"} = $1 if defined $1;  # distinguish between "" and "0";
        if( $2 ) {
            while( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) {
                $params{"$1"} = $2 if defined $2;
            }
        }
    } elsif( ( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) && ( $1 ) ) {
        # is: %VAR{ name = "value" }%
        $params{"$1"} = $2 if defined $2;
        while( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) {
            $params{"$1"} = $2 if defined $2;
        }
    } elsif( $str =~ s/^\s*(.*?)\s*$// ) {
        # is: %VAR{ value }%
        $params{"_DEFAULT"} = $1 unless $1 eq "";
    }
    return map{ s/\\$TranslationToken/\"/go; $_ } %params;
}

=pod

---++ extractNameValuePair (  $str, $name  )

Extract a named or unnamed value from a variable parameter string
Function extractParameters is more efficient for extracting several parameters
| =$attr= | Attribute string |
| =$name= | Name, optional |
| Return: =$value=   | Extracted value |

=cut

sub extractNameValuePair {
    my( $str, $name ) = @_;

    my $value = "";
    return $value unless( $str );
    $str =~ s/\\\"/\\$TranslationToken/g;  # escape \"

    if( $name ) {
        # format is: %VAR{ ... name = "value" }%
        if( $str =~ /(^|[^\S])$name\s*=\s*\"([^\"]*)\"/ ) {
            $value = $2 if defined $2;  # distinguish between "" and "0"
        }

    } else {
        # test if format: { "value" ... }
        if( $str =~ /(^|\=\s*\"[^\"]*\")\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/ ) {
            # is: %VAR{ "value" }%
            # or: %VAR{ "value" param="etc" ... }%
            # or: %VAR{ ... = "..." "value" ... }%
            # Note: "value" may contain embedded double quotes
            $value = $2 if defined $2;  # distinguish between "" and "0";

        } elsif( ( $str =~ /^\s*\w+\s*=\s*\"([^\"]*)/ ) && ( $1 ) ) {
            # is: %VAR{ name = "value" }%
            # do nothing, is not a standalone var

        } else {
            # format is: %VAR{ value }%
            $value = $str;
        }
    }
    $value =~ s/\\$TranslationToken/\"/go;  # resolve \"
    return $value;
}

sub _fixN {
    my( $theTag ) = @_;
    $theTag =~ s/[\r\n]+//gs;
    return $theTag;
}

# Convert relative URLs to absolute URIs
sub __fixURL {
    my( $theHost, $theAbsPath, $theUrl ) = @_;

    my $url = $theUrl;
    if( $url =~ /^\// ) {
        # fix absolute URL
        $url = "$theHost$url";
    } elsif( $url =~ /^\./ ) {
        # fix relative URL
        $url = "$theHost$theAbsPath/$url";
    } elsif( $url =~ /^$regex{linkProtocolPattern}\:/o ) {
        # full qualified URL, do nothing
    } elsif( $url ) {
        # FIXME: is this test enough to detect relative URLs?
        $url = "$theHost$theAbsPath/$url";
    }

    return $url;
}

sub _fixIncludeLink {
    my( $theWeb, $theLink, $theLabel ) = @_;

    # [[...][...]] link
    if( $theLink =~ /^($regex{webNameRegex}\.|$regex{defaultWebNameRegex}\.|$regex{linkProtocolPattern}\:)/o ) {
        if ( $theLabel ) {
            return "[[$theLink][$theLabel]]";
        } else {
            return "[[$theLink]]";
        }
    } elsif ( $theLabel ) {
        return "[[$theWeb.$theLink][$theLabel]]";
    } else {
        return "[[$theWeb.$theLink][$theLink]]";
    }
}

# Clean-up HTML text so that it can be shown embedded in a topic
sub _cleanupIncludedHTML {
    my( $text, $host, $path ) = @_;

    # FIXME: Make aware of <base> tag

    $text =~ s/^.*?<\/head>//is;            # remove all HEAD
    $text =~ s/<script.*?<\/script>//gis;   # remove all SCRIPTs
    $text =~ s/^.*?<body[^>]*>//is;         # remove all to <BODY>
    $text =~ s/(?:\n)<\/body>//is;          # remove </BODY>
    $text =~ s/(?:\n)<\/html>//is;          # remove </HTML>
    $text =~ s/(<[^>]*>)/&_fixN($1)/ges;     # join tags to one line each
    $text =~ s/(\s(href|src|action)\=[\"\']?)([^\"\'\>\s]*)/$1 . &_fixURL( $host, $path, $3 )/geois;

    return $text;
}

=pod

---++ applyPatternToIncludedText (  $theText, $thePattern )

Apply a pattern on included text to extract a subset

=cut

sub applyPatternToIncludedText {
    my( $theText, $thePattern ) = @_;
    $thePattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/g;  # escape some special chars
    $thePattern =~ /(.*)/;     # untaint
    $thePattern = $1;
    $theText = "" unless( $theText =~ s/$thePattern/$1/is );
    return $theText;
}

sub _handleFORMFIELD {
    return TWiki::Render::renderFormField( @_ );
}

sub _handleTMPLP {
    my $params = shift;
    return TWiki::Templates::expandTemplate( $params->{_DEFAULT} );
}

sub _handleVAR {
    my $params = shift;
    return TWiki::Prefs::getWebVariable( $params->{_DEFAULT} );
}

sub _handlePLUGINVERSION {
    my $params = shift;
    TWiki::Plugins::getPluginVersion( $params->{_DEFAULT} );
}

# Fetch content from a URL for includion by an INCLUDE
sub _includeUrl {
    my( $theUrl, $thePattern, $theWeb, $theTopic ) = @_;
    my $text = "";
    my $host = "";
    my $port = 80;
    my $path = "";
    my $user = "";
    my $pass = "";

    # For speed, read file directly if URL matches an attachment directory
    if( $theUrl =~ /^$urlHost$pubUrlPath\/([^\/\.]+)\/([^\/\.]+)\/([^\/]+)$/ ) {
        my $web = $1;
        my $topic = $2;
        my $fileName = "$pubDir/$web/$topic/$3";
        if( $fileName =~ m/\.(txt|html?)$/i ) {       # FIXME: Check for MIME type, not file suffix
            unless( -e $fileName ) {
                return _inlineError( "Error: File attachment at $theUrl does not exist" );
            }
            if( "$web.$topic" ne "$theWeb.$theTopic" ) {
                # CODE_SMELL: Does not account for not yet authenticated user
                unless( TWiki::Access::checkAccessPermission( "VIEW", $wikiUserName, "", $topic, $web ) ) {
                    return _inlineError( "Error: No permission to view files attached to $web.$topic" );
                }
            }
            $text = TWiki::Store::readFile( $fileName );
            $text = _cleanupIncludedHTML( $text, $urlHost, $pubUrlPath );
            $text = applyPatternToIncludedText( $text, $thePattern ) if( $thePattern );
            return $text;
        }
        # fall through; try to include file over http based on MIME setting
    }

    if( $theUrl =~ /http\:\/\/(.+)\:(.+)\@([^\:]+)\:([0-9]+)(\/.*)/ ) {
        ( $user, $pass, $host, $port, $path ) = ( $1, $2, $3, $4, $5 );
    } elsif( $theUrl =~ /http\:\/\/(.+)\:(.+)\@([^\/]+)(\/.*)/ ) {
        ( $user, $pass, $host, $path ) = ( $1, $2, $3, $4 );
    } elsif( $theUrl =~ /http\:\/\/([^\:]+)\:([0-9]+)(\/.*)/ ) {
        ( $host, $port, $path ) = ( $1, $2, $3 );
    } elsif( $theUrl =~ /http\:\/\/([^\/]+)(\/.*)/ ) {
        ( $host, $path ) = ( $1, $2 );
    } else {
        $text = _inlineError( "Error: Unsupported protocol. (Must be 'http://domain/...')" );
        return $text;
    }

    use TWiki::Net;       # SMTP, get URL

    $text = TWiki::Net::getUrl( $host, $port, $path, $user, $pass );
    $text =~ s/\r\n/\n/gs;
    $text =~ s/\r/\n/gs;
    $text =~ s/^(.*?\n)\n(.*)/$2/s;
    my $httpHeader = $1;
    my $contentType = "";
    if( $httpHeader =~ /content\-type\:\s*([^\n]*)/ois ) {
        $contentType = $1;
    }
    if( $contentType =~ /^text\/html/ ) {
        $path =~ s/(.*)\/.*/$1/; # build path for relative address
        $host = "http://$host";   # build host for absolute address
        if( $port != 80 ) {
            $host .= ":$port";
        }
        $text = _cleanupIncludedHTML( $text, $host, $path );

    } elsif( $contentType =~ /^text\/(plain|css)/ ) {
        # do nothing

    } else {
        $text = _inlineError( "Error: Unsupported content type: $contentType."
              . " (Must be text/html, text/plain or text/css)" );
    }

    $text = applyPatternToIncludedText( $text, $thePattern ) if( $thePattern );

    return $text;
}

# Processes a specific instance %<nop>INCLUDE{...}% syntax.
# Returns the text to be inserted in place of the INCLUDE command.
# $topic and $web should be for the immediate parent topic in the
# include hierarchy. Works for both URLs and absolute server paths.
# 
# \@verbatim is a buffer for storing removed verbatim blocks.
# It is optional.
# 
# \%theProcessedTopics is a hash of topics already %<nop>INCLUDE%'ed.
# These are not allowed to be included again to prevent infinte recursive
# inclusion. It is optional (will be created on demand).
sub _handleINCLUDE {
    my ( $params, $theTopic, $theWeb, $verbatim, $theProcessedTopics ) = @_;

    my $incfile = $params->{_DEFAULT} || "";
    my $pattern = $params->{pattern};
    my $rev     = $params->{rev};
    my $warn    = $params->{warn};

    if( $incfile =~ /^http\:/ ) {
        # include web page
        return _includeUrl( $incfile, $pattern, $theWeb, $theTopic );
    }

    $theProcessedTopics = {} unless $theProcessedTopics;

    $incfile =~ s/$securityFilter//go;    # zap anything suspicious
    if( $doSecureInclude ) {
        # Filter out ".." from filename, this is to
        # prevent includes of "../../file"
        $incfile =~ s/\.+/\./g;
    } else {
        # danger, could include .htpasswd with relative path
        $incfile =~ s/passwd//gi;    # filter out passwd filename
    }

    my $text = "";
    my $meta = "";
    my $isTopic = 0;

    # test for different topic name and file name patterns
    my $fileName = "";
    TRY: {
        # check for topic
        $fileName = "$dataDir/$theWeb/$incfile.txt";      # TopicName
        last TRY if( -e $fileName );
        my $incwebfile = $incfile;
        $incwebfile =~ s/\.([^\.]*)$/\/$1/;
        $fileName = "$dataDir/$incwebfile.txt";           # Web.TopicName
        last TRY if( -e $fileName );
        $fileName = "$dataDir/$theWeb/$incfile";          # TopicName.txt
        last TRY if( -e $fileName );
        $fileName = "$dataDir/$incfile";                  # Web/TopicName.txt
        last TRY if( -e $fileName );

        # give up, file not found
        $warn = TWiki::Prefs::getPreferencesValue( "INCLUDEWARNING" ) unless( $warn );
        if( $warn =~ /^on$/i ) {
            return _inlineError( "Warning: Can't INCLUDE <nop>$incfile, topic not found" );
        } elsif( $warn && $warn !~ /^(off|no)$/i ) {
            $incfile =~ s/\//\./go;
            $warn =~ s/\$topic/$incfile/go;
            return $warn;
        } # else fail silently
        return "";
    }

    # prevent recursive loop
    if( $theProcessedTopics->{$fileName} ) {
        # file already included
        if( $warn || TWiki::Prefs::getPreferencesFlag( "INCLUDEWARNING" ) ) {
            unless( $warn =~ /^(off|no)$/i ) {
                return _inlineError( "Warning: Can't INCLUDE <nop>$incfile twice, topic is already included" );
            }
        }
        return "";
    } else {
        # remember for next time
        $theProcessedTopics->{$fileName} = 1;
    }

    # set include web/filenames and current web/filenames
    $sessionInternalTags{INCLUDINGWEB} = $theWeb;
    $sessionInternalTags{INCLUDINGTOPIC} = $theTopic;
    if( $fileName =~ s/\/([^\/]*)\/([^\/]*)\.txt$/$1/ ) {
        # identified "/Web/TopicName.txt" filename, e.g. a Wiki topic
        # so save the current web and topic name
        $theWeb = $1;
        $theTopic = $2;
        $isTopic = 1;

        if( $rev ) {
            $rev = "1.$rev" unless( $rev =~ /^1\./ );
            ( $meta, $text ) = TWiki::Store::readTopicVersion( $theWeb, $theTopic, $rev );
        } else {
            ( $meta, $text ) = TWiki::Store::readTopic( $theWeb, $theTopic );
        }
        # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
        $text =~ s/.*?%STARTINCLUDE%//s;
        $text =~ s/%STOPINCLUDE%.*//s;

    } # else is a file with relative path, e.g. $dataDir/../../path/to/non-twiki/file.ext

    $text = applyPatternToIncludedText( $text, $pattern ) if( $pattern );

    # handle all preferences and internal tags
    $text = TWiki::Render::takeOutBlocks( $text, "verbatim", $verbatim );

    # Escape rendering: Change " !%VARIABLE%" to " %<nop>VARIABLE%", for final " %VARIABLE%" output
    $text =~ s/(\s)\!\%([A-Z])/$1%<nop>$2/g;

    processTags( \$text, $theTopic, $theWeb,
                        $verbatim, $theProcessedTopics );

    # 4th parameter tells plugin that its called from an include
    TWiki::Plugins::commonTagsHandler( $text, $theTopic, $theWeb, 1 );

    # If needed, fix all "TopicNames" to "Web.TopicNames" to get the
    # right context
    # SMELL: This is a hack.
    if( ( $isTopic ) && ( $theWeb ne $webName ) ) {
        # "TopicName" to "Web.TopicName"
        $text =~ s/(^|[\s\(])($regex{webNameRegex}\.$regex{wikiWordRegex})/$1$TranslationToken$2/go;
        $text =~ s/(^|[\s\(])($regex{wikiWordRegex})/$1$theWeb\.$2/go;
        $text =~ s/(^|[\s\(])$TranslationToken/$1/go;
        # "[[TopicName]]" to "[[Web.TopicName][TopicName]]"
        $text =~ s/\[\[([^\]]+)\]\]/&_fixIncludeLink( $theWeb, $1 )/geo;
        # "[[TopicName][...]]" to "[[Web.TopicName][...]]"
        $text =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&_fixIncludeLink( $theWeb, $1, $2 )/geo;
        # FIXME: Support for <noautolink>
    }

    # handle tags again because of plugin hook
    processTags( \$text, $theTopic, $theWeb,
                        $verbatim, $theProcessedTopics );

    $text =~ s/^\n+/\n/;
    $text =~ s/\n+$/\n/;

    # FIXME What about attachments?

    return $text;
}

sub _handleHTTP_HOST {
    return $ENV{HTTP_HOST};
}

sub _handleREMOTE_ADDR {
    return $ENV{REMOTE_ADDR};
}

sub _handleREMOTE_PORT {
    return $ENV{REMOTE_PORT};
}

sub _handleREMOTE_USER {
    return $ENV{REMOTE_USER};
}

# Only does simple search for topicmoved at present, can be expanded when required
# SMELL: this violates encapsulation of Store and Meta, by exporting
# the assumption that meta-data is stored embedded inside topic
# text.
sub _handleMETASEARCH {
    my $params = shift;
    my $attrWeb           = $params->{web} || "";
    my $attrTopic         = $params->{topic} || "";
    my $attrType          = $params->{type};
    my $attrTitle         = $params->{title} || "";
    my $attrDefault       = $params->{default} || "";

    my $searchVal = "XXX";

    if( ! $attrType ) {
       $attrType = "";
    }

    my $searchWeb = "all";

    if( $attrType eq "topicmoved" ) {
       $searchVal = "%META:TOPICMOVED[{].*from=\\\"$attrWeb\.$attrTopic\\\".*[}]%";
    } elsif ( $attrType eq "parent" ) {
       $searchWeb = $attrWeb;
       $searchVal = "%META:TOPICPARENT[{].*name=\\\"($attrWeb\\.)?$attrTopic\\\".*[}]%";
    }

    use TWiki::Search;    # search engine

    my $text = TWiki::Search::searchWeb(
        #"_callback"    => undef,
        "search"        => $searchVal,
        "web"           => $searchWeb,
        "type"          => "regex",
        "nosummary"     => "on",
        "nosearch"      => "on",
        "noheader"      => "on",
        "nototal"       => "on",
        "noempty"       => "on",
        "template"      => "searchmeta",
    );

    if( $text =~ /^\s*$/ ) {
       $text = "$attrTitle$attrDefault";
    } else {
       $text = "$attrTitle$text";
    }
    return $text;
}

# Deprecated, but used in signatures
sub _handleDATE {
    return formatTime(time(), "\$day \$mon \$year", "gmtime");
}

sub _handleGMTIME {
    my $params = shift;
    return formatTime( time(), $params->{_DEFAULT} || "", "gmtime" );
}

sub _handleSERVERTIME {
    my $params = shift;
    return formatTime( time(), $params->{_DEFAULT} || "", "servertime" );
}

sub _handleDISPLAYTIME {
    my $params = shift;
    return formatTime( time(), $params->{_DEFAULT} || "", $displayTimeValues );
}

=pod

---++ formatTime ($epochSeconds, $formatString, $outputTimeZone) ==> $value
| $epochSeconds | epochSecs GMT |
| $formatString | twiki time date format |
| $outputTimeZone | timezone to display. (not sure this will work)(gmtime or servertime) |

=cut
sub formatTime  {
    my ($epochSeconds, $formatString, $outputTimeZone) = @_;
    my $value = $epochSeconds;

    # use default TWiki format "31 Dec 1999 - 23:59" unless specified
    $formatString = "\$day \$month \$year - \$hour:\$min" unless( $formatString );
    $outputTimeZone = $displayTimeValues unless( $outputTimeZone );

    my( $sec, $min, $hour, $day, $mon, $year, $wday) = gmtime( $epochSeconds );
      ( $sec, $min, $hour, $day, $mon, $year, $wday ) = localtime( $epochSeconds ) if( $outputTimeZone eq "servertime" );

    #standard twiki date time formats
    if( $formatString =~ /rcs/i ) {
        # RCS format, example: "2001/12/31 23:59:59"
        $formatString = "\$year/\$mo/\$day \$hour:\$min:\$sec";
    } elsif ( $formatString =~ /http|email/i ) {
        # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
 	    # - based on RFC 2616/1123 and HTTP::Date; also used
        # by TWiki::Net for Date header in emails.
        $formatString = "\$wday, \$day \$month \$year \$hour:\$min:\$sec \$tz";
    } elsif ( $formatString =~ /iso/i ) {
        # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
        # e.g. "2002-12-31T19:30Z"
        $formatString = "\$year-\$mo-\$dayT\$hour:\$min";
        if( $outputTimeZone eq "gmtime" ) {
            $formatString = $formatString."Z";
        } else {
            #TODO:            $formatString = $formatString.  # TZD  = time zone designator (Z or +hh:mm or -hh:mm) 
        }
    }

    $value = $formatString;
    $value =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
    $value =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
    $value =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
    $value =~ s/\$day/sprintf("%.2u",$day)/geoi;
    my @weekDay = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    $value =~ s/\$wday/$weekDay[$wday]/geoi;
    $value =~ s/\$mon[t]?[h]?/$isoMonth[$mon]/goi;
    $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
    $value =~ s/\$yea[r]?/sprintf("%.4u",$year+1900)/geoi;
    $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;

#TODO: how do we get the different timezone strings (and when we add usertime, then what?)
    my $tz_str = "GMT";
    $tz_str = "Local" if ( $outputTimeZone eq "servertime" );
    $value =~ s/\$tz/$tz_str/geoi;

    return $value;
}

#| $web | web and  |
#| $topic | topic to display the name for |
#| $formatString | twiki format string (like in search) |
sub _handleREVINFO {
    my ( $params, $theTopic, $theWeb ) = @_;

    my $format = $params->{_DEFAULT} || $params->{format}
                 || "r1.\$rev - \$date - \$wikiusername";
    my $web    = $params->{web} || $theWeb;
    my $topic  = $params->{topic} || $theTopic;
    my $cgiQuery = getCgiQuery();
    my $cgiRev = "";
    $cgiRev = $cgiQuery->param('rev') if( $cgiQuery );
    my $revnum = $cgiRev || $params->{rev} || "";

    $revnum =~ s/r?1\.//; # cut "r" and major

    my( $date, $user, $rev, $comment ) =
      TWiki::Store::getRevisionInfo( $web, $topic, $revnum );
    my $wikiName     = TWiki::User::userToWikiName( $user, 1 );
    my $wikiUserName = TWiki::User::userToWikiName( $user );

    my $value = $format;
    $value =~ s/\$web/$web/goi;
    $value =~ s/\$topic/$topic/goi;
    $value =~ s/\$rev/$rev/goi;
    $value =~ s/\$date/&formatTime($date)/geoi;
    $value =~ s/\$comment/$comment/goi;
    $value =~ s/\$username/$user/goi;
    $value =~ s/\$wikiname/$wikiName/goi;
    $value =~ s/\$wikiusername/$wikiUserName/goi;

    return $value;
}

sub _handleENCODE {
    my $params = shift;

    my $type = $params->{type};
    my $text = $params->{_DEFAULT} || "";
    if ( $type && $type =~ /^entit(y|ies)$/i ) {
        return entityEncode( $text );
    } else {
        return _urlEncode( $text );
    }
}

sub _handleSEARCH {
    my ( $params, $theTopic, $theWeb ) = @_;

    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{inline} = 1;
    $params->{baseweb} = $theTopic;
    $params->{basetopic} = $theWeb;
    $params->{search} = $params->{_DEFAULT} if( $params->{_DEFAULT} );
    $params->{type} = TWiki::Prefs::getPreferencesValue( "SEARCHVARDEFAULTTYPE" ) unless( $params->{type} );

    use TWiki::Search;    # search engine

    return TWiki::Search::searchWeb( %$params );
}

# Format an error for inline inclusion in HTML
sub _inlineError {
    my( $errormessage ) = @_;
    return "<font size=\"-1\" class=\"twikiAlert\" color=\"red\">$errormessage</font>" ;
}

=pod

---++ getPublicWebList ()
Return public web list, i.e. exclude hidden webs, but include current web

=cut

sub getPublicWebList {
    if( ! @publicWebList ) {
        my @list = TWiki::Store::getAllWebs();
        my $item = "";
        my $hidden = "";
        foreach $item ( @list ) {
            $hidden = TWiki::Prefs::getPreferencesValue( "NOSEARCHALL", $item );
            if( ( $item eq $TWiki::webName  ) || ( ( ! $hidden ) && ( $item =~ /^[^\.\_]/ ) ) ) {
                push( @publicWebList, $item );
            }
        }
    }
    return @publicWebList;
}

=pod

---++ expandVariablesOnTopicCreation ( $theText, $theUser, $theWikiName, $theWikiUserName )
Expand limited set of variables during topic creation. These are variables
expected in templates that must be statically expanded in new content.

The expanded variables are:
| =%DATE%= | Signature-format date |
| =%USERNAME%= | Base login name |
| =%WIKINAME%= | Wiki name |
| =%WIKIUSERNAME%= | Wiki name with prepended web |
| =%URLPARAM%= | Parameters to the current CGI query |
| =%NOP%= | No-op |

=cut

sub expandVariablesOnTopicCreation {
  my ( $theText, $theUser, $theWikiName, $theWikiUserName ) = @_;

  $theUser = $userName unless $theUser;
  $theWikiName = TWiki::User::userToWikiName( $theUser, 1 )
    unless $theWikiName;
  $theWikiUserName = TWiki::User::userToWikiName( $theUser )
    unless $theWikiUserName;

  $theText =~ s/%DATE%/&_handleDATE()/ge;
  $theText =~ s/%USERNAME%/$theUser/go;               # "jdoe"
  $theText =~ s/%WIKINAME%/$theWikiName/go;           # "JonDoe"
  $theText =~ s/%WIKIUSERNAME%/$theWikiUserName/go; # "Main.JonDoe"
  $theText =~ s/%URLPARAM{(.*?)}%/&_handleURLPARAM(\%{extractParameters($1)})/geo;
  # Remove filler: Use it to remove access control at time of
  # topic instantiation or to prevent search from hitting a template
  # SMELL: this expansion of %NOP{}% is different to the default
  # which retains content.....
  $theText =~ s/%NOP{.*?}%//gos;
  $theText =~ s/%NOP%//go;

  return $theText;
}

sub _handleWEBLIST {
    return _webOrTopicList( 1, @_ );
}

sub _handleTOPICLIST {
    return _webOrTopicList( 0, @_ );
}

sub _webOrTopicList {
    my( $isWeb, $params ) = @_;

    my $format = $params->{_DEFAULT} || $params->{format};
    $format .= '$name' unless( $format =~ /\$name/ );
    my $separator = $params->{separator} || "\n";
    my $web = $params->{web} || "";
    my $webs = $params->{webs} || "public";
    my $selection = $params->{selection} || "";
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker    = $params->{marker} || 'selected="selected"';

    my @list = ();
    if( $isWeb ) {
        my @webslist = split( /,\s?/, $webs );
        foreach my $aweb ( @webslist ) {
            if( $aweb eq "public" ) {
                push( @list, getPublicWebList() );
            } elsif( $aweb eq "webtemplate" ) {
                push( @list, grep { /^\_/o } TWiki::Store::getAllWebs() );
            } else{
                push( @list, $aweb ) if( TWiki::Store::webExists( $aweb ) );
            }
        }
    } else {
        $web = $webName if( ! $web );
        my $hidden = TWiki::Prefs::getPreferencesValue( "NOSEARCHALL", $web );
        if( ( $web eq $TWiki::webName  ) || ( ! $hidden ) ) {
            @list = TWiki::Store::getTopicNames( $web );
        }
    }
    my $text = "";
    my $item = "";
    my $line = "";
    my $mark = "";
    foreach $item ( @list ) {
        $line = $format;
        $line =~ s/\$web/$web/goi;
        $line =~ s/\$name/$item/goi;
        $line =~ s/\$qname/"$item"/goi;
        $mark = ( $selection =~ / \Q$item\E / ) ? $marker : "";
        $line =~ s/\$marker/$mark/goi;
        $text .= "$line$separator";
    }
    $text =~ s/$separator$//s;  # remove last separator
    return $text;
}

sub _handleURLPARAM {
    my $params = shift;

    my $param     = $params->{_DEFAULT} || "";
    my $newLine   = $params->{newline} || "";
    my $encode    = $params->{encode};
    my $multiple  = $params->{multiple};
    my $separator = $params->{separator} || "\n";

    my $value = "";
    if( $cgiQuery ) {
        if( $multiple ) {
            my @valueArray = $cgiQuery->param( $param );
            if( @valueArray ) {
                unless( $multiple =~ m/^on$/i ) {
                    my $item = "";
                    @valueArray = map {
                        $item = $_;
                        $_ = $multiple;
                        $_ .= $item unless( s/\$item/$item/go );
                        $_
                    } @valueArray;
                }
                $value = join ( $separator, @valueArray );
            }
        } else {
            $value = $cgiQuery->param( $param );
            $value = "" unless( defined $value );
        }
    }
    $value =~ s/\r?\n/$newLine/go if( $newLine );
    if ( $encode && $encode =~ /^entit(y|ies)$/ ) {
        $value = entityEncode( $value );
    } else {
        $value = _urlEncode( $value );
    }
    unless( $value ) {
        $value = $params->{default} || "";
    }
    return $value;
}

=pod

---++ entityEncode (text )
| =$text= | Text to encode |
Escape certain characters to HTML entities

=cut

sub entityEncode {
    my $text = shift;

    # HTML entity encoding
    $text =~ s/([\"\%\*\_\=\[\]\<\>\|])/"\&\#".ord( $1 ).";"/ge;
    return $text;
}

# Generate a $w-char hexidecimal number representing $n.
# Default $w is 2 (one byte)
sub _hexchar {
    my( $n, $w ) = @_;
    $w = 2 unless $w;
    return sprintf( "%0${w}x", ord( $n ));
}

# Encode to URL parameter
# TODO: For non-ISO-8859-1 $siteCharset, need to convert to
# UTF-8 before URL encoding.
# | =$text= | Text to encode |
# SMELL: what is the relationship to nativeUrlEncode??
sub _urlEncode {
    my $text = shift;

    # URL encoding
    $text =~ s/[\n\r]/\%3Cbr\%20\%2F\%3E/g;
    $text =~ s/\s/\%20/g;
    $text =~ s/(["&+<>\\])/"%"._hexchar($1,2)/ge;
    # Encode characters > 0x7F (ASCII-derived charsets only)
	# TODO: Encode to UTF-8 first
    $text =~ s/([\x7f-\xff])/'%' . unpack( "H*", $1 ) /ge;

    return $text;
}

=pod

---++ nativeUrlEncode ( $theStr, $doExtract )
Perform URL encoding into native charset ($siteCharset) - for use when
viewing attachments via browsers that generate UTF-8 URLs, on sites running
with non-UTF-8 (Native) character sets.  Aim is to prevent UTF-8 URL
encoding.  For mainframes, we assume that UTF-8 URLs will be translated
by the web server to an EBCDIC character set.

SMELL: why is this different to _urlEncode?

=cut

sub nativeUrlEncode {
    my $theStr = shift;

    my $isEbcdic = ( 'A' eq chr(193) ); 	# True if Perl is using EBCDIC

    if( $siteCharset eq "utf-8" or $isEbcdic ) {
        # Just strip double quotes, no URL encoding - let browser encode to
        # UTF-8 or EBCDIC based $siteCharset as appropriate
        $theStr =~ s/^"(.*)"$/$1/;	
        return $theStr;
    } else {
        return _urlEncode( $theStr );
    }
}

# This routine was introduced to URL encode Mozilla UTF-8 POST URLs in the
# TWiki Feb2003 release - encoding is no longer needed since UTF-URLs are now
# directly supported, but it is provided for backward compatibility with
# skins that may still be using the deprecated %INTURLENCODE%.
sub _handleINTURLENCODE {
    my $params = shift;
    # Just strip double quotes, no URL encoding - Mozilla UTF-8 URLs
    # directly supported now
    return $params->{_DEFAULT} || "";
}

=pod

---++ sub searchableTopic (  $topic  )

Space out the topic name for a search, by inserting " *" at
the start of each component word.

=cut

sub searchableTopic
{
    my( $topic ) = @_;
    # FindMe -> Find\s*Me
    $topic =~ s/([$regex{lowerAlpha}]+)([$regex{upperAlpha}$regex{numeric}]+)/$1%20*$2/go;   # "%20*" is " *" - I18N: only in ASCII-derived charsets
    return $topic;
}

sub _handleSPACEDTOPIC {
    my ( $params, $theTopic ) = @_;

    return _urlEncode( searchableTopic( $theTopic ));
}

sub _handleICON {
    my $params = shift;

    my $theParam = $params->{_DEFAULT};

    my $value = TWiki::Render::filenameToIcon( "file.$theParam" );
    return $value;
}

sub _handleRELATIVETOPICPATH {
    my ( $params, $theTopic, $theWeb ) = @_;

    my $theStyleTopic = $params->{_DEFAULT} || "";

    return "" unless $theStyleTopic;

    my $theRelativePath;
    # if there is no dot in $theStyleTopic, no web has been specified
    if ( index( $theStyleTopic, "." ) == -1 ) {
        # add local web
        $theRelativePath = $theWeb . "/" . $theStyleTopic;
    } else {
        $theRelativePath = $theStyleTopic; #including dot
    }
    # replace dot by slash is not necessary; TWiki.MyTopic is a valid url
    # add ../ if not already present to make a relative file reference
    if ( index( $theRelativePath, "../" ) == -1 ) {
        $theRelativePath = "../" . $theRelativePath;
    }
    return $theRelativePath;
}

sub _handleATTACHURLPATH {
    my ( $params, $theTopic, $theWeb ) = @_;

    return nativeUrlEncode( "$pubUrlPath/$theWeb/$theTopic" );
}

=pod

---++ processTags( \$text, $topic, $web, $verb, $incs )
Expands variables by replacing the variables with their
values. Some example variables: %<nop>TOPIC%, %<nop>SCRIPTURL%,
%<nop>WIKINAME%, etc.

$web and $incs are passed in for recursive include expansion. They can
safely be undef.

The rules for tag expansion are:
   1 Tags are expanded left to right, in the order they are encountered.
   1 Tags are recursively expanded as soon as they are encountered - the algorithm is inherently single-pass
   1 A tag is not ""encountered" until the matching }% has been seen, by which time all tags in parameters will have been expanded
   1 Tag expansions that create new tags recursively are limited to a set number of hierarchical levels of expansion

Formerly known as handleInternalTags, but renamed when it was rewritten
because the old name clashes with the namespace of handlers.

=cut

sub processTags {
    my $text = shift; # reference
    my ( $topic, $web ) = @_;

    my $memTopic = $sessionInternalTags{TOPIC};
    my $memWeb = $sessionInternalTags{WEB};
    my $memEurl = $sessionInternalTags{EDITURL};

    $sessionInternalTags{TOPIC} = $topic;
    $sessionInternalTags{WEB} = $web;
    # Make Edit URL unique - fix for RefreshEditPage.
    $sessionInternalTags{EDITURL} =
      "$dispScriptUrlPath/edit$scriptSuffix/$web/$topic\?t=" . time();

    # SMELL: why is this done every time, and not statically during
    # template loading?
    $$text =~ s/%NOP{(.*?)}%/$1/gs;  # remove NOP tag in template topics but show content
    $$text =~ s/%NOP%/<nop>/g;
    my $sep = TWiki::Templates::expandTemplate('"sep"');
    $$text =~ s/%SEP%/$sep/g;

    # NOTE TO DEBUGGERS
    # The depth parameter in the following call controls the maximum number
    # of levels of expansion. If it is set to 1 then only tags in the
    # topic will be expanded; tags that they in turn generate will be
    # left unexpanded. If it is set to 2 then the expansion will stop after
    # the first recursive inclusion, and so on. This is incredible useful
    # when debugging The default is set to 16
    # to match the original limit on search expansion, though this of
    # course applies to _all_ tags and not just search.
    $$text = _processTags( $$text, 16, "", @_ );

    $sessionInternalTags{TOPIC} = $memTopic;
    $sessionInternalTags{WEB} = $memWeb;
    $sessionInternalTags{EDITURL} = $memEurl;
}

# Process TWiki %TAGS{}% by parsing the input tokenised into
# % separated sections. The parser is a simple stack-based parse,
# sufficient to ensure nesting of tags is correct, but no more
# than that.
# $depth limits the number of recursive expansion steps that
# can be performed on expanded tags.
sub _processTags {
    my $text = shift;

    return "" unless defined( $text );

    my $depth = shift;
    my $expanding = shift;

    # my( $topic, $web, $verbatim, $processedTopics ) = @_;

    unless ( $depth ) {
        my $mess = "Max recursive depth reached: $expanding";
        writeWarning( $mess );
        return $text;
        #return _inlineError( $mess );
    }

    my @queue = split( /%/, $text );
    my $sep = "";
    my @stack;
    #my $tell = 0;
    push( @stack, "" );
    foreach my $token ( @queue ) {
        #print  "PROCESSING $token \n" if $tell;
        my $close = 0;

        if ( $sep && $token =~ /^[A-Z][A-Z0-9_:]*{/ ) {
            # a parameterised tag; push a new context
            #print  "PUSHING $token\n" if $tell;
            push( @stack, $token );
            $close = ( $token =~ /}$/ );
        } elsif ( $sep && $token =~ /^[A-Z][A-Z0-9_:]*$/ ) {
            #print  "PUSHING $token\n" if $tell;
            push( @stack, $token ); # push a new context
            $close = 1;
        } else {
            #print  "ADDING $sep$token\n" if $tell;
            $stack[$#stack] .= "$sep$token";
            $sep = "%";
            $close = ( $#stack && $token =~ /}$/ );
        }

        if ( $close) {
            # close of a tag. Pop the context.
            my $expr = pop( @stack );
            my ( $tag, $args );
            if( $expr =~ /^(.*?)\{(.*)\}$/s ) {
                ( $tag, $args) = ( $1, $2 );
            } else {
                ( $tag, $args ) = ( $expr, undef );
            }
            my ( $ok, $e ) = _handleTag( $expr, $tag, $args, @_ );
            if ( $ok ) {
                # recursively expand what we just got
                $e = _processTags( $e, $depth - 1,
                                   "$expanding:$depth/$tag", @_ );
                #print  "EXPANDED $tag -> $e\n" if $tell;
                # no sep between this and the next token;
                # we just ate it.
                $sep = "";
            } else {
                #print  "EXPANSION OF $tag\{$expr\} FAILED\n" if $tell;
                $e = "%$expr";
            }
            $stack[$#stack] .= $e;
        }
    }

    # Run out of input. Close open tags.
    while ( $#stack ) {
        my $expr = pop( @stack );
        writeWarning( "Unclosed tag $expr...");
        $stack[$#stack] .= "%$expr";
    }

    return pop( @stack );
}

# Handle expansion of 'constant' tags (as against preference tags)
# $eref is a reference to the flag that records the number of
# successful expansions on a single pass through the text
# $result is (initially) the whole tag expression
# $tag is the tag part
# $args is the bit in the {} (if there are any)
sub _handleTag {
    my $result = shift; # whole expression
    my $tag = shift;    # tag subexpression
    my $args = shift;
    # my( $topic, $web, $verbatim, $processedTopics ) = @_;

    my $res;

    if ( defined( $preferencesTags{$tag} )) {
        $res = $preferencesTags{$tag};
    } elsif ( defined( $sessionInternalTags{$tag} )) {
        $res = $sessionInternalTags{$tag};
    } elsif ( defined( $staticInternalTags{$tag} )) {
        $res = $staticInternalTags{$tag};
    } elsif ( defined( $dynamicInternalTags{$tag} )) {
        my %params = extractParameters( $args );

        $res = &{$dynamicInternalTags{$tag}}( \%params, @_ );
    }

    return ( defined( $res ), $res );
}

=pod

---++ handleCommonTags( $text, $topic, $web ) => processed $text
Processes %<nop>VARIABLE%, and %<nop>TOC% syntax; also includes
"commonTagsHandler" plugin hook.

Returns the text of the topic, after file inclusion, variable substitution,
table-of-contents generation, and any plugin changes from commonTagsHandler.

=cut

sub handleCommonTags {
    my( $text, $theTopic, $theWeb ) = @_;

    if( !$theWeb ) {
        $theWeb = $webName;
    }

    my @verbatim = ();
    my $theProcessedTopics = {};

    # Plugin Hook (for cache Plugins only)
    TWiki::Plugins::beforeCommonTagsHandler( $text, $theTopic, $theWeb );

    $text = TWiki::Render::takeOutBlocks( $text, "verbatim", \@verbatim );

    # Escape rendering: Change " !%VARIABLE%" to " %<nop>VARIABLE%", for final " %VARIABLE%" output
    $text =~ s/(\s)\!\%([A-Z])/$1%<nop>$2/g;

    my $memW = $sessionInternalTags{INCLUDINGWEB};
    my $memT = $sessionInternalTags{INCLUDINGTOPIC};
    $sessionInternalTags{INCLUDINGWEB} = $theWeb;
    $sessionInternalTags{INCLUDINGTOPIC} = $theTopic;

    processTags( \$text, $theTopic, $theWeb,
                        \@verbatim, $theProcessedTopics );

    # Plugin Hook
    TWiki::Plugins::commonTagsHandler( $text, $theTopic, $theWeb, 0 );

    # process tags again because plugin hook may have added more in
    processTags( \$text, $theTopic, $theWeb,
                        \@verbatim, $theProcessedTopics );

    $sessionInternalTags{INCLUDINGWEB} = $memW;
    $sessionInternalTags{INCLUDINGTOPIC} = $memT;

    # Codev.FormattedSearchWithConditionalOutput: remove <nop> lines,
    # possibly introduced by SEARCHes with conditional CALC. This needs
    # to be done after CALC and before table rendering
    # SMELL: is this a hack? Looks like it....
    $text =~ s/^<nop>\r?\n//gm;

    $text = TWiki::Render::putBackBlocks( $text, \@verbatim, "verbatim" );

    # TWiki Plugin Hook (for cache Plugins only)
    TWiki::Plugins::afterCommonTagsHandler( $text, $theTopic, $theWeb );

    return $text;
}

=end twiki

=cut

1;
