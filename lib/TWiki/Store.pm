#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Copyright (C) 1999, 2000 Peter Thoeny, peter@thoeny.com
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
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Optionally change wikicfg.pm for custom extensions of rendering rules.
# - Files wiki[a-z]+.pm are included by wiki.pm
# - Upgrading TWiki is easy as long as you do not customize wiki.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log
#
# 20000917 - NicholasLee : Split file/storage related functions from wiki.pm
#

package TWiki::Store;

use strict;

##use vars qw(
##        $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd $revInfoCmd 
##        $revDiffCmd $revDelRevCmd $revUnlockCmd $revLockCmd
##);


# view:	    $text= &TWiki::readVersion( $topic, "1.$rev" );
sub readVersion
{
    my( $theTopic, $theRev ) = @_;
    my $tmp= $TWiki::revCoCmd;
    my $fileName = "$TWiki::dataDir/$TWiki::webName/$theTopic.txt";
    $tmp =~ s/%FILENAME%/$fileName/;
    $tmp =~ s/%REVISION%/$theRev/;
    $tmp =~ /(.*)/;
    $tmp = $1;       # now safe, so untaint variable
    return `$tmp`;
}

# =========================
# rdiff:	$maxrev = &TWiki::Store::getRevisionNumber( $topic );
# view:	$maxrev = &TWiki::Store::getRevisionNumber( $topic );

sub getRevisionNumber
{
    my( $theTopic, $theWebName ) = @_;
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }
    my $tmp= $TWiki::revHistCmd;
    my $fileName = "$TWiki::dataDir/$theWebName/$theTopic.txt";
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
# rdiff:            $text = &TWiki::Store::getRevisionDiff( $topic, "1.$r2", "1.$r1" );
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
        $tmp= $TWiki::revDiffCmd;
        $tmp =~ s/%REVISION1%/$rev1/;
        $tmp =~ s/%REVISION2%/$rev2/;
        my $fileName = "$TWiki::dataDir/$TWiki::webName/$topic.txt";
        $fileName =~ s/$TWiki::securityFilter//go;
        $tmp =~ s/%FILENAME%/$fileName/;
        $tmp =~ /(.*)/;
        $tmp = $1;       # now safe, so untaint variable
        $tmp = `$tmp`;
    }
    return "$tmp";
}


# =========================
# rdiff:         my( $date, $user ) = &TWiki::Store::getRevisionInfo( $topic, "1.$rev", 1 );
# view:          my( $date, $user ) = &TWiki::Store::getRevisionInfo( $topic, "1.$rev", 1 );
# wikisearch.pm: my ( $revdate, $revuser, $revnum ) = &TWiki::Store::getRevisionInfo( $filename, "", 1, $thisWebName );
sub getRevisionInfo
{
    my( $theTopic, $theRev, $changeToIsoDate, $theWebName ) = @_;
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }
    if( ! $theRev ) {
        # PTh 03 Nov 2000: comment out for performance
        ### $theRev = getRevisionNumber( $theTopic, $theWebName );
        $theRev = "";  # do a "rlog -r filename" to get top revision info
    }
    my $tmp= $TWiki::revInfoCmd;
    $theRev =~ s/$TWiki::securityFilter//go;
    $theRev =~ /(.*)/;
    $theRev = $1;       # now safe, so untaint variable
    $tmp =~ s/%REVISION%/$theRev/;
    my $fileName = "$TWiki::dataDir/$theWebName/$theTopic.txt";
    $fileName =~ s/$TWiki::securityFilter//go;
    $fileName =~ /(.*)/;
    $fileName = $1;       # now safe, so untaint variable
    $tmp =~ s/%FILENAME%/$fileName/;
    $tmp = `$tmp`;
    $tmp =~ /date: (.*?);  author: (.*?);/;
    my $date = $1;
    my $user = $2;
    $tmp =~ /revision 1.([0-9]*)/;
    my $rev = $1;
    if( ! $user ) {
        # repository file is missing or corrupt, use file timestamp
        $user = $TWiki::defaultUserName;
        $date = (stat "$fileName")[9] || 600000000;
        my @arr = gmtime( $date );
        # format to RCS date "2000.12.31.23.59.59"
        $date = sprintf( "%.4u.%.2u.%.2u.%.2u.%.2u.%.2u", $arr[5] + 1900,
                         $arr[4] + 1, $arr[3], $arr[2], $arr[1], $arr[0] );
        $rev = 1;
    }
    if( $changeToIsoDate ) {
        # change date to ISO format
        $tmp = $date;
        # try "2000.12.31.23.59.59" format
        $tmp =~ /(.*?)\.(.*?)\.(.*?)\.(.*?)\.(.*?)\.[0-9]/;
        if( $5 ) {
            $date = "$3 $TWiki::isoMonth[$2-1] $1 - $4:$5";
        } else {
            # try "2000/12/31 23:59:59" format
            $tmp =~ /(.*?)\/(.*?)\/(.*?) (.*?):[0-9][0-9]$/;
            if( $4 ) {
                $date = "$3 $TWiki::isoMonth[$2-1] $1 - $4";
            }
        }
    }
    return ( $date, $user, $rev );
}


