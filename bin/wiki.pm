#
# TWiki WikiClone (see $wikiversion for version)
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999 Peter Thoeny, peter.thoeny@takefive.com , 
# TakeFive Software Inc.
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

package wiki;
use strict;

use vars qw(
	$webName $topicName $defaultUserName $userName 
	$wikiToolName $wikiHomeUrl $defaultRootUrl $pubUrl $wikiDir $templateDir 
	$dataDir $pubDir $debugFilename $logDateCmd $logFilename $userListFilename 
	$mainWebname $mainTopicname $notifyTopicname $mailProgram $wikiwebmaster 
	$wikiversion $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd $revInfoCmd 
	$revDiffCmd $revDelRevCmd $revDelRepCmd $headCmd $rmFileCmd 
	@isoMonth $TranslationToken $code @code $depth $scriptUrl );

# variables: (new variables must be declared in "use vars qw(..)" above)

# TWiki version:
$wikiversion      = "14 Jun 1999";

# variables that need to be changed when installing on new server:
$wikiHomeUrl      = "http://your.domain.com/twiki";
$defaultRootUrl   = "http://your.domain.com/twiki/bin";
$pubUrl           = "http://your.domain.com/twiki/pub";   # must match $pubDir
$wikiDir          = "/home/httpd/twiki";
$wikiwebmaster    = "yourname\@your.domain.com";

# variables that might need to be changed:
$logDateCmd       = "date '+%Y%m'";
$mailProgram      = "/usr/sbin/sendmail -t -oi -oeq";
$revCiCmd         = "ci -l -q -mnone -t-none -w'%USERNAME%' %FILENAME%";
$revCiDateCmd     = "ci -l -q -mnone -t-none -d'%DATE%' -w'%USERNAME%' %FILENAME%";
$revCoCmd         = "co -q -p%REVISION% %FILENAME%";
$revHistCmd       = "rlog -h %FILENAME%";
$revInfoCmd       = "rlog -r%REVISION% %FILENAME%";
$revDiffCmd       = "rcsdiff -w -B -r%REVISION1% -r%REVISION2% %FILENAME%";
$revDelRevCmd     = "rcs -u %FILENAME%; rcs -o%REVISION% %FILENAME%; rcs -l %FILENAME%";
$revDelRepCmd     = "rm -f %FILENAME%,v";
$headCmd          = "head -%LINES% %FILENAME%";
$rmFileCmd        = "rm -f %FILENAME%";

# variables that do not change:
$wikiToolName     = "betaTWiki";
$templateDir      = "$wikiDir/bin/templates";
$dataDir          = "$wikiDir/bin/data";
$pubDir           = "$wikiDir/pub";
$debugFilename    = "$wikiDir/bin/debug.txt";
$logFilename      = "$dataDir/log%DATE%.txt";
$userListFilename = "$dataDir/Main/TWikiUsers.txt";
$defaultUserName  = "guest";
$mainWebname      = "Main";
$mainTopicname    = "WebHome";
$notifyTopicname  = "WebNotify";
@isoMonth         = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );


# =========================
sub initialize
{
    my ( $thePathInfo, $theRemoteUser, $theTopic, $theUrl ) = @_;

    $userName = $defaultUserName;
    if( $theRemoteUser ) {
        $userName = $theRemoteUser;
    }

    $thePathInfo =~ /[\/](.*)\/(.*)/;
    $webName= $1;
	if( ! $1)
	{
		$thePathInfo =~ /[\/](.*)/;
		$webName= $1 || $mainWebname;
	}	

    if( ! $2)
    {
	if( $theTopic)
	{
	    $topicName = $theTopic;
	}
	else
	{
	    $topicName = $mainTopicname;
	}
    }
    else
    {
	$topicName = $2;
    }

    ($topicName =~ /\.\./) && ($topicName = $mainTopicname);

    if( $theUrl eq "")
    {
        $scriptUrl = $defaultRootUrl;
    }
    else
    {
        $scriptUrl = $theUrl;
        $scriptUrl =~ s/(.*)\/.*$/$1/;
        $scriptUrl =~ s/:[0-9]+\//\//;
    }

    $TranslationToken= "\263";
    $code="";
    @code= ();
    return ( $topicName, $webName, $scriptUrl, $userName, $dataDir );
}

