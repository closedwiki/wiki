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


package wiki;
use strict;

use vars qw(
	$webName $topicName $defaultUserName $userName 
	$wikiToolName $wikiHomeUrl $pubUrl $templateDir 
	$dataDir $pubDir $debugFilename $logDateCmd $htpasswdFilename 
	$logFilename $userListFilename 
	$mainWebname $mainTopicname $notifyTopicname
	$statisticsTopicname $statsTopViews $statsTopContrib
	$mailProgram $wikiwebmaster 
	$wikiversion $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd $revInfoCmd 
	$revDiffCmd $revDelRevCmd $revDelRepCmd $headCmd $rmFileCmd 
	$doRemovePortNumber $doPluralToSingular
	$doLogTopicView $doLogTopicEdit $doLogTopicSave
	$doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff 
	$doLogTopicChanges $doLogTopicSearch $doLogRegistration
	@isoMonth $TranslationToken $code @code $depth
	$defaultScriptUrl $scriptUrl $scriptUrlPath $scriptSuffix );

# variables: (new variables must be declared in "use vars qw(..)" above)

# TWiki version:
$wikiversion      = "11 Feb 2000";

@isoMonth         = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );


# ===========================
# read the configuration part
do "wikicfg.pm";

# ===========================
# read the search engine part
do "wikisearch.pm";

# =========================
sub initialize
{
    my ( $thePathInfo, $theRemoteUser, $theTopic, $theUrl ) = @_;

    $userName = $defaultUserName;
    if( $theRemoteUser ) {
        $userName = $theRemoteUser;
    }

    # test if $thePathInfo is "/Webname/SomeTopic" or "/Webname/"
    if( ( $thePathInfo =~ /[\/](.*)\/(.*)/ ) && ( $1 ) )
    {
        $webName = $1;
    }
    else
    {
        # test if $thePathInfo is "/Webname" or "/"
        $thePathInfo =~ /[\/](.*)/;
        $webName = $1 || $mainWebname;
    }

    if( $2 )
    {
        $topicName = $2;
    }
    else
    {
        if( $theTopic )
        {
            $topicName = $theTopic;
        }
        else
        {
            $topicName = $mainTopicname;
        }
    }

    ( $topicName =~ /\.\./ ) && ( $topicName = $mainTopicname );

    if( $theUrl )
    {
        $scriptUrl = $theUrl;
        $scriptUrl =~ s/(.*)\/.*$/$1/;
        if( $doRemovePortNumber )
        {
            $scriptUrl =~ s/:[0-9]+\//\//;
        }
    }
    else
    {
        $scriptUrl = $defaultScriptUrl;
    }

    $scriptUrlPath = $scriptUrl;
    $scriptUrlPath =~ s/.*\:\/\/[^\/]*(.*)/$1/go;

    $TranslationToken= "\263";
    $code="";
    @code= ();
    return ( $topicName, $webName, $scriptUrlPath, $userName, $dataDir );
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
    my( $text ) = @_;
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
    my( $web, $topicname ) = @_;

    if ( ! $topicname )
    {
        $topicname = $notifyTopicname;
    }
    my $list = "";
    my $line = "";
    my $fileName = "$dataDir/$web/$topicname.txt";
    if ( -e $fileName )
    {
        my $result = `grep '\* *.*[-:<].* *\@' $fileName`;
        foreach $line ( split( /\n/, $result))
        {
            $line =~ s/\s/ /go;
            $line =~ s/(^.*[- :<])([-_A-Za-z0-9\.]*\@[-_A-Za-z0-9\.]*)(.*)/$2/go;
            $list = "$list $line";
        }
        $list =~ s/^ *//go;
        $list =~ s/ *$//go;
    }
    return $list;
}

