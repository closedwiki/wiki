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
#    With this patch each topic can have its own template. TWiki::readTemplate()
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
        $wikiToolName $securityFilter
        $debugFilename $htpasswdFilename 
        $logFilename $remoteUserFilename $wikiUsersTopicname 
        $userListFilename %userToWikiList
        $twikiWebname $mainWebname $mainTopicname $notifyTopicname
        $wikiPrefsTopicname $webPrefsTopicname
        $statisticsTopicname $statsTopViews $statsTopContrib
        $numberOfRevisions $editLockTime $mailProgram $wikiversion 
        $doKeepRevIfEditLock $doRemovePortNumber
        $doRememberRemoteUser $doPluralToSingular
        $doHidePasswdInRegistration $doSecureInclude
        $doLogTopicView $doLogTopicEdit $doLogTopicSave
        $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff 
        $doLogTopicChanges $doLogTopicSearch $doLogRegistration
        @isoMonth $TranslationToken $code @code $depth %mon2num
        $scriptSuffix
        $newTopicFontColor $newTopicBgColor
    );

# TWiki::Store config:
use vars qw(
        $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd $revInfoCmd
        $revDiffCmd $revDelRevCmd $revUnlockCmd $revLockCmd
    );

# TWiki::Search config:
use vars qw(
        $lsCmd $egrepCmd $fgrepCmd
    );



# ===========================
# TWiki version:
$wikiversion      = "11 Feb 2001";

# ===========================
# read the configuration part
do "TWiki.cfg";

# ===========================
# read the preferences part
##do "TWiki/Prefs.pm";
use TWiki::Prefs;

# ===========================
# read the search engine part
##do "TWiki/Search.pm";
use TWiki::Search;

# ===========================
# read the access control part
##do "TWiki/Access.pm";
use TWiki::Access;

# ===========================
# read the rcs related functions
##do "TWiki/Store.pm";
use TWiki::Store;

#AS
# =========================
# read the plugins handler
##do "TWiki/Plugins.pm";
use TWiki::Plugins;
#/AS


# ===========================
# variables: (new variables must be declared in "use vars qw(..)" above)
@isoMonth     = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );

{ my $count = 0;
  %mon2num = map { $_ => $count++ } @isoMonth; }

# =========================
sub initialize
{
    my ( $thePathInfo, $theRemoteUser, $theTopic, $theUrl ) = @_;

    # Make %ENV safer for CGI
    $ENV{'PATH'} = '/bin:/usr/bin';
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    # initialize access control
    &TWiki::Access::initializeAccess();

    # initialize user name and user to WikiName list
    $userName = initializeRemoteUser( $theRemoteUser );
    userToWikiListInit();
    $wikiUserName = userToWikiName( $userName );

    # initialize $webName and $topicName
    # test if $thePathInfo is "/Webname/SomeTopic" or "/Webname/"
    if( ( $thePathInfo =~ /[\/](.*)\/(.*)/ ) && ( $1 ) ) {
        $webName = $1;
    } else {
        # test if $thePathInfo is "/Webname" or "/"
        $thePathInfo =~ /[\/](.*)/;
        $webName = $1 || $mainWebname;
    }
    if( $2 ) {
        $topicName = $2;
    } else {
        if( $theTopic ) {
            $topicName = $theTopic;
        } else {
            $topicName = $mainTopicname;
        }
    }
    ( $topicName =~ /\.\./ ) && ( $topicName = $mainTopicname );
    # filter out dangerous or unwanted characters:
    $topicName =~ s/$securityFilter//go;
    $topicName =~ /(.*)/;
    $topicName = $1;  # untaint variable
    $webName   =~ s/$securityFilter//go;
    $webName   =~ /(.*)/;
    $webName   = $1;  # untaint variable
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
    &TWiki::Plugins::initialize( $topicName, $webName, $userName );
#/AS

    return ( $topicName, $webName, $scriptUrlPath, $userName, $dataDir );
}

