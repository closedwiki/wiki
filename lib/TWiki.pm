# Main Module of TWiki Collaboration Platform, http://TWiki.org/
# ($wikiversion has version info)
#
# Copyright (C) 1999-2003 Peter Thoeny, peter@thoeny.com
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
#
# 20000501 Kevin Kinnell : changed beta0404 to have many new search
#                          capabilities.  This file had a new hash added
#                          for month name-to-number look-ups, a slight
#                          change in the parameter list for the search
#                          script call in &handleSearchWeb, and a new
#                          sub -- &revDate2EpSecs -- for calculating the
#                          epoch seconds from a rev date (the only way
#                          to sort dates.)

package TWiki;

use strict;

use Time::Local;	# Added for revDate2EpSecs
use Cwd qw( cwd ); 	# Added for getTWikiLibDir

require 5.005;		# For regex objects and internationalisation

# ===========================
# TWiki config variables from TWiki.cfg:
use vars qw(
        $webName $topicName $includingWebName $includingTopicName
        $defaultUserName $userName $wikiName $wikiUserName
        $wikiHomeUrl $defaultUrlHost $urlHost
        $scriptUrlPath $pubUrlPath $viewScript
        $pubDir $templateDir $dataDir $logDir $twikiLibDir
        $siteWebTopicName $wikiToolName $securityFilter $uploadFilter
        $debugFilename $warningFilename $htpasswdFilename
        $logFilename $remoteUserFilename $wikiUsersTopicname
        $userListFilename %userToWikiList %wikiToUserList
        $twikiWebname $mainWebname $mainTopicname $notifyTopicname
        $wikiPrefsTopicname $webPrefsTopicname
        $statisticsTopicname $statsTopViews $statsTopContrib $doDebugStatistics
        $numberOfRevisions $editLockTime
        $attachAsciiPath $scriptSuffix $wikiversion
        $safeEnvPath $mailProgram $noSpamPadding $mimeTypesFilename
        $doKeepRevIfEditLock $doGetScriptUrlFromCgi $doRemovePortNumber
        $doRemoveImgInMailnotify $doRememberRemoteUser $doPluralToSingular
        $doHidePasswdInRegistration $doSecureInclude
        $doLogTopicView $doLogTopicEdit $doLogTopicSave $doLogRename
        $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff
        $doLogTopicChanges $doLogTopicSearch $doLogRegistration
        $disableAllPlugins 
    );

# ===========================
# Global variables:
use vars qw(
	@isoMonth @weekDay 
	$TranslationToken %mon2num $isList @listTypes @listElements
        $newTopicFontColor $newTopicBgColor $noAutoLink $linkProtocolPattern
        $headerPatternDa $headerPatternSp $headerPatternHt $headerPatternNoTOC
        $debugUserTime $debugSystemTime
        $viewableAttachmentCount $noviewableAttachmentCount
        $superAdminGroup $doSuperAdminGroup
        $cgiQuery @publicWebList
        $formatVersion $OS
        $readTopicPermissionFailed
	$pageMode
    );

# Internationalisation and regex setup:
use vars qw(
	$basicInitDone $useLocale $localeRegexes $siteLocale $siteCharset $siteLang

	$upperNational $lowerNational 
	$upperAlpha $lowerAlpha $mixedAlpha $mixedAlphaNum $lowerAlphaNum $numeric

	$wikiWordRegex $webNameRegex $defaultWebNameRegex $anchorRegex $abbrevRegex $emailAddrRegex
	$singleUpperAlphaRegex $singleLowerAlphaRegex $singleUpperAlphaNumRegex
	$singleMixedAlphaNumRegex $singleMixedNonAlphaNumRegex 
	$singleMixedNonAlphaRegex $mixedAlphaNumRegex
    );

# TWiki::Store config:
use vars qw(
        $rcsDir $rcsArg $nullDev $endRcsCmd $storeTopicImpl $keywordMode
        $storeImpl @storeSettings
    );

# TWiki::Search config:
use vars qw(
        $cmdQuote $lsCmd $egrepCmd $fgrepCmd
    );

# ===========================
# TWiki version:
$wikiversion      = "01 Feb 2003";

# ===========================
# Key Global variables, required for writeDebug
# (new variables must be declared in "use vars qw(..)" above)
@isoMonth = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
@weekDay = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");

{ 
    my $count = 0;
    %mon2num = map { $_ => $count++ } @isoMonth; 
}

# ===========================
# Read the configuration file at compile time in order to set locale
BEGIN {
    do "TWiki.cfg";

    # Do a dynamic 'use locale' for this module
    if( $useLocale ) {
        require locale;
	import locale ();
    }
}

sub writeDebug;
sub writeWarning;

# writeDebug "got useLocale = $useLocale";


# ===========================
# use TWiki and other modules
use TWiki::Prefs;     # preferences
use TWiki::Search;    # search engine
use TWiki::Access;    # access control
use TWiki::Meta;      # Meta class - topic meta data
use TWiki::Store;     # file I/O and rcs related functions
use TWiki::Attach;    # file attachment functions
use TWiki::Form;      # forms for topics
use TWiki::Func;      # official TWiki functions for plugins
use TWiki::Plugins;   # plugins handler  #AS
use TWiki::Net;       # SMTP, get URL



# ===========================
# Other Global variables

# Token character/string that must not occur in any normal text - converted
# to a flag character if it ever does occur (very unlikely).
$TranslationToken= "\0";	# Null should not be used by any charsets

# Use a multi-byte token only if above clashes with multi-byte character sets
# $TranslationToken= "_token_\0";

# The following are also initialized in initialize, here for cases where
# initialize not called.
$cgiQuery = 0;
@publicWebList = ();
$noAutoLink = 0;
$viewScript = "view";

$linkProtocolPattern = "(http|ftp|gopher|news|file|https|telnet)";

# Header patterns based on '+++'. The '###' are reserved for numbered headers
$headerPatternDa = '^---+(\++|\#+)\s*(.+)\s*$';       # '---++ Header', '---## Header'
$headerPatternSp = '^\t(\++|\#+)\s*(.+)\s*$';         # '   ++ Header', '   + Header'
$headerPatternHt = '^<h([1-6])>\s*(.+?)\s*</h[1-6]>'; # '<h6>Header</h6>
$headerPatternNoTOC = '(\!\!+|%NOTOC%)';  # '---++!! Header' or '---++ Header %NOTOC% ^top'

$debugUserTime   = 0;
$debugSystemTime = 0;

$formatVersion = "1.0";

$basicInitDone = 0;		# basicInitialize not yet done

$pageMode = 'html';		# Default is to render as HTML


# =========================
# Warning and errors that may require admin intervention, to 'warnings.txt' typically.
# Not using store writeLog; log file is more of an audit/usage file.
# Use this for defensive programming warnings (e.g. assertions).
sub writeWarning {
    my( $text ) = @_;
    if( $warningFilename ) {
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
    my( $tmon) = $isoMonth[$mon];
    $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
    my $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min );
        open( FILE, ">>$warningFilename" );
        print FILE "$time $text\n";
        close( FILE );
    }
}

# =========================
# Use for debugging messages, goes to 'debug.txt' normally
sub writeDebug {
    my( $text ) = @_;
    open( FILE, ">>$debugFilename" );
    
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
    my( $tmon) = $isoMonth[$mon];
    $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
    my $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min );

    print FILE "$time $text\n";
    close(FILE);
}

# =========================
# Use for performance monitoring/debugging
sub writeDebugTimes
{
    my( $text ) = @_;

    if( ! $debugUserTime ) {
        writeDebug( "===      sec (delta:)     sec (delta:)     sec   function:" );
    }
    my( $puser, $psystem, $cuser, $csystem ) = times();
    my $duser = $puser - $debugUserTime;
    my $dsystem = $psystem - $debugSystemTime;
    my $times = sprintf( "usr %1.2f (%1.2f), sys %1.2f (%1.2f), sum %1.2f",
                  $puser, $duser, $psystem, $dsystem, $puser+$psystem );
    $debugUserTime   = $puser;
    $debugSystemTime = $psystem;

    writeDebug( "==> $times,  $text" );
}

# Basic initialisation - for use from scripts that handle multiple webs
# (e.g. mailnotify) and need regexes or isWebName/isWikiName to work before
# the per-web initialize() is called.
sub basicInitialize() {
    # Set up locale for internationalisation and pre-compile regexes
    setupLocale();
    setupRegexes();
    
    $basicInitDone = 1;
}