# =========================
sub writeDebug
{
    my( $text) = @_;
    open( FILE, ">> $debugFilename");
    print FILE "$text\n";
    close( FILE);
}

# =========================
sub writeLog
{
    my( $text) = @_;
    my $date = `$logDateCmd`;
    $date =~ s/\n//go;
    my $filename = $logFilename;
    $filename =~ s/%DATE%/$date/go;
    open( FILE, ">> $filename");
    print FILE "$text\n";
    close( FILE);
}

# =========================
sub sendEmail
{
    # Notefor format: "From: ...\nTo: ...\nSubject: ...\n\nMailBody..."

    my( $mailText) = @_;

    if (open (MAIL,"|-") || exec "$mailProgram") 
    {
      print MAIL $mailText;
      close (MAIL);
      return "OK";
    }
    return "";
}

# =========================
sub getEmailNotifyList
{
    my( $web) = @_;

    my $result = `grep '\* *.*[-:<].* *\@' $dataDir/$web/$notifyTopicname.txt`;
    my $list = "";
    my $line = "";
    foreach $line ( split( /\n/, $result))
    {
        $line =~ s/\s/ /go;
        $line =~ s/(^.*[- :<])([-_A-Za-z0-9\.]*\@[-_A-Za-z0-9\.]*)(.*)/$2/go;
        $list = "$list $line";
    }
    $list =~ s/^ *//go;
    $list =~ s/ *$//go;
    return $list;
}

# =========================
sub userToWikiName
{
    my( $user) = @_;

    my $result = `grep '\* [A-Za-z0-9]* \- $user' $userListFilename`;
    my @foo = split(" ", $result);
    if ( isWikiName( $foo[1]))
    {
        return "$mainWebname.$foo[1]";
    }
    if ( isWikiName( $foo[2]))
    {
        return "$mainWebname.$foo[2]";
    }
    return $user;
}

# =========================
sub getWikiBaseDir
{
    return $wikiDir;
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
sub getPubUrl
{
    my( $topic) = @_;
    return "$pubUrl";
}

# =========================
sub getLocaldate
{
    my( $sec, $min, $hour, $mday, $mon, $year) = localtime(time());
    if( $year < 50)
    {
        $year = sprintf("20%.2u", $year);
    }
    elsif( $year < 100)
    {
        $year = sprintf("19%.2u", $year);
    }
    my( $tmon) = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];
    my $date = sprintf("%.2u ${tmon} %.2u", $mday, $year);
    return $date;
}

# =========================
sub formatGmTime
{
    my( $time) = @_;

    if ( $time =~ /[A-Za-z]/ )
    {
        # already formatted, for compatibility with older entries in .changes:
        return $time;
    }

    my ( $sec, $min, $hour, $mday, $mon, $year) = gmtime($time);
    my( $tmon) = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];
    if( $year < 50)
    {
        $year = sprintf("20%.2u", $year);
    }
    elsif( $year < 100)
    {
        $year = sprintf("19%.2u", $year);
    }
    $time = sprintf("%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min);
    return $time;
}

# =========================
sub readIncludeFile
{
    my( $name ) = @_;
    return `cat $dataDir/$webName/$name`;
}

# =========================
sub readFile
{
    my( $name ) = @_;
    return `cat $name`;
}

# =========================
sub readFileHead
{
    my( $name, $lines ) = @_;
    my $cmd= $headCmd;
    $cmd =~ s/%LINES%/$lines/;
    $cmd =~ s/%FILENAME%/$name/;
    return `$cmd`;
}

