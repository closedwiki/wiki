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
#   custom extensions of rendering rules.
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
#
# 15 May 2000  PeterFokkinga :
#    With this patch each topic can have its own template. TWiki::Store::readTemplate()
#    has been modified to search for the following templates (in this order): 
#
#     1.$templateDir/$webName/$name.$topic.tmpl 
#     2.$templateDir/$webName/$name.tmpl 
#     3.$templateDir/$name.$topic.tmpl 
#     4.$templateDir/$name.tmpl 
#	    
#    $name is the name of the script, e.g. ``view''. The current
#    TWiki version uses steps 2 and 4.
#
#    See http://twiki.org/cgi-bin/view/Codev/UniqueTopicTemplates
#    for further details    

package TWiki;

## 0501 kk : vvv Added for revDate2EpSecs
use Time::Local;

use strict;

# ===========================
# TWiki config variables:
use vars qw(
        $webName $topicName $includingWebName $includingTopicName
        $defaultUserName $userName $wikiUserName 
        $wikiHomeUrl $defaultUrlHost $urlHost
        $scriptUrlPath $pubUrlPath $pubDir $templateDir $dataDir
        $siteWebTopicName $wikiToolName $securityFilter $uploadFilter
        $debugFilename $warningFilename $htpasswdFilename
        $logFilename $remoteUserFilename $wikiUsersTopicname
        $userListFilename %userToWikiList
        $twikiWebname $mainWebname $mainTopicname $notifyTopicname
        $wikiPrefsTopicname $webPrefsTopicname
        $statisticsTopicname $statsTopViews $statsTopContrib
        $numberOfRevisions $editLockTime
        $attachAsciiPath
        $scriptSuffix $safeEnvPath $mailProgram $wikiversion
        $doKeepRevIfEditLock $doRemovePortNumber
        $doRememberRemoteUser $doPluralToSingular
        $doHidePasswdInRegistration $doSecureInclude
        $doLogTopicView $doLogTopicEdit $doLogTopicSave $doLogRename
        $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff
        $doLogTopicChanges $doLogTopicSearch $doLogRegistration
        $disableAllPlugins
        @isoMonth $TranslationToken $code @code $depth %mon2num
        $newTopicFontColor $newTopicBgColor
        $headerPatternDa $headerPatternSp $headerPatternHt
        $debugUserTime $debugSystemTime
        $viewableAttachmentCount $noviewableAttachmentCount
	$superAdminGroup $doSuperAdminGroup
        $cgiQuery @publicWebList
    );

# Experimental persistent vars - modPerl issue?
use vars qw (
        %headerfooter
    );

# TWiki::Store config:
use vars qw(
        $useRcsDir
        $revInitBinaryCmd $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd
        $revInfoCmd $revDiffCmd $revDelRevCmd $revUnlockCmd $revLockCmd $nullDev
    );

# TWiki::Search config:
use vars qw(
        $cmdQuote $lsCmd $egrepCmd $fgrepCmd
    );



# ===========================
# TWiki version:
$wikiversion      = "07 Jun 2001";

# ===========================
# read the configuration part
do "TWiki.cfg";

# ===========================
# use TWiki modules
use TWiki::Prefs;     # preferences
use TWiki::Search;    # search engine
use TWiki::Access;    # access control
use TWiki::Store;     # file I/O and rcs related functions
use TWiki::Attach;    # file attachment functions
use TWiki::Plugins;   # plugins handler  #AS
use TWiki::Classification; # category handling functions

# ===========================
# variables: (new variables must be declared in "use vars qw(..)" above)
@isoMonth     = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );

{ my $count = 0;
  %mon2num = map { $_ => $count++ } @isoMonth; }

$cgiQuery = 0;
@publicWebList = ();

# Header patterns based on '+++'. The '###' are reserved for numbered headers
$headerPatternDa = '^---+(\++|\#+)\s+(.+)\s*$';       # '---++ Header', '---## Header'
$headerPatternSp = '^\t(\++|\#+)\s+(.+)\s*$';         # '   ++ Header', '   + Header'
$headerPatternHt = '^<h([1-6])>\s*(.+?)\s*</h[1-6]>'; # '<h6>Header</h6>

$debugUserTime   = 0;
$debugSystemTime = 0;