# =========================
sub initialize
{
    my ( $thePathInfo, $theRemoteUser, $theTopic, $theUrl, $theQuery ) = @_;
    
    if( not $basicInitDone ) {
	basicInitialize();
    }

    ##writeDebug( "\n---------------------------------" );

    $cgiQuery = $theQuery;
    
    # Initialise vars here rather than at start of module, so compatible with modPerl
    @publicWebList = ();
    &TWiki::Store::initialize();

    # Make %ENV safer for CGI
    if( $safeEnvPath ) {
        $ENV{'PATH'} = $safeEnvPath;
    }
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    # initialize lib directory early because of later 'cd's
    getTWikiLibDir();

    # initialize access control
    &TWiki::Access::initializeAccess();
    $readTopicPermissionFailed = ""; # Will be set to name(s) of topic(s) that can't be read

    # initialize user name and user to WikiName list
    userToWikiListInit();
    # FIXME: Restored old spec for Beijing release since Codev.InitializeUserHandlerBroken
    #$userName = TWiki::Plugins::initializeUserHandler( $theRemoteUser, $theUrl, $thePathInfo );  # e.g. "jdoe"
    $userName = TWiki::Plugins::initializeUser( $theRemoteUser, $theUrl, $thePathInfo );  # e.g. "jdoe"
    $wikiName     = userToWikiName( $userName, 1 );      # i.e. "JonDoe"
    $wikiUserName = userToWikiName( $userName );         # i.e. "Main.JonDoe"

    # initialize $webName and $topicName
    $topicName = "";
    $webName   = "";
    if( $theTopic ) {
        if(( $theTopic =~ /^$linkProtocolPattern\:\/\//o ) && ( $cgiQuery ) ) {
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
    ## DEBUG: Simulate broken path_info
    ## $thePathInfo = "$scriptUrlPath/view/Main/WebStatistics";
    $thePathInfo =~ s!$scriptUrlPath/[\-\.A-Z]+$scriptSuffix/!/!i;
    ##writeDebug( "===== thePathInfo after cleanup = $thePathInfo" );

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

    ##writeDebug "raw topic is $topicName";

    # Filter out dangerous or unwanted characters
    $topicName =~ s/$securityFilter//go;
    $topicName =~ /(.*)/;
    $topicName = $1 || $mainTopicname;  # untaint variable
    $webName   =~ s/$securityFilter//go;
    $webName   =~ /(.*)/;
    $webName   = $1 || $mainWebname;  # untaint variable
    $includingTopicName = $topicName;
    $includingWebName = $webName;

    # initialize $urlHost and $scriptUrlPath 
    if( ( $theUrl ) && ( $theUrl =~ /^([^\:]*\:\/\/[^\/]*)(.*)\/.*$/ ) && ( $2 ) ) {
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
    # PTh 15 Jul 2001: Removed init of $scriptUrlPath based on $theUrl because
    # $theUrl has incorrect URI after failed authentication

    # initialize preferences
    &TWiki::Prefs::initializePrefs( $wikiUserName, $webName );

    # some remaining init
    $viewScript = "view";
    if( ( $ENV{'SCRIPT_NAME'} ) && ( $ENV{'SCRIPT_NAME'} =~ /^.*\/viewauth$/ ) ) {
        # Needed for TOC
        $viewScript = "viewauth";
    }

    # Add background color and font color (AlWilliams - 18 Sep 2000)
    # PTh: Moved from internalLink to initialize ('cause of performance)
    $newTopicBgColor   = TWiki::Prefs::getPreferencesValue("NEWTOPICBGCOLOR")   || "#FFFFCE";
    $newTopicFontColor = TWiki::Prefs::getPreferencesValue("NEWTOPICFONTCOLOR") || "#0000FF";
    # Prevent autolink of WikiWords
    $noAutoLink        = TWiki::Prefs::getPreferencesValue("NOAUTOLINK") || 0;

#AS
    if( !$disableAllPlugins ) {
        &TWiki::Plugins::initialize( $topicName, $webName, $userName );
    }
#/AS

    return ( $topicName, $webName, $scriptUrlPath, $userName, $dataDir );
}

# =========================
# Run-time locale setup - 'use locale' must be done in BEGIN block
# for regexes and sorting to work properly, although regexes can still
# work without this in 'non-locale regexes' mode (see setupRegexes routine).
sub setupLocale {
 
    $siteCharset = 'ISO-8859-1';	# Defaults if locale mis-configured
    $siteLang = 'en';

    if ( $useLocale ) {
	if ( not defined $siteLocale or $siteLocale !~ /[a-z]/i ) {
	    writeWarning "Locale $siteLocale unset or has no alphabetic characters";
	    return;
	}
	# Extract the character set from locale and use in HTML templates
	# and HTTP headers
	$siteLocale =~ m/\.([a-z0-9_-]+)$/i;
	$siteCharset = $1 if defined $1;
	##writeDebug "Charset is now $siteCharset";

	# Extract the language - use to disable plural processing if
	# non-English
	$siteLocale =~ m/^([a-z]+)_/i;
	$siteLang = $1 if defined $1;
	##writeDebug "Language is now $siteLang";

	# Set environment variables for grep 
	# FIXME: collate probably not necessary since all sorting is done
	# in Perl
	$ENV{'LC_CTYPE'}= $siteLocale;
	$ENV{'LC_COLLATE'}= $siteLocale;

	# Load POSIX for i18n support 
	require POSIX;
	import POSIX qw( locale_h LC_CTYPE LC_COLLATE );

	##my $old_locale = setlocale(LC_CTYPE);
	##writeDebug "Old locale was $old_locale";

	# Set new locale
	my $locale = setlocale(&LC_CTYPE, $siteLocale);
	setlocale(&LC_COLLATE, $siteLocale);
	##writeDebug "New locale is $locale";
    }
}

# =========================
# Set up pre-compiled regexes for use in rendering.  All regexes with
# unchanging variables in match should use the '/o' option, even if not in a
# loop, to help mod_perl, where the same code can be executed many times
# without recompilation.
sub setupRegexes {

    # Build up character class components for use in regexes.
    # Depends on locale mode and Perl version, and finally on
    # whether locale-based regexes are turned off.
    if ( not $useLocale or $] < 5.006 or not $localeRegexes ) {
	# No locales needed/working, or Perl 5.005_03 or lower, so just use
	# any additional national characters defined in TWiki.cfg
	$upperAlpha = "A-Z$upperNational";
	$lowerAlpha = "a-z$lowerNational";
	$numeric = '\d';
	$mixedAlpha = "${upperAlpha}${lowerAlpha}";
    } else {
	# Perl 5.6 or higher with working locales
	$upperAlpha = "[:upper:]";
	$lowerAlpha = "[:lower:]";
	$numeric = "[:digit:]";
	$mixedAlpha = "[:alpha:]";
    }
    $mixedAlphaNum = "${mixedAlpha}${numeric}";
    $lowerAlphaNum = "${lowerAlpha}${numeric}";

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/. 

    # TWiki concept regexes
    $wikiWordRegex = qr/[$upperAlpha]+[$lowerAlpha]+[$upperAlpha]+[$mixedAlphaNum]*/;
    $webNameRegex = qr/[$upperAlpha]+[$lowerAlphaNum]*/;
    $defaultWebNameRegex = qr/_[${mixedAlphaNum}_]+/;
    $anchorRegex = qr/\#[${mixedAlphaNum}_]+/;
    $abbrevRegex = qr/[$upperAlpha]{3,}/;

    # Simplistic email regex, e.g. for WebNotify processing - no i18n
    # characters allowed
    $emailAddrRegex = qr/([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/;

    # Single-character alpha-based regexes
    $singleUpperAlphaRegex = qr/[$upperAlpha]/;
    $singleLowerAlphaRegex = qr/[$lowerAlpha]/;
    $singleUpperAlphaNumRegex = qr/[${upperAlpha}${numeric}]/;
    $singleMixedAlphaNumRegex = qr/[${upperAlpha}${lowerAlpha}${numeric}]/;

    $singleMixedNonAlphaRegex = qr/[^${upperAlpha}${lowerAlpha}]/;
    $singleMixedNonAlphaNumRegex = qr/[^${upperAlpha}${lowerAlpha}${numeric}]/;

    # Multi-character alpha-based regexes
    $mixedAlphaNumRegex = qr/[${mixedAlphaNum}]*/;

}

# =========================
# writeHeader: simple header setup for most scripts
sub writeHeader
{
    my( $query ) = @_;

    # FIXME: Pass real content-length to make persistent connections work
    # in HTTP/1.1 (performance improvement for browsers and servers). 
    # Requires significant but easy changes in various places.

    # Just write a basic content-type header for text/html
    writeHeaderFull( $query, 'basic', 'text/html', 0);
}

# =========================
# writeHeaderFull: full header setup for Edit page; will be used
# to improve cacheability for other pages in future.  Setting
# cache headers on Edit page fixes the Codev.BackFromPreviewLosesText
# bug, which caused data loss with IE5 and IE6.
#
# Implements the post-Dec2001 release plugin API, which
# requires the writeHeaderHandler in plugin to return a string of
# HTTP headers, CR/LF delimited.  Filters out headers that the
# core code needs to generate for whatever reason, and any illegal
# headers.
sub writeHeaderFull
{
    my( $query, $pageType, $contentType, $contentLength ) = @_;

    # Handle Edit pages - future versions will extend to caching
    # of other types of page, with expiry time driven by page type.
    my( $pluginHeaders, $coreHeaders );


    $contentType .= "; charset=$siteCharset";

    if ($pageType eq 'edit') {
	# Get time now in HTTP header format
	my $lastModifiedString = formatGmTime(time, 'http');

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
	writeWarning( "===== invalid page type in TWiki.pm, writeHeaderFull(): $pageType" );
    }

    # Delete extra CR/LF to allow suffixing more headers
    $coreHeaders =~ s/\r\n\r\n$/\r\n/s;
    ##writeDebug( "===== After trim, Headers are:\n$coreHeaders" );

    # Wiki Plugin Hook - get additional headers from plugin
    $pluginHeaders = &TWiki::Plugins::writeHeaderHandler( $query ) || '';

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
	    ##writeDebug("==== core header name $headerName");
	    $coreHeaderSeen{$headerName}++;
	}
	# Append plugin headers if legal and not seen in core headers
	for $headerLine (split /\r\n/, $pluginHeaders) {
	    $headerLine =~ m/^([^ ]+): /i;		# Get header name
	    $headerName = lc($1);
	    if ( $headerName =~ m/[\-a-z]+/io ) {	# Skip bad headers
		##writeDebug("==== plugin header name $headerName");
		##writeDebug("Saw $headerName already ") if $coreHeaderSeen{$headerName};
		$finalHeaders .= $headerLine . "\r\n"
		    unless $coreHeaderSeen{$headerName};
	    }

	}
    }
    $finalHeaders .= "\r\n";		
    ##writeDebug( "===== Final Headers are:\n$finalHeaders" );
    print $finalHeaders;

}

# =========================
# Set page mode:
#   - 'rss' - encode 8-bit characters as XML entities
#   - 'html' - no encoding of 8-bit characters
sub setPageMode
{
    $pageMode = shift;
}

# =========================
sub getPageMode
{
    return $pageMode;
}

# =========================
sub getCgiQuery
{
    return $cgiQuery;
}

# =========================
sub redirect
{
    my( $query, $url ) = @_;
    if( ! &TWiki::Plugins::redirectCgiQueryHandler( $query, $url ) ) {
        print $query->redirect( $url );
    }
}


# =========================
# Get email list from WebNotify page - this now handles entries of the form:
#    * Main.UserName 
#    * UserName 
#    * Main.GroupName
#    * GroupName
# The 'UserName' format (i.e. no Main webname) is supported in any web, but
# is not recommended since this may make future data conversions more
# complicated, especially if used outside the Main web.  %MAINWEB% is OK
# instead of 'Main'.  The user's email address(es) are fetched from their
# user topic (home page) as long as they are listed in the '* Email:
# fred@example.com' format.  Nested groups are supported.
sub getEmailNotifyList
{
    my( $web, $topicname ) = @_;

    $topicname = $notifyTopicname unless $topicname;
    return() unless &TWiki::Store::topicExists( $web, $topicname );

    # Allow %MAINWEB% as well as 'Main' in front of users/groups -
    # non-capturing regex.
    my $mainWebPattern = qr/(?:$mainWebname|%MAINWEB%)/;

    my @list = ();
    my %seen;			# Incremented when email address is seen
    foreach ( split ( /\n/, TWiki::Store::readWebTopic( $web, $topicname ) ) ) {
        if ( /^\s+\*\s(?:$mainWebPattern\.)?($wikiWordRegex)\s+\-\s+($emailAddrRegex)/o ) {
	    # Got full form:   * Main.WikiName - email@domain
	    # (the 'Main.' part is optional, non-capturing)
	    if ( $1 ne 'TWikiGuest' ) {
		# Add email address to list if non-guest and non-duplicate
		push (@list, $2) unless $seen{$1}++;
            }
        } elsif ( /^\s+\*\s(?:$mainWebPattern\.)?($wikiWordRegex)\s*$/o ) { 
	    # Got short form:   * Main.WikiName
	    # (the 'Main.' part is optional, non-capturing)
            my $userWikiName = $1;
            foreach ( getEmailOfUser($userWikiName) ) {
		# Add email address to list if it's not a duplicate
                push (@list, $_) unless $seen{$_}++;
            }
        }
    }
    ##writeDebug "list of emails: @list";
    return( @list);
}

# Get email address for a given WikiName or group, from the user's home page
sub getEmailOfUser
{
    my ($wikiName) = @_;		# WikiName without web prefix

    my @list = ();
    # Ignore guest entry and non-existent pages
    if ( $wikiName ne "TWikiGuest" && 
		TWiki::Store::topicExists( $mainWebname, $wikiName ) ) {
        if ( $wikiName =~ /Group$/ ) {
            # Page is for a group, get all users in group
	    ##writeDebug "using group: $mainWebname . $wikiName";
	    my @userList = TWiki::Access::getUsersOfGroup( $wikiName ); 
	    foreach my $user ( @userList ) {
		$user =~ s/^.*\.//;	# Get rid of 'Main.' part.
		foreach my $email ( getEmailOfUser($user) ) {
		    push @list, $email;
		}
	    }
        } else {
	    # Page is for a user
	    ##writeDebug "reading home page: $mainWebname . $wikiName";
            foreach ( split ( /\n/, &TWiki::Store::readWebTopic( 
					    $mainWebname, $wikiName ) ) ) {
                if (/^\s\*\sEmail:\s+([\w\-\.\+]+\@[\w\-\.\+]+)/) {   
		    # Add email address to list
                    push @list, $1;
                }
            }
        }
    }
    return (@list);
}

# =========================
sub initializeRemoteUser
{
    my( $theRemoteUser ) = @_;

    my $remoteUser = $theRemoteUser || $defaultUserName;
    $remoteUser =~ s/$securityFilter//go;
    $remoteUser =~ /(.*)/;
    $remoteUser = $1;  # untaint variable

    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";

    if( ( ! $doRememberRemoteUser ) || ( ! $remoteAddr ) ) {
        # do not remember IP address
        return $remoteUser;
    }

    my $text = &TWiki::Store::readFile( $remoteUserFilename );
    # Assume no I18N characters in userids, as for email addresses
    my %AddrToName = map { split( /\|/, $_ ) }
                     grep { /^[0-9\.]+\|[A-Za-z0-9]+\|$/ }
                     split( /\n/, $text );

    my $rememberedUser = "";
    if( exists( $AddrToName{ $remoteAddr } ) ) {
        $rememberedUser = $AddrToName{ $remoteAddr };
    }

    if( $theRemoteUser ) {
        if( $theRemoteUser ne $rememberedUser ) {
            $AddrToName{ $remoteAddr } = $theRemoteUser;
            # create file as "$remoteAddr|$theRemoteUser|" lines
            $text = "# This is a generated file, do not modify.\n";
            foreach my $usrAddr ( sort keys %AddrToName ) {
                my $usrName = $AddrToName{ $usrAddr };
                # keep $userName unique
                if(  ( $usrName ne $theRemoteUser )
                  || ( $usrAddr eq $remoteAddr ) ) {
                    $text .= "$usrAddr|$usrName|\n";
                }
            }
            &TWiki::Store::saveFile( $remoteUserFilename, $text );
        }
    } else {
        # get user name from AddrToName table
        $remoteUser = $rememberedUser || $defaultUserName;
    }

    return $remoteUser;
}

# =========================
# Build hashes to translate in both directions between username (e.g. jsmith) 
# WikiName (e.g. JaneSmith)
sub userToWikiListInit
{
    my $text = &TWiki::Store::readFile( $userListFilename );
    my @list = split( /\n/, $text );

    # Get all entries with two '-' characters on same line, i.e.
    # 'WikiName - userid - date created'
    @list = grep { /^\s*\* $wikiWordRegex\s*-\s*[^\-]*-/o } @list;
    %userToWikiList = ();
    %wikiToUserList = ();
    my $wUser;
    my $lUser;
    foreach( @list ) {
	# Get the WikiName and userid, and build hashes in both directions
        if(  ( /^\s*\* ($wikiWordRegex)\s*\-\s*([^\s]*).*/o ) && $2 ) {
            $wUser = $1;	# WikiName
            $lUser = $2;	# userid
            $lUser =~ s/$securityFilter//go;	# FIXME: Should filter in for security...
            $userToWikiList{ $lUser } = $wUser;
            $wikiToUserList{ $wUser } = $lUser;
        }
    }
}

# =========================
# Translate intranet username (e.g. jsmith) to WikiName (e.g. JaneSmith)
sub userToWikiName
{
    my( $loginUser, $dontAddWeb ) = @_;
    
    if( !$loginUser ) {
        return "";
    }

    $loginUser =~ s/$securityFilter//go;
    my $wUser = $userToWikiList{ $loginUser } || $loginUser;
    if( $dontAddWeb ) {
        return $wUser;
    }
    return "$mainWebname.$wUser";
}

# =========================
sub wikiToUserName
{
    my( $wikiUser ) = @_;
    $wikiUser =~ s/^.*\.//g;
    my $userName =  $wikiToUserList{"$wikiUser"} || $wikiUser;
    ##writeDebug( "TWiki::wikiToUserName: $wikiUser->$userName" );
    return $userName;
}

# =========================
sub isGuest
{
   return ( $userName eq $defaultUserName );
}

# =========================
sub getWikiUserTopic
{
    # Topic without Web name
    return $wikiName;
}

# =========================
# Check for a valid WikiWord
sub isWikiName
{
    my( $name ) = @_;

    $name ||= "";	# Default value if undef
    return ( $name =~ m/^${wikiWordRegex}$/o )
}

# =========================
# Check for a valid ABBREV (acronym)
sub isAbbrev
{
    my( $name ) = @_;

    $name ||= "";	# Default value if undef
    return ( $name =~ m/^${abbrevRegex}$/o )
}

# =========================
# Check for a valid web name
sub isWebName
{
    my( $name ) = @_;

    $name ||= "";	# Default value if undef
    return ( $name =~ m/^${webNameRegex}$/o )
}

# =========================
sub readOnlyMirrorWeb
{
    my( $theWeb ) = @_;

    my @mirrorInfo = ( "", "", "", "" );
    if( $siteWebTopicName ) {
        my $mirrorSiteName = &TWiki::Prefs::getPreferencesValue( "MIRRORSITENAME", $theWeb );
        if( $mirrorSiteName && $mirrorSiteName ne $siteWebTopicName ) {
            my $mirrorViewURL  = &TWiki::Prefs::getPreferencesValue( "MIRRORVIEWURL", $theWeb );
            my $mirrorLink = &TWiki::Store::readTemplate( "mirrorlink" );
            $mirrorLink =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorLink =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorLink =~ s/\s*$//g;
            my $mirrorNote = &TWiki::Store::readTemplate( "mirrornote" );
            $mirrorNote =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorNote =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorNote = getRenderedVersion( $mirrorNote, $theWeb );
            $mirrorNote =~ s/\s*$//g;
            @mirrorInfo = ( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote );
        }
    }
    return @mirrorInfo;
}


# =========================
sub getDataDir
{
    return $dataDir;
}

# =========================
sub getPubDir
{
    return $pubDir;
}

# =========================
sub getPubUrlPath
{
    return $pubUrlPath;
}

# =========================
sub getTWikiLibDir
{
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

    # fix relative path
    if( $twikiLibDir =~ /^\./ ) {
        my $curr = cwd();
        $twikiLibDir = "$curr/$twikiLibDir/";
        # normalize "/../" and "/./"
        while ( $twikiLibDir =~ s|([\\/])[^\\/]+[\\/]\.\.[\\/]|$1| ) {};
        $twikiLibDir =~ s|([\\/])\.[\\/]|$1|g;
    }
    $twikiLibDir =~ s|([\\/])[\\/]*|$1|g; # reduce "//" to "/"
    $twikiLibDir =~ s|[\\/]$||;           # cut trailing "/"

    return $twikiLibDir;
}

# =========================
# Get date in '1 Jan 2002' format, in GMT as for other dates
sub getGmDate
{
    my( $sec, $min, $hour, $mday, $mon, $year) = gmtime(time());
    $year = sprintf("%.4u", $year + 1900);  # Y2K fix
    my( $tmon) = $isoMonth[$mon];
    my $date = sprintf("%.2u ${tmon} %.2u", $mday, $year);
    return $date;
}

# =========================
# Get date in '1 Jan 2002' format, in local timezone of server
sub getLocaldate
{
    my( $sec, $min, $hour, $mday, $mon, $year) = localtime(time());
    $year = sprintf("%.4u", $year + 1900);  # Y2K fix
    my( $tmon) = $isoMonth[$mon];
    my $date = sprintf("%.2u ${tmon} %.2u", $mday, $year);
    return $date;
}

# =========================
# Return GMT date/time as formatted string 
sub formatGmTime
{
    my( $theTime, $theFormat ) = @_;

    my( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime( $theTime );

    if( $theFormat ) {
        $year += 1900;

        if( $theFormat =~ /rcs/i ) {
            # RCS format, example: "2001/12/31 23:59:59"
            return sprintf( "%.4u/%.2u/%.2u %.2u:%.2u:%.2u", 
                            $year, $mon+1, $mday, $hour, $min, $sec );
        } elsif ( $theFormat =~ /http|email/i ) {
            # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 GMT"
	    # - based on RFC 2616/1123 and HTTP::Date; also used
	    # by TWiki::Net for Date header in emails.
	    return sprintf( "%s, %02d %s %04d %02d:%02d:%02d GMT", 
			$weekDay[$wday], $mday, $isoMonth[$mon], $year, 
			$hour, $min, $sec );
        } else {
	    # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
	    # e.g. "2002-12-31T19:30Z"
	    return sprintf( "%.4u\-%.2u\-%.2uT%.2u\:%.2u:%.2uZ", 
			    $year, $mon+1, $mday, $hour, $min, $sec );
	}
    }

    # Default format, e.g. "31 Dec 2002 - 19:30"
    my( $tmon ) = $isoMonth[$mon];
    $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
    return sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min );
}

# =========================
sub revDate2ISO
{
    my $epochSec = revDate2EpSecs( $_[0] );
    return formatGmTime( $epochSec, 1 );
}

# =========================
sub revDate2EpSecs
# Convert RCS revision date/time to seconds since epoch, for easier sorting 
{
    my( $date ) = @_;
    # NOTE: This routine *will break* if input is not one of below formats!
    
    # FIXME - why aren't ifs around pattern match rather than $5 etc
    # try "31 Dec 2001 - 23:59"  (TWiki date)
    $date =~ /([0-9]+)\s+([A-Za-z]+)\s+([0-9]+)[\s\-]+([0-9]+)\:([0-9]+)/;
    if( $5 ) {
        my $year = $3;
        $year -= 1900 if( $year > 1900 );
        return timegm( 0, $5, $4, $1, $mon2num{$2}, $year );
    }

    # try "2001/12/31 23:59:59" or "2001.12.31.23.59.59" (RCS date)
    $date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)[\.\s\-]+([0-9]+)[\.\:]([0-9]+)[\.\:]([0-9]+)/;
    if( $6 ) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timegm( $6, $5, $4, $3, $2-1, $year );
    }

    # try "2001/12/31 23:59" or "2001.12.31.23.59" (RCS short date)
    $date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)[\.\s\-]+([0-9]+)[\.\:]([0-9]+)/;
    if( $5 ) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timegm( 0, $5, $4, $3, $2-1, $year );
    }

    # try "2001-12-31T23:59:59Z" or "2001-12-31T23:59:59+01:00" (ISO date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59:59+01:00"
    $date =~ /([0-9]+)\-([0-9]+)\-([0-9]+)T([0-9]+)\:([0-9]+)\:([0-9]+)/;
    if( $6 ) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timegm( $6, $5, $4, $3, $2-1, $year );
    }

    # try "2001-12-31T23:59Z" or "2001-12-31T23:59+01:00" (ISO short date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59+01:00"
    $date =~ /([0-9]+)\-([0-9]+)\-([0-9]+)T([0-9]+)\:([0-9]+)/;
    if( $5 ) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timegm( 0, $5, $4, $3, $2-1, $year );
    }

    # give up, return start of epoch (01 Jan 1970 GMT)
    return 0;
}