# =========================
sub saveFile
{
    my( $name, $text) = @_;
    open( FILE, "> $name") or warn "Can't create file $name\n";
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
    if( -e "$lockFilename" )
    {
        my $tmp = readFile( $lockFilename );
        my( $lockUser, $lockTime ) = split( /\n/, $tmp );
        if( $lockUser ne $userName )
        {
            # time stamp of lock within one hour of current time?
            my $systemTime = time();
            if( abs( $systemTime - $lockTime ) < 3600 )
            {
                # must warn user that it is locked
                return $lockUser;
            }
        }
    }
    return "";
}

# =========================
sub lockTopic
{
    my( $name ) = @_;

    my $lockFilename = "$dataDir/$webName/$name.lock";
    my $lockTime = time();
    saveFile( $lockFilename, "$userName\n$lockTime" );
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
    my $tmp = "";
    my $lockUser = "";
    my $lockTime = "";
    my $systemTime = time();
    foreach $file ( @fileList )
    {
        $tmp = readFile( "$webDir/$file" );
        ( $lockUser, $lockTime ) = split( /\n/, $tmp );

        # time stamp of lock over one hour of current time?
        if( abs( $systemTime - $lockTime ) > 3600 )
        {
            # obsolete, so delete
            $tmp= $rmFileCmd;
            $tmp =~ s/%FILENAME%/$webDir\/$file/;
            `$tmp`;
        }
    }
}

# =========================
sub topicExists
{
    my( $web, $name) = @_;
    return -e "$dataDir/$web/$name.txt";
}

# =========================
sub readTopic
{
    my( $name) = @_;
    return &readFile( "$dataDir/$webName/$name.txt");
}

# =========================
sub readWebTopic
{
    my( $web, $name) = @_;
    return &readFile( "$dataDir/$web/$name.txt");
}

# =========================
sub viewUrl
{
    my( $topic) = @_;
    return "$scriptUrl/view/$webName/$topic";
}

# =========================
sub readTemplate
{
    my( $name) = @_;
    my $webtmpl = "$templateDir/$webName/$name.tmpl";
    if( -e $webtmpl )
    {
	return &readFile( $webtmpl);
    }
    return &readFile( "$templateDir/$name.tmpl");
}

# =========================
sub readVersion
{
    my( $name, $rev) = @_;
    my $tmp= $revCoCmd;
    $tmp =~ s/%REVISION%/$rev/;
    $tmp =~ s/%FILENAME%/$dataDir\/$webName\/$name.txt/;
    return `$tmp`;
}

# =========================
sub getRevisionNumber
{
    my( $topic) = @_;
    my $tmp= $revHistCmd;
    $tmp =~ s/%FILENAME%/$dataDir\/$webName\/$topic.txt/;
    $tmp = `$tmp`;
    $tmp =~ /head: (.*?)\n/;
    return $1;
}

# =========================
sub getRevisionDiff
{
    my( $topic, $rev1, $rev2) = @_;

    my $tmp= "";
    if ( $rev1 eq "1.1" && $rev2 eq "1.1" )
    {
        my $text = readVersion($topic, 1.1);    # bug fix 19 Feb 1999
        $tmp = "1a1\n";
        foreach( split( /\n/, $text))
        {
           $tmp = "$tmp> $_\n";
        }
    }
    else
    {
        $tmp= $revDiffCmd;
        $tmp =~ s/%REVISION1%/$rev1/;
        $tmp =~ s/%REVISION2%/$rev2/;
        $tmp =~ s/%FILENAME%/$dataDir\/$webName\/$topic.txt/;
        $tmp = `$tmp`;
    }
    return "$tmp";
}

# =========================
sub getRevisionInfo
{
    my( $topic, $rev, $changeToIsoDate ) = @_;
    if( $rev eq "" )
    {
        $rev = getRevisionNumber( $topic );
    }
    my $tmp= $revInfoCmd;
    $tmp =~ s/%REVISION%/$rev/;
    $tmp =~ s/%FILENAME%/$dataDir\/$webName\/$topic.txt/;
    $tmp = `$tmp`;
    $tmp =~ /date: (.*?);  author: (.*?);/;
    my $date = $1;
    my $user = $2;
    if( $changeToIsoDate )
    {
        # change date to ISO format
        $tmp = $1;
        $tmp =~ /(.*?)\/(.*?)\/(.*?) (.*?):[0-9][0-9]$/;
        if( $4 ne "")
        {
           $date = "$3 @isoMonth[$2-1] $1 - $4";
        }
    }
    return ( $date, $user );
}

