#
# TWiki WikiClone (see $wikiversion for version)
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999, 2000 Peter Thoeny, TakeFive Software Inc., 
# peter.thoeny@takefive.com , peter.thoeny@attglobal.net
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
# http://www.gnu.ai.mit.edu/copyleft/gpl.html 
#
# Notes:
# - Latest version at http://www.mindspring.net/~peterthoeny/twiki/index.html
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Optionally change wikicfg.pm for custom extensions of rendering rules.
# - Files wikifcg.pm and wikisearch.pm are included by wiki.pm
# - Upgrading TWiki is easy as long as you do not customize wiki.pm.
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
#    With this patch each topic can have its own template. wiki::readTemplate()
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
#    See http://twiki.sourceforge.net/cgi-bin/view/Codev/UniqueTopicTemplates
#    for further details    

package wiki;

## 0501 kk : vvv Added for revDate2EpSecs
use Time::Local;

use strict;

use vars qw(
        $webName $topicName
        $defaultUserName $userName $wikiUserName 
        $wikiHomeUrl $defaultUrlHost $urlHost
        $scriptUrlPath $pubUrlPath $pubDir $templateDir $dataDir
        $wikiToolName $securityFilter
        $debugFilename $htpasswdFilename 
        $logFilename $wikiUsersTopicname $userListFilename %userToWikiList
        $mainWebname $mainTopicname $notifyTopicname
        $wikiPrefsTopicname $webPrefsTopicname @prefsKeys @prefsValues
        $statisticsTopicname $statsTopViews $statsTopContrib
	$editLockTime 
        $mailProgram $wikiversion 
        $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd $revInfoCmd 
        $revDiffCmd $revDelRevCmd $revUnlockCmd $revLockCmd
        $lsCmd $cpCmd $egrepCmd $fgrepCmd
        $doKeepRevIfEditLock $doRemovePortNumber $doPluralToSingular
        $doSecureInclude
        $doLogTopicView $doLogTopicEdit $doLogTopicSave
        $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff 
        $doLogTopicChanges $doLogTopicSearch $doLogRegistration
        @isoMonth $TranslationToken $code @code $depth %mon2num
        $scriptSuffix );


# ===========================
# TWiki version:
$wikiversion      = "21 Jun 2000";

# ===========================
# read the configuration part
do "wikicfg.pm";

# ===========================
# read the search engine part
do "wikisearch.pm";

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

    # initialize user name and user to WikiName list
    $userName = $defaultUserName;
    if( $theRemoteUser ) {
        $userName = $theRemoteUser;
    }
    $userName =~ s/$securityFilter//go;
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
    # (Note: Do not use a %hash, because order is significant)
    @prefsKeys = ();
    @prefsValues = ();
    getPrefsList( "$mainWebname\.$wikiPrefsTopicname" ); # site-level
    getPrefsList( "$webName\.$webPrefsTopicname" );      # web-level
    getPrefsList( $wikiUserName );                       # user-level

    # some remaining init
    $TranslationToken= "\263";
    $code="";
    @code= ();

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
                $list = "$list $1";
            }
        }
        $list =~ s/^ *//go;
        $list =~ s/ *$//go;
    }
    return $list;
}

