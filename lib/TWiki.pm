#
# TWiki WikiClone ($wikiversion has version info)
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999-2001 Peter Thoeny, Peter@Thoeny.com
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

## 0501 kk : vvv Added for revDate2EpSecs
use Time::Local;

use strict;

# ===========================
# TWiki config variables:
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
        $statisticsTopicname $statsTopViews $statsTopContrib
        $numberOfRevisions $editLockTime
        $attachAsciiPath $scriptSuffix $wikiversion
        $safeEnvPath $mailProgram $noSpamPadding $mimeTypesFilename
        $doKeepRevIfEditLock $doGetScriptUrlFromCgi $doRemovePortNumber
        $doRemoveImgInMailnotify $doRememberRemoteUser $doPluralToSingular
        $doHidePasswdInRegistration $doSecureInclude
        $doLogTopicView $doLogTopicEdit $doLogTopicSave $doLogRename
        $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff
        $doLogTopicChanges $doLogTopicSearch $doLogRegistration
        $disableAllPlugins @isoMonth @weekDay 
	$TranslationToken %mon2num $isList @listTypes @listElements
        $newTopicFontColor $newTopicBgColor $linkProtocolPattern
        $headerPatternDa $headerPatternSp $headerPatternHt $headerPatternNoTOC
        $debugUserTime $debugSystemTime
        $viewableAttachmentCount $noviewableAttachmentCount
        $superAdminGroup $doSuperAdminGroup
        $cgiQuery @publicWebList
        $formatVersion $OS
        $readTopicPermissionFailed
    );

# TWiki::Store config:
use vars qw(
        $storeImpl @storeSettings
    );

# TWiki::Search config:
use vars qw(
        $cmdQuote $lsCmd $egrepCmd $fgrepCmd
    );



# ===========================
# TWiki version:
$wikiversion      = "09 Nov 2002";

# ===========================
# read the configuration part
do "TWiki.cfg";

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
use Cwd;

# ===========================
# variables: (new variables must be declared in "use vars qw(..)" above)
@isoMonth = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
@weekDay = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");

{ my $count = 0;
  %mon2num = map { $_ => $count++ } @isoMonth; }

# The following are also initialized in initialize, here for cases where
# initialize not called.
$TranslationToken= "\263";
$cgiQuery = 0;
@publicWebList = ();
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