# =========================
sub saveTopic
{
    my( $topic, $text, $saveCmd) = @_;
    my $name = "$dataDir/$webName/$topic.txt";
    my $time = time();
    my $tmp = "";

    #### Normal Save
    if( $saveCmd eq "" )
    {
        # get time stamp of existing file
        my( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$tmp8,$tmp9,
            $mtime1,$mtime2,$tmp11,$tmp12,$tmp13 ) = "";
        if( -e $name )
        {
            ( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$tmp8,$tmp9,
              $mtime1,$tmp11,$tmp12,$tmp13 ) = stat $name;
        }

        # save file
        saveFile( $name, $text );

        # reset lock time, this is to prevent contention in case of a long edit session
        lockTopic( $topic );

        # time stamp of existing file within one hour of old one?
        ( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$tmp8,$tmp9,
          $mtime2,$tmp11,$tmp12,$tmp13 ) = stat $name;
        if( abs( $mtime2 - $mtime1 ) < 3600 )
        {
            my $rev = getRevisionNumber( $topic );
            my( $date, $user ) = getRevisionInfo( $topic, $rev );
            # same user?
            if( $user eq $userName )
            {
                # replace last repository entry
                $saveCmd = "repRev";
            }
        }

        if( $saveCmd ne "repRev" )
        {
            # update repository
            $tmp= $revCiCmd;
            $tmp =~ s/%USERNAME%/$userName/;
            $tmp =~ s/%FILENAME%/$name/;
            `$tmp`;

            # update .changes
            my @foo = split(/\n/, &readFile("$dataDir/$webName/.changes"));
            if( $#foo > 199)
            {
                shift( @foo);
            }
            push( @foo, "$topic\t$userName\t$time");
            open( FILE, "> $dataDir/$webName/.changes");
            print FILE join("\n",@foo)."\n";
            close(FILE);

            # write log entry
            $time = formatGmTime( $time );
            $name = userToWikiName( $userName );
            writeLog( "$time  $webName.$topic -- $name" );
        }
    }

    #### Replace Revision Save
    if( $saveCmd eq "repRev" )
    {
        # fix topic by replacing last revision

        # save file
        saveFile( $name, $text);
        lockTopic( $topic );

        # update repository with same userName and date, but do not update .changes
        my $rev = getRevisionNumber( $topic );
        my( $date, $user ) = getRevisionInfo( $topic, $rev );
        if( $rev eq "1.1" )
        {
            # initial revision, so delete repository file and start again
            $tmp = $revDelRepCmd;
            $tmp =~ s/%FILENAME%/$name/go;
            `$tmp`;
        }
        else
        {
            # delete latest revision
            $tmp = $revDelRevCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name/go;
            `$tmp`;
        }
        $tmp = $revCiDateCmd;
        $tmp =~ s/%DATE%/$date/;
        $tmp =~ s/%USERNAME%/$user/;
        $tmp =~ s/%FILENAME%/$name/;
        `$tmp`;

        # write log entry
        $time = formatGmTime( $time );
        $name = userToWikiName( $userName );
        writeLog( "$time  $webName.$topic -- $name  cmd=$saveCmd $rev $user $date" );
    }

    #### Delete Revision
    if( $saveCmd eq "delRev" )
    {
        # delete last revision

        # delete last entry in repository
        my $rev = getRevisionNumber( $topic );
        if( $rev eq "1.1" )
        {
            return; #can't delete initial revision
        }
        $tmp= $revDelRevCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name/go;
        `$tmp`;

        # restore last topic from repository
        my $rev = getRevisionNumber( $topic );
        $tmp = readVersion( $topic, $rev );
        saveFile( $name, $tmp );
        lockTopic( $topic );

        # delete entry in .changes

        # write log entry
        $time = formatGmTime( $time );
        $name = userToWikiName( $userName );
        $rev = $rev + 0.1;
        writeLog( "$time  $webName.$topic -- $name  cmd=$saveCmd $rev" );
    }
}

# =========================
sub webExists
{
    my( $web) = @_;
    return -e "$templateDir/$web";
}

# =========================
sub handleCommonTags
{
    my( $text, $topic)= @_;
    $text=~ s/%INCLUDE:"(.*?)"%/&readIncludeFile($1)/geo;
    $text=~ s/%INCLUDE:"(.*?)"%/&readIncludeFile($1)/geo;  # allow two level includes
    $text=~ s/%TOPIC%/$topic/go;
    $text=~ s/%WEB%/$webName/go;
    $text=~ s/%WIKIHOMEURL%/$wikiHomeUrl/go;
    $text=~ s/%SCRIPTURL%/$scriptUrl/go;
    $text=~ s/%PUBURL%/$pubUrl/go;
    $text=~ s/%ATTACHURL%/$pubUrl\/$webName\/$topic/go;
    $text=~ s/%DATE%/&getLocaldate()/geo;
    $text=~ s/%WIKIWEBMASTER%/$wikiwebmaster/go;
    $text=~ s/%WIKIVERSION%/$wikiversion/go;
    $text=~ s/%USERNAME%/$userName/go;
    $text=~ s/%WIKIUSERNAME%/&userToWikiName($userName)/geo;
    $text=~ s/%WIKITOOLNAME%/$wikiToolName/go;
    $text=~ s/%%/%/g;
    return $text;
}

# =========================
sub emitCode {
    ($code, $depth) = @_;
    my $result="";
    while (@code > $depth) {
	local($_) = pop @code;
	$result= "$result</$_>\n"
    }
    while (@code < $depth)
    {
	push (@code, ($code));
	$result= "$result<$code>\n"
    }

    if($#code>-1 && ($code[$#code] ne $code))
    {
	$result= "$result</$code[$#code]><$code>\n";
	$code[$#code] = $code;
    }
    return $result;
}

# =========================
sub internalLink
{
    my( $web, $page, $text, $bar, $foo) = @_;
    $page =~ s/\s/_/;

    topicExists( $web, $page) ?
    "$bar<A href=\"$scriptUrl/view/$web/$page\">$text<\/A>"
        : $foo?"$bar$text<A href=\"$scriptUrl/edit/$web/$page\">?</A>"
            : "$bar$text";
}

# =========================
sub externalLink
{
    my( $pre, $url) = @_;
    if( $url =~ /\.(gif|jpg|jpeg)$/ )
    {
	return "$pre<IMG src=\"$url\" alt=\"$url\">";
    }

    return "$pre<A href=\"$url\" target=\"_top\">$url</A>";
}

# =========================
sub isWikiName
{
    my( $name) = @_;
     if ( $name =~ /[A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*)$/ )
    {
        return "1";
    }
    return "";
}

# =========================
sub getRenderedVersion
{
    my( $text ) = @_;
    my( $result, $insidePRE, $blockquote, $index);
    $index = <<EOINDEX
<A href="#A">A</A> |
<A href="#B">B</A> |
<A href="#C">C</A> |
<A href="#D">D</A> |
<A href="#E">E</A> |
<A href="#F">F</A> |
<A href="#G">G</A> |
<A href="#H">H</A> |
<A href="#I">I</A> |
<A href="#J">J</A> |
<A href="#K">K</A> |
<A href="#L">L</A> |
<A href="#M">M</A> |
<A href="#N">N</A> |
<A href="#O">O</A> |
<A href="#P">P</A> |
<A href="#Q">Q</A> |
<A href="#R">R</A> |
<A href="#S">S</A> |
<A href="#T">T</A> |
<A href="#U">U</A> |
<A href="#V">V</A> |
<A href="#W">W</A> |
<A href="#X">X</A> |
<A href="#Y">Y</A> |
<A href="#Z">Z</A>
EOINDEX
;

    $result = "";
    $insidePRE= 0;
    $blockquote= 0;
    $code= "";
    $text =~ s/\\\n//go;
    $text =~ s/\r//go;
    foreach( split( /\n/, $text))
    {
        m/<PRE>/i && ($insidePRE= 1);
        m@</PRE>@i && ($insidePRE= 0);

	if( $insidePRE==0)
        {

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

# Lists etc.
	    s/^\s*$/<p> /o                   && ($code= 0);
	    m/^(\S+?)/o                      && ($code= 0);
	    s/^(\t+)(\S+?):\s/<DT>$2<DD> /o  && ($result= $result . &emitCode( "DL", length $1));
	    s/^(\t+)\* /<LI> /o              && ($result= $result . &emitCode( "UL", length $1));
	    s/^(\t+)\d+\.?/<LI> /o           && ($result= $result . &emitCode( "OL", length $1));
	    if( !$code )
	    {
	        $result=$result.&emitCode("",0);
	        $code= "";
	    }

	    s/(.*)/\n$1\n/o;

# Emphasizing
	    s/(\s)\*_([^\s].*?[^\s])_\*(\s)/$1<STRONG><EM>$2<\/EM><\/STRONG>$3/go;
	    s/(\s)\*([^\s].*?[^\s])\*(\s)/$1<STRONG>$2<\/STRONG>$3/go;
	    s/(\s)=([^\s].*?[^\s])=(\s)/$1<CODE>$2<\/CODE>$3/go;
	    s/(\s)_([^\s].*?[^\s])_(\s)/$1<EM>$2<\/EM>$3/go;

	    s/<INSERTINDEX>/$index/go;

# Make internal links
	    ## add Web.TopicName internal link -- PeterThoeny:
	    ## allow 'AaA1' type format, but not 'Aa1' type -- PeterThoeny:
	    s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]*)\.([A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*))/&internalLink($2,$3,"$TranslationToken$3$TranslationToken",$1,1)/geo;
	    s/([\*\s][\(\-\*\s]*)([A-Z]+[a-z]+(?:[A-Z]+[a-zA-Z0-9]*))/&internalLink($webName,$2,$2,$1,1)/geo;
	    s/$TranslationToken(\S.*?)$TranslationToken/$1/go;

	    ## comment out name.org type link -- PeterThoeny:
	    ##s/([\*\s][\-\*\s]*)([a-zA-Z]+[\._][a-zA-Z](?:[a-zA-Z\._]+))/&internalLink($webName,$2,$2,$1,1)/geo;
	    s/([\*\s][\-\*\s]*)([A-Z]{3,})/&internalLink($webName,$2,$2,$1,0)/geo;
	    s/<link>(.*?)<\/link>/&internalLink($webName,$1,$1,"",1)/geo;
	    ## comment out %Web:TopicName% type link, use Web.TopicName instead -- PeterThoeny:
	    ##s/(\s)\%(.*?):(.*?)\%/&internalLink($2,$3,"$2:$3",$1,1)/geo;
	    ##s/(\s)\%(.*?)\%/&internalLink($webName,$2,$2,$1,1)/geo;

# Handle TakeFive specific URL for ClearDDTS
	    s@([\(\*\s])(TKFat[0-9]*)@$1<A HREF="https://owl.takefive.co.at/ddts/dumpbug_ddts.sh?bug_id=$2">$2</A>@go;

# Mailto
	    s#(^|[\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.]+@[a-zA-Z0-9\-\_\.]+)(?=[\s\)]|$)#$1<A href=\"mailto\:$2">$2</A>#go;
	    
	    s/^\n//o;
	}
        else
        {
            # inside <PRE>
     	    s/(.*)/$1\n/o;
        }
	s/\t/   /go;
        $result="$result$_";
    }
    $result=$result . &emitCode("",0);
    return $result;
}

1;