# =========================
sub initialize
{
    my ( $thePathInfo, $theRemoteUser, $theTopic, $theUrl, $theQuery ) = @_;
    
    ##writeDebug( "\n---------------------------------" );
    
    $TWiki::Attach::noFooter = 0;
    $TWiki::Attach::showAttr = 0;
    $cgiQuery = $theQuery;

    # Make %ENV safer for CGI
    if( $safeEnvPath ) {
        $ENV{'PATH'} = $safeEnvPath;
    }
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    # initialize access control
    &TWiki::Access::initializeAccess();

    # initialize user name and user to WikiName list
    $userName = initializeRemoteUser( $theRemoteUser );
    userToWikiListInit();
    $wikiUserName = userToWikiName( $userName );

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
    if( $thePathInfo =~ /\/(.*)\/(.*)/ ) {
        # is "bin/script/Webname/SomeTopic" or "bin/script/Webname/"
        $webName   = $1 || "" if( ! $webName );
        $topicName = $2 || "" if( ! $topicName );
    } else {
        # is "bin/script/Webname" or "bin/script/"
        $thePathInfo =~ s/^\/(.*)//o;
        $webName = $thePathInfo if( ! $webName );
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
        $urlHost = $1;
        $scriptUrlPath = $2;
        if( $doRemovePortNumber )
        {
            $urlHost =~ s/\:[0-9]+$//;
        }
    } else {
        $urlHost = $defaultUrlHost;
        # $scriptUrlPath does not change
    }

    # initialize preferences
    &TWiki::Prefs::initializePrefs( $wikiUserName, $webName );

    # some remaining init
    $TranslationToken= "\263";
    $code="";
    @code= ();

    # Add background color and font color (AlWilliams - 18 Sep 2000)
    # PTh: Moved from interalLink to initialize ('cause of performance)
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
# Can save cookies if required
sub writeHeader
{
    my( $query ) = @_;
    print $query->header();
    # Can change to save cookie if required
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
    print $query->redirect( $url );
    # Can change to save cookie if required
}

# =========================
# Warning and errors that may require admin intervention
# Not using store writeLog and log file is more of an audit/usage file
sub writeWarning
{
    my( $text ) = @_;
    if( $warningFilename ) {
        open( FILE, ">>$warningFilename" );
        print FILE "$text\n";
        close( FILE );
    }
}

# =========================
sub writeDebug
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
{
    my( $text ) = @_;

    if( ! $debugUserTime ) {
        writeDebug( "=====       sec:  (delta:)         sec:  (delta:)  function:" );
    }
    my( $puser, $psystem, $cuser, $csystem ) = times();
    my $duser = $puser - $debugUserTime;
    my $dsystem = $psystem - $debugSystemTime;
    my $times = sprintf( "user: %1.3f (%1.3f), system: %1.3f (%1.3f)",
                  $puser, $duser, $psystem, $dsystem );
    $debugUserTime   = $puser;
    $debugSystemTime = $psystem;

    writeDebug( "===== $times,  $text" );
}

# =========================
sub getEmailNotifyList
{
    my( $web, $topicname ) = @_;

    $topicname |= $TWiki::notifyTopicname;
    return undef unless &TWiki::Store::topicExists( $web, $topicname );

    my @list = ();
    foreach ( split( /\n/, &TWiki::Store::readWebTopic( $web, $topicname ) ) ) {
	next unless /^\s\*\s[A-Za-z0-9\.]+\s+\-\s+/;
	push @list, $1 if (/([\w\-\.\+]+\@[\w\-\.\+]+)/);
    }

    return (scalar @list ? @list : undef);    
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
    my $wUser;
    my $lUser;
    foreach( @list ) {
        if(  ( /^\s*\* ([A-Za-z0-9]*)\s*\-\s*([^\s]*).*/ ) 
          && ( isWikiName( $1 ) ) && ( $2 ) ) {
            $wUser = $1;
            $lUser = $2;
            $lUser =~ s/$securityFilter//go;
            $userToWikiList{ $lUser } = $wUser;
        }
    }
}

# =========================
sub userToWikiName
{
    my( $loginUser, $onlyTranslate ) = @_;
    
    if( !$loginUser ) {
        return "";
    }

    $loginUser =~ s/$securityFilter//go;
    my $wUser = $userToWikiList{ $loginUser };
    if( $wUser ) {
        return "$mainWebname.$wUser";
    }
    if( $onlyTranslate ) {
       return "";
    } else {
       return "$mainWebname.$loginUser";
    }
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
# Topic without Web name
sub getWikiUserTopic
{
    $wikiUserName =~ /([^.]+)$/;
    return $1;
}

# =========================
sub getLocaldate
{
    my( $sec, $min, $hour, $mday, $mon, $year) = localtime(time());
    $year = sprintf("%.4u", $year + 1900);  # Y2K fix
    my( $tmon) = $isoMonth[$mon];
    my $date = sprintf("%.2u ${tmon} %.2u", $mday, $year);
    return $date;
}

# =========================
sub formatGmTime
{
    my( $time ) = @_;

    my( $sec, $min, $hour, $mday, $mon, $year) = gmtime( $time );
    my( $tmon) = $isoMonth[$mon];
    $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
    $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min );
    return $time;
}

# =========================
sub revDate2EpSecs {

# This routine *will break* if formatGMTime changes output format.

    my ($day, $mon, $year, $hyph, $hrmin, @junk) = split(" ",$_[0]);
    my ($hr, $min) = split(/:/, $hrmin);

    #my $mon = $mon2num{$monstr};

    return timegm(0, $min, $hr, $day, $mon2num{$mon}, $year - 1900);
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
sub getOopsUrl
{
    my( $theWeb, $theTopic, $theTemplate,
        $theParam1, $theParam2, $theParam3, $theParam4 ) = @_;
    # PTh 20 Jun 2000: new sub
    my $web = $webName;  # current web
    if( $theWeb ) {
        $web = $theWeb;
    }
    # $urlHost is needed, see Codev.PageRedirectionNotWorking
    my $url = "$urlHost$scriptUrlPath/oops$scriptSuffix/$web/$theTopic";
    $url .= "\?template=$theTemplate";
    if( $theParam1 ) {
        # PTh, Stanley Knutson 03 Feb 2001: Proper URL encoding
        $theParam1 =~ s/[\n\r]/\%3Cbr\%3E/go;
        $theParam1 =~ s/\s+/\%20/go;
        $theParam1 =~ s/\&/\%26/go;
        $theParam1 =~ s/\</\%3C/go;
        $theParam1 =~ s/\>/\%3E/go;
        $url .= "\&param1=$theParam1";
    }
    if( $theParam2 ) {
        $theParam2 =~ s/[\n\r]/\%3Cbr\%3E/go;
        $theParam2 =~ s/\s+/\%20/go;
        $theParam2 =~ s/\&/\%26/go;
        $theParam2 =~ s/\</\%3C/go;
        $theParam2 =~ s/\>/\%3E/go;
        $url .= "\&param2=$theParam2";
    }
    if( $theParam3 ) {
        $theParam3 =~ s/[\n\r]/\%3Cbr\%3E/go;
        $theParam3 =~ s/\s+/\%20/go;
        $theParam3 =~ s/\&/\%26/go;
        $theParam3 =~ s/\</\%3C/go;
        $theParam3 =~ s/\>/\%3E/go;
        $url .= "\&param3=$theParam3";
    }
    if( $theParam4 ) {
        $theParam4 =~ s/[\n\r]/\%3Cbr\%3E/go;
        $theParam4 =~ s/\s+/\%20/go;
        $theParam4 =~ s/\&/\%26/go;
        $theParam4 =~ s/\</\%3C/go;
        $theParam4 =~ s/\>/\%3E/go;
        $url .= "\&param4=$theParam4";
    }
    return $url;
}

# =========================
sub makeTopicSummary
{
    my( $theText, $theTopic, $theWeb ) = @_;
    # called by search, mailnotify & changes after calling readFileHead

    my $htext = $theText;
    $htext =~ s/<\!\-\-.*?\-\->//gos;  # remove all HTML comments
    $htext =~ s/<\!\-\-.*$//os;        # remove cut HTML comment
    $htext =~ s/<[^>]*>//go;           # remove all HTML tags
    $htext =~ s/%WEB%/$theWeb/go;      # resolve web
    $htext =~ s/%TOPIC%/$theTopic/go;  # resolve topic
    $htext =~ s/%WIKITOOLNAME%/$wikiToolName/go; # resolve TWiki tool name
    $htext =~ s/%META:.*?%//go;        # Remove meta data variables
    $htext =~ s/[\%\[\]\*\|=_]/ /go;   # remove Wiki formatting chars & defuse %VARS%
    $htext =~ s/\-\-\-+\+*/ /go;       # remove heading formatting
    $htext =~ s/\s+[\+\-]*/ /go;       # remove newlines and special chars

    # inline search renders text, 
    # so prevent linking of external and internal links:
    $htext =~ s/([\-\*\s])((http|ftp|gopher|news|file|https)\:)/$1<nop>$2/go;
    $htext =~ s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]*\.[A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
    $htext =~ s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
    $htext =~ s/([\*\s][\-\*\s]*)([A-Z]{3,})/$1<nop>$2/go;
    $htext =~ s/@([a-zA-Z0-9\-\_\.]+)/@<nop>$1/go;

    # limit to 162 chars
    $htext =~ s/(.{162})([a-zA-Z0-9]*)(.*?)$/$1$2 \.\.\./go;

    return $htext;
}

# =========================
sub extractNameValuePair
{
    my( $str, $name ) = @_;

    if( $name ) {
        # format is: %VAR{ ... name = "value" }%
        if( ( $str =~ /(^|[^\S])$name\s*=\s*\"([^\"]*)\"/ ) && ( $2 ) ) {
            return $2;
        }
    } else {
        # test if format: { "value" ... }
        if( ( $str =~ /(^|\=\s*\"[^\"]*\")\s*\"([^\"]*)\"/ ) && ( $2 ) ) {
            # is: { "value" ... }
            return $2;

        } elsif( ( $str =~ /^\s*\w+\s*=\s*\"([^\"]*)/ ) && ( $1 ) ) {
            # is not a standalone var, but: %VAR{ name = "value" }%
            return "";

        } else {
            # format is: %VAR{ value }%
            return $1;
        }
    }
    return "";
}

# =========================
sub handleIncludeFile
{
    my( $theAttributes, $theTopic, $theWeb, @theProcessedTopics ) = @_;
    my $incfile = extractNameValuePair( $theAttributes );

    # CrisBailiff, PeterThoeny 12 Jun 2000: Add security
    $incfile =~ s/$securityFilter//go;    # zap anything suspicious
    $incfile =~ s/passwd//goi;    # filter out passwd filename
    if( $doSecureInclude ) {
        # Filter out ".." from filename, this is to
        # prevent includes of "../../file"
        $incfile =~ s/\.+/\./g;
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
    my @meta = ();

    # set include web/filenames and current web/filenames
    $includingWebName = $theWeb;
    $includingTopicName = $theTopic;
    $fileName =~ s/\/([^\/]*)\/([^\/]*)(\.txt)$/$1/go;
    if( $3 ) {
        # identified "/Web/TopicName.txt" filename, e.g. a Wiki topic
        # so save the current web and topic name
        $theWeb = $1;
        $theTopic = $2;

        ( $text, @meta ) = &TWiki::Store::readWebTopicNew( $theWeb, $theTopic );
        # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
        $text =~ s/.*?%STARTINCLUDE%//os;
        $text =~ s/%STOPINCLUDE%.*//os;
    } # FIXME what if it's not a topic, is this possible given only dataDir above?

    # handle all preferences and internal tags (for speed: call by reference)
    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );
    
    # FIXME ??? Should attachments and other meta data be included?
    my $metaText = renderMetaData( $theWeb, $theTopic, \@meta, "noMove" );
    $text .= $metaText;

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
    
    #%META:TOPICMOVED{from="Test.HiJohn"
    my $searchVal = "XXX";
    
    if( ! $attrType ) {
       $attrType = "";
    }
    
    if( $attrType eq "topicmoved" ) {
       $searchVal = "%META:TOPICMOVED\{.*from=\\\"$attrWeb\.$attrTopic\\\".*\}%";
    }
    
    my $text = &TWiki::Search::searchWeb( "1", "all", $searchVal, "",
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

    return &TWiki::Search::searchWeb( "1", $attrWeb, $searchVal, $attrScope,
       $attrOrder, $attrRegex, $attrLimit, $attrReverse,
       $attrCasesensitive, $attrNosummary, $attrNosearch,
       $attrNoheader, $attrNototal, $attrBookview, $attrRenameview,
       $attrShowlock, $attrNoEmpty
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
        if( $theZone eq "gmtime" ) {
            my( $sec, $min, $hour, $day, $mon, $year) = gmtime( $time );
            $value = $format;
            $value =~ s/\$sec[a-z]*/sprintf("%.2u",$sec)/geoi;
            $value =~ s/\$min[a-z]*/sprintf("%.2u",$min)/geoi;
            $value =~ s/\$hou[a-z]*/sprintf("%.2u",$hour)/geoi;
            $value =~ s/\$day[a-z]*/sprintf("%.2u",$day)/geoi;
            $value =~ s/\$yea[a-z]*/sprintf("%.4u",$year+1900)/geoi;
            $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;
            $value =~ s/\$mon[a-z]*/$isoMonth[$mon]/goi;
            $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
        } elsif( $theZone eq "servertime" ) {
            my( $sec, $min, $hour, $day, $mon, $year) = localtime( $time );
            $value = $format;
            $value =~ s/\$sec[a-z]*/sprintf("%.2u",$sec)/geoi;
            $value =~ s/\$min[a-z]*/sprintf("%.2u",$min)/geoi;
            $value =~ s/\$hou[a-z]*/sprintf("%.2u",$hour)/geoi;
            $value =~ s/\$day[a-z]*/sprintf("%.2u",$day)/geoi;
            $value =~ s/\$yea[a-z]*/sprintf("%.4u",$year+1900)/geoi;
            $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;
            $value =~ s/\$mon[a-z]*/$isoMonth[$mon]/goi;
            $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
        }
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

    @list = grep { /(<\/?[pP][rR][eE]>)|($headerPatternDa)|($headerPatternSp)|($headerPatternHt)/ } @list;
    my $insidePre = 0;
    my $i = 0;
    my $tabs = "";
    my $anchor = "";
    my $highest = 99;
    foreach $line ( @list ) {
        if( $line =~ /^.*<[pP][rR][eE]>.*$/ ) {
            $insidePre = 1;
            $line = "";
        }
        if( $line =~ /^.*<\/[pP][rR][eE]>.*$/ ) {
            $insidePre = 0;
            $line = "";
        }
        if (!$insidePre) {
            $level = $line ;
            if ( $line =~  /$headerPatternDa/ ) {
                $level =~ s/$headerPatternDa/$1/go ;
                $level = length $level;
                $line  =~ s/$headerPatternDa/$2/go ;
                $anchor = makeAnchorName( $line );
            } elsif
               ( $line =~  /$headerPatternSp/ ) {
                $level =~ s/$headerPatternSp/$1/go ;
                $level = length $level;
                $line  =~ s/$headerPatternSp/$2/go ;
                $anchor = makeAnchorName( $line );
            } elsif
               ( $line =~  /$headerPatternHt/ ) {
                $level =~ s/$headerPatternHt/$1/go ;
                $line  =~ s/$headerPatternHt/$2/go ;
                $anchor = makeAnchorName( $line );
            }
            if( ( $line ) && ( $level <= $depth ) ) {
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
                $line =~ s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]*)\.([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$3/go;  # 'Web.TopicName'
                $line =~ s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;  # 'TopicName'
                $line =~ s/([\*\s][\-\*\s]*)([A-Z]{3,})/$1<nop>$2/go;  # 'TLA'
                # create linked bullet item
                $line = "$tabs* <a href=\"$scriptUrlPath/view$scriptSuffix/$webPath/$topicname#$anchor\">$line</a>";
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
            if( ( $item eq $TWiki::webName  ) || ( ! $hidden ) ) {
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
    $format = "   * "   if( ! $format );
    $format .= '$name' if( ! ( $format =~ /\$name/ ) );
    my $web = extractNameValuePair( $theAttr, "web" ) || "";

    my @list = ();
    if( $isWeb ) {
        @list = getPublicWebList();
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
    foreach $item ( @list ) {
        $line = $format;
        $line =~ s/\$web/$web/goi;
        $line =~ s/\$name/$item/goi;
        $text .= "$line\n";
    }
    $text =~ s/\n$//os;  # remove last new line
    return $text;
}

# =========================
sub handleUrlParam
{
    my( $theParam ) = @_;

    $theParam = extractNameValuePair( $theParam );
    my $value = "";
    if( $cgiQuery ) {
        $value = $cgiQuery->param( $theParam ) || "";
    }

    return $value;
}

# =========================
sub handleEnvVariable
{
    my( $theVar ) = @_;
    my $value = $ENV{$theVar} || "";
    return $value;
}

# =========================
sub handleSpacedTopic
{
    my( $theTopic ) = @_;
    my $spacedTopic = $theTopic;
    $spacedTopic =~ s/([a-z]+)([A-Z0-9]+)/$1%20*$2/go;   # "%20*" is " *"
    return $spacedTopic;
}

# =========================
sub handleInternalTags
{
    # modify arguments directly, e.g. call by reference
    # $_[0] is text
    # $_[1] is topic
    # $_[2] is web

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
    $_[0] =~ s/%DATE%/&getLocaldate()/geo; # depreciated
    $_[0] =~ s/%GMTIME%/&handleTime("","gmtime")/geo;
    $_[0] =~ s/%GMTIME{(.*?)}%/&handleTime($1,"gmtime")/geo;
    $_[0] =~ s/%SERVERTIME%/&handleTime("","servertime")/geo;
    $_[0] =~ s/%SERVERTIME{(.*?)}%/&handleTime($1,"servertime")/geo;
    $_[0] =~ s/%WIKIVERSION%/$wikiversion/go;
    $_[0] =~ s/%USERNAME%/$userName/go;
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
    $_[0] =~ s/%SEARCH{(.*?)}%/&handleSearchWeb($1)/geo;
    $_[0] =~ s/%METASEARCH{(.*?)}%/&handleMetaSearch($1)/geo;
}

sub readHeaderFooter
{
    my( $theWeb, $theSkin ) = @_;
    
    if( ! %headerfooter ) {
        my $tmpl = &TWiki::Store::readTemplate( "headerfooter", $theWeb, $theSkin );
        # Might want to have generalised variable rather than just sep
        my( $header, $footerstart, $footerend, $sep ) = split /%SPLIT%/, $tmpl;
    
        $headerfooter{"header"} = $header;
        $headerfooter{"footerstart"} = $footerstart;
        $headerfooter{"footerend"}   = $footerend;
        $headerfooter{"sep"} = $sep;
     }
}

# =========================
# Experimental routine for header/footer
sub handleHeader
{
    my( $args, $theTopic, $theSkin ) = @_;
    
    readHeaderFooter( $theTopic, $theSkin );
    
    my $action = extractNameValuePair( $args, "action" );
    my $description = extractNameValuePair( $args, "description" );
    
    my $tmpl = $headerfooter{"header"}; #&TWiki::Store::readTemplate( "top" );
    $tmpl =~ s/%ACTION%/$action/go;
    $tmpl =~ s/%DESCRIPTION%/$description/go;
    
    return $tmpl;
}

# =========================
# Experimental routine for header/footer
sub handleFooter
{
    my( $pos, $theTopic, $theSkin  ) = @_;
    
    readHeaderFooter( $theTopic, $theSkin );
    
    my $ret = "";

    if( ! $pos || $pos =~ /:START/ ) {
       $ret .= $headerfooter{"footerstart"};
    }
    
    if( ! $pos || $pos =~ /:END/ ) {
       $ret .= $headerfooter{"footerend"};
    }
    
    return $ret;
}

# =========================
# Experimental routine for header/footer
sub handleSep
{
    my( $theTopic, $theSkin ) = @_;
    
    readHeaderFooter( $theTopic, $theSkin );
    return $headerfooter{"sep"};
}

# =========================
sub handleCommonTags
{
    my( $text, $theTopic, $theWeb, @theProcessedTopics ) = @_;

    # PTh 22 Jul 2000: added $theWeb for correct handling of %INCLUDE%, %SEARCH%
    if( !$theWeb ) {
        $theWeb = $webName;
    }

    # handle all preferences and internal tags (for speed: call by reference)
    $includingWebName = $theWeb;
    $includingTopicName = $theTopic;
    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );

    # recursively process multiple embeded %INCLUDE% statements and prefs
    $text =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $theTopic, $theWeb, @theProcessedTopics )/geo;

    # Wiki Plugin Hook
    &TWiki::Plugins::commonTagsHandler( $text, $theTopic, $theWeb );

    # handle tags again because of plugin hook
    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );

    $text =~ s/%TOC{([^}]*)}%/&handleToc($text,$theTopic,$theWeb,$1)/geo;
    $text =~ s/%TOC%/&handleToc($text,$theTopic,$theWeb,"")/geo;

    return $text;
}

# ========================
sub renderMoved
{
    my( $web, $topic, $metar ) = @_;
    
    my @meta = @$metar;
    my $text = "";
    
    my @tmp = grep { /^%META:TOPICMOVED/ } @meta;
    
    if( @tmp ) {
        my $movedMeta = shift @tmp;
        $movedMeta =~ /{([^}]*)}/;
        my $args = $1;
        my $from = extractNameValuePair( $args, "from" );
        $from =~ /(.*)\.(.*)/;
        my $fromWeb = $1;
        my $fromTopic = $2;
        my $to   = extractNameValuePair( $args, "to" );
        $to =~ /(.*)\.(.*)/;
        my $toWeb = $1;
        my $toTopic = $2;
        my $by   = extractNameValuePair( $args, "by" );
        my $date = extractNameValuePair( $args, "date" );
        $date = formatGmTime( $date );
        
        # Only allow put back, if current web and topic match stored to information
        my $putBack = "";
        if( $web eq $toWeb && $topic eq $toTopic ) {
            $putBack  = " - <a title=\"Click to move topic back to previous location, with option to change references.\"";
            $putBack .= " href=\"$scriptUrlPath/rename?newWeb=$fromWeb&newTopic=$fromTopic&oldWeb=$web";
            $putBack .= "&oldTopic=$topic&confirm=yes\">put it back</a>";
        }
        $text = "<p><i><nop>$to moved from <nop>$from on $date by %MAINWEB%.$by </i>$putBack</p>";
    }
    
    return $text;
}


# =========================
sub renderClassificationData
{
    my( $web, $topic, $metaP ) = @_;

    my @meta = @$metaP;
    
    my $metaText = "";
    
    foreach my $metaItem ( @meta ) {
       if( $metaItem =~ /(%META:CLASSIFICATION\{)([^\}]*)(}%)/ ) {
           my $args = $2;
           my $name = extractNameValuePair( $args, "name" );
           $metaText .= "| *[[$name]]*  ||\n";
       }
    }
    
    foreach my $metaItem( @meta ) {
       if( $metaItem =~ /(%META:CATEGORY\{)([^\}]*)(}%)/ ) {
           my $args = $2;
           my $name  = extractNameValuePair( $args, "name" );
           my $value = extractNameValuePair( $args, "value" );
           $metaText .= "|  *[[$name]]*  |  $value  |\n";
       }
    }
    
    return $metaText;
}


# =========================
sub renderMetaData
{
    my( $web, $topic, $meta, $dontRenderMoved ) = @_;

    my $attachmentText = TWiki::Attach::renderMetaData( $web, $topic, $meta );
    
    my $classificationText = renderClassificationData( $web, $topic, $meta );

    my $movedText = "";
    if( ! $dontRenderMoved ) {
        $movedText = renderMoved( $web, $topic, $meta );
    }
    
    my $text = "\n---\n$attachmentText\n$classificationText\n$movedText";
    
    $text = handleCommonTags( $text, $topic, $web );
    $text = getRenderedVersion( $text, $web );
    
    return $text;
}


# =========================
sub emitCode {
    ( $code, $depth ) = @_;
    my $result="";
    while( @code > $depth ) {
        local($_) = pop @code;
        $result= "$result</$_>\n"
    } while( @code < $depth ) {
        push( @code, ($code) );
        $result= "$result<$code>\n"
    }

    if( ( $#code > -1 ) && ( $code[$#code] ne $code ) ) {
        $result= "$result</$code[$#code]><$code>\n";
        $code[$#code] = $code;
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
        s/^\s$/ &nbsp; /o;
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
    #   case heading has a WikiName that gets linked

    my $text = $theText;
    my $anchorName = &makeAnchorName( $text );
    my $hasAnchor = 0;  # text contains potential anchor
    $hasAnchor = 1 if( $text =~ m/<a /i );
    $hasAnchor = 1 if( $text =~ m/\[\[/ );

    $hasAnchor = 1 if( $text =~ m/(^|[\*\s][\-\*\s]*)([A-Z]{3,})/ );
    $hasAnchor = 1 if( $text =~ m/(^|[\*\s][\(\-\*\s]*)([A-Z]+[a-z]*)\.([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/ );
    $hasAnchor = 1 if( $text =~ m/(^|[\*\s][\(\-\*\s]*)([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/ );
    if( $hasAnchor ) {
        # FIXME: '<h1><a name="atext"></a></h1> WikiName' has an
        #        empty <a> tag, which is not HTML conform
        $text = "<nop><h$theLevel><a name =\"$anchorName\"> </a> $theText <\/h$theLevel>";
    } else {
        $text = "<nop><h$theLevel><a name =\"$anchorName\"> $theText <\/a><\/h$theLevel>";
    }

    return $text;
}

# =========================
sub makeAnchorName
{
    my( $theName ) = @_;
    my $anchorName = $theName;

    $anchorName =~ s/^[\s\#\_]*//o;       # no leading space nor '#', '_'
    $anchorName =~ s/[\s\_]*$//o;         # no trailing space, nor '_'
    $anchorName =~ s/<\w[^>]*>//goi;      # remove HTML tags
    $anchorName =~ s/[^a-zA-Z0-9]/_/go;   # only allowed chars
    $anchorName =~ s/__+/_/go;            # remove excessive '_'
    $anchorName =~ s/^(.{32})(.*)$/$1/o;  # limit to 32 chars

    return $anchorName;
}

# =========================
sub internalLink
{
    my( $thePreamble, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink ) = @_;
    # $thePreamble is heading space
    # $doLink is boolean, false suppress link for non-existing pages

    # kill spaces and Wikify page name (ManpreetSingh - 15 Sep 2000)
    $theTopic =~ s/^\s*//;
    $theTopic =~ s/\s*$//;
    $theTopic =~ s/^(.)/\U$1/;
    $theTopic =~ s/\s([a-zA-Z0-9])/\U$1/g;
    # Add <nop> before WikiWord inside text to prevent double links
    $theLinkText =~ s/(\s)([A-Z]+[a-z]+[A-Z])/$1<nop>$2/go;

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
              .  "<a href=\"$scriptUrlPath/edit$scriptSuffix/$theWeb/$theTopic\">?</a>";
        return $text;

    } else {
        $text .= $theLinkText;
        return $text;
    }
}

# =========================
sub specificLink
{
    my( $thePreamble, $theWeb, $theTopic, $theText, $theLink ) = @_;

    # format: $thePreamble[[$theText]]
    # format: $thePreamble[[$theText][$theLink]]

    $theLink =~ s/^\s*//o;
    $theLink =~ s/\s*$//o;

    if( $theLink =~ /^(http|ftp|gopher|news|file|https)\:/ ) {
        # found external link
        return "$thePreamble<a href=\"$theLink\" target=\"_top\">$theText</a>";
    }

    $theLink =~ s/^([A-Z]+[a-z]*)\.//o;

    my $web = $1 || $theWeb;            # extract 'Web.'
    (my $baz = "foo") =~ s/foo//;       # reset $1, defensive coding
    $theLink =~ s/(\#[a-zA-Z_0-9\-]*$)//o;
    my $anchor = $1 || "";              # extract '#anchor'
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
    my( $text, $theWeb ) = @_;
    my( $result, $insidePRE, $insideVERBATIM, $insideTABLE, $noAutoLink, $blockquote );

    # FIXME: Get $theTopic from parameter to handle [[#anchor]] correctly
    # (fails in %INCLUDE%, %SEARCH%)
    my $theTopic = $topicName;

    # PTh 22 Jul 2000: added $theWeb for correct handling of %INCLUDE%, %SEARCH%
    if( !$theWeb ) {
        $theWeb = $webName;
    }
    $result = "";
    $insidePRE = 0;
    $insideVERBATIM = 0;  # PTh 31 Jan 2001: Added Codev.VerbatimModeForSourceCodes
    $insideTABLE = 0;
    $noAutoLink = 0;      # PTh 02 Feb 2001: Added Codev.DisableWikiWordLinks
    $blockquote = 0;
    $code = "";
    $text =~ s/\r//go;
    $text =~ s/\\\n//go;  # Join lines ending in "\"

    # Wiki Plugin Hook
    &TWiki::Plugins::startRenderingHandler( $text, $theWeb );

    foreach( split( /\n/, $text ) ) {

        # change state:
        m|<pre>|i  && ( $insidePRE = 1 );
        m|</pre>|i && ( $insidePRE = 0 );
        if( m|<verbatim>|i ) {
            s|<verbatim>|<pre>|goi;
            $insideVERBATIM = 1;
        }
        if( m|</verbatim>|i ) {
            s|</verbatim>|</pre>|goi;
            $insideVERBATIM = 0;
        }
        m|<noautolink>|i   && ( $noAutoLink = 1 );
        m|</noautolink>|i  && ( $noAutoLink = 0 );

        if( $insidePRE || $insideVERBATIM ) {
            # inside <PRE> or <VERBATIM>

            if( $insideVERBATIM ) {
                s/\&/&amp;/go;
                s/\</&lt;/go;
                s/\>/&gt;/go;
                s/\&lt;pre\&gt;/<pre>/go;  # fix escaped <pre>
            }

# Wiki Plugin Hook
            &TWiki::Plugins::insidePREHandler( $_ );

            s/(.*)/$1\n/o;

        } else {
            # normal state, do Wiki rendering

# Wiki Plugin Hook
            &TWiki::Plugins::outsidePREHandler( $_ );

# Blockquote
            s/^>(.*?)$/> <cite> $1 <\/cite><br>/go;

# Embedded HTML
            s/\<(\!\-\-)/$TranslationToken$1/go;  # Allow standalone "<!--"
            s/(\-\-)\>/$1$TranslationToken/go;    # Allow standalone "-->"
            s/\<(\S.*?)\>/$TranslationToken$1$TranslationToken/go;
            s/</&lt\;/go;
            s/>/&gt\;/go;
            s/$TranslationToken(\S.*?)$TranslationToken/\<$1\>/go;
            s/(\-\-)$TranslationToken/$1\>/go;
            s/$TranslationToken(\!\-\-)/\<$1/go;

# Handle embedded URLs
            s@(^|[\-\*\s])((http|ftp|gopher|news|file|https)\:(\S+[^\s\.,!\?;:]))@&externalLink($1,$2)@geo;

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
            s@^([a-zA-Z0-9]+)----*@<table width=\"100%\"><tr><td valign=\"bottom\"><h2>$1</h2></td><td width=\"98%\" valign=\"middle\"><HR></td></tr></table>@o;

# Table of format: | cell | cell |
            # PTh 25 Jan 2001: Forgiving syntax, allow trailing white space
            if( $_ =~ /^(\s*)\|.*\|\s*$/ ) {
                s/^(\s*)\|(.*)/&emitTR($1,$2,$insideTABLE)/eo;
                $insideTABLE = 1;
            } elsif( $insideTABLE ) {
                $result .= "</table>\n";
                $insideTABLE = 0;
            }

# Lists etc.
            s/^\s*$/<p> /o                   && ( $code = 0 );
            m/^(\S+?)/o                      && ( $code = 0 );
            s/^(\t+)(\S+?):\s/<dt> $2<dd> /o && ( $result .= &emitCode( "dl", length $1 ) );
            s/^(\t+)\* /<li> /o              && ( $result .= &emitCode( "ul", length $1 ) );
            s/^(\t+)\d+\.?/<li> /o           && ( $result .= &emitCode( "ol", length $1 ) );
            if( !$code ) {
                $result .= &emitCode( "", 0 );
                $code = "";
            }

# '#WikiName' anchors
            s/^(\#)([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/ '<a name="' . &makeAnchorName( $2 ) . '"><\/a>'/geo;

# enclose in white space for the regex that follow
             s/(.*)/\n$1\n/o;

# Emphasizing
            # PTh 25 Sep 2000: More relaxing rules, allow leading '(' and trailing ',.;:!?)'
            s/([\s\(])==([^\s]+?|[^\s].*?[^\s])==([\s\,\.\;\:\!\?\)])/$1 . &fixedFontText( $2, 1 ) . $3/geo;
            s/([\s\(])__([^\s]+?|[^\s].*?[^\s])__([\s\,\.\;\:\!\?\)])/$1<strong><em>$2<\/em><\/strong>$3/go;
            s/([\s\(])\*([^\s]+?|[^\s].*?[^\s])\*([\s\,\.\;\:\!\?\)])/$1<strong>$2<\/strong>$3/go;
            s/([\s\(])_([^\s]+?|[^\s].*?[^\s])_([\s\,\.\;\:\!\?\)])/$1<em>$2<\/em>$3/go;
            s/([\s\(])=([^\s]+?|[^\s].*?[^\s])=([\s\,\.\;\:\!\?\)])/$1 . &fixedFontText( $2, 0 ) . $3/geo;

# Mailto
            s#(^|[\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+@[a-zA-Z0-9\-\_\.]+\.[a-zA-Z0-9\-\_\.]*[a-zA-Z0-9\-\_])(?=[\s\.\,\;\:\!\?\)])#$1<a href=\"mailto\:$2">$2</a>#go;

# Make internal links
            # '[[Web.odd wiki word#anchor][display text]]' link:
            s/\[\[(.*?)\]\[(.*?)\]\]/&specificLink("",$theWeb,$theTopic,$2,$1)/geo;
            # '[[Web.odd wiki word#anchor]]' link:
            s/\[\[(.*?)\]\]/&specificLink("",$theWeb,$theTopic,$1,$1)/geo;

            # do normal WikiWord link if not disabled by <noautolink>
            if( ! ( $noAutoLink ) ) {

                # 'Web.TopicName#anchor' link:
                s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]*)\.([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)(\#[a-zA-Z0-9_]*)/&internalLink($1,$2,$3,"$TranslationToken$3$4$TranslationToken",$4,1)/geo;
                # 'Web.TopicName' link:
                s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]*)\.([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/&internalLink($1,$2,$3,"$TranslationToken$3$TranslationToken","",1)/geo;
                # 'TopicName#anchor' link:
                s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)(\#[a-zA-Z0-9_]*)/&internalLink($1,$theWeb,$2,"$TranslationToken$2$3$TranslationToken",$3,1)/geo;
                # 'TopicName' link:
                s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/&internalLink($1,$theWeb,$2,$2,"",1)/geo;
                # 'Web.ABBREV' link:
                s/([\*\s][\-\*\s]*)([A-Z]+[a-z]*)\.([A-Z]{3,})/&internalLink($1,$2,$3,$3,"",0)/geo;
                # 'ABBREV' link:
                s/([\*\s][\-\*\s]*)([A-Z]{3,})/&internalLink($1,$theWeb,$2,$2,"",0)/geo;
                # depreciated link:
                s/<link>(.*?)<\/link>/&internalLink("",$theWeb,$1,$1,"",1)/geo;

                s/$TranslationToken(\S.*?)$TranslationToken/$1/go;
            }

            s/^\n//o;
        }
        s/\t/   /go;
        $result .= $_;
    }
    if( $insideTABLE ) {
        $result .= "</table>\n";
    }
    $result .= &emitCode( "", 0 );
    if( $insidePRE || $insideVERBATIM ) {
        $result .= "</pre>\n";
    }

    # Wiki Plugin Hook
    &TWiki::Plugins::endRenderingHandler( $result );

    return $result;
}

1;