# =========================
sub initialize
{
    my ( $thePathInfo, $theRemoteUser, $theTopic, $theUrl, $theQuery ) = @_;
    
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
    $userName = &TWiki::Plugins::initializeUser( $theRemoteUser, $theUrl, $thePathInfo );  # e.g. "jdoe"
    $wikiName     = userToWikiName( $userName, 1 );      # i.e. "JonDoe"
    $wikiUserName = userToWikiName( $userName );         # i.e. "Main.JonDoe"

    # initialize $webName and $topicName
    $topicName = "";
    $webName   = "";
    if( $theTopic ) {
        if( $theTopic =~ /(.*)\.(.*)/ ) {
            # is "bin/script?topic=Webname.SomeTopic"
            $webName   = $1 || "";
            $topicName = $2 || "";
        } else {
            # is "bin/script/Webname?topic=SomeTopic"
            $topicName = $theTopic;
        }
    }

    # RD 19 Mar 02: Fix for Support.WebNameIncludesViewScriptPath and
    # Support.CobaltRaqInstall.  A valid PATH_INFO is '/Main/WebHome', 
    # i.e. the text after the script name; invalid PATH_INFO is often 
    # a full path starting with '/cgi-bin/...'.

    # Fix path_info if broken - FIXME: extreme brokenness may require more work
    # DEBUG: Simulate broken path_info
    # $thePathInfo = "$scriptUrlPath/view/Main/WebStatistics";
    $thePathInfo =~ s!$scriptUrlPath/[\-\.A-Z]+$scriptSuffix/!/!i;
    ## writeDebug( "===== thePathInfo after cleanup = $thePathInfo" );

    if( $thePathInfo =~ /\/(.*)\/(.*)/ ) {
        # is "bin/script/Webname/SomeTopic" or "bin/script/Webname/"
        $webName   = $1 || "" if( ! $webName );
        $topicName = $2 || "" if( ! $topicName );
    } elsif( $thePathInfo =~ /\/(.*)/ ) {
        # is "bin/script/Webname" or "bin/script/"
        $webName   = $1 || "" if( ! $webName );
    }
    ( $topicName =~ /\.\./ ) && ( $topicName = $mainTopicname );
    # filter out dangerous or unwanted characters:
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
    $newTopicBgColor = &TWiki::Prefs::getPreferencesValue("NEWTOPICBGCOLOR");
    if ($newTopicBgColor eq "") { $newTopicBgColor="#FFFFCE"; }
    $newTopicFontColor = &TWiki::Prefs::getPreferencesValue("NEWTOPICFONTCOLOR");
    if ($newTopicFontColor eq "") { $newTopicFontColor="#0000FF"; }

#AS
    if( !$disableAllPlugins ) {
        &TWiki::Plugins::initialize( $topicName, $webName, $userName );
    }
#/AS

    return ( $topicName, $webName, $scriptUrlPath, $userName, $dataDir );
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
	$coreHeaders = $query->header( -content_type => $contentType,
			     -content_length => $contentLength,
			     -last_modified => $lastModifiedString,
			     -expires => "+${expireHours}h",
			     -cache_control => "max-age=$expireSeconds"
			 );
    } elsif ($pageType eq 'basic') {
	$coreHeaders = $query->header(-content_type => $contentType);
    } else {
	writeWarning( "===== invalid page type in TWiki.pm, writeHeaderFull(): $pageType" );
    }

    # Delete extra CR/LF to allow suffixing more headers
    $coreHeaders =~ s/\r\n\r\n$/\r\n/so;
    ##writeDebug( "===== After trim, Headers are:\n$coreHeaders" );

    # Wiki Plugin Hook - get additional headers from plugin
    $pluginHeaders = &TWiki::Plugins::writeHeaderHandler( $query ) || '';

    # Delete any trailing blank line
    $pluginHeaders =~ s/\r\n\r\n$/\r\n/so;

    # Add headers supplied by plugin, omitting any already in core headers
    my $finalHeaders = $coreHeaders;
    if( $pluginHeaders ) {
	# Build hash of all core header names, lower-cased
	my ($headerLine, $headerName, %coreHeaderSeen);
	for $headerLine (split /\r\n/, $coreHeaders) {
	    $headerLine =~ m/^([^ ]+): /io;		# Get header name
	    $headerName = lc($1);
	    ##writeDebug("==== core header name $headerName");
	    $coreHeaderSeen{$headerName}++;
	}
	# Append plugin headers if legal and not seen in core headers
	for $headerLine (split /\r\n/, $pluginHeaders) {
	    $headerLine =~ m/^([^ ]+): /io;		# Get header name
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
# Warning and errors that may require admin intervention, to 'warnings.txt' typically.
# Not using store writeLog; log file is more of an audit/usage file.
# Use this for defensive programming warnings (e.g. assertions).
sub writeWarning
{
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
sub writeDebug
# Use for debugging messages, goes to 'debug.txt' normally
{
    my( $text ) = @_;
    open( FILE, ">>$debugFilename" );
    
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
    my( $tmon) = $isoMonth[$mon];
    $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
    my $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min );

    print FILE "$time $text\n";
    close( FILE);
}

# =========================
sub writeDebugTimes
# Use for performance monitoring/debugging
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

    $topicname = $TWiki::notifyTopicname unless $topicname;
    return() unless &TWiki::Store::topicExists( $web, $topicname );

    # Allow %MAINWEB% as well as 'Main' in front of users/groups -
    # non-capturing regex.
    my $mainWebPattern = "(?:$TWiki::mainWebname|%MAINWEB%)";	

    my @list = ();
    my %seen;			# Incremented when email address is seen
    foreach ( split ( /\n/, TWiki::Store::readWebTopic( $web, $topicname ) ) ) {
        if (/^\s\*\s[A-Za-z0-9\.]+\s+\-\s+/) {
            # full form:   * Main.WikiName - email@domain
	    # (the 'Main.' part is optional, non-capturing)
            if ( !/^\s\*\s(?:$mainWebPattern\.)?TWikiGuest\s/o ) {
		# Add email address to list if it's not a duplicate
                if ( /([\w\-\.\+]+\@[\w\-\.\+]+)/ ) {
		    push (@list, $1) unless $seen{$1}++;
		}
            }
        } elsif (/^\s\*\s(?:$mainWebPattern\.)?([A-Z][A-Za-z0-9]+)/o ) {   
	    # short form:   * Main.WikiName
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
	    ## writeDebug "using group: $mainWebname . $wikiName";
	    my @userList = TWiki::Access::getUsersOfGroup( $wikiName ); 
	    foreach my $user ( @userList ) {
		$user =~ s/^.*\.//;	# Get rid of 'Main.' part.
		foreach my $email ( getEmailOfUser($user) ) {
		    push @list, $email;
		}
	    }
        } else {
	    # Page is for a user
	    ## writeDebug "reading home page: $mainWebname . $wikiName";
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
    my %AddrToName = map { split( /\|/, $_ ) }
                   grep { /[^\|]*\|[^\|]*\|$/ }
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
sub userToWikiListInit
{
    my $text = &TWiki::Store::readFile( $userListFilename );
    my @list = split( /\n/, $text );
    @list = grep { /^\s*\* [A-Za-z0-9]*\s*\-\s*[^\-]*\-/ } @list;
    %userToWikiList = ();
    %wikiToUserList = ();
    my $wUser;
    my $lUser;
    foreach( @list ) {
        if(  ( /^\s*\* ([A-Za-z0-9]*)\s*\-\s*([^\s]*).*/ ) 
          && ( isWikiName( $1 ) ) && ( $2 ) ) {
            $wUser = $1;
            $lUser = $2;
            $lUser =~ s/$securityFilter//go;
            $userToWikiList{ $lUser } = $wUser;
            $wikiToUserList{ $wUser } = $lUser;
        }
    }
}

# =========================
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
    $wikiUser =~ s/^.*\.//go;
    my $userName =  $wikiToUserList{"$wikiUser"} || $wikiUser;
    ## writeDebug( "TWiki::wikiToUserName: $wikiUser->$userName" );
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
sub readOnlyMirrorWeb
{
    my( $theWeb ) = @_;

    my @mirrorInfo = ( "", "", "", "" );
    if( $siteWebTopicName ) {
        my $mirrorSiteName = &TWiki::Prefs::getPreferencesValue( "MIRRORSITENAME", $theWeb );
        if( $mirrorSiteName && $mirrorSiteName ne $siteWebTopicName ) {
            my $mirrorViewURL  = &TWiki::Prefs::getPreferencesValue( "MIRRORVIEWURL", $theWeb );
            my $mirrorLink = &TWiki::Store::readTemplate( "mirrorlink" );
            $mirrorLink =~ s/%MIRRORSITENAME%/$mirrorSiteName/go;
            $mirrorLink =~ s/%MIRRORVIEWURL%/$mirrorViewURL/go;
            $mirrorLink =~ s/\s*$//go;
            my $mirrorNote = &TWiki::Store::readTemplate( "mirrornote" );
            $mirrorNote =~ s/%MIRRORSITENAME%/$mirrorSiteName/go;
            $mirrorNote =~ s/%MIRRORVIEWURL%/$mirrorViewURL/go;
            $mirrorNote = getRenderedVersion( $mirrorNote, $theWeb );
            $mirrorNote =~ s/\s*$//go;
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
        while ( $twikiLibDir =~ s|([\\/])[^\\/]+[\\/]\.\.[\\/]|$1|o) {};
        $twikiLibDir =~ s|([\\/])\.[\\/]|$1|go;
    }
    $twikiLibDir =~ s|([\\/])[\\/]*|$1|go; # reduce "//" to "/"
    $twikiLibDir =~ s|[\\/]$||o;           # cut trailing "/"

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
    $theTopic =~ s/\s*//gos; # Illedal URL, remove space

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
    $htext =~ s/([\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . &mailtoLink( $2, $3, $4 )/geo;
    $htext =~ s/<\!\-\-.*?\-\->//gos;  # remove all HTML comments
    $htext =~ s/<\!\-\-.*$//os;        # cut HTML comment
    $htext =~ s/<[^>]*>//go;           # remove all HTML tags
    $htext =~ s/\&[a-z]+;/ /go;        # remove entities
    $htext =~ s/%WEB%/$theWeb/go;      # resolve web
    $htext =~ s/%TOPIC%/$theTopic/go;  # resolve topic
    $htext =~ s/%WIKITOOLNAME%/$wikiToolName/go; # resolve TWiki tool name
    $htext =~ s/%META:.*?%//go;        # remove meta data variables
    $htext =~ s/[\%\[\]\*\|=_\&\<\>]/ /go; # remove Wiki formatting chars & defuse %VARS%
    $htext =~ s/\-\-\-+\+*\s*\!*/ /go; # remove heading formatting
    $htext =~ s/\s+[\+\-]*/ /go;       # remove newlines and special chars

    # limit to 162 chars
    $htext =~ s/(.{162})([a-zA-Z0-9]*)(.*?)$/$1$2 \.\.\./go;

    # encode special chars to be iso-8859-1 conformant
    $htext =~ s/([\x7f-\xff])/"\&\#" . unpack( "C", $1 ) .";"/geo;

    # inline search renders text, 
    # so prevent linking of external and internal links:
    $htext =~ s/([\-\*\s])($linkProtocolPattern\:)/$1<nop>$2/go;
    $htext =~ s/([\s\(])([A-Z]+[a-z0-9]*\.[A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
    $htext =~ s/([\s\(])([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
    $htext =~ s/([\s\(])([A-Z]{3,})/$1<nop>$2/go;
    $htext =~ s/@([a-zA-Z0-9\-\_\.]+)/@<nop>$1/go;

    return $htext;
}

# =========================
sub extractNameValuePair
{
    my( $str, $name ) = @_;

    my $value = "";
    return $value unless( $str );
    $str =~ s/\\\"/\\$TranslationToken/go;  # escape \"

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
    $theTag =~ s/[\r\n]+//gos;
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
    $text =~ s/\r\n/\n/gos;
    $text =~ s/\r/\n/gos;
    $text =~ s/^(.*?\n)\n(.*)/$2/os;
    my $httpHeader = $1;
    my $contentType = "";
    if( $httpHeader =~ /content\-type\:\s*([^\n]*)/ois ) {
        $contentType = $1;
    }
    if( $contentType =~ /^text\/html/ ) {
        $path =~ s/(.*)\/.*/$1/o; # build path for relative address
        $host = "http://$host";   # build host for absolute address
        if( $port != 80 ) {
            $host .= ":$port";
        }

        # FIXME: Make aware of <base> tag

        $text =~ s/^.*?<\/head>//ois;            # remove all HEAD
        $text =~ s/<script.*?<\/script>//gois;   # remove all SCRIPTs
        $text =~ s/^.*?<body[^>]*>//ois;         # remove all to <BODY>
        $text =~ s/(?:\n)<\/body>//ois;          # remove </BODY>
        $text =~ s/(?:\n)<\/html>//ois;          # remove </HTML>
        $text =~ s/(<[^>]*>)/&fixN($1)/geos;     # join tags to one line each
        $text =~ s/(\s(href|src|action)\=\"?)([^\"\>\s]*)/$1 . &fixURL( $host, $path, $3 )/geois;

    } elsif( $contentType =~ /^text\/plain/ ) {
        # do nothing

    } else {
        $text = showError( "Error: Unsupported content type: $contentType."
              . " (Must be text/html or text/plain)" );
    }

    if( $thePattern ) {
        $thePattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/go;  # escape some special chars
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
        $incfile =~ s/passwd//goi;    # filter out passwd filename
    }

    # test for different usage
    my $fileName = "$dataDir/$theWeb/$incfile";       # TopicName.txt
    if( ! -e $fileName ) {
        $fileName = "$dataDir/$theWeb/$incfile.txt";  # TopicName
        if( ! -e $fileName ) {
            $fileName = "$dataDir/$incfile";              # Web/TopicName.txt
            if( ! -e $fileName ) {
                $incfile =~ s/\.([^\.]*)$/\/$1/go;
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
    $fileName =~ s/\/([^\/]*)\/([^\/]*)(\.txt)$/$1/go;
    if( $3 ) {
        # identified "/Web/TopicName.txt" filename, e.g. a Wiki topic
        # so save the current web and topic name
        $theWeb = $1;
        $theTopic = $2;

        ( $meta, $text ) = &TWiki::Store::readTopic( $theWeb, $theTopic );
        # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
        $text =~ s/.*?%STARTINCLUDE%//os;
        $text =~ s/%STOPINCLUDE%.*//os;
    } # else is a file with relative path, e.g. $dataDir/../../path/to/non-twiki/file.ext

    if( $pattern ) {
        $pattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/go;  # escape some special chars
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

    # recursively process multiple embeded %INCLUDE% statements and prefs
    $text =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $theTopic, $theWeb, @theProcessedTopics )/geo;

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
    $web =~ s/\//\./go;
    my $webPath = $web;
    $webPath =~ s/\./\//go;

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
                $line =~ s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*($|[\s\,\.\;\:\!\?\)])/$1$2$3/go;
                $line =~ s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+($|[\s\,\.\;\:\!\?\)])/$1$2$3/go;
                # Prevent WikiLinks
                $line =~ s/\[\[.*\]\[(.*?)\]\]/$1/go;  # '[[...][...]]'
                $line =~ s/\[\[(.*?)\]\]/$1/geo;       # '[[...]]'
                $line =~ s/([\s\(])([A-Z]+[a-z0-9]*)\.([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$3/go;  # 'Web.TopicName'
                $line =~ s/([\s\(])([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;  # 'TopicName'
                $line =~ s/([\s\(])([A-Z]{3,})/$1<nop>$2/go;  # 'TLA'
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
sub handleUrlEncode
{
    my( $theStr, $doExtract ) = @_;

    $theStr = extractNameValuePair( $theStr ) if( $doExtract );
    $theStr =~ s/[\n\r]/\%3Cbr\%20\%3E/go;
    $theStr =~ s/\s+/\%20/go;
    $theStr =~ s/\&/\%26/go;
    $theStr =~ s/\</\%3C/go;
    $theStr =~ s/\>/\%3E/go;

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
sub handleSpacedTopic
{
    my( $theTopic ) = @_;
    my $spacedTopic = $theTopic;
    $spacedTopic =~ s/([a-z]+)([A-Z0-9]+)/$1%20*$2/g;   # "%20*" is " *"
    return $spacedTopic;
}

# =========================
sub handleInternalTags
{
    # modify arguments directly, e.g. call by reference
    # $_[0] is text
    # $_[1] is topic
    # $_[2] is web

    # Make Edit URL unique for every edit - fix for RefreshEditPage
    $_[0] =~ s!%EDITURL%!"$scriptUrlPath/edit$scriptSuffix/%WEB%/%TOPIC%\?t=".time()!geo;

    $_[0] =~ s/%NOP{(.*?)}%/$1/gos;  # remove NOP tag in template topics but show content
    $_[0] =~ s/%NOP%/<nop>/go;
    $_[0] =~ s/%TMPL\:P{(.*?)}%/&handleTmplP($1)/geo;
    $_[0] =~ s/%SEP%/&handleTmplP('"sep"')/geo;
    $_[0] =~ s/%HTTP_HOST%/&handleEnvVariable('HTTP_HOST')/geo;
    $_[0] =~ s/%REMOTE_ADDR%/&handleEnvVariable('REMOTE_ADDR')/geo;
    $_[0] =~ s/%REMOTE_PORT%/&handleEnvVariable('REMOTE_PORT')/geo;
    $_[0] =~ s/%REMOTE_USER%/&handleEnvVariable('REMOTE_USER')/geo;
    $_[0] =~ s/%TOPIC%/$_[1]/go;
    $_[0] =~ s/%BASETOPIC%/$topicName/go;
    $_[0] =~ s/%INCLUDINGTOPIC%/$includingTopicName/go;
    $_[0] =~ s/%SPACEDTOPIC%/&handleSpacedTopic($_[1])/geo;
    $_[0] =~ s/%WEB%/$_[2]/go;
    $_[0] =~ s/%BASEWEB%/$webName/go;
    $_[0] =~ s/%INCLUDINGWEB%/$includingWebName/go;
    $_[0] =~ s/%TOPICLIST{(.*?)}%/&handleWebAndTopicList($1,'0')/geo;
    $_[0] =~ s/%WEBLIST{(.*?)}%/&handleWebAndTopicList($1,'1')/geo;
    $_[0] =~ s/%WIKIHOMEURL%/$wikiHomeUrl/go;
    $_[0] =~ s/%SCRIPTURL%/$urlHost$scriptUrlPath/go;
    $_[0] =~ s/%SCRIPTURLPATH%/$scriptUrlPath/go;
    $_[0] =~ s/%SCRIPTSUFFIX%/$scriptSuffix/go;
    $_[0] =~ s/%PUBURL%/$urlHost$pubUrlPath/go;
    $_[0] =~ s/%PUBURLPATH%/$pubUrlPath/go;
    $_[0] =~ s/%ATTACHURL%/$urlHost$pubUrlPath\/$_[2]\/$_[1]/go;
    $_[0] =~ s/%ATTACHURLPATH%/$pubUrlPath\/$_[2]\/$_[1]/go;
    $_[0] =~ s/%URLPARAM{(.*?)}%/&handleUrlParam($1)/geo;
    $_[0] =~ s/%URLENCODE{(.*?)}%/&handleUrlEncode($1,1)/geo;
    $_[0] =~ s/%DATE%/&getGmDate()/geo; # deprecated, but used in signatures
    $_[0] =~ s/%GMTIME%/&handleTime("","gmtime")/geo;
    $_[0] =~ s/%GMTIME{(.*?)}%/&handleTime($1,"gmtime")/geo;
    $_[0] =~ s/%SERVERTIME%/&handleTime("","servertime")/geo;
    $_[0] =~ s/%SERVERTIME{(.*?)}%/&handleTime($1,"servertime")/geo;
    $_[0] =~ s/%WIKIVERSION%/$wikiversion/go;
    $_[0] =~ s/%USERNAME%/$userName/go;
    $_[0] =~ s/%WIKINAME%/$wikiName/go;
    $_[0] =~ s/%WIKIUSERNAME%/$wikiUserName/go;
    $_[0] =~ s/%WIKITOOLNAME%/$wikiToolName/go;
    $_[0] =~ s/%MAINWEB%/$mainWebname/go;
    $_[0] =~ s/%TWIKIWEB%/$twikiWebname/go;
    $_[0] =~ s/%HOMETOPIC%/$mainTopicname/go;
    $_[0] =~ s/%WIKIUSERSTOPIC%/$wikiUsersTopicname/go;
    $_[0] =~ s/%WIKIPREFSTOPIC%/$wikiPrefsTopicname/go;
    $_[0] =~ s/%WEBPREFSTOPIC%/$webPrefsTopicname/go;
    $_[0] =~ s/%NOTIFYTOPIC%/$notifyTopicname/go;
    $_[0] =~ s/%STATISTICSTOPIC%/$statisticsTopicname/go;
    $_[0] =~ s/%STARTINCLUDE%//go;
    $_[0] =~ s/%STOPINCLUDE%//go;
    $_[0] =~ s/%SEARCH{(.*?)}%/&handleSearchWeb($1)/geo; # can be nested
    $_[0] =~ s/%SEARCH{(.*?)}%/&handleSearchWeb($1)/geo if( $_[0] =~ /%SEARCH/o );
    $_[0] =~ s/%METASEARCH{(.*?)}%/&handleMetaSearch($1)/geo;

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
        if( /^(\s*)<verbatim>\s*$/oi ) {
            $nesting++;
            if( $nesting == 1 ) {
                $outtext .= "$1%_VERBATIM$verbatimCount%\n";
                $tmp = "";
                next;
            }
        } elsif( m|^\s*</verbatim>\s*$|oi ) {
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
            $val =~ s/</&lt;/go;
            $val =~ s/</&gt;/go;
            $val =~ s/\t/   /go; # A shame to do this, but been in TWiki.org have converted
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

    # recursively process multiple embeded %INCLUDE% statements and prefs
    $text =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $theTopic, $theWeb, \@verbatim, @theProcessedTopics )/geo;

    # Wiki Plugin Hook
    &TWiki::Plugins::commonTagsHandler( $text, $theTopic, $theWeb, 0 );

    # handle tags again because of plugin hook
    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );

    $text =~ s/%TOC{([^}]*)}%/&handleToc($text,$theTopic,$theWeb,$1)/geo;
    $text =~ s/%TOC%/&handleToc($text,$theTopic,$theWeb,"")/geo;
    
    # Ideally would put back in getRenderedVersion rather than here which would save removing
    # it again!  But this would mean altering many scripts to pass back verbatim
    $text = putBackVerbatim( $text, "verbatim", @verbatim );

    return $text;
}

# =========================
sub handleMetaTags
{
    my( $theWeb, $theTopic, $text, $meta, $isTopRev ) = @_;

    $text =~ s/%META{\s*"form"\s*}%/&renderFormData( $theWeb, $theTopic, $meta )/goe;
    $text =~ s/%META{\s*"attachments"\s*(.*)}%/&TWiki::Attach::renderMetaData( $theWeb,
                                                $theTopic, $meta, $1, $isTopRev )/goe;
    $text =~ s/%META{\s*"moved"\s*}%/&renderMoved( $theWeb, $theTopic, $meta )/goe;
    $text =~ s/%META{\s*"parent"\s*(.*)}%/&renderParent( $theWeb, $theTopic, $meta, $1 )/goe;

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
    
    $text =~ s/&/%_A_%/go;
    $text =~ s/\"/%_Q_%/go;
    $text =~ s/>/%_G_%/go;
    $text =~ s/</%_L_%/go;
    # PTh, JoachimDurchholz 22 Nov 2001: Fix for Codev.OperaBrowserDoublesEndOfLines
    $text =~ s/(\r*\n|\r)/%_N_%/go;

    return $text;
}

sub decodeSpecialChars
{
    my( $text ) = @_;
    
    $text =~ s/%_N_%/\r\n/go;
    $text =~ s/%_L_%/</go;
    $text =~ s/%_G_%/>/go;
    $text =~ s/%_Q_%/\"/go;
    $text =~ s/%_A_%/&/go;

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
    $theRow =~ s/\t/   /go;  # change tabs to space
    $theRow =~ s/\s*$//o;    # remove trailing spaces
    $theRow =~ s/(\|\|+)/$TranslationToken . length($1) . "\|"/geo;  # calc COLSPAN
    foreach( split( /\|/, $theRow ) ) {
        $attr = "";
        #AS 25-5-01 Fix to avoid matching also single columns
        if ( s/$TranslationToken([0-9]+)// ) { # No o flag for mod-perl compatibility
            $attr = " colspan=\"$1\"" ;
        }
        s/^\s+$/ &nbsp; /o;
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
    $theText =~ s/\t/   /go;
    $theText =~ s|((?:[\s]{2})+)([^\s])|'&nbsp; ' x (length($1) / 2) . "$2"|eg;
    if( $theDoBold ) {
        return "<code><b>$theText</b></code>";
    } else {
        return "<code>$theText</code>";
    }
}

# =========================
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

    $hasAnchor = 1 if( $text =~ m/(^|[\s\(])([A-Z]{3,})/ );
    $hasAnchor = 1 if( $text =~ m/(^|[\s\(])([A-Z]+[a-z0-9]*)\.([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/ );
    $hasAnchor = 1 if( $text =~ m/(^|[\s\(])([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/ );
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
sub makeAnchorName
{
    my( $theName ) = @_;
    my $anchorName = $theName;

    $anchorName =~ s/^[\s\#\_]*//o;          # no leading space nor '#', '_'
    $anchorName =~ s/[\s\_]*$//o;            # no trailing space, nor '_'
    $anchorName =~ s/<\w[^>]*>//goi;         # remove HTML tags
    $anchorName =~ s/^(.+?)\s*$headerPatternNoTOC.*/$1/o; # filter TOC excludes if not at beginning
    $anchorName =~ s/$headerPatternNoTOC//o; # filter '!!', '%NOTOC%'
    $anchorName =~ s/[^a-zA-Z0-9]/_/go;      # only allowed chars
    $anchorName =~ s/__+/_/go;               # remove excessive '_'
    $anchorName =~ s/^(.{32})(.*)$/$1/o;     # limit to 32 chars

    return $anchorName;
}

# =========================
sub internalLink
{
    my( $thePreamble, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink ) = @_;
    # $thePreamble is text used before the TWiki link syntax
    # $doLink is boolean: false means suppress link for non-existing pages

    # kill spaces and Wikify page name (ManpreetSingh - 15 Sep 2000)
    $theTopic =~ s/^\s*//;
    $theTopic =~ s/\s*$//;
    $theTopic =~ s/^(.)/\U$1/;
    $theTopic =~ s/\s([a-zA-Z0-9])/\U$1/g;
    # Add <nop> before WikiWord inside text to prevent double links
    $theLinkText =~ s/([\s\(])([A-Z])/$1<nop>$2/go;

    my $exist = &TWiki::Store::topicExists( $theWeb, $theTopic );
    if(  ( $doPluralToSingular ) && ( $theTopic =~ /s$/ ) && ! ( $exist ) ) {
        # page is a non-existing plural
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
    $theLink =~ s/^\s*//o;
    $theLink =~ s/\s*$//o;

    if( $theLink =~ /^$linkProtocolPattern\:/ ) {
        # Found external link, add <nop> before WikiWord and ABBREV 
	# inside link text, to prevent double links
	$theText =~ s/([\s\(])([A-Z])/$1<nop>$2/go;
        return "$thePreamble<a href=\"$theLink\" target=\"_top\">$theText</a>";
    }

    # Get any 'Web.' prefix, or use current web
    $theLink =~ s/^([A-Z]+[a-z0-9]*|_[a-zA-Z0-9_]+)\.//o;
    my $web = $1 || $theWeb;
    (my $baz = "foo") =~ s/foo//;       # reset $1, defensive coding

    # Extract '#anchor'
    $theLink =~ s/(\#[a-zA-Z_0-9\-]*$)//o;
    my $anchor = $1 || "";

    # Get the topic name
    my $topic = $theLink || $theTopic;  # remaining is topic
    $topic =~ s/\&[a-z]+\;//goi;        # filter out &any; entities
    $topic =~ s/\&\#[0-9]+\;//go;       # filter out &#123; entities
    $topic =~ s/[\\\/\#\&\(\)\{\}\[\]\<\>\!\=\:\,\.]//go;
    $topic =~ s/$securityFilter//go;    # filter out suspicious chars
    if( ! $topic ) {
        return "$thePreamble$theText"; # no link if no topic
    }

    return internalLink( $thePreamble, $web, $topic, $theText, $anchor, 1 );
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
sub isWikiName
{
    my( $name ) = @_;
    if( ! $name ) {
        $name = "";
    }
    if ( $name =~ /^[A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*$/ ) {
        return "1";
    }
    return "";
}

# =========================
sub getRenderedVersion
{
    my( $text, $theWeb, $meta ) = @_;
    my( $head, $result, $extraLines, $insidePRE, $insideTABLE, $noAutoLink );

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
    $noAutoLink = 0;      # PTh 02 Feb 2001: Added Codev.DisableWikiWordLinks
    $isList = 0;
    @listTypes = ();
    @listElements = ();
    $text =~ s/\r//go;
    $text =~ s/(\n?)$/\n<nop>\n/os; # clutch to enforce correct rendering at end of doc

    my @verbatim = ();
    $text = takeOutVerbatim( $text, \@verbatim );
    $text =~ s/\\\n//go;  # Join lines ending in "\"

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
        m|<noautolink>|i   && ( $noAutoLink = 1 );
        m|</noautolink>|i  && ( $noAutoLink = 0 );

        if( $insidePRE ) {
            # inside <PRE>

            # close list tags if any
            if( @listTypes ) {
                $result .= &emitList( "", "", 0 );
                $isList = 0;
            }

# Wiki Plugin Hook
            &TWiki::Plugins::insidePREHandler( $_ );

            s/(.*)/$1\n/o;
            s/\t/   /go;
            $result .= $_;

        } else {
          # normal state, do Wiki rendering

# Wiki Plugin Hook
          &TWiki::Plugins::outsidePREHandler( $_ );
          $extraLines = undef;   # Plugins might introduce extra lines
          do {                   # Loop over extra lines added by plugins
            $_ = $extraLines if( defined $extraLines );
            s/^(.*?)\n(.*)$/$1/os;
            $extraLines = $2;    # Save extra lines, need to parse each separately

# Blockquote
            s/^>(.*?)$/> <cite> $1 <\/cite><br \/>/go;

# Embedded HTML
            s/\<(\!\-\-)/$TranslationToken$1/go;  # Allow standalone "<!--"
            s/(\-\-)\>/$1$TranslationToken/go;    # Allow standalone "-->"
            s/(\<\<+)/"&lt\;" x length($1)/geo;
            s/(\>\>+)/"&gt\;" x length($1)/geo;
            s/\<nop\>/nopTOKEN/go;  # defuse <nop> inside HTML tags
            s/\<(\S.*?)\>/$TranslationToken$1$TranslationToken/go;
            s/</&lt\;/go;
            s/>/&gt\;/go;
            s/$TranslationToken(\S.*?)$TranslationToken/\<$1\>/go;
            s/nopTOKEN/\<nop\>/go;
            s/(\-\-)$TranslationToken/$1\>/go;
            s/$TranslationToken(\!\-\-)/\<$1/go;

# Handle embedded URLs
            s!(^|[\-\*\s\(])($linkProtocolPattern\:([^\s\<\>\"]+[^\s\.\,\!\?\;\:\)\<]))!&externalLink($1,$2)!geo;

# Entities
            s/&(\w+?)\;/$TranslationToken$1\;/go;      # "&abc;"
            s/&(\#[0-9]+)\;/$TranslationToken$1\;/go;  # "&#123;"
            s/&/&amp;/go;                              # escape standalone "&"
            s/$TranslationToken/&/go;

# Headings
            # '<h6>...</h6>' HTML rule
            s/$headerPatternHt/&makeAnchorHeading($2,$1)/geoi;
            # '\t+++++++' rule
            s/$headerPatternSp/&makeAnchorHeading($2,(length($1)))/geo;
            # '----+++++++' rule
            s/$headerPatternDa/&makeAnchorHeading($2,(length($1)))/geo;

# Horizontal rule
            s/^---+/<hr \/>/o;
            s!^([a-zA-Z0-9]+)----*!<table width=\"100%\"><tr><td valign=\"bottom\"><h2>$1</h2></td><td width=\"98%\" valign=\"middle\"><hr /></td></tr></table>!o;

# Table of format: | cell | cell |
            # PTh 25 Jan 2001: Forgiving syntax, allow trailing white space
            if( $_ =~ /^(\s*)\|.*\|\s*$/ ) {
                s/^(\s*)\|(.*)/&emitTR($1,$2,$insideTABLE)/eo;
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
            s/^(\#)([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/ '<a name="' . &makeAnchorName( $2 ) . '"><\/a>'/geo;

# enclose in white space for the regex that follow
             s/(.*)/\n$1\n/o;

# Emphasizing
            # PTh 25 Sep 2000: More relaxed rules, allow leading '(' and trailing ',.;:!?)'
            s/([\s\(])==([^\s]+?|[^\s].*?[^\s])==([\s\,\.\;\:\!\?\)])/$1 . &fixedFontText( $2, 1 ) . $3/geo;
            s/([\s\(])__([^\s]+?|[^\s].*?[^\s])__([\s\,\.\;\:\!\?\)])/$1<strong><em>$2<\/em><\/strong>$3/go;
            s/([\s\(])\*([^\s]+?|[^\s].*?[^\s])\*([\s\,\.\;\:\!\?\)])/$1<strong>$2<\/strong>$3/go;
            s/([\s\(])_([^\s]+?|[^\s].*?[^\s])_([\s\,\.\;\:\!\?\)])/$1<em>$2<\/em>$3/go;
            s/([\s\(])=([^\s]+?|[^\s].*?[^\s])=([\s\,\.\;\:\!\?\)])/$1 . &fixedFontText( $2, 0 ) . $3/geo;

# Mailto
	    # RD 27 Mar 02: Mailto improvements - FIXME: check security...
	    # Explicit [[mailto:... ]] link without an '@' - hence no 
	    # anti-spam padding needed.
            # '[[mailto:string display text]]' link (no '@' in 'string'):
            s/\[\[mailto\:([^\s\@]+)\s+(.+?)\]\]/&mailtoLinkSimple( $1, $2 )/geo;
	    # Explicit [[mailto:... ]] link including '@', with anti-spam 
	    # padding, so match name@subdom.dom.
            # '[[mailto:string display text]]' link
            s/\[\[mailto\:([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.(.+?)\s+(.*?)\]\]/&mailtoLinkFull( $1, $2, $3, $4 )/geo;

	    # Normal mailto:foo@example.com ('mailto:' part optional)
            s/([\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . &mailtoLink( $2, $3, $4 )/geo;

# Make internal links
	    # Spaced-out Wiki words with alternative link text
            # '[[Web.odd wiki word#anchor][display text]]' link:
            s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&specificLink("",$theWeb,$theTopic,$2,$1)/geo;
            # RD 25 Mar 02: Codev.EasierExternalLinking
            # '[[URL#anchor display text]]' link:
            s/\[\[([a-z]+\:\S+)\s+(.*?)\]\]/&specificLink("",$theWeb,$theTopic,$2,$1)/geo;
	    # Spaced-out Wiki words
            # '[[Web.odd wiki word#anchor]]' link:
            s/\[\[([^\]]+)\]\]/&specificLink("",$theWeb,$theTopic,$1,$1)/geo;

            # do normal WikiWord link if not disabled by <noautolink>
            if( ! ( $noAutoLink ) ) {

                # 'Web.TopicName#anchor' link:
                s/([\s\(])([A-Z]+[a-z0-9]*)\.([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)(\#[a-zA-Z0-9_]*)/&internalLink($1,$2,$3,"$TranslationToken$3$4$TranslationToken",$4,1)/geo;
                # 'Web.TopicName' link:
                s/([\s\(])([A-Z]+[a-z0-9]*)\.([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/&internalLink($1,$2,$3,"$TranslationToken$3$TranslationToken","",1)/geo;
                # 'TopicName#anchor' link:
                s/([\s\(])([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)(\#[a-zA-Z0-9_]*)/&internalLink($1,$theWeb,$2,"$TranslationToken$2$3$TranslationToken",$3,1)/geo;
                # 'TopicName' link:
                s/([\s\(])([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/&internalLink($1,$theWeb,$2,$2,"",1)/geo;

		# Handle acronyms/abbreviations of three or more letters
                # 'Web.ABBREV' link:
                s/([\s\(])([A-Z]+[a-z0-9]*)\.([A-Z]{3,})/&internalLink($1,$2,$3,$3,"",0)/geo;
                # 'ABBREV' link:
                s/([\s\(])([A-Z]{3,})/&internalLink($1,$theWeb,$2,$2,"",0)/geo;
                # (deprecated <link> moved to DefaultPlugin)

                s/$TranslationToken(\S.*?)$TranslationToken/$1/go;
            }

            s/^\n//o;
            s/\t/   /go;
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

    $result =~ s|\n?<nop>\n$||os; # clean up clutch
    return "$head$result";
}

1;