# =========================
sub saveTopic
{
    my( $topic, $text, $saveCmd, $doUnlock, $dontNotify, $dontLogSave ) = @_;
    my $name = "$TWiki::dataDir/$TWiki::webName/$topic.txt";
    my $time = time();
    my $tmp = "";
    my $rcsError = "";

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
        if( abs( $mtime2 - $mtime1 ) < $TWiki::editLockTime ) {
            my $rev = getRevisionNumber( $topic );
            my( $date, $user ) = getRevisionInfo( $topic, $rev );
            # same user?
            if( ( $TWiki::doKeepRevIfEditLock ) && ( $user eq $TWiki::userName ) ) {
                # replace last repository entry
                $saveCmd = "repRev";
            }
        }

        if( $saveCmd ne "repRev" ) {
            # update repository
            $tmp= $TWiki::revCiCmd;
            $tmp =~ s/%USERNAME%/$TWiki::userName/;
            $tmp =~ s/%FILENAME%/$name/;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
            if( $rcsError ) {   # oops, stderr was not empty, return error
                return $rcsError;
            }

            if( ! $dontNotify ) {
                # update .changes
                my( $fdate, $fuser, $frev ) = getRevisionInfo( $topic, "" );
                $fdate = ""; # suppress warning
                $fuser = ""; # suppress warning

                my @foo = split( /\n/, &readFile( "$TWiki::dataDir/$TWiki::webName/.changes" ) );
                if( $#foo > 100 ) {
                    shift( @foo);
                }
                push( @foo, "$topic\t$TWiki::userName\t$time\t$frev" );
                open( FILE, ">$TWiki::dataDir/$TWiki::webName/.changes" );
                print FILE join( "\n", @foo )."\n";
                close(FILE);
            }

            if( ( $TWiki::doLogTopicSave ) && ! ( $dontLogSave ) ) {
                # write log entry
                writeLog( "save", "$TWiki::webName.$topic", "" );
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
            $tmp= $TWiki::revUnlockCmd;
            $tmp =~ s/%FILENAME%/$name/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
            if( $rcsError ) {   # oops, stderr was not empty, return error
                return $rcsError;
            }
            $tmp= $TWiki::revDelRevCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
            if( $rcsError ) {   # oops, stderr was not empty, return error
                return $rcsError;
            }
            $tmp= $TWiki::revLockCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
            if( $rcsError ) {   # oops, stderr was not empty, return error
                return $rcsError;
            }
        }
        $tmp = $TWiki::revCiDateCmd;
        $tmp =~ s/%DATE%/$date/;
        $tmp =~ s/%USERNAME%/$user/;
        $tmp =~ s/%FILENAME%/$name/;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
        if( $rcsError ) {   # oops, stderr was not empty, return error
            return $rcsError;
        }

        if( ( $TWiki::doLogTopicSave ) && ! ( $dontLogSave ) ) {
            # write log entry
            $tmp  = &TWiki::userToWikiName( $user );
            writeLog( "save", "$TWiki::webName.$topic", "repRev $rev $tmp $date" );
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
        $tmp= $TWiki::revUnlockCmd;
        $tmp =~ s/%FILENAME%/$name/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
        if( $rcsError ) {   # oops, stderr was not empty, return error
            return $rcsError;
        }
        $tmp= $TWiki::revDelRevCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
        if( $rcsError ) {   # oops, stderr was not empty, return error
            return $rcsError;
        }
        $tmp= $TWiki::revLockCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
        if( $rcsError ) {   # oops, stderr was not empty, return error
            return $rcsError;
        }

        # restore last topic from repository
        $rev = getRevisionNumber( $topic );
        $tmp = readVersion( $topic, $rev );
        saveFile( $name, $tmp );
        lockTopic( $topic, $doUnlock );

        # delete entry in .changes : To Do !

        if( $TWiki::doLogTopicSave ) {
            # write log entry
            writeLog( "cmd", "$TWiki::webName.$topic", "delRev $rev" );
        }
    }
    return 0; # all is well
}

# =========================
sub writeLog
{
    my( $action, $webTopic, $extra, $user ) = @_;

    # use local time for log, not UTC (gmtime)

    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
    my( $tmon) = $TWiki::isoMonth[$mon];
    $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
    my $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min );
    my $yearmonth = sprintf( "%.4u%.2u", $year, $mon+1 );

    my $wuserName = $user || $TWiki::userName;
    $wuserName = &TWiki::userToWikiName( $wuserName );
    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";
    my $text = "| $time | $wuserName | $action | $webTopic | $extra | $remoteAddr |";

    my $filename = $TWiki::logFilename;
    $filename =~ s/%DATE%/$yearmonth/go;
    open( FILE, ">>$filename");
    print FILE "$text\n";
    close( FILE);
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
sub lockTopic
{
    my( $name, $doUnlock ) = @_;

    my $lockFilename = "$TWiki::dataDir/$TWiki::webName/$name.lock";
    if( $doUnlock ) {
        unlink "$lockFilename";
    } else {
        my $lockTime = time();
        saveFile( $lockFilename, "$TWiki::userName\n$lockTime" );
    }
}

# =========================
sub removeObsoleteTopicLocks
{
    my( $web ) = @_;

    # Clean all obsolete .lock files in a web.
    # This should be called regularly, best from a cron job (called from mailnotify)

    my $webDir = "$TWiki::dataDir/$web";
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
        if( abs( $systemTime - $lockTime ) > $TWiki::editLockTime ) {
            # obsolete, so delete file
            unlink "$pathFile";
        }
    }
}