# =========================
sub writeDebug
{
    my( $text) = @_;
    open( FILE, ">>$debugFilename");
    print FILE "$text\n";
    close( FILE);
}

# =========================
sub writeLog
{
    my( $action, $webTopic, $extra, $user ) = @_;

    # use local time for log, not UTC (gmtime)

    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
    my( $tmon) = $isoMonth[$mon];
    $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
    my $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min );
    my $yearmonth = sprintf( "%.4u%.2u", $year, $mon+1 );

    my $wuserName = $user || $userName;
    $wuserName = userToWikiName( $wuserName );
    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";
    my $text = "| $time | $wuserName | $action | $webTopic | $extra | $remoteAddr |";

    my $filename = $logFilename;
    $filename =~ s/%DATE%/$yearmonth/go;
    open( FILE, ">>$filename");
    print FILE "$text\n";
    close( FILE);
}

# =========================
sub sendEmail
{
    # Format: "From: ...\nTo: ...\nSubject: ...\n\nMailBody..."

    my( $mailText) = @_;

    if( open( MAIL, "|-" ) || exec "$mailProgram" ) {
        print MAIL $mailText;
        close( MAIL );
        return "OK";
    }
    return "";
}

# =========================
sub getEmailNotifyList
{
    my( $web, $topicname ) = @_;

    if ( ! $topicname ) {
        $topicname = $notifyTopicname;
    }
    my $list = "";
    my $line = "";
    my $fileName = "$dataDir/$web/$topicname.txt";
    if ( -e $fileName ) {
        my @list = split( /\n/, readFile( $fileName ) );
        @list = grep { /^\s\*\s[A-Za-z0-9\.]+\s+\-\s+[A-Za-z0-9\-_\.\+]+/ } @list;
        foreach $line ( @list ) {
            $line =~ s/\-\s+([A-Za-z0-9\-_\.\+]+\@[A-Za-z0-9\-_\.\+]+)/$1/go;
            if( $1 ) {
                $list = "$list, $1";
            }
        }
        $list =~ s/^[\s\,]*//go;
        $list =~ s/[\s\,]*$//go;
    }
    return $list;
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

    my $text = TWiki::readFile( $remoteUserFilename );
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
            TWiki::saveFile( $remoteUserFilename, $text );
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
    my $text = TWiki::readFile( $userListFilename );
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
            %userToWikiList = ( %userToWikiList, $lUser, $wUser );
        }
    }
}