# =========================
sub getSessionValue
{
#   my( $key ) = @_;
    return &TWiki::Plugins::getSessionValueHandler( @_ );
}

# =========================
sub setSessionValue
{
#   my( $key, $value ) = @_;
    return &TWiki::Plugins::setSessionValueHandler( @_ );
}

# =========================
sub getSkin
{
    my $skin = "";
    $skin = $cgiQuery->param( 'skin' ) if( $cgiQuery );
    $skin = &TWiki::Prefs::getPreferencesValue( "SKIN" ) unless( $skin );
    return $skin;
}

# =========================
sub getViewUrl
{
    my( $theWeb, $theTopic ) = @_;
    # PTh 20 Jun 2000: renamed sub viewUrl to getViewUrl, added $theWeb
    my $web = $webName;  # current web
    if( $theWeb ) {
        $web = $theWeb;
    }
    $theTopic =~ s/\s*//gs; # Illegal URL, remove space

    # PTh 24 May 2000: added $urlHost, needed for some environments
    # see also Codev.PageRedirectionNotWorking
    return "$urlHost$scriptUrlPath/view$scriptSuffix/$web/$theTopic";
}

# =========================
sub getScriptUrl
{
    my( $theWeb, $theTopic, $theScript ) = @_;
    
    my $url = "$urlHost$scriptUrlPath/$theScript$scriptSuffix/$theWeb/$theTopic";

    # FIXME consider a plugin call here - useful for certificated logon environment
    
    return $url;
}

# =========================
sub getOopsUrl
{
    my( $theWeb, $theTopic, $theTemplate,
        $theParam1, $theParam2, $theParam3, $theParam4 ) = @_;
    # PTh 20 Jun 2000: new sub
    my $web = $webName;  # current web
    if( $theWeb ) {
        $web = $theWeb;
    }
    my $url = "";
    # $urlHost is needed, see Codev.PageRedirectionNotWorking
    $url = getScriptUrl( $web, $theTopic, "oops" );
    $url .= "\?template=$theTemplate";
    $url .= "\&amp;param1=" . handleUrlEncode( $theParam1 ) if ( $theParam1 );
    $url .= "\&amp;param2=" . handleUrlEncode( $theParam2 ) if ( $theParam2 );
    $url .= "\&amp;param3=" . handleUrlEncode( $theParam3 ) if ( $theParam3 );
    $url .= "\&amp;param4=" . handleUrlEncode( $theParam4 ) if ( $theParam4 );

    return $url;
}