# =========================
sub userToWikiName
{
    my( $loginUser ) = @_;

    my $result = `grep '\* [A-Za-z0-9]* \- $loginUser' $userListFilename`;
    my @foo = split( " ", $result );
    if ( ( $foo[1] ) && ( isWikiName( $foo[1] ) ) )
    {
        return "$mainWebname.$foo[1]";
    }
    if ( ( $foo[2] ) && ( isWikiName( $foo[2] ) ) )
    {
        return "$mainWebname.$foo[2]";
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
sub getPubUrl
{
    my( $topic) = @_;
    return "$pubUrl";
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
    my( $time) = @_;

    if ( $time =~ /[A-Za-z]/ )
    {
        # already formatted, for compatibility with older entries in .changes:
        $time =~ s/GMT\s*$//;
        return $time;
    }

    my ( $sec, $min, $hour, $mday, $mon, $year) = gmtime($time);
    my( $tmon) = $isoMonth[$mon];
    $year = sprintf("%.4u", $year + 1900);  # Y2K fix
    $time = sprintf("%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min);
    return $time;
}

# =========================
sub readFile
{
    my( $name ) = @_;
    my $data = "";
    undef $/; # set to read to EOF
    open( IN_FILE, $name ) || return "";
    $data = <IN_FILE>;
    $/ = "\n";
    close( IN_FILE );
    return $data;
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
    my( $web, $name ) = @_;
    return -e "$dataDir/$web/$name.txt";
}

# =========================
sub readTopic
{
    my( $name ) = @_;
    return &readFile( "$dataDir/$webName/$name.txt");
}

# =========================
sub readWebTopic
{
    my( $web, $name ) = @_;
    return &readFile( "$dataDir/$web/$name.txt");
}

# =========================
sub viewUrl
{
    my( $topic ) = @_;
    return "$scriptUrlPath/view$scriptSuffix/$webName/$topic";
}

# =========================
sub readTemplate
{
    my( $name ) = @_;
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
    my( $name, $rev ) = @_;
    my $tmp= $revCoCmd;
    $tmp =~ s/%REVISION%/$rev/;
    $tmp =~ s/%FILENAME%/$dataDir\/$webName\/$name.txt/;
    return `$tmp`;
}

# =========================
sub getRevisionNumber
{
    my( $theTopic, $theWebName ) = @_;
    if( ! $theWebName )
    {
        $theWebName = $webName;
    }
    my $tmp= $revHistCmd;
    $tmp =~ s/%FILENAME%/$dataDir\/$theWebName\/$theTopic.txt/;
    $tmp = `$tmp`;
    $tmp =~ /head: (.*?)\n/;
    return $1;
}

# =========================
sub getRevisionDiff
{
    my( $topic, $rev1, $rev2 ) = @_;

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
    my( $theTopic, $theRev, $changeToIsoDate, $theWebName ) = @_;
    if( ! $theWebName )
    {
        $theWebName = $webName;
    }
    if( ! $theRev )
    {
        $theRev = getRevisionNumber( $theTopic, $theWebName );
    }
    my $tmp= $revInfoCmd;
    $tmp =~ s/%REVISION%/$theRev/;
    $tmp =~ s/%FILENAME%/$dataDir\/$theWebName\/$theTopic.txt/;
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
           $date = "$3 $isoMonth[$2-1] $1 - $4";
        }
    }
    return ( $date, $user );
}

# =========================
sub saveTopic
{
    my( $topic, $text, $saveCmd, $doNotLogChanges ) = @_;
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

            if( ! $doNotLogChanges )
            {
                # update .changes
                my @foo = split(/\n/, &readFile("$dataDir/$webName/.changes"));
                if( $#foo > 100 )
                {
                    shift( @foo);
                }
                push( @foo, "$topic\t$userName\t$time");
                open( FILE, "> $dataDir/$webName/.changes");
                print FILE join("\n",@foo)."\n";
                close(FILE);
            }

            if( $doLogTopicSave )
            {
                # write log entry
                $time = formatGmTime( $time );
                $name = userToWikiName( $userName );
                writeLog( "| $time | $name | save | $webName.$topic |  |" );
            }
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

        if( $doLogTopicSave )
        {
            # write log entry
            $time = formatGmTime( $time );
            $name = userToWikiName( $userName );
            $tmp  = userToWikiName( $user );
            writeLog( "| $time | $name | save | $webName.$topic | repRev $rev $tmp $date |" );
        }
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
        $rev = getRevisionNumber( $topic );
        $tmp = readVersion( $topic, $rev );
        saveFile( $name, $tmp );
        lockTopic( $topic );

        # delete entry in .changes : To Do !

        if( $doLogTopicSave )
        {
            # write log entry
            $time = formatGmTime( $time );
            $name = userToWikiName( $userName );
            writeLog( "| $time | $name | cmd | $webName.$topic | delRev $rev |" );
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

    if( $name )
    {
        # format is: name = "value"
        if( ( $str =~ /(^|[^\S])$name[\s]*=[\s]*[\"]([^\"]*)/ ) && ( $2 ) )
        {
            return $2;
        }
    }
    else
    {
        # test if format: "value"
        if( ( $str =~ /(^|=[\s]*[\"][^\"]*\")[\s]*[\"]([^\"]*)/ ) && ( $2 ) )
        {
            return $2;
        }
        elsif( ( $str =~ /^[\s]*([^"]\S*)/ ) && ( $1 ) )
        {
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
    my $fileName = "$dataDir/$webName/$incfile";
    if( -e $fileName )
    {
	return &readFile( $fileName );
    }
    return &readFile( "$dataDir/$incfile" );
}

# =========================
sub handleSearchWeb
{
    my( $attributes ) = @_;
    my $searchVal = extractNameValuePair( $attributes );
    if( ! $searchVal )
    {
        # %SEARCH{"string" ...} not found, try
        # %SEARCH{search="string" ...}
        $searchVal = extractNameValuePair( $attributes, "search" );
    }

    return &searchWikiWeb( "1",
       extractNameValuePair( $attributes, "web" ),
       $searchVal, 
       extractNameValuePair( $attributes, "scope" ),
       extractNameValuePair( $attributes, "regex" ),
       extractNameValuePair( $attributes, "casesensitive" ),
       extractNameValuePair( $attributes, "nosummary" ),
       extractNameValuePair( $attributes, "nosearch" ),
       extractNameValuePair( $attributes, "nototal" ),
    );
}

# =========================
sub handleCommonTags
{
    my( $text, $topic ) = @_;
    $text=~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1)/geo;
    $text=~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1)/geo;  # allow two level includes

    # Wiki extended rules
    $text = extendHandleCommonTags( $text, $topic );

    $text=~ s/%TOPIC%/$topic/go;
    $text=~ s/%WEB%/$webName/go;
    $text=~ s/%WIKIHOMEURL%/$wikiHomeUrl/go;
    $text=~ s/%SCRIPTURL%/$scriptUrl/go;
    $text=~ s/%SCRIPTURLPATH%/$scriptUrlPath/go;
    $text=~ s/%SCRIPTSUFFIX%/$scriptSuffix/go;
    $text=~ s/%PUBURL%/$pubUrl/go;
    $text=~ s/%ATTACHURL%/$pubUrl\/$webName\/$topic/go;
    $text=~ s/%DATE%/&getLocaldate()/geo;
    $text=~ s/%WIKIWEBMASTER%/$wikiwebmaster/go;
    $text=~ s/%WIKIVERSION%/$wikiversion/go;
    $text=~ s/%USERNAME%/$userName/go;
    $text=~ s/%WIKIUSERNAME%/&userToWikiName($userName)/geo;
    $text=~ s/%WIKITOOLNAME%/$wikiToolName/go;
    $text=~ s/%MAINWEB%/$mainWebname/go;
    $text=~ s/%HOMETOPIC%/$mainTopicname/go;
    $text=~ s/%NOTIFYTOPIC%/$notifyTopicname/go;
    $text=~ s/%STATISTICSTOPIC%/$statisticsTopicname/go;
    $text=~ s/%SEARCH{(.*?)}%/&handleSearchWeb($1)/geo;

    return $text;
}

# =========================
sub emitCode {
    ( $code, $depth ) = @_;
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

    if( $doPluralToSingular && $page =~ /s$/ && ! topicExists( $web, $page) )
    {
        # page is a non-existing plural
        my $tmp = $page;
	$tmp =~ s/ies$/y/;	# plurals like policy / policies
	$tmp =~ s/sses$/ss/;	# plurals like address / addresses
	$tmp =~ s/xes$/x/;	# plurals like box / boxes
	$tmp =~ s/([A-Za-rt-z])s$/$1/; # others, excluding ending ss like address(es)
        if( topicExists( $web, $tmp ) )
        {
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
    if( $url =~ /\.(gif|jpg|jpeg)$/ )
    {
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
    my( $result, $insidePRE, $insideTABLE, $blockquote );

    $result = "";
    $insidePRE = 0;
    $insideTABLE = 0;
    $blockquote = 0;
    $code = "";
    $text =~ s/\\\n//go;
    $text =~ s/\r//go;
    foreach( split( /\n/, $text))
    {
        m/<PRE>/i && ($insidePRE= 1);
        m@</PRE>@i && ($insidePRE= 0);

	if( $insidePRE==0)
        {

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
	    if( !$code )
	    {
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
	}
        else
        {
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