# =========================
sub userToWikiName
{
    my( $loginUser ) = @_;

    $loginUser =~ s/$securityFilter//go;
    my $wUser = $userToWikiList{ $loginUser };
    if( $wUser ) {
        return "$mainWebname.$wUser";
    }
    return "$mainWebname.$loginUser";
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
sub readFile
{
    my( $name ) = @_;
    my $data = "";
    undef $/; # set to read to EOF
    open( IN_FILE, "<$name" ) || return "";
    $data = <IN_FILE>;
    $/ = "\n";
    close( IN_FILE );
    return $data;
}

# =========================
sub readFileHead
{
    my( $name, $maxLines ) = @_;
    my $data = "";
    my $line;
    my $l = 0;
    $/ = "\n";     # read line by line
    open( IN_FILE, "<$name" ) || return "";
    while( ( $l < $maxLines ) && ( $line = <IN_FILE> ) ) {
        $data .= $line;
        $l += 1;
    }
    close( IN_FILE );
    return $data;
}

# =========================
sub saveFile
{
    my( $name, $text ) = @_;
    open( FILE, ">$name" ) or warn "Can't create file $name\n";
    print FILE $text;
    close( FILE);
}

# =========================
sub topicIsLocked
{
    my( $name ) = @_;

    # pragmatic approach: Warn user if somebody else pressed the
    # edit link within one hour

    my $lockFilename = "$dataDir/$webName/$name.lock";
    if( ( -e "$lockFilename" ) && ( $editLockTime > 0 ) ) {
        my $tmp = TWiki::readFile( $lockFilename );
        my( $lockUser, $lockTime ) = split( /\n/, $tmp );
        if( $lockUser ne $userName ) {
            # time stamp of lock within one hour of current time?
            my $systemTime = time();
            # calculate remaining lock time in seconds
            $lockTime = $lockTime + $editLockTime - $systemTime;
            if( $lockTime > 0 ) {
                # must warn user that it is locked
                return ( $lockUser, $lockTime );
            }
        }
    }
    return ( "", 0);
}

# =========================
sub lockTopic
{
    my( $name, $doUnlock ) = @_;

    my $lockFilename = "$dataDir/$webName/$name.lock";
    if( $doUnlock ) {
        unlink "$lockFilename";
    } else {
        my $lockTime = time();
        saveFile( $lockFilename, "$userName\n$lockTime" );
    }
}

# =========================
sub removeObsoleteTopicLocks
{
    my( $web ) = @_;

    # Clean all obsolete .lock files in a web.
    # This should be called regularly, best from a cron job (called from mailnotify)

    my $webDir = "$dataDir/$web";
    opendir( DIR, "$webDir" );
    my @fileList = grep /\.lock$/, readdir DIR;
    closedir DIR;
    my $file = "";
    my $pathFile = "";
    my $lockUser = "";
    my $lockTime = "";
    my $systemTime = time();
    foreach $file ( @fileList ) {
        $pathFile = "$webDir/$file";
        $pathFile =~ /(.*)/;
        $pathFile = $1;       # untaint file
        ( $lockUser, $lockTime ) = split( /\n/, readFile( "$pathFile" ) );
        if( ! $lockTime ) { $lockTime = ""; }

        # time stamp of lock over one hour of current time?
        if( abs( $systemTime - $lockTime ) > $editLockTime ) {
            # obsolete, so delete file
            unlink "$pathFile";
        }
    }
}

# =========================
sub topicExists
{
    my( $web, $name ) = @_;
    return -e "$dataDir/$web/$name.txt";
}

# =========================
sub readTopic
{
    my( $name ) = @_;
    return &readFile( "$dataDir/$webName/$name.txt" );
}

# =========================
sub readWebTopic
{
    my( $web, $name ) = @_;
    return &readFile( "$dataDir/$web/$name.txt" );
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
sub readTemplate
{
    my( $theName, $theTopic, $theSkin ) = @_;
    $theTopic = "" unless $theTopic; # prevent 'uninitialized value' ...
    $theSkin  = "" unless $theSkin;  #   ... warnings

    # CrisBailiff, PeterThoeny 13 Jun 2000: Add security
    $theName =~ s/$securityFilter//go;    # zap anything suspicious
    $theName =~ s/\.+/\./g;               # Filter out ".." from filename
    $theTopic =~ s/$securityFilter//go;   # zap anything suspicious
    $theTopic =~ s/\.+/\./g;              # Filter out ".." from filename
    $theSkin =~ s/$securityFilter//go;    # zap anything suspicious
    $theSkin =~ s/\.+/\./g;               # Filter out ".." from filename

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.topic)(.skin).tmpl
    my $tmplDir = "$templateDir/$webName";
    if( opendir( DIR, $tmplDir ) ) {
        # for performance use readdir, not a row of ( -e file )
        my @filelist = grep /^$theName\..*tmpl$/, readdir DIR;
        closedir DIR;
        $tmplFile = "$theName.$theTopic.tmpl";
        if( ! grep { /^$tmplFile$/ } @filelist ) {
            $tmplFile = "$theName.$theSkin.tmpl";
            if( ! grep { /^$tmplFile$/ } @filelist ) {
                $tmplFile = "$theName.$theTopic.$theSkin.tmpl";
                if( ! grep { /^$tmplFile$/ } @filelist ) {
                    $tmplFile = "$theName.tmpl";
                    if( ! grep { /^$tmplFile$/ } @filelist ) {
                        $tmplFile = "";
                    }
                }
            }
        }
        if( $tmplFile ) {
            $tmplFile = "$tmplDir/$tmplFile";
        }
    }

    # if not found, search in twiki/templates dir
    $tmplDir = $templateDir;
    if( ( ! $tmplFile ) && ( opendir( DIR, $tmplDir ) ) ) {
        my @filelist = grep /^$theName\..*tmpl$/, readdir DIR;
        closedir DIR;
        $tmplFile = "$theName.$theTopic.tmpl";
        if( ! grep { /^$tmplFile$/ } @filelist ) {
            $tmplFile = "$theName.$theSkin.tmpl";
            if( ! grep { /^$tmplFile$/ } @filelist ) {
                $tmplFile = "$theName.$theTopic.$theSkin.tmpl";
                if( ! grep { /^$tmplFile$/ } @filelist ) {
                    $tmplFile = "$theName.tmpl";
                    if( ! grep { /^$tmplFile$/ } @filelist ) {
                        $tmplFile = "";
                    }
                }
            }
        }
        if( $tmplFile ) {
            $tmplFile = "$tmplDir/$tmplFile";
        }
    }

    # read the template file
    if( -e $tmplFile ) {
        return &readFile( $tmplFile );
    }
    return "";
}


# =========================
sub webExists
{
    my( $web ) = @_;
    return -e "$dataDir/$web";
}

# =========================
sub makeTopicSummary
{
    my( $theText, $theTopic, $theWeb ) = @_;
    # called by search, mailnotify & changes after calling readFileHead

    my $htext = $theText;
    $htext =~ s/<[^>]*>//go;         # remove all HTML tags
    $htext =~ s/%INCLUDE[^%]*%/ /go; # remove server side includes
    $htext =~ s/%SEARCH[^%]*%/ /go;  # remove inline search
    $htext =~ s/%DRAWING[^%]*%/ /go; # remove TWikiDraw drawing
    $htext =~ s/%ATTACH[A-Z_0-9]*%//go;
    $htext =~ s/%PUB[A-Z_0-9]*%//go;
    $htext =~ s/%SCRIPT[A-Z_0-9]*%//go;
    $htext = handleCommonTags( $htext, $theTopic, $theWeb );
    $htext =~ s/<[^>]*>//go;         # remove all HTML tags
    $htext =~ s/[\[\]\*\|=_]/ /go;   # remove Wiki formatting chars
    $htext =~ s/\s+[\+\-]*/ /go;     # remove newlines and special chars

    # inline search renders text, 
    # so prevent linking of external and internal links:
    $htext =~ s/([\-\*\s])((http|ftp|gopher|news|https)\:)/$1<nop>$2/go;
    $htext =~ s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]*\.[A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*))/$1<nop>$2/go;
    $htext =~ s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*))/$1<nop>$2/go;
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
        # format is: name = "value"
        if( ( $str =~ /(^|[^\S])$name[\s]*=[\s]*[\"]([^\"]*)/ ) && ( $2 ) ) {
            return $2;
        }
    } else {
        # test if format: "value"
        if( ( $str =~ /(^|=[\s]*[\"][^\"]*\")[\s]*[\"]([^\"]*)/ ) && ( $2 ) ) {
            return $2;
        } elsif( ( $str =~ /^[\s]*([^"]\S*)/ ) && ( $1 ) ) {
            # format is: value
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

    # finally include file
    my $text = &readFile( $fileName );

    # set include web/filenames and current web/filenames
    $includingWebName = $theWeb;
    $includingTopicName = $theTopic;
    $fileName =~ s/\/([^\/]*)\/([^\/]*)(\.txt)$/$1/go;
    if( $3 ) {
        # identified "/Web/TopicName.txt" filename, e.g. a Wiki topic
        # so save the current web and topic name
        $theWeb = $1;
        $theTopic = $2;

        # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
        $text =~ s/.*?%STARTINCLUDE%//os;
        $text =~ s/%STOPINCLUDE%.*//os;
    }

    # handle all preferences and internal tags (for speed: call by reference)
    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );

    # recursively process multiple embeded %INCLUDE% statements and prefs
    $text =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $theTopic, $theWeb, @theProcessedTopics )/geo;

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

    my $attrWeb = extractNameValuePair( $attributes, "web" );
    my $attrScope = extractNameValuePair( $attributes, "scope" );
    my $attrOrder = extractNameValuePair( $attributes, "order" );
    my $attrRegex = extractNameValuePair( $attributes, "regex" );
    my $attrLimit = extractNameValuePair( $attributes, "limit" );
    my $attrReverse = extractNameValuePair( $attributes, "reverse" );
    my $attrCasesensitive = extractNameValuePair( $attributes, "casesensitive" );
    my $attrNosummary = extractNameValuePair( $attributes, "nosummary" );
    my $attrNosearch = extractNameValuePair( $attributes, "nosearch" );
    my $attrNoheader = extractNameValuePair( $attributes, "noheader" );
    my $attrNototal = extractNameValuePair( $attributes, "nototal" );
    my $attrBookview = extractNameValuePair( $attributes, "bookview" );

    return &TWiki::Search::searchWeb( "1", $attrWeb, $searchVal, $attrScope,
       $attrOrder, $attrRegex, $attrLimit, $attrReverse,
       $attrCasesensitive, $attrNosummary, $attrNosearch,
       $attrNoheader, $attrNototal, $attrBookview
    );
}

# =========================
sub handleTime
{
    my( $theAttributes, $theZone ) = @_;
    # format examples:
    #   28 Jul 2000 15:33 is "day month year hour:min:sec"
    #   001128 "2year0monthday"

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
            $value =~ s/\$mon[a-z]*/$isoMonth[$mon]/goi;
            $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
            $value =~ s/\$yea[a-z]*/sprintf("%.4u",$year+1900)/geoi;
            $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;
        } elsif( $theZone eq "servertime" ) {
            my( $sec, $min, $hour, $day, $mon, $year) = localtime( $time );
            $value = $format;
            $value =~ s/\$sec[a-z]*/sprintf("%.2u",$sec)/geoi;
            $value =~ s/\$min[a-z]*/sprintf("%.2u",$min)/geoi;
            $value =~ s/\$hou[a-z]*/sprintf("%.2u",$hour)/geoi;
            $value =~ s/\$day[a-z]*/sprintf("%.2u",$day)/geoi;
            $value =~ s/\$mon[a-z]*/$isoMonth[$mon]/goi;
            $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
            $value =~ s/\$yea[a-z]*/sprintf("%.4u",$year+1900)/geoi;
            $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;
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
    $_[0] =~ s/%WIKIHOMEURL%/$wikiHomeUrl/go;
    $_[0] =~ s/%SCRIPTURL%/$urlHost$scriptUrlPath/go;
    $_[0] =~ s/%SCRIPTURLPATH%/$scriptUrlPath/go;
    $_[0] =~ s/%SCRIPTSUFFIX%/$scriptSuffix/go;
    $_[0] =~ s/%PUBURL%/$urlHost$pubUrlPath/go;
    $_[0] =~ s/%PUBURLPATH%/$pubUrlPath/go;
    $_[0] =~ s/%ATTACHURL%/$urlHost$pubUrlPath\/$_[2]\/$_[1]/go;
    $_[0] =~ s/%ATTACHURLPATH%/$pubUrlPath\/$_[2]\/$_[1]/go;
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

    # handle tags again because of extend
    &TWiki::Prefs::handlePreferencesTags( $text );
    handleInternalTags( $text, $theTopic, $theWeb );

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
    my ( $pre, $cells, $insideTABLE ) = @_;
    if( $insideTABLE ) {
        $cells = "$pre<TR><TD> $cells";
    } else {
        $cells = "$pre<TABLE border=\"1\"><TR><TD> $cells";
    }
    $cells =~ s@\|\s*$@ </TD></TR>@go;
    $cells =~ s@\|@ </TD><TD> @go;
    return $cells;
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
sub internalLink
{
    my( $web, $page, $text, $bar, $foo ) = @_;
    # bar is heading space
    # foo is boolean, false suppress link for non-existing pages

    # kill spaces and Wikify page name (ManpreetSingh - 15 Sep 2000)
    $page =~ s/^\s*//;
    $page =~ s/\s*$//;
    $page =~ s/^(.)/\U$1/;
    $page =~ s/\s([a-zA-Z0-9])/\U$1/g;
    # Add <nop> before WikiWord inside text to prevent double links
    $text =~ s/(\s)([A-Z]+[a-z]+[A-Z])/$1<nop>$2/go;

    if( $doPluralToSingular && $page =~ /s$/ && ! topicExists( $web, $page) ) {
        # page is a non-existing plural
        my $tmp = $page;
        $tmp =~ s/ies$/y/;      # plurals like policy / policies
        $tmp =~ s/sses$/ss/;    # plurals like address / addresses
        $tmp =~ s/xes$/x/;      # plurals like box / boxes
        $tmp =~ s/([A-Za-rt-z])s$/$1/; # others, excluding ending ss like address(es)
        if( topicExists( $web, $tmp ) ) {
            $page = $tmp;
        }
    }

    topicExists( $web, $page) ?
        "$bar<A href=\"$scriptUrlPath/view$scriptSuffix/$web/$page\">$text<\/A>"
        : $foo?"$bar<SPAN STYLE='background : $newTopicBgColor;'><font color=\"$newTopicFontColor\">$text</font></SPAN><A href=\"$scriptUrlPath/edit$scriptSuffix/$web/$page\">?</A>"
            : "$bar$text";
}

# =========================
sub externalLink
{
    my( $pre, $url ) = @_;
    if( $url =~ /\.(gif|jpg|jpeg|png)$/i ) {
        my $filename = $url;
        $filename =~ s@.*/([^/]*)@$1@go;
        return "$pre<IMG src=\"$url\" alt=\"$filename\">";
    }

    return "$pre<A href=\"$url\" target=\"_top\">$url</A>";
}

# =========================
sub isWikiName
{
    my( $name ) = @_;
    if ( $name =~ /^[A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*)$/ ) {
        return "1";
    }
    return "";
}

# =========================
sub getRenderedVersion
{
    my( $text, $theWeb ) = @_;
    my( $result, $insidePRE, $insideVERBATIM, $insideTABLE, $noAutoLink, $blockquote );

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
            s/^>(.*?)$/> <cite> $1 <\/cite><BR>/go;

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
            s@(^|[\-\*\s])((http|ftp|gopher|news|https)\:(\S+[^\s\.,!\?;:]))@&externalLink($1,$2)@geo;

# Entities
            s/&(\w+?)\;/$TranslationToken$1\;/go;      # "&abc;"
            s/&(\#[0-9]+)\;/$TranslationToken$1\;/go;  # "&#123;"
            s/&/&amp;/go;                              # escape standalone "&"
            s/$TranslationToken/&/go;
            
            s/^----*/<HR>/o;
            s@^([a-zA-Z0-9]+)----*@<table width=\"100%\"><tr><td valign=\"bottom\"><h2>$1</h2></td><td width=\"98%\" valign=\"middle\"><HR></td></tr></table>@o;

# Table of format: | cell | cell |
            # PTh 25 Jan 2001: Forgiving syntax, allow trailing white space
            if( $_ =~ /^(\s*)\|.*\|\s*$/ ) {
                s/^(\s*)\|(\s*)(.*)/&emitTR($1,$3,$insideTABLE)/eo;
                $insideTABLE = 1;
            } elsif( $insideTABLE ) {
                $result .= "</TABLE>\n";
                $insideTABLE = 0;
            }

# Lists etc.
            s/^\s*$/<p> /o                   && ( $code = 0 );
            m/^(\S+?)/o                      && ( $code = 0 );
            s/^(\t+)(\S+?):\s/<DT> $2<DD> /o && ( $result .= &emitCode( "DL", length $1 ) );
            s/^(\t+)\* /<LI> /o              && ( $result .= &emitCode( "UL", length $1 ) );
            s/^(\t+)\d+\.?/<LI> /o           && ( $result .= &emitCode( "OL", length $1 ) );
            if( !$code ) {
                $result .= &emitCode( "", 0 );
                $code = "";
            }

            s/(.*)/\n$1\n/o;

# Emphasizing
            # PTh 25 Sep 2000: More relaxing rules, allow leading '(' and trailing ',.;:!?)'
            s/([\s\(])==([^\s]+?|[^\s].*?[^\s])==([\s\,\.\;\:\!\?\)])/$1 . &fixedFontText( $2, 1 ) . $3/geo;
            s/([\s\(])__([^\s]+?|[^\s].*?[^\s])__([\s\,\.\;\:\!\?\)])/$1<STRONG><EM>$2<\/EM><\/STRONG>$3/go;
            s/([\s\(])\*([^\s]+?|[^\s].*?[^\s])\*([\s\,\.\;\:\!\?\)])/$1<STRONG>$2<\/STRONG>$3/go;
            s/([\s\(])_([^\s]+?|[^\s].*?[^\s])_([\s\,\.\;\:\!\?\)])/$1<EM>$2<\/EM>$3/go;
            s/([\s\(])=([^\s]+?|[^\s].*?[^\s])=([\s\,\.\;\:\!\?\)])/$1 . &fixedFontText( $2, 0 ) . $3/geo;

# Mailto
            s#(^|[\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.]+@[a-zA-Z0-9\-\_\.]+)(?=[\s\)]|$)#$1<A href=\"mailto\:$2">$2</A>#go;

# Make internal links
            # allow [[Odd Wiki Word]] links and [[Web.Odd Wiki Name]]
            s/([\*\s][\(\-\*\s]*)\[\[([A-Z]+[a-z]*)\.([\w\s]+)\]\]/&internalLink($2,$3,"$TranslationToken$3$TranslationToken",$1,1)/geo;
            s/([\*\s][\(\-\*\s]*)\[\[([\w\s]+)\]\]/&internalLink($webName,$2,$2,$1,1)/geo;
            if( $noAutoLink ) {
                # no WikiWord links except [[forced links]]
                s/$TranslationToken(\S.*?)$TranslationToken/$1/go;

            } else {

                ## add Web.TopicName internal link -- PeterThoeny:
                ## allow 'AaA1' type format, but not 'Aa1' type -- PeterThoeny:
                s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]*)\.([A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*))/&internalLink($2,$3,"$TranslationToken$3$TranslationToken",$1,1)/geo;
                s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*))/&internalLink($theWeb,$2,$2,$1,1)/geo;
                s/$TranslationToken(\S.*?)$TranslationToken/$1/go;

                s/([\*\s][\-\*\s]*)([A-Z]{3,})/&internalLink($theWeb,$2,$2,$1,0)/geo;
                s/<link>(.*?)<\/link>/&internalLink($theWeb,$1,$1,"",1)/geo;
            }

            s/^\n//o;
        }
        s/\t/   /go;
        $result .= $_;
    }
    if( $insideTABLE ) {
        $result .= "</TABLE>\n";
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