# =========================
sub makeTopicSummary
{
    my( $theText, $theTopic, $theWeb ) = @_;
    # called by search, mailnotify & changes after calling readFileHead

    my $htext = $theText;
    # Format e-mail to add spam padding (HTML tags removed later)
    $htext =~ s/([\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . &mailtoLink( $2, $3, $4 )/ge;
    $htext =~ s/<\!\-\-.*?\-\->//gs;  # remove all HTML comments
    $htext =~ s/<\!\-\-.*$//s;        # cut HTML comment
    $htext =~ s/<[^>]*>//g;           # remove all HTML tags
    $htext =~ s/\&[a-z]+;/ /g;        # remove entities
    $htext =~ s/%WEB%/$theWeb/g;      # resolve web
    $htext =~ s/%TOPIC%/$theTopic/g;  # resolve topic
    $htext =~ s/%WIKITOOLNAME%/$wikiToolName/g; # resolve TWiki tool name
    $htext =~ s/%META:.*?%//g;        # remove meta data variables
    $htext =~ s/[\%\[\]\*\|=_\&\<\>]/ /g; # remove Wiki formatting chars & defuse %VARS%
    $htext =~ s/\-\-\-+\+*\s*\!*/ /g; # remove heading formatting
    $htext =~ s/\s+[\+\-]*/ /g;       # remove newlines and special chars

    # limit to 162 chars 
    # FIXME I18N: Avoid splitting within multi-byte character sets
    $htext =~ s/(.{162})($mixedAlphaNumRegex)(.*?)$/$1$2 \.\.\./g;

    # Encode special chars into XML &#nnn; entities for use in RSS feeds
    # - no encoding for HTML pages, to avoid breaking international 
    # characters.
    if( $pageMode eq 'rss' ) {
	$htext =~ s/([\x7f-\xff])/"\&\#" . unpack( "C", $1 ) .";"/ge;
    }

    # inline search renders text, so prevent linking of external and
    # internal links:
    $htext =~ s/([\-\*\s])($linkProtocolPattern\:)/$1<nop>$2/go;
    $htext =~ s/([\s\(])($webNameRegex\.$wikiWordRegex)/$1<nop>$2/g;
    $htext =~ s/([\s\(])($wikiWordRegex)/$1<nop>$2/g;
    $htext =~ s/([\s\(])($abbrevRegex)/$1<nop>$2/g;
    $htext =~ s/@([a-zA-Z0-9\-\_\.]+)/@<nop>$1/g;	# email address

    return $htext;
}

# =========================
sub extractNameValuePair
{
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
        if( $str =~ /(^|\=\s*\"[^\"]*\")\s*\"([^\"]*)\"/ ) {
            # is: %VAR{ ... = "..." "value" ... }%
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

# =========================
sub fixN
{
    my( $theTag ) = @_;
    $theTag =~ s/[\r\n]+//gs;
    return $theTag;
}

# =========================
sub fixURL
{
    my( $theHost, $theAbsPath, $theUrl ) = @_;

    my $url = $theUrl;
    if( $url =~ /^\// ) {
        # fix absolute URL
        $url = "$theHost$url";
    } elsif( $url =~ /^\./ ) {
        # fix relative URL
        $url = "$theHost$theAbsPath/$url";
    } elsif( $url =~ /^$linkProtocolPattern\:/ ) {
        # full qualified URL, do nothing
    } elsif( $url ) {
        # FIXME: is this test enough to detect relative URLs?
        $url = "$theHost$theAbsPath/$url";
    }

    return $url;
}

# =========================
sub handleIncludeUrl
{
    my( $theUrl, $thePattern ) = @_;
    my $text = "";
    my $host = "";
    my $port = 80;
    my $path = "";
    my $user = "";
    my $pass = "";

    # RNF 22 Jan 2002 Handle http://user:pass@host
    if( $theUrl =~ /http\:\/\/(.+)\:(.+)\@([^\:]+)\:([0-9]+)(\/.*)/ ) {
        $user = $1;
        $pass = $2;
        $host = $3;
        $port = $4;
        $path = $5;

    } elsif( $theUrl =~ /http\:\/\/(.+)\:(.+)\@([^\/]+)(\/.*)/ ) {
        $user = $1;
        $pass = $2;
        $host = $3;
        $path = $4;

    } elsif( $theUrl =~ /http\:\/\/([^\:]+)\:([0-9]+)(\/.*)/ ) {
        $host = $1;
        $port = $2;
        $path = $3;

    } elsif( $theUrl =~ /http\:\/\/([^\/]+)(\/.*)/ ) {
        $host = $1;
        $path = $2;

    } else {
        $text = showError( "Error: Unsupported protocol. (Must be 'http://domain/...')" );
        return $text;
    }

    $text = &TWiki::Net::getUrl( $host, $port, $path, $user, $pass );
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

        # FIXME: Make aware of <base> tag

        $text =~ s/^.*?<\/head>//is;            # remove all HEAD
        $text =~ s/<script.*?<\/script>//gis;   # remove all SCRIPTs
        $text =~ s/^.*?<body[^>]*>//is;         # remove all to <BODY>
        $text =~ s/(?:\n)<\/body>//is;          # remove </BODY>
        $text =~ s/(?:\n)<\/html>//is;          # remove </HTML>
        $text =~ s/(<[^>]*>)/&fixN($1)/ges;     # join tags to one line each
        $text =~ s/(\s(href|src|action)\=\"?)([^\"\>\s]*)/$1 . &fixURL( $host, $path, $3 )/geis;

    } elsif( $contentType =~ /^text\/plain/ ) {
        # do nothing

    } else {
        $text = showError( "Error: Unsupported content type: $contentType."
              . " (Must be text/html or text/plain)" );
    }

    if( $thePattern ) {
        $thePattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/g;  # escape some special chars
        $thePattern =~ /(.*)/;     # untaint
        $thePattern = $1;
        $text = "" unless( $text =~ s/$thePattern/$1/is );
    }

    return $text;
}

# =========================
sub handleIncludeFile
{
    my( $theAttributes, $theTopic, $theWeb, $verbatim, @theProcessedTopics ) = @_;
    my $incfile = extractNameValuePair( $theAttributes );
    my $pattern = extractNameValuePair( $theAttributes, "pattern" );
    my $rev = extractNameValuePair( $theAttributes, "rev" );

    if( $incfile =~ /^http\:/ ) {
        # include web page
        return handleIncludeUrl( $incfile, $pattern );
    }

    # CrisBailiff, PeterThoeny 12 Jun 2000: Add security
    $incfile =~ s/$securityFilter//go;    # zap anything suspicious
    if( $doSecureInclude ) {
        # Filter out ".." from filename, this is to
        # prevent includes of "../../file"
        $incfile =~ s/\.+/\./g;
    } else {
        # danger, could include .htpasswd with relative path
        $incfile =~ s/passwd//gi;    # filter out passwd filename
    }

    # test for different usage
    my $fileName = "$dataDir/$theWeb/$incfile";       # TopicName.txt
    if( ! -e $fileName ) {
        $fileName = "$dataDir/$theWeb/$incfile.txt";  # TopicName
        if( ! -e $fileName ) {
            $fileName = "$dataDir/$incfile";              # Web/TopicName.txt
            if( ! -e $fileName ) {
                $incfile =~ s/\.([^\.]*)$/\/$1/g;
                $fileName = "$dataDir/$incfile.txt";      # Web.TopicName
                if( ! -e $fileName ) {
                    # give up, file not found
                    return "";
                }
            }
        }
    }

    # prevent recursive loop
    if( ( @theProcessedTopics ) && ( grep { /^$fileName$/ } @theProcessedTopics ) ) {
        # file already included
        return "";
    } else {
        # remember for next time
        push( @theProcessedTopics, $fileName );
    }

    my $text = "";
    my $meta = "";

    # set include web/filenames and current web/filenames
    $includingWebName = $theWeb;
    $includingTopicName = $theTopic;
    $fileName =~ s/\/([^\/]*)\/([^\/]*)(\.txt)$/$1/g;
    if( $3 ) {
        # identified "/Web/TopicName.txt" filename, e.g. a Wiki topic
        # so save the current web and topic name
        $theWeb = $1;
        $theTopic = $2;

        if( $rev ) {
            $rev = "1.$rev" unless( $rev =~ /^1\./ );
            ( $meta, $text ) = &TWiki::Store::readTopicVersion( $theWeb, $theTopic, $rev );
        } else {
            ( $meta, $text ) = &TWiki::Store::readTopic( $theWeb, $theTopic );
        }
        # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
        $text =~ s/.*?%STARTINCLUDE%//s;
        $text =~ s/%STOPINCLUDE%.*//s;
    } # else is a file with relative path, e.g. $dataDir/../../path/to/non-twiki/file.ext

    if( $pattern ) {
        $pattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/g;  # escape some special chars
        $pattern =~ /(.*)/;     # untaint
        $pattern = $1;
        $text = "" unless( $text =~ s/$pattern/$1/is );
    }

    # handle all preferences and internal tags (for speed: call by reference)
    $text = takeOutVerbatim( $text, $verbatim );

    # Wiki Plugin Hook (4th parameter tells plugin that its called from an include)
    &TWiki::Plugins::commonTagsHandler( $text, $theTopic, $theWeb, 1 );

    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );
    
    # FIXME What about attachments?

    # recursively process multiple embedded %INCLUDE% statements and prefs
    $text =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $theTopic, $theWeb, @theProcessedTopics )/ge;

    return $text;
}

# =========================
# Only does simple search for topicmoved at present, can be expanded when required
sub handleMetaSearch
{
    my( $attributes ) = @_;
    
    my $attrWeb           = extractNameValuePair( $attributes, "web" );
    my $attrTopic         = extractNameValuePair( $attributes, "topic" );
    my $attrType          = extractNameValuePair( $attributes, "type" );
    my $attrTitle         = extractNameValuePair( $attributes, "title" );
    
    my $searchVal = "XXX";
    
    if( ! $attrType ) {
       $attrType = "";
    }
    
    
    my $searchWeb = "all";
    
    if( $attrType eq "topicmoved" ) {
       $searchVal = "%META:TOPICMOVED\{.*from=\\\"$attrWeb\.$attrTopic\\\".*\}%";
    } elsif ( $attrType eq "parent" ) {
       $searchWeb = $attrWeb;
       $searchVal = "%META:TOPICPARENT\{.*name=\\\"($attrWeb\\.)?$attrTopic\\\".*\}%";
    }
    
    my $text = &TWiki::Search::searchWeb( "1", $searchWeb, $searchVal, "",
       "", "on", "", "",
       "", "on", "on",
       "on", "on", "", "",
       "", "on", "searchmeta"
    );    
    
    if( $text !~ /^\s*$/ ) {
       $text = "$attrTitle$text";
    }
    
    return $text;
}

# =========================
sub handleSearchWeb
{
    my( $attributes ) = @_;
    my $searchVal = extractNameValuePair( $attributes );
    if( ! $searchVal ) {
        # %SEARCH{"string" ...} not found, try
        # %SEARCH{search="string" ...}
        $searchVal = extractNameValuePair( $attributes, "search" );
    }

    my $attrWeb           = extractNameValuePair( $attributes, "web" );
    my $attrScope         = extractNameValuePair( $attributes, "scope" );
    my $attrOrder         = extractNameValuePair( $attributes, "order" );
    my $attrRegex         = extractNameValuePair( $attributes, "regex" );
    my $attrLimit         = extractNameValuePair( $attributes, "limit" );
    my $attrReverse       = extractNameValuePair( $attributes, "reverse" );
    my $attrCasesensitive = extractNameValuePair( $attributes, "casesensitive" );
    my $attrNosummary     = extractNameValuePair( $attributes, "nosummary" );
    my $attrNosearch      = extractNameValuePair( $attributes, "nosearch" );
    my $attrNoheader      = extractNameValuePair( $attributes, "noheader" );
    my $attrNototal       = extractNameValuePair( $attributes, "nototal" );
    my $attrBookview      = extractNameValuePair( $attributes, "bookview" );
    my $attrRenameview    = extractNameValuePair( $attributes, "renameview" );
    my $attrShowlock      = extractNameValuePair( $attributes, "showlock" );
    my $attrNoEmpty       = extractNameValuePair( $attributes, "noempty" );
    my $attrTemplate      = extractNameValuePair( $attributes, "template" ); # undocumented
    my $attrHeader        = extractNameValuePair( $attributes, "header" );
    my $attrFormat        = extractNameValuePair( $attributes, "format" );

    return &TWiki::Search::searchWeb( "1", $attrWeb, $searchVal, $attrScope,
       $attrOrder, $attrRegex, $attrLimit, $attrReverse,
       $attrCasesensitive, $attrNosummary, $attrNosearch,
       $attrNoheader, $attrNototal, $attrBookview, $attrRenameview,
       $attrShowlock, $attrNoEmpty, $attrTemplate, $attrHeader, $attrFormat
    );
}

# =========================
sub handleTime
{
    my( $theAttributes, $theZone ) = @_;
    # format examples:
    #   28 Jul 2000 15:33:59 is "$day $month $year $hour:$min:$sec"
    #   001128               is "$ye$mo$day"

    my $format = extractNameValuePair( $theAttributes );

    my $value = "";
    my $time = time();

    if( $format ) {
        my( $sec, $min, $hour, $day, $mon, $year ) = gmtime( $time );
          ( $sec, $min, $hour, $day, $mon, $year ) = localtime( $time ) if( $theZone eq "servertime" );
        $value = $format;
        $value =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
        $value =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
        $value =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
        $value =~ s/\$day/sprintf("%.2u",$day)/geoi;
        $value =~ s/\$mon[t]?[h]?/$isoMonth[$mon]/goi;
        $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
        $value =~ s/\$yea[r]?/sprintf("%.4u",$year+1900)/geoi;
        $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;

    } else {
        if( $theZone eq "gmtime" ) {
            $value = gmtime( $time );
        } elsif( $theZone eq "servertime" ) {
            $value = localtime( $time );
        }
    }
    return $value;
}

#AS
# =========================
sub showError
{
    my( $errormessage ) = @_;
    return "<font size=\"-1\" color=\"#FF0000\">$errormessage</font>" ;
}

#AS
# =========================
# Create markup for %TOC%
sub handleToc
{
    # Andrea Sterbini 22-08-00 / PTh 28 Feb 2001
    # Routine to create a TOC bulleted list linked to the section headings
    # of a topic. A section heading is entered in one of the following forms:
    #   $headingPatternSp : \t++... spaces section heading
    #   $headingPatternDa : ---++... dashes section heading
    #   $headingPatternHt : <h[1-6]> HTML section heading </h[1-6]>
    # Parameters:
    #   $_[0] : the text of the current topic
    #   $_[1] : the topic we are in
    #   $_[2] : the web we are in
    #   $_[3] : attributes = "Topic" [web="Web"] [depth="N"]

    ##     $_[0]     $_[1]      $_[2]    $_[3]
    ## my( $theText, $theTopic, $theWeb, $attributes ) = @_;

    # get the topic name attribute
    my $topicname = extractNameValuePair( $_[3] )  || $_[1];

    # get the web name attribute
    my $web = extractNameValuePair( $_[3], "web" ) || $_[2];
    $web =~ s/\//\./g;
    my $webPath = $web;
    $webPath =~ s/\./\//g;

    # get the depth limit attribute
    my $depth = extractNameValuePair( $_[3], "depth" ) || 6;

    my $result  = "";
    my $line  = "";
    my $level = "";
    my @list  = ();

    if( "$web.$topicname" eq "$_[2].$_[1]" ) {
        # use text from parameter
        @list = split( /\n/, $_[0] );

    } else {
        # read text from file
        if ( ! &TWiki::Store::topicExists( $web, $topicname ) ) {
            return showError( "TOC: Cannot find topic \"$web.$topicname\"" );
        }
        @list = split( /\n/, handleCommonTags( 
            &TWiki::Store::readWebTopic( $web, $topicname ), $topicname, $web ) );
    }

    @list = grep { /(<\/?pre>)|($headerPatternDa)|($headerPatternSp)|($headerPatternHt)/i } @list;
    my $insidePre = 0;
    my $i = 0;
    my $tabs = "";
    my $anchor = "";
    my $highest = 99;
    foreach $line ( @list ) {
        if( $line =~ /^.*<pre>.*$/io ) {
            $insidePre = 1;
            $line = "";
        }
        if( $line =~ /^.*<\/pre>.*$/io ) {
            $insidePre = 0;
            $line = "";
        }
        if (!$insidePre) {
            $level = $line ;
            if ( $line =~  /$headerPatternDa/o ) {
                $level =~ s/$headerPatternDa/$1/go;
                $level = length $level;
                $line  =~ s/$headerPatternDa/$2/go;
            } elsif
               ( $line =~  /$headerPatternSp/o ) {
                $level =~ s/$headerPatternSp/$1/go;
                $level = length $level;
                $line  =~ s/$headerPatternSp/$2/go;
            } elsif
               ( $line =~  /$headerPatternHt/io ) {
                $level =~ s/$headerPatternHt/$1/gio;
                $line  =~ s/$headerPatternHt/$2/gio;
            }
            if( ( $line ) && ( $level <= $depth ) ) {
                $anchor = makeAnchorName( $line );
                # cut TOC exclude '---+ heading !! exclude'
                $line  =~ s/\s*$headerPatternNoTOC.+$//go;
                next unless $line;
                $highest = $level if( $level < $highest );
                $tabs = "";
                for( $i=0 ; $i<$level ; $i++ ) {
                    $tabs = "\t$tabs";
                }
                # Remove *bold* and _italic_ formatting
                $line =~ s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
                $line =~ s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
                # Prevent WikiLinks
                $line =~ s/\[\[.*\]\[(.*?)\]\]/$1/g;  # '[[...][...]]'
                $line =~ s/\[\[(.*?)\]\]/$1/ge;       # '[[...]]'
                $line =~ s/([\s\(])($webNameRegex)\.($wikiWordRegex)/$1<nop>$3/g;  # 'Web.TopicName'
                $line =~ s/([\s\(])($wikiWordRegex)/$1<nop>$2/g;  # 'TopicName'
                $line =~ s/([\s\(])($abbrevRegex)/$1<nop>$2/g;  # 'TLA'
                # create linked bullet item
                $line = "$tabs* <a href=\"$scriptUrlPath/$viewScript$scriptSuffix/$webPath/$topicname#$anchor\">$line</a>";
                $result .= "\n$line";
            }
        }
    }
    if( $result ) {
        if( $highest > 1 ) {
            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }
        return $result;

    } else {
        return showError("TOC: No TOC in \"$web.$topicname\"");
    }
}

# =========================
sub getPublicWebList
{
    # FIXME: Should this go elsewhere?
    # (Not in Store because Store should not be dependent on Prefs.)

    if( ! @publicWebList ) {
        # build public web list, e.g. exclude hidden webs, but include current web
        my @list = &TWiki::Store::getAllWebs( "" );
        my $item = "";
        my $hidden = "";
        foreach $item ( @list ) {
            $hidden = &TWiki::Prefs::getPreferencesValue( "NOSEARCHALL", $item );
            # exclude topics that are hidden or start with . or _ unless current web
            if( ( $item eq $TWiki::webName  ) || ( ( ! $hidden ) && ( $item =~ /^[^\.\_]/ ) ) ) {
                push( @publicWebList, $item );
            }
        }
    }
    return @publicWebList;
}

# =========================
sub handleWebAndTopicList
{
    my( $theAttr, $isWeb ) = @_;

    my $format = extractNameValuePair( $theAttr );
    $format = extractNameValuePair( $theAttr, "format" ) if( ! $format );
    my $separator = extractNameValuePair( $theAttr, "separator" ) || "\n";
    $format .= '$name' if( ! ( $format =~ /\$name/ ) );
    my $web = extractNameValuePair( $theAttr, "web" ) || "";
    my $webs = extractNameValuePair( $theAttr, "webs" ) || "public";
    my $selection = extractNameValuePair( $theAttr, "selection" ) || "";
    my $marker    = extractNameValuePair( $theAttr, "marker" ) || "selected";

    my @list = ();
    if( $isWeb ) {
        my @webslist = split( /,/, $webs );
        foreach my $aweb ( @webslist ) {
            if( $aweb eq "public" ) {
                push( @list, getPublicWebList() );
            } elsif( $aweb eq "webtemplate" ) {
                push( @list, grep { /^\_/o } &TWiki::Store::getAllWebs( "" ) );
            } else{
                push( @list, $aweb ) if( &TWiki::Store::webExists( $aweb ) );
            }
        }
    } else {
        $web = $webName if( ! $web );
        my $hidden = &TWiki::Prefs::getPreferencesValue( "NOSEARCHALL", $web );
        if( ( $web eq $TWiki::webName  ) || ( ! $hidden ) ) {
            @list = &TWiki::Store::getTopicNames( $web );
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
        $mark = ( $item eq $selection ) ? $marker : "";
        $line =~ s/\$marker/$mark/goi;
        $text .= "$line$separator";
    }
    $text =~ s/$separator$//s;  # remove last separator
    return $text;
}

# =========================
sub handleUrlParam
{
    my( $theParam ) = @_;

    $theParam = extractNameValuePair( $theParam );
    my $value = "";
    if( $cgiQuery ) {
        $value = $cgiQuery->param( $theParam );
        $value = "" unless( defined $value );
    }

    return $value;
}

# =========================
# Encode 8-bit-set characters for use in URLs (not using UTF8 URL
# encoding by browser)
sub handleUrlEncode
{
    my( $theStr, $doExtract ) = @_;

    $theStr = extractNameValuePair( $theStr ) if( $doExtract );
    $theStr =~ s/[\n\r]/\%3Cbr\%20\%3E/g;
    $theStr =~ s/\s+/\%20/g;
    $theStr =~ s/\&/\%26/g;
    $theStr =~ s/\</\%3C/g;
    $theStr =~ s/\>/\%3E/g;
    $theStr =~ s/([\x7f-\xff])/'%' . unpack( "H*", $1 ) /ge;

    return $theStr;
}

# =========================
sub handleEnvVariable
{
    my( $theVar ) = @_;
    my $value = $ENV{$theVar} || "";
    return $value;
}

# =========================
sub handleTmplP
{
    my( $theParam ) = @_;

    $theParam = extractNameValuePair( $theParam );
    my $value = &TWiki::Store::handleTmplP( $theParam );
    return $value;
}

# =========================
# Create spaced-out topic name for Ref-By search 
sub handleSpacedTopic
{
    my( $theTopic ) = @_;
    my $spacedTopic = $theTopic;
    $spacedTopic =~ s/($singleLowerAlphaRegex+)($singleUpperAlphaNumRegex+)/$1%20*$2/go;   # "%20*" is " *"
    return $spacedTopic;
}

# =========================
sub handleInternalTags
{
    # modify arguments directly, i.e. call by reference
    # $_[0] is text
    # $_[1] is topic
    # $_[2] is web

    # Make Edit URL unique for every edit - fix for RefreshEditPage
    $_[0] =~ s!%EDITURL%!"$scriptUrlPath/edit$scriptSuffix/%URLENCODE{\"%WEB%/%TOPIC%\"}%\?t=" . time()!ge;

    $_[0] =~ s/%NOP{(.*?)}%/$1/gs;  # remove NOP tag in template topics but show content
    $_[0] =~ s/%NOP%/<nop>/g;
    $_[0] =~ s/%TMPL\:P{(.*?)}%/&handleTmplP($1)/ge;
    $_[0] =~ s/%SEP%/&handleTmplP('"sep"')/ge;

    $_[0] =~ s/%HTTP_HOST%/&handleEnvVariable('HTTP_HOST')/ge;
    $_[0] =~ s/%REMOTE_ADDR%/&handleEnvVariable('REMOTE_ADDR')/ge;
    $_[0] =~ s/%REMOTE_PORT%/&handleEnvVariable('REMOTE_PORT')/ge;
    $_[0] =~ s/%REMOTE_USER%/&handleEnvVariable('REMOTE_USER')/ge;

    # Un-encoded topic and web names. Note: In form action, URL encode variables 
    # that might have 8-bit characters with %INTURLENCODE{"%TOPIC%"}%
    $_[0] =~ s/%TOPIC%/$_[1]/g;
    $_[0] =~ s/%BASETOPIC%/$topicName/g;
    $_[0] =~ s/%INCLUDINGTOPIC%/$includingTopicName/g;
    $_[0] =~ s/%SPACEDTOPIC%/&handleSpacedTopic($_[1])/ge;
    $_[0] =~ s/%WEB%/$_[2]/g;
    $_[0] =~ s/%BASEWEB%/$webName/g;
    $_[0] =~ s/%INCLUDINGWEB%/$includingWebName/g;

    $_[0] =~ s/%CHARSET%/$siteCharset/g;

    $_[0] =~ s/%TOPICLIST{(.*?)}%/&handleWebAndTopicList($1,'0')/ge;
    $_[0] =~ s/%WEBLIST{(.*?)}%/&handleWebAndTopicList($1,'1')/ge;
    $_[0] =~ s/%WIKIHOMEURL%/$wikiHomeUrl/g;
    $_[0] =~ s/%SCRIPTURL%/$urlHost$scriptUrlPath/g;
    $_[0] =~ s/%SCRIPTURLPATH%/$scriptUrlPath/g;
    $_[0] =~ s/%SCRIPTSUFFIX%/$scriptSuffix/g;
    $_[0] =~ s/%PUBURL%/$urlHost$pubUrlPath/g;
    $_[0] =~ s/%PUBURLPATH%/$pubUrlPath/g;
    $_[0] =~ s/%ATTACHURL%/$urlHost$pubUrlPath\/$_[2]\/$_[1]/g;
    $_[0] =~ s/%ATTACHURLPATH%/$pubUrlPath\/$_[2]\/$_[1]/g;
    $_[0] =~ s/%URLPARAM{(.*?)}%/&handleUrlParam($1)/ge;
    $_[0] =~ s/%URLENCODE{(.*?)}%/&handleUrlEncode($1,1)/ge;
    $_[0] =~ s/%INTURLENCODE{(.*?)}%/&handleUrlEncode($1,1)/ge;
    $_[0] =~ s/%DATE%/&getGmDate()/ge; # deprecated, but used in signatures
    $_[0] =~ s/%GMTIME%/&handleTime("","gmtime")/ge;
    $_[0] =~ s/%GMTIME{(.*?)}%/&handleTime($1,"gmtime")/ge;
    $_[0] =~ s/%SERVERTIME%/&handleTime("","servertime")/ge;
    $_[0] =~ s/%SERVERTIME{(.*?)}%/&handleTime($1,"servertime")/ge;
    $_[0] =~ s/%WIKIVERSION%/$wikiversion/g;
    $_[0] =~ s/%USERNAME%/$userName/g;
    $_[0] =~ s/%WIKINAME%/$wikiName/g;
    $_[0] =~ s/%WIKIUSERNAME%/$wikiUserName/g;
    $_[0] =~ s/%WIKITOOLNAME%/$wikiToolName/g;
    $_[0] =~ s/%MAINWEB%/$mainWebname/g;
    $_[0] =~ s/%TWIKIWEB%/$twikiWebname/g;
    $_[0] =~ s/%HOMETOPIC%/$mainTopicname/g;
    $_[0] =~ s/%WIKIUSERSTOPIC%/$wikiUsersTopicname/g;
    $_[0] =~ s/%WIKIPREFSTOPIC%/$wikiPrefsTopicname/g;
    $_[0] =~ s/%WEBPREFSTOPIC%/$webPrefsTopicname/g;
    $_[0] =~ s/%NOTIFYTOPIC%/$notifyTopicname/g;
    $_[0] =~ s/%STATISTICSTOPIC%/$statisticsTopicname/g;
    $_[0] =~ s/%STARTINCLUDE%//g;
    $_[0] =~ s/%STOPINCLUDE%//g;
    $_[0] =~ s/%SEARCH{(.*?)}%/&handleSearchWeb($1)/ge; # can be nested
    $_[0] =~ s/%SEARCH{(.*?)}%/&handleSearchWeb($1)/ge if( $_[0] =~ /%SEARCH/o );
    $_[0] =~ s/%METASEARCH{(.*?)}%/&handleMetaSearch($1)/ge;

}

# =========================
sub takeOutVerbatim
{
    my( $intext, $verbatim ) = @_;
    
    if( $intext !~ /<verbatim>/oi ) {
        return( $intext );
    }
    
    # Exclude text inside verbatim from variable substitution
    
    my $tmp = "";
    my $outtext = "";
    my $nesting = 0;
    my $verbatimCount = $#{$verbatim} + 1;
    
    foreach( split( /\n/, $intext ) ) {
        if( /^(\s*)<verbatim>\s*$/i ) {
            $nesting++;
            if( $nesting == 1 ) {
                $outtext .= "$1%_VERBATIM$verbatimCount%\n";
                $tmp = "";
                next;
            }
        } elsif( m|^\s*</verbatim>\s*$|i ) {
            $nesting--;
            if( ! $nesting ) {
                $verbatim->[$verbatimCount++] = $tmp;
                next;
            }
        }

        if( $nesting ) {
            $tmp .= "$_\n";
        } else {
            $outtext .= "$_\n";
        }
    }
    
    # Deal with unclosed verbatim
    if( $nesting ) {
        $verbatim->[$verbatimCount] = $tmp;
    }
       
    return $outtext;
}

# =========================
# set type=verbatim to get back original text
#     type=pre to convert to HTML readable verbatim text
sub putBackVerbatim
{
    my( $text, $type, @verbatim ) = @_;
    
    for( my $i=0; $i<=$#verbatim; $i++ ) {
        my $val = $verbatim[$i];
        if( $type ne "verbatim" ) {
            $val =~ s/</&lt;/g;
            $val =~ s/</&gt;/g;
            $val =~ s/\t/   /g; # A shame to do this, but been in TWiki.org have converted
                                # 3 spaces to tabs since day 1
        }
        $text =~ s|%_VERBATIM$i%|<$type>\n$val</$type>|;
    }

    return $text;
}



# =========================
sub handleCommonTags
{
    my( $text, $theTopic, $theWeb, @theProcessedTopics ) = @_;

    # PTh 22 Jul 2000: added $theWeb for correct handling of %INCLUDE%, %SEARCH%
    if( !$theWeb ) {
        $theWeb = $webName;
    }
    
    my @verbatim = ();
    $text = takeOutVerbatim( $text, \@verbatim );

    # handle all preferences and internal tags (for speed: call by reference)
    $includingWebName = $theWeb;
    $includingTopicName = $theTopic;
    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );

    # recursively process multiple embedded %INCLUDE% statements and prefs
    $text =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $theTopic, $theWeb, \@verbatim, @theProcessedTopics )/ge;

    # Wiki Plugin Hook
    &TWiki::Plugins::commonTagsHandler( $text, $theTopic, $theWeb, 0 );

    # handle tags again because of plugin hook
    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );

    $text =~ s/%TOC{([^}]*)}%/&handleToc($text,$theTopic,$theWeb,$1)/ge;
    $text =~ s/%TOC%/&handleToc($text,$theTopic,$theWeb,"")/ge;
    
    # Ideally would put back in getRenderedVersion rather than here which would save removing
    # it again!  But this would mean altering many scripts to pass back verbatim
    $text = putBackVerbatim( $text, "verbatim", @verbatim );

    return $text;
}

# =========================
sub handleMetaTags
{
    my( $theWeb, $theTopic, $text, $meta, $isTopRev ) = @_;

    $text =~ s/%META{\s*"form"\s*}%/&renderFormData( $theWeb, $theTopic, $meta )/ge;
    $text =~ s/%META{\s*"attachments"\s*(.*)}%/&TWiki::Attach::renderMetaData( $theWeb,
                                                $theTopic, $meta, $1, $isTopRev )/ge;
    $text =~ s/%META{\s*"moved"\s*}%/&renderMoved( $theWeb, $theTopic, $meta )/ge;
    $text =~ s/%META{\s*"parent"\s*(.*)}%/&renderParent( $theWeb, $theTopic, $meta, $1 )/ge;

    $text = &TWiki::handleCommonTags( $text, $theTopic );

    return $text;
}

# ========================
sub renderParent
{
    my( $web, $topic, $meta, $args ) = @_;
    
    my $text = "";

    my $dontRecurse = 0;
    my $noWebHome = 0;
    my $prefix = "";
    my $suffix = "";
    my $usesep = "";

    if( $args ) {
       $dontRecurse = extractNameValuePair( $args, "dontrecurse" );
       $noWebHome =   extractNameValuePair( $args, "nowebhome" );
       $prefix =      extractNameValuePair( $args, "prefix" );
       $suffix =      extractNameValuePair( $args, "suffix" );
       $usesep =      extractNameValuePair( $args, "separator" );
    }

    if( ! $usesep ) {
       $usesep = " &gt; ";
    }

    my %visited = ();
    $visited{"$web.$topic"} = 1;

    my $sep = "";
    my $cWeb = $web;

    while( 1 ) {
        my %parent = $meta->findOne( "TOPICPARENT" );
        if( %parent ) {
            my $name = $parent{"name"};
            my $pWeb = $cWeb;
            my $pTopic = $name;
            if( $name =~ /^(.*)\.(.*)$/ ) {
               $pWeb = $1;
               $pTopic = $2;
            }
            if( $noWebHome && ( $pTopic eq $mainTopicname ) ) {
               last;  # exclude "WebHome"
            }
            $text = "[[$pWeb.$pTopic][$pTopic]]$sep$text";
            $sep = $usesep;
            if( $dontRecurse || ! $name ) {
               last;
            } else {
               my $dummy;
               if( $visited{"$pWeb.$pTopic"} ) {
                  last;
               } else {
                  $visited{"$pWeb.$pTopic"} = 1;
               }
               if( TWiki::Store::topicExists( $pWeb, $pTopic ) ) {
                   ( $meta, $dummy ) = TWiki::Store::readTopMeta( $pWeb, $pTopic );
               } else {
                   last;
               }
               $cWeb = $pWeb;
            }
        } else {
            last;
        }
    }

    if( $text && $prefix ) {
       $text = "$prefix$text";
    }

    if( $text && $suffix ) {
       $text .= $suffix;
    }

    if( $text ) {
        $text = handleCommonTags( $text, $topic, $web );
        $text = getRenderedVersion( $text, $web );
    }

    return $text;
}

# ========================
sub renderMoved
{
    my( $web, $topic, $meta ) = @_;
    
    my $text = "";
    
    my %moved = $meta->findOne( "TOPICMOVED" );
    
    if( %moved ) {
        my $from = $moved{"from"};
        $from =~ /(.*)\.(.*)/;
        my $fromWeb = $1;
        my $fromTopic = $2;
        my $to   = $moved{"to"};
        $to =~ /(.*)\.(.*)/;
        my $toWeb = $1;
        my $toTopic = $2;
        my $by   = $moved{"by"};
        $by = userToWikiName( $by );
        my $date = $moved{"date"};
        $date = formatGmTime( $date );
        
        # Only allow put back, if current web and topic match stored to information
        my $putBack = "";
        if( $web eq $toWeb && $topic eq $toTopic ) {
            $putBack  = " - <a title=\"Click to move topic back to previous location, with option to change references.\"";
            $putBack .= " href=\"$scriptUrlPath/rename/$web/$topic?newweb=$fromWeb&newtopic=$fromTopic&";
            $putBack .= "confirm=on\">put it back</a>";
        }
        $text = "<p><i><nop>$to moved from <nop>$from on $date by $by </i>$putBack</p>";
    }
    
    $text = handleCommonTags( $text, $topic, $web );
    $text = getRenderedVersion( $text, $web );

    
    return $text;
}


# =========================
sub renderFormData
{
    my( $web, $topic, $meta ) = @_;

    my $metaText = "";
    
    my %form = $meta->findOne( "FORM" );
    if( %form ) {
        my $name = $form{"name"};
        $metaText = "<p />\n<table border=\"1\" cellspacing=\"0\" cellpadding=\"0\">\n   <tr>";
        $metaText .= "<th colspan=\"2\" align=\"center\" bgcolor=\"#99CCCC\"> $name </th></tr>\n";        
        
        my @fields = $meta->find( "FIELD" );
        foreach my $field ( @fields ) {
            my $title = $field->{"title"};
            my $value = $field->{"value"};
            $metaText .= "<tr><th bgcolor=\"#99CCCC\" align=\"right\"> $title:</th><td align=\"left\"> $value </td></tr>\n";
        }

        $metaText .= "</table>\n";

        $metaText = getRenderedVersion( $metaText, $web );
    }

    return $metaText;
}

# =========================
sub encodeSpecialChars
{
    my( $text ) = @_;
    
    $text =~ s/&/%_A_%/g;
    $text =~ s/\"/%_Q_%/g;
    $text =~ s/>/%_G_%/g;
    $text =~ s/</%_L_%/g;
    # PTh, JoachimDurchholz 22 Nov 2001: Fix for Codev.OperaBrowserDoublesEndOfLines
    $text =~ s/(\r*\n|\r)/%_N_%/g;

    return $text;
}

sub decodeSpecialChars
{
    my( $text ) = @_;
    
    $text =~ s/%_N_%/\r\n/g;
    $text =~ s/%_L_%/</g;
    $text =~ s/%_G_%/>/g;
    $text =~ s/%_Q_%/\"/g;
    $text =~ s/%_A_%/&/g;

    return $text;
}


# =========================
sub emitList {
    my( $theType, $theElement, $theDepth ) = @_;
    my $result = "";
    $isList = 1;

    if( @listTypes < $theDepth ) {
        my $firstTime = 1;
        while( @listTypes < $theDepth ) {
            push( @listTypes, $theType );
            push( @listElements, $theElement );
            $result .= "<$theElement>\n" unless( $firstTime );
            $result .= "<$theType>\n";
            $firstTime = 0;
        }

    } elsif( @listTypes > $theDepth ) {
        while( @listTypes > $theDepth ) {
            local($_) = pop @listElements;
            $result .= "</$_>\n";
            local($_) = pop @listTypes;
            $result .= "</$_>\n";
        }
        $result .= "</$listElements[$#listElements]>\n" if( @listElements );

    } elsif( @listElements ) {
        $result = "</$listElements[$#listElements]>\n";
    }

    if( ( @listTypes ) && ( $listTypes[$#listTypes] ne $theType ) ) {
        $result .= "</$listTypes[$#listTypes]>\n<$theType>\n";
        $listTypes[$#listTypes] = $theType;
        $listElements[$#listElements] = $theElement;
    }

    return $result;
}

# =========================
sub emitTR {
    my ( $thePre, $theRow, $insideTABLE ) = @_;

    my $text = "";
    my $attr = "";
    my $l1 = 0;
    my $l2 = 0;
    if( $insideTABLE ) {
        $text = "$thePre<tr>";
    } else {
        $text = "$thePre<table border=\"1\" cellspacing=\"0\" cellpadding=\"1\"> <tr>";
    }
    $theRow =~ s/\t/   /g;  # change tabs to space
    $theRow =~ s/\s*$//;    # remove trailing spaces
    $theRow =~ s/(\|\|+)/$TranslationToken . length($1) . "\|"/ge;  # calc COLSPAN
    foreach( split( /\|/, $theRow ) ) {
        $attr = "";
        #AS 25-5-01 Fix to avoid matching also single columns
        if ( s/$TranslationToken([0-9]+)// ) { # No o flag for mod-perl compatibility
            $attr = " colspan=\"$1\"" ;
        }
        s/^\s+$/ &nbsp; /;
        /^(\s*).*?(\s*)$/;
        $l1 = length( $1 || "" );
        $l2 = length( $2 || "" );
        if( $l1 >= 2 ) {
            if( $l2 <= 1 ) {
                $attr .= ' align="right"';
            } else {
                $attr .= ' align="center"';
            }
        }
        if( /^\s*(\*.*\*)\s*$/ ) {
            $text .= "<th$attr bgcolor=\"#99CCCC\"> $1 </th>";
        } else {
            $text .= "<td$attr> $_ </td>";
        }
    }
    $text .= "</tr>";
    return $text;
}

# =========================
sub fixedFontText
{
    my( $theText, $theDoBold ) = @_;
    # preserve white space, so replace it by "&nbsp; " patterns
    $theText =~ s/\t/   /g;
    $theText =~ s|((?:[\s]{2})+)([^\s])|'&nbsp; ' x (length($1) / 2) . "$2"|eg;
    if( $theDoBold ) {
        return "<code><b>$theText</b></code>";
    } else {
        return "<code>$theText</code>";
    }
}

# =========================
# Build an HTML <Hn> element with suitable anchor for linking from %TOC%
sub makeAnchorHeading
{
    my( $theText, $theLevel ) = @_;

    # - Need to build '<nop><h1><a name="atext"> text </a></h1>'
    #   type markup.
    # - Initial '<nop>' is needed to prevent subsequent matches.
    # - Need to make sure that <a> tags are not nested, i.e. in
    #   case heading has a WikiName or ABBREV that gets linked
    # - filter out $headerPatternNoTOC ( '!!' and '%NOTOC%' )

    my $text = $theText;
    my $anchorName = &makeAnchorName( $text );
    $text =~ s/$headerPatternNoTOC//o; # filter '!!', '%NOTOC%'
    my $hasAnchor = 0;  # text contains potential anchor
    $hasAnchor = 1 if( $text =~ m/<a /i );
    $hasAnchor = 1 if( $text =~ m/\[\[/ );

    $hasAnchor = 1 if( $text =~ m/(^|[\s\(])($abbrevRegex)/ );
    $hasAnchor = 1 if( $text =~ m/(^|[\s\(])($webNameRegex)\.($wikiWordRegex)/ );
    $hasAnchor = 1 if( $text =~ m/(^|[\s\(])($wikiWordRegex)/ );
    if( $hasAnchor ) {
        # FIXME: '<h1><a name="atext"></a></h1> WikiName' has an
        #        empty <a> tag, which is not HTML conform
        $text = "<nop><h$theLevel><a name=\"$anchorName\"> </a> $text <\/h$theLevel>";
    } else {
        $text = "<nop><h$theLevel><a name=\"$anchorName\"> $text <\/a><\/h$theLevel>";
    }

    return $text;
}

# =========================
# Build a valid HTML anchor name
sub makeAnchorName
{
    my( $anchorName ) = @_;

    $anchorName =~ s/^[\s\#\_]*//;          # no leading space nor '#', '_'
    $anchorName =~ s/[\s\_]*$//;            # no trailing space, nor '_'
    $anchorName =~ s/<\w[^>]*>//gi;         # remove HTML tags
    $anchorName =~ s/\&\#?[a-zA-Z0-9]*;//g; # remove HTML entities
    $anchorName =~ s/^(.+?)\s*$headerPatternNoTOC.*/$1/o; # filter TOC excludes if not at beginning
    $anchorName =~ s/$headerPatternNoTOC//o; # filter '!!', '%NOTOC%'
    # FIXME: More efficient to match with '+' on next line:
    $anchorName =~ s/$singleMixedNonAlphaNumRegex/_/g;      # only allowed chars
    $anchorName =~ s/__+/_/g;               # remove excessive '_'
    $anchorName =~ s/^(.{32})(.*)$/$1/;     # limit to 32 chars

    # Encode 8-bit characters in anchor - due to Mozilla problems with
    # URL-encoded anchors, such characters are mapped to '_'.  If this
    # causes some anchors to collide, a consistent 8-bit-to-7-bit
    # alphabetic character mapping could be defined to minimise this issue.  
    $anchorName =~ s/([\x7f-\xff])/_/g;		# Map 8-bit chars
    ##$anchorName =~ handleUrlEncode( $anchorName );	# Was doing URL-encode 

    return $anchorName;
}

# =========================
sub internalLink {
    my( $thePreamble, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink ) = @_;
    # $thePreamble is text used before the TWiki link syntax
    # $doLink is boolean: false means suppress link for non-existing pages

    # Get rid of leading/trailing spaces in topic name
    $theTopic =~ s/^\s*//;
    $theTopic =~ s/\s*$//;

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word. TODO: Try to turn this off,
    # avoiding spaces being stripped elsewhere - e.g. $doPreserveSpacedOutWords 
    $theTopic =~ s/^(.)/\U$1/;
    $theTopic =~ s/\s($singleMixedAlphaNumRegex)/\U$1/go;	

    # Add <nop> before WikiWord inside link text to prevent double links
    $theLinkText =~ s/([\s\(])($singleUpperAlphaRegex)/$1<nop>$2/go;

    my $exist = &TWiki::Store::topicExists( $theWeb, $theTopic );
    # I18N - Only apply plural processing if site language is English,
    # and to topic names ending in 's'.
    if(  ( $doPluralToSingular ) && ( $siteLang eq 'en' ) 
		&& ( $theTopic =~ /s$/ ) && ! ( $exist ) ) {
        # Topic name is plural in form and doesn't exist as written
        my $tmp = $theTopic;
        $tmp =~ s/ies$/y/;       # plurals like policy / policies
        $tmp =~ s/sses$/ss/;     # plurals like address / addresses
        $tmp =~ s/([Xx])es$/$1/; # plurals like box / boxes
        $tmp =~ s/([A-Za-rt-z])s$/$1/; # others, excluding ending ss like address(es)
        if( &TWiki::Store::topicExists( $theWeb, $tmp ) ) {
            $theTopic = $tmp;
            $exist = 1;
        }
    }

    my $text = $thePreamble;
    if( $exist) {
        if( $theAnchor ) {
            my $anchor = makeAnchorName( $theAnchor );
            $text .= "<a href=\"$scriptUrlPath/view$scriptSuffix/"
                  .  "$theWeb/$theTopic\#$anchor\">$theLinkText<\/a>";
            return $text;
        } else {
            $text .= "<a href=\"$scriptUrlPath/view$scriptSuffix/"
                  .  "$theWeb/$theTopic\">$theLinkText<\/a>";
            return $text;
        }

    } elsif( $doLink ) {
        $text .= "<span style='background : $newTopicBgColor;'>"
              .  "<font color=\"$newTopicFontColor\">$theLinkText</font></span>"
              .  "<a href=\"$scriptUrlPath/edit$scriptSuffix/$theWeb/$theTopic?topicparent=$webName.$topicName\">?</a>";
        return $text;

    } else {
        $text .= $theLinkText;
        return $text;
    }
}

# =========================
# Handle most internal and external links
sub specificLink
{
    my( $thePreamble, $theWeb, $theTopic, $theText, $theLink ) = @_;

    # format: $thePreamble[[$theText]]
    # format: $thePreamble[[$theLink][$theText]]
    #
    # Current page's $theWeb and $theTopic are also used

    # Strip leading/trailing spaces
    $theLink =~ s/^\s*//;
    $theLink =~ s/\s*$//;

    if( $theLink =~ /^$linkProtocolPattern\:/ ) {

        # External link: add <nop> before WikiWord and ABBREV 
	# inside link text, to prevent double links
	$theText =~ s/([\s\(])($singleUpperAlphaRegex)/$1<nop>$2/go;
        return "$thePreamble<a href=\"$theLink\" target=\"_top\">$theText</a>";

    } else {

	# Internal link: get any 'Web.' prefix, or use current web
	$theLink =~ s/^($webNameRegex|$defaultWebNameRegex)\.//;
	my $web = $1 || $theWeb;
	(my $baz = "foo") =~ s/foo//;       # reset $1, defensive coding

	# Extract '#anchor'
	# FIXME and NOTE: Had '-' as valid anchor character, removed
	# $theLink =~ s/(\#[a-zA-Z_0-9\-]*$)//;
	$theLink =~ s/($anchorRegex$)//;
	my $anchor = $1 || "";

	# Get the topic name
	my $topic = $theLink || $theTopic;  # remaining is topic
	$topic =~ s/\&[a-z]+\;//gi;        # filter out &any; entities
	$topic =~ s/\&\#[0-9]+\;//g;       # filter out &#123; entities
	$topic =~ s/[\\\/\#\&\(\)\{\}\[\]\<\>\!\=\:\,\.]//g;
	$topic =~ s/$securityFilter//go;    # filter out suspicious chars
	if( ! $topic ) {
	    return "$thePreamble$theText"; # no link if no topic
	}

	return internalLink( $thePreamble, $web, $topic, $theText, $anchor, 1 );
    }

}

# =========================
sub externalLink
{
    my( $pre, $url ) = @_;
    if( $url =~ /\.(gif|jpg|jpeg|png)$/i ) {
        my $filename = $url;
        $filename =~ s@.*/([^/]*)@$1@go;
        return "$pre<img src=\"$url\" alt=\"$filename\" />";
    }

    return "$pre<a href=\"$url\" target=\"_top\">$url</a>";
}

# =========================
sub mailtoLink
{
    my( $theAccount, $theSubDomain, $theTopDomain ) = @_;

    my $addr = "$theAccount\@$theSubDomain$TWiki::noSpamPadding\.$theTopDomain";
    return "<a href=\"mailto\:$addr\">$addr</a>";
}

# =========================
sub mailtoLinkFull
{
    my( $theAccount, $theSubDomain, $theTopDomain, $theLinkText ) = @_;

    my $addr = "$theAccount\@$theSubDomain$TWiki::noSpamPadding\.$theTopDomain";
    return "<a href=\"mailto\:$addr\">$theLinkText</a>";
}

# =========================
sub mailtoLinkSimple
{
    # Does not do any anti-spam padding, because address will not include '@'
    my( $theMailtoString, $theLinkText ) = @_;	

    # Defensive coding
    if ($theMailtoString =~ s/@//g ) {
    	writeWarning("mailtoLinkSimple called with an '\@' in string - internal TWiki error");
    }
    return "<a href=\"mailto\:$theMailtoString\">$theLinkText</a>";
}


# =========================
sub getRenderedVersion {
    my( $text, $theWeb, $meta ) = @_;
    my( $head, $result, $extraLines, $insidePRE, $insideTABLE, $insideNoAutoLink );

    return "" unless $text;  # nothing to do

    # FIXME: Get $theTopic from parameter to handle [[#anchor]] correctly
    # (fails in %INCLUDE%, %SEARCH%)
    my $theTopic = $topicName;

    # PTh 22 Jul 2000: added $theWeb for correct handling of %INCLUDE%, %SEARCH%
    if( !$theWeb ) {
        $theWeb = $webName;
    }

    $head = "";
    $result = "";
    $insidePRE = 0;
    $insideTABLE = 0;
    $insideNoAutoLink = 0;      # PTh 02 Feb 2001: Added Codev.DisableWikiWordLinks
    $isList = 0;
    @listTypes = ();
    @listElements = ();

    # Initial cleanup
    $text =~ s/\r//g;
    $text =~ s/(\n?)$/\n<nop>\n/s; # clutch to enforce correct rendering at end of doc
    $text =~ s/$TranslationToken/!/go;	# Convert any occurrences of token
    					# (very unlikely)

    my @verbatim = ();
    $text = takeOutVerbatim( $text, \@verbatim );
    $text =~ s/\\\n//g;  # Join lines ending in "\"

    # do not render HTML head, style sheets and scripts
    if( $text =~ m/<body[\s\>]/i ) {
        my $bodyTag = "";
        my $bodyText = "";
        ( $head, $bodyTag, $bodyText ) = split( /(<body)/i, $text, 3 );
        $text = $bodyTag . $bodyText;
    }
    
    # Wiki Plugin Hook
    &TWiki::Plugins::startRenderingHandler( $text, $theWeb, $meta );

    foreach( split( /\n/, $text ) ) {

        # change state:
        m|<pre>|i  && ( $insidePRE = 1 );
        m|</pre>|i && ( $insidePRE = 0 );
        m|<noautolink>|i   && ( $insideNoAutoLink = 1 );
        m|</noautolink>|i  && ( $insideNoAutoLink = 0 );

        if( $insidePRE ) {
            # inside <PRE>

            # close list tags if any
            if( @listTypes ) {
                $result .= &emitList( "", "", 0 );
                $isList = 0;
            }

# Wiki Plugin Hook
            &TWiki::Plugins::insidePREHandler( $_ );

            s/(.*)/$1\n/;
            s/\t/   /g;		# Three spaces
            $result .= $_;

        } else {
          # normal state, do Wiki rendering

# Wiki Plugin Hook
          &TWiki::Plugins::outsidePREHandler( $_ );
          $extraLines = undef;   # Plugins might introduce extra lines
          do {                   # Loop over extra lines added by plugins
            $_ = $extraLines if( defined $extraLines );
            s/^(.*?)\n(.*)$/$1/s;
            $extraLines = $2;    # Save extra lines, need to parse each separately

# Blockquote
            s/^>(.*?)$/> <cite> $1 <\/cite><br \/>/g;

# Embedded HTML
            s/\<(\!\-\-)/$TranslationToken$1/g;  # Allow standalone "<!--"
            s/(\-\-)\>/$1$TranslationToken/g;    # Allow standalone "-->"
            s/(\<\<+)/"&lt\;" x length($1)/ge;
            s/(\>\>+)/"&gt\;" x length($1)/ge;
            s/\<nop\>/nopTOKEN/g;  # defuse <nop> inside HTML tags
            s/\<(\S.*?)\>/$TranslationToken$1$TranslationToken/g;
            s/</&lt\;/g;
            s/>/&gt\;/g;
            s/$TranslationToken(\S.*?)$TranslationToken/\<$1\>/go;
            s/nopTOKEN/\<nop\>/g;
            s/(\-\-)$TranslationToken/$1\>/go;
            s/$TranslationToken(\!\-\-)/\<$1/go;

# Handle embedded URLs
            s!(^|[\-\*\s\(])($linkProtocolPattern\:([^\s\<\>\"]+[^\s\.\,\!\?\;\:\)\<]))!&externalLink($1,$2)!geo;

# Entities
            s/&(\w+?)\;/$TranslationToken$1\;/g;      # "&abc;"
            s/&(\#[0-9]+)\;/$TranslationToken$1\;/g;  # "&#123;"
            s/&/&amp;/g;                              # escape standalone "&"
            s/$TranslationToken/&/go;

# Headings
            # '<h6>...</h6>' HTML rule
            s/$headerPatternHt/&makeAnchorHeading($2,$1)/geoi;
            # '\t+++++++' rule
            s/$headerPatternSp/&makeAnchorHeading($2,(length($1)))/geo;
            # '----+++++++' rule
            s/$headerPatternDa/&makeAnchorHeading($2,(length($1)))/geo;

# Horizontal rule
            s/^---+/<hr \/>/;
            s!^([a-zA-Z0-9]+)----*!<table width=\"100%\"><tr><td valign=\"bottom\"><h2>$1</h2></td><td width=\"98%\" valign=\"middle\"><hr /></td></tr></table>!o;

# Table of format: | cell | cell |
            # PTh 25 Jan 2001: Forgiving syntax, allow trailing white space
            if( $_ =~ /^(\s*)\|.*\|\s*$/ ) {
                s/^(\s*)\|(.*)/&emitTR($1,$2,$insideTABLE)/e;
                $insideTABLE = 1;
            } elsif( $insideTABLE ) {
                $result .= "</table>\n";
                $insideTABLE = 0;
            }

# Lists and paragraphs
            s/^\s*$/<p \/>/o                 && ( $isList = 0 );
            m/^(\S+?)/o                      && ( $isList = 0 );
            s/^(\t+)(\S+?):\s/<dt> $2<\/dt><dd> /o && ( $result .= &emitList( "dl", "dd", length $1 ) );
            s/^(\t+)\* /<li> /o              && ( $result .= &emitList( "ul", "li", length $1 ) );
            s/^(\t+)\d+\.? ?/<li> /o         && ( $result .= &emitList( "ol", "li", length $1 ) );
            if( ! $isList ) {
                $result .= &emitList( "", "", 0 );
                $isList = 0;
            }

# '#WikiName' anchors
            s/^(\#)($wikiWordRegex)/ '<a name="' . &makeAnchorName( $2 ) . '"><\/a>'/ge;

# enclose in white space for the regex that follow
             s/(.*)/\n$1\n/;

# Emphasizing
            # PTh 25 Sep 2000: More relaxed rules, allow leading '(' and trailing ',.;:!?)'
            s/([\s\(])==([^\s]+?|[^\s].*?[^\s])==([\s\,\.\;\:\!\?\)])/$1 . &fixedFontText( $2, 1 ) . $3/ge;
            s/([\s\(])__([^\s]+?|[^\s].*?[^\s])__([\s\,\.\;\:\!\?\)])/$1<strong><em>$2<\/em><\/strong>$3/g;
            s/([\s\(])\*([^\s]+?|[^\s].*?[^\s])\*([\s\,\.\;\:\!\?\)])/$1<strong>$2<\/strong>$3/g;
            s/([\s\(])_([^\s]+?|[^\s].*?[^\s])_([\s\,\.\;\:\!\?\)])/$1<em>$2<\/em>$3/g;
            s/([\s\(])=([^\s]+?|[^\s].*?[^\s])=([\s\,\.\;\:\!\?\)])/$1 . &fixedFontText( $2, 0 ) . $3/ge;

# Mailto
	    # Email addresses must always be 7-bit, even within I18N sites

	    # RD 27 Mar 02: Mailto improvements - FIXME: check security...
	    # Explicit [[mailto:... ]] link without an '@' - hence no 
	    # anti-spam padding needed.
            # '[[mailto:string display text]]' link (no '@' in 'string'):
            s/\[\[mailto\:([^\s\@]+)\s+(.+?)\]\]/&mailtoLinkSimple( $1, $2 )/ge;

	    # Explicit [[mailto:... ]] link including '@', with anti-spam 
	    # padding, so match name@subdom.dom.
            # '[[mailto:string display text]]' link
            s/\[\[mailto\:([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.(.+?)(\s+|\]\[)(.*?)\]\]/&mailtoLinkFull( $1, $2, $3, $5 )/ge;

	    # Normal mailto:foo@example.com ('mailto:' part optional)
	    # FIXME: Should be '?' after the 'mailto:'...
            s/([\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . &mailtoLink( $2, $3, $4 )/ge;

# Make internal links
	    # Spaced-out Wiki words with alternative link text
            # '[[Web.odd wiki word#anchor][display text]]' link:
            s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&specificLink("",$theWeb,$theTopic,$2,$1)/ge;
            # RD 25 Mar 02: Codev.EasierExternalLinking
            # '[[URL#anchor display text]]' link:
            s/\[\[([a-z]+\:\S+)\s+(.*?)\]\]/&specificLink("",$theWeb,$theTopic,$2,$1)/ge;
	    # Spaced-out Wiki words
            # '[[Web.odd wiki word#anchor]]' link:
            s/\[\[([^\]]+)\]\]/&specificLink("",$theWeb,$theTopic,$1,$1)/ge;

            # do normal WikiWord link if not disabled by <noautolink> or NOAUTOLINK preferences variable
            unless( $noAutoLink || $insideNoAutoLink ) {

                # 'Web.TopicName#anchor' link:
                s/([\s\(])($webNameRegex)\.($wikiWordRegex)($anchorRegex)/&internalLink($1,$2,$3,"$TranslationToken$3$4$TranslationToken",$4,1)/geo;
                # 'Web.TopicName' link:
                s/([\s\(])($webNameRegex)\.($wikiWordRegex)/&internalLink($1,$2,$3,"$TranslationToken$3$TranslationToken","",1)/geo;

                # 'TopicName#anchor' link:
                s/([\s\(])($wikiWordRegex)($anchorRegex)/&internalLink($1,$theWeb,$2,"$TranslationToken$2$3$TranslationToken",$3,1)/geo;

                # 'TopicName' link:
		s/([\s\(])($wikiWordRegex)/&internalLink($1,$theWeb,$2,$2,"",1)/geo;

		# Handle acronyms/abbreviations of three or more letters
                # 'Web.ABBREV' link:
                s/([\s\(])($webNameRegex)\.($abbrevRegex)/&internalLink($1,$2,$3,$3,"",0)/geo;
                # 'ABBREV' link:
		s/([\s\(])($abbrevRegex)/&internalLink($1,$theWeb,$2,$2,"",0)/geo;
                # (deprecated <link> moved to DefaultPlugin)

                s/$TranslationToken(\S.*?)$TranslationToken/$1/go;
            }

            s/^\n//;
            s/\t/   /g;
            $result .= $_;

          } while( defined( $extraLines ) );  # extra lines produced by plugins
        }
    }
    if( $insideTABLE ) {
        $result .= "</table>\n";
    }
    $result .= &emitList( "", "", 0 );
    if( $insidePRE ) {
        $result .= "</pre>\n";
    }

    # Wiki Plugin Hook
    &TWiki::Plugins::endRenderingHandler( $result );

    $result = putBackVerbatim( $result, "pre", @verbatim );

    $result =~ s|\n?<nop>\n$||o; # clean up clutch
    return "$head$result";
}

1;