# =========================
sub userToWikiListInit
{
    my $text = readFile( $userListFilename );
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
sub getPrefsList
{
    my ( $theWebTopic ) = @_;
    my $fileName = $theWebTopic;                  # "Main.TopicName"
    $fileName =~ s/([^\.]*)\.(.*)/$1\/$2\.txt/go; # "Main/TopicName.txt"
    my $text = readFile( "$dataDir/$fileName" );  # read topic text
    $text =~ s/\r//go;                            # cut CR
    my $key;
    my $value;
    my $isKey = 0;
    foreach( split( /\n/, $text ) ) {
        if( /^\t+\*\sSet\s([a-zA-Z0-9_]*)\s\=\s*(.*)/ ) {
            if( $isKey ) {
                addToPrefsList( $key, $value );
            }
            $key = $1;
            $value = $2 || "";
            $isKey = 1;
        } elsif ( $isKey ) {
            if( ( /^\t+/ ) && ( ! /^\t+\*/ ) ) {
                # follow up line, extending value
                $value .= "\n";
                $value .= $_;
            } else {
                addToPrefsList( $key, $value );
                $isKey = 0;
            }
        }
    }
    if( $isKey ) {
        addToPrefsList( $key, $value );
    }
}

# =========================
sub addToPrefsList
{
    my ( $theKey, $theValue ) = @_;

    $theValue =~ s/\t/ /go;     # replace TAB by space
    $theValue =~ s/\\n/\n/go;   # replace \n by new line
    $theValue =~ s/`//go;       # filter out dangerous chars
    my $x;
    my $found = 0;
    for( $x = 0; $x < @prefsKeys; $x++ ) {
        if( $prefsKeys[$x] eq $theKey ) {
            # replace value of existing key
            $prefsValues[$x] = $theValue;
            $found = "1";
            last;
        }
    }
    if( ! $found ) {
        # append to list
        $prefsKeys[@prefsKeys] = $theKey;
        $prefsValues[@prefsValues] = $theValue;
    }
}

# =========================
sub getPrefsValue
{
    my ( $theKey ) = @_;
    my $x;
    for( $x = 0; $x < @prefsKeys; $x++ ) {
        if( $prefsKeys[$x] eq $theKey ) {
            return $prefsValues[$x];
        }
    }
    return "";
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
        my $tmp = readFile( $lockFilename );
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
        $url .= "\&param1=$theParam1";
    }
    if( $theParam2 ) {
        $url .= "\&param2=$theParam2";
    }
    if( $theParam3 ) {
        $url .= "\&param3=$theParam3";
    }
    if( $theParam4 ) {
        $url .= "\&param4=$theParam4";
    }
    return $url;
}

# =========================
sub readTemplate
{
    my( $name, $topic ) = @_;
    $topic = "" unless $topic; # prevent 'uninitialized value' warnings

    # CrisBailiff, PeterThoeny 13 Jun 2000: Add security
    $name =~ s/$securityFilter//go;    # zap anything suspicious
    $name =~ s/\.+/\./g;               # Filter out ".." from filename
    $topic =~ s/$securityFilter//go;   # zap anything suspicious
    $topic =~ s/\.+/\./g;              # Filter out ".." from filename

    my $webtmpl = "$templateDir/$webName/$name.$topic.tmpl";
    if( -e $webtmpl ) {
        return &readFile( $webtmpl );
    }
    
    $webtmpl = "$templateDir/$webName/$name.tmpl";
    if( -e $webtmpl ) {
        return &readFile( $webtmpl );
    }
    
    $webtmpl = "$templateDir/$name.$topic.tmpl";
    if( -e $webtmpl ) {
        return &readFile( $webtmpl );
    }
    return &readFile( "$templateDir/$name.tmpl" );
}

# =========================
sub readVersion
{
    my( $theTopic, $theRev ) = @_;
    my $tmp= $revCoCmd;
    my $fileName = "$dataDir/$webName/$theTopic.txt";
    $tmp =~ s/%FILENAME%/$fileName/;
    $tmp =~ s/%REVISION%/$theRev/;
    $tmp =~ /(.*)/;
    $tmp = $1;       # now safe, so untaint variable
    return `$tmp`;
}

# =========================
sub getRevisionNumber
{
    my( $theTopic, $theWebName ) = @_;
    if( ! $theWebName ) {
        $theWebName = $webName;
    }
    my $tmp= $revHistCmd;
    my $fileName = "$dataDir/$theWebName/$theTopic.txt";
    $tmp =~ s/%FILENAME%/$fileName/;
    $tmp =~ /(.*)/;
    $tmp = $1;       # now safe, so untaint variable
    $tmp = `$tmp`;
    $tmp =~ /head: (.*?)\n/;
    if( ( $tmp ) && ( $1 ) ) {
        return $1;
    } else {
        return "1.1";
    }
}

# =========================
sub getRevisionDiff
{
    my( $topic, $rev1, $rev2 ) = @_;

    my $tmp= "";
    if ( $rev1 eq "1.1" && $rev2 eq "1.1" ) {
        my $text = readVersion($topic, 1.1);    # bug fix 19 Feb 1999
        $tmp = "1a1\n";
        foreach( split( /\n/, $text ) ) {
           $tmp = "$tmp> $_\n";
        }
    } else {
        $tmp= $revDiffCmd;
        $tmp =~ s/%REVISION1%/$rev1/;
        $tmp =~ s/%REVISION2%/$rev2/;
        my $fileName = "$dataDir/$webName/$topic.txt";
        $fileName =~ s/$securityFilter//go;
        $tmp =~ s/%FILENAME%/$fileName/;
        $tmp =~ /(.*)/;
        $tmp = $1;       # now safe, so untaint variable
        $tmp = `$tmp`;
    }
    return "$tmp";
}

# =========================
sub getRevisionInfo
{
    my( $theTopic, $theRev, $changeToIsoDate, $theWebName ) = @_;
    if( ! $theWebName ) {
        $theWebName = $webName;
    }
    if( ! $theRev ) {
        $theRev = getRevisionNumber( $theTopic, $theWebName );
    }
    my $tmp= $revInfoCmd;
    $theRev =~ s/$securityFilter//go;
    $tmp =~ s/%REVISION%/$theRev/;
    my $fileName = "$dataDir/$theWebName/$theTopic.txt";
    $fileName =~ s/$securityFilter//go;
    $tmp =~ s/%FILENAME%/$fileName/;
    $tmp =~ /(.*)/;
    $tmp = $1;       # now safe, so untaint variable
    $tmp = `$tmp`;
    $tmp =~ /date: (.*?);  author: (.*?);/;
    my $date = $1;
    my $user = $2;
    if( ! $user ) {
        return ( "", "" );
    }
    if( $changeToIsoDate ) {
        # change date to ISO format
        $tmp = $1;
        $tmp =~ /(.*?)\/(.*?)\/(.*?) (.*?):[0-9][0-9]$/;
        if( $4 ) {
           $date = "$3 $isoMonth[$2-1] $1 - $4";
        }
    }
    return ( $date, $user );
}

# =========================
sub saveTopic
{
    my( $topic, $text, $saveCmd, $doNotLogChanges, $doUnlock ) = @_;
    my $name = "$dataDir/$webName/$topic.txt";
    my $time = time();
    my $tmp = "";

    #### Normal Save
    if( ! $saveCmd ) {
        $saveCmd = "";

        # get time stamp of existing file
        my $mtime1 = 0;
        my $mtime2 = 0;
        if( -e $name ) {
            my( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$tmp8,$tmp9,
                $tmp10,$tmp11,$tmp12,$tmp13 ) = stat $name;
            $mtime1 = $tmp10;
        }

        # save file
        saveFile( $name, $text );

        # reset lock time, this is to prevent contention in case of a long edit session
        lockTopic( $topic, $doUnlock );

        # time stamp of existing file within one hour of old one?
        my( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$tmp8,$tmp9,
            $tmp10,$tmp11,$tmp12,$tmp13 ) = stat $name;
        $mtime2 = $tmp10;
        if( abs( $mtime2 - $mtime1 ) < $editLockTime ) {
            my $rev = getRevisionNumber( $topic );
            my( $date, $user ) = getRevisionInfo( $topic, $rev );
            # same user?
            if( ( $doKeepRevIfEditLock ) && ( $user eq $userName ) ) {
                # replace last repository entry
                $saveCmd = "repRev";
            }
        }

        if( $saveCmd ne "repRev" ) {
            # update repository
            $tmp= $revCiCmd;
            $tmp =~ s/%USERNAME%/$userName/;
            $tmp =~ s/%FILENAME%/$name/;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            `$tmp`;

            if( ! $doNotLogChanges ) {
                # update .changes
                my @foo = split(/\n/, &readFile( "$dataDir/$webName/.changes" ) );
                if( $#foo > 100 ) {
                    shift( @foo);
                }
                push( @foo, "$topic\t$userName\t$time" );
                open( FILE, ">$dataDir/$webName/.changes" );
                print FILE join( "\n", @foo )."\n";
                close(FILE);

                if( $doLogTopicSave ) {
                    # write log entry
                    writeLog( "save", "$webName.$topic", "" );
                }
            }
        }
    }

    #### Replace Revision Save
    if( $saveCmd eq "repRev" ) {
        # fix topic by replacing last revision

        # save file
        saveFile( $name, $text );
        lockTopic( $topic, $doUnlock );

        # update repository with same userName and date, but do not update .changes
        my $rev = getRevisionNumber( $topic );
        my( $date, $user ) = getRevisionInfo( $topic, $rev );
        if( $rev eq "1.1" ) {
            # initial revision, so delete repository file and start again
            unlink "$name,v";
        } else {
            # delete latest revision (unlock, delete revision, lock)
            $tmp= $revUnlockCmd;
            $tmp =~ s/%FILENAME%/$name/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            `$tmp`;
            $tmp= $revDelRevCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            `$tmp`;
            $tmp= $revLockCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            `$tmp`;
        }
        $tmp = $revCiDateCmd;
        $tmp =~ s/%DATE%/$date/;
        $tmp =~ s/%USERNAME%/$user/;
        $tmp =~ s/%FILENAME%/$name/;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        `$tmp`;

        if( ( $doLogTopicSave ) && ( ! $doNotLogChanges ) ) {
            # write log entry
            $tmp  = userToWikiName( $user );
            writeLog( "save", "$webName.$topic", "repRev $rev $tmp $date" );
        }
    }

    #### Delete Revision
    if( $saveCmd eq "delRev" ) {
        # delete last revision

        # delete last entry in repository (unlock, delete revision, lock operation)
        my $rev = getRevisionNumber( $topic );
        if( $rev eq "1.1" ) {
            # can't delete initial revision
            return;
        }
        $tmp= $revUnlockCmd;
        $tmp =~ s/%FILENAME%/$name/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        `$tmp`;
        $tmp= $revDelRevCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        `$tmp`;
        $tmp= $revLockCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        `$tmp`;

        # restore last topic from repository
        $rev = getRevisionNumber( $topic );
        $tmp = readVersion( $topic, $rev );
        saveFile( $name, $tmp );
        lockTopic( $topic, $doUnlock );

        # delete entry in .changes : To Do !

        if( $doLogTopicSave ) {
            # write log entry
            writeLog( "cmd", "$webName.$topic", "delRev $rev" );
        }
    }
}

# =========================
sub webExists
{
    my( $web ) = @_;
    return -e "$dataDir/$web";
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
    my( $attributes ) = @_;
    my $incfile = extractNameValuePair( $attributes );

    # CrisBailiff, PeterThoeny 12 Jun 2000: Add security
    $incfile =~ s/$securityFilter//go;    # zap anything suspicious
    $incfile =~ s/passwd//goi;    # filter out passwd filename
    if( $doSecureInclude ) {
        # Filter out ".." from filename, this is to
        # prevent includes of "../../file"
        $incfile =~ s/\.+/\./g;
    }

    my $fileName = "$dataDir/$webName/$incfile";
    if( -e $fileName ) {
        return &readFile( $fileName );
    }
    return &readFile( "$dataDir/$incfile" );
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

    return &searchWikiWeb( "1",
       extractNameValuePair( $attributes, "web" ),
       $searchVal, 
       extractNameValuePair( $attributes, "scope" ),
       extractNameValuePair( $attributes, "order" ),
       extractNameValuePair( $attributes, "regex" ),
       extractNameValuePair( $attributes, "limit" ),
       extractNameValuePair( $attributes, "reverse" ),
       extractNameValuePair( $attributes, "casesensitive" ),
       extractNameValuePair( $attributes, "nosummary" ),
       extractNameValuePair( $attributes, "nosearch" ),
       extractNameValuePair( $attributes, "nototal" ),
    );
}

# =========================
sub handlePrefsValue
{
    my( $theIdx ) = @_;
    # dummy sub needed because eval can't have multiple lines in s/../../go
    return $prefsValues[$theIdx];
}

# =========================
sub handleEnvVariable
{
    my( $theVar ) = @_;
    my $value = $ENV{$theVar} || "";
    return $value;
}

# =========================
sub handleCommonTags
{
    my( $text, $topic ) = @_;
    $text =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1)/geo;
    $text =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1)/geo;  # allow two level includes

    # Wiki extended rules
    $text = extendHandleCommonTags( $text, $topic );

    my $x;
    my $cmd;
    for( $x = 0; $x < @prefsKeys; $x++ ) {
        $cmd = "\$text =~ s/%$prefsKeys[$x]%/&handlePrefsValue($x)/geo;";
        eval( $cmd );
    }

    $text =~ s/%HTTP_HOST%/&handleEnvVariable('HTTP_HOST')/geo;
    $text =~ s/%REMOTE_ADDR%/&handleEnvVariable('REMOTE_ADDR')/geo;
    $text =~ s/%REMOTE_PORT%/&handleEnvVariable('REMOTE_PORT')/geo;
    $text =~ s/%REMOTE_USER%/&handleEnvVariable('REMOTE_USER')/geo;
    $text =~ s/%TOPIC%/$topic/go;
    $text =~ s/%WEB%/$webName/go;
    $text =~ s/%WIKIHOMEURL%/$wikiHomeUrl/go;
    $text =~ s/%SCRIPTURL%/$urlHost$scriptUrlPath/go;
    $text =~ s/%SCRIPTURLPATH%/$scriptUrlPath/go;
    $text =~ s/%SCRIPTSUFFIX%/$scriptSuffix/go;
    $text =~ s/%PUBURL%/$urlHost$pubUrlPath/go;
    $text =~ s/%PUBURLPATH%/$pubUrlPath/go;
    $text =~ s/%ATTACHURL%/$urlHost$pubUrlPath\/$webName\/$topic/go;
    $text =~ s/%ATTACHURLPATH%/$pubUrlPath\/$webName\/$topic/go;
    $text =~ s/%DATE%/&getLocaldate()/geo;
    $text =~ s/%GMTIME%/&formatGmTime(time())/geo;
    $text =~ s/%WIKIVERSION%/$wikiversion/go;
    $text =~ s/%USERNAME%/$userName/go;
    $text =~ s/%WIKIUSERNAME%/$wikiUserName/go;
    $text =~ s/%WIKITOOLNAME%/$wikiToolName/go;
    $text =~ s/%MAINWEB%/$mainWebname/go;
    $text =~ s/%HOMETOPIC%/$mainTopicname/go;
    $text =~ s/%WIKIUSERSTOPIC%/$wikiUsersTopicname/go;
    $text =~ s/%WIKIPREFSTOPIC%/$wikiPrefsTopicname/go;
    $text =~ s/%WEBPREFSTOPIC%/$webPrefsTopicname/go;
    $text =~ s/%NOTIFYTOPIC%/$notifyTopicname/go;
    $text =~ s/%STATISTICSTOPIC%/$statisticsTopicname/go;
    $text =~ s/%SEARCH{(.*?)}%/&handleSearchWeb($1)/geo;

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
    $cells =~ s@\|$@ </TD></TR>@go;
    $cells =~ s@\|@ </TD><TD> @go;
    return $cells;
}

# =========================
sub internalLink
{
    my( $web, $page, $text, $bar, $foo ) = @_;
    # bar is heading space
    # foo is boolean, false suppress link for non-existing pages

    $page =~ s/\s/_/;

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
        : $foo?"$bar$text<A href=\"$scriptUrlPath/edit$scriptSuffix/$web/$page\">?</A>"
            : "$bar$text";
}

# =========================
sub externalLink
{
    my( $pre, $url ) = @_;
    if( $url =~ /\.(gif|jpg|jpeg)$/ ) {
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
    my( $text ) = @_;
    my( $result, $insidePRE, $insideTABLE, $blockquote );

    $result = "";
    $insidePRE = 0;
    $insideTABLE = 0;
    $blockquote = 0;
    $code = "";
    $text =~ s/\\\n//go;
    $text =~ s/\r//go;
    foreach( split( /\n/, $text ) ) {
        m/<PRE>/i && ($insidePRE= 1);
        m@</PRE>@i && ($insidePRE= 0);

        if( $insidePRE==0) {

# Wiki extended rules
            $_ = extendGetRenderedVersionOutsidePRE( $_ );

#Blockquote
            s/^>(.*?)$/> <cite> $1 <\/cite><BR>/go;

            s/\<(\S.*?)\>/$TranslationToken$1$TranslationToken/go;
            s/</&lt\;/go;
            s/>/&gt\;/go;
            s/$TranslationToken(\S.*?)$TranslationToken/\<$1\>/go;
            
# Handle embedded URLs
            s@(^|[\-\*\s])((http|ftp|gopher|news|https)\:(\S+[^\s\.,!\?;:]))@&externalLink($1,$2)@geo;

# Entities
            s/&(\w+?)\;/$TranslationToken$1\;/go;
            s/&/&amp;/go;
            s/$TranslationToken/&/go;
            
            s/^----*/<HR>/o;
            s@^([a-zA-Z0-9]+)----*@<table width=\"100%\"><tr><td valign=\"bottom\"><h2>$1</h2></td><td width=\"98%\" valign=\"middle\"><HR></td></tr></table>@o;

# Table of format: | cell | cell |
            if( $_ =~ /^(\s*)\|.*\|$/ ) {
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
            s/(\s)__([^\s].*?[^\s])__(\s)/$1<STRONG><EM>$2<\/EM><\/STRONG>$3/go;
            s/(\s)\*_([^\s].*?[^\s])_\*(\s)/$1<STRONG><EM>$2<\/EM><\/STRONG>$3/go;
            s/(\s)\*([^\s].*?[^\s])\*(\s)/$1<STRONG>$2<\/STRONG>$3/go;
            s/(\s)=([^\s].*?[^\s])=(\s)/$1<CODE>$2<\/CODE>$3/go;
            s/(\s)_([^\s].*?[^\s])_(\s)/$1<EM>$2<\/EM>$3/go;

# Mailto
            s#(^|[\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.]+@[a-zA-Z0-9\-\_\.]+)(?=[\s\)]|$)#$1<A href=\"mailto\:$2">$2</A>#go;

# Make internal links
            ## add Web.TopicName internal link -- PeterThoeny:
            ## allow 'AaA1' type format, but not 'Aa1' type -- PeterThoeny:
            s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]*)\.([A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*))/&internalLink($2,$3,"$TranslationToken$3$TranslationToken",$1,1)/geo;
            s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*))/&internalLink($webName,$2,$2,$1,1)/geo;
            s/$TranslationToken(\S.*?)$TranslationToken/$1/go;

            s/([\*\s][\-\*\s]*)([A-Z]{3,})/&internalLink($webName,$2,$2,$1,0)/geo;
            s/<link>(.*?)<\/link>/&internalLink($webName,$1,$1,"",1)/geo;

            s/^\n//o;

        } else {
            # inside <PRE>

# Wiki extended rules
            $_ = extendGetRenderedVersionInsidePRE( $_ );

            s/(.*)/$1\n/o;
        }
        s/\t/   /go;
        $result .= $_;
    }
    if( $insideTABLE ) {
        $result .= "</TABLE>\n";
    }
    $result .= &emitCode( "", 0 );
    if( $insidePRE ) {
        $result .= "</PRE>\n";
    }
    return $result;
}

1;