# =========================
sub topicIsLocked
{
    my( $theName ) = @_;

    # pragmatic approach: Warn user if somebody else pressed the
    # edit link within one hour

    my $lockFilename = "$TWiki::dataDir/$TWiki::webName/$theName.lock";
    if( ( -e "$lockFilename" ) && ( $TWiki::editLockTime > 0 ) ) {
        my $tmp = readFile( $lockFilename );
        my( $lockUser, $lockTime ) = split( /\n/, $tmp );
        if( $lockUser ne $TWiki::userName ) {
            # time stamp of lock within one hour of current time?
            my $systemTime = time();
            # calculate remaining lock time in seconds
            $lockTime = $lockTime + $TWiki::editLockTime - $systemTime;
            if( $lockTime > 0 ) {
                # must warn user that it is locked
                return ( $lockUser, $lockTime );
            }
        }
    }
    return ( "", 0 );
}


# =========================
sub webExists
{
    my( $theWeb ) = @_;
    return -e "$TWiki::dataDir/$theWeb";
}

# =========================
sub topicExists
{
    my( $theWeb, $theName ) = @_;
    return -e "$TWiki::dataDir/$theWeb/$theName.txt";
}

# =========================
sub readTopic
{
    my( $theName ) = @_;
    return &readFile( "$TWiki::dataDir/$TWiki::webName/$theName.txt" );
}

# =========================
sub readWebTopic
{
    my( $theWeb, $theName ) = @_;
    return &readFile( "$TWiki::dataDir/$theWeb/$theName.txt" );
}

# =========================
sub readTemplate
{
    my( $theName, $theTopic, $theSkin ) = @_;
    $theTopic = "" unless $theTopic; # prevent 'uninitialized value' ...
    $theSkin  = "" unless $theSkin;  #   ... warnings

    # CrisBailiff, PeterThoeny 13 Jun 2000: Add security
    $theName =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    $theName =~ s/\.+/\./g;                      # Filter out ".." from filename
    $theTopic =~ s/$TWiki::securityFilter//go;   # zap anything suspicious
    $theTopic =~ s/\.+/\./g;                     # Filter out ".." from filename
    $theSkin =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    $theSkin =~ s/\.+/\./g;                      # Filter out ".." from filename

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.topic)(.skin).tmpl
    my $tmplDir = "$TWiki::templateDir/$TWiki::webName";
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
    $tmplDir = $TWiki::templateDir;
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

1;

# EOF
