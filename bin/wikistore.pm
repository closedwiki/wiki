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

use vars qw(
        $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd $revInfoCmd 
        $revDiffCmd $revDelRevCmd $revUnlockCmd $revLockCmd

);


# view:	    $text= &wiki::readVersion( $topic, "1.$rev" );
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
# rdiff:	$maxrev = &wiki::getRevisionNumber( $topic );
# view:	$maxrev = &wiki::getRevisionNumber( $topic );

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
# rdiff:            $text = &wiki::getRevisionDiff( $topic, "1.$r2", "1.$r1" );
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
# rdiff:         my( $date, $user ) = &wiki::getRevisionInfo( $topic, "1.$rev", 1 );
# view:          my( $date, $user ) = &wiki::getRevisionInfo( $topic, "1.$rev", 1 );
# wikisearch.pm: my ( $revdate, $revuser, $revnum ) = getRevisionInfo( $filename, "", 1, $thisWebName );
sub getRevisionInfo
{
    my( $theTopic, $theRev, $changeToIsoDate, $theWebName ) = @_;
    if( ! $theWebName ) {
        $theWebName = $webName;
    }
    if( ! $theRev ) {
        # PTh 03 Nov 2000: comment out for performance
        ### $theRev = getRevisionNumber( $theTopic, $theWebName );
        $theRev = "";  # do a "rlog -r filename" to get top revision info
    }
    my $tmp= $revInfoCmd;
    $theRev =~ s/$securityFilter//go;
    $theRev =~ /(.*)/;
    $theRev = $1;       # now safe, so untaint variable
    $tmp =~ s/%REVISION%/$theRev/;
    my $fileName = "$dataDir/$theWebName/$theTopic.txt";
    $fileName =~ s/$securityFilter//go;
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
        $user = $defaultUserName;
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
            $date = "$3 $isoMonth[$2-1] $1 - $4:$5";
        } else {
            # try "2000/12/31 23:59:59" format
            $tmp =~ /(.*?)\/(.*?)\/(.*?) (.*?):[0-9][0-9]$/;
            if( $4 ) {
                $date = "$3 $isoMonth[$2-1] $1 - $4";
            }
        }
    }
    return ( $date, $user, $rev );
}

# =========================


sub saveTopic
{
    my( $topic, $text, $saveCmd, $dontNotify, $doUnlock ) = @_;
    my $name = "$dataDir/$webName/$topic.txt";
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
            $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
            if( $rcsError ) {   # oops, stderr was not empty, return error
                return $rcsError;
            }

            if( ! $dontNotify ) {
                # update .changes
                my( $fdate, $fuser, $frev ) = getRevisionInfo( $topic, "" );
                $fdate = ""; # suppress warning
                $fuser = ""; # suppress warning

                my @foo = split(/\n/, &readFile( "$dataDir/$webName/.changes" ) );
                if( $#foo > 100 ) {
                    shift( @foo);
                }
                push( @foo, "$topic\t$userName\t$time\t$frev" );
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
            $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
            if( $rcsError ) {   # oops, stderr was not empty, return error
                return $rcsError;
            }
            $tmp= $revDelRevCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
            if( $rcsError ) {   # oops, stderr was not empty, return error
                return $rcsError;
            }
            $tmp= $revLockCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
            if( $rcsError ) {   # oops, stderr was not empty, return error
                return $rcsError;
            }
        }
        $tmp = $revCiDateCmd;
        $tmp =~ s/%DATE%/$date/;
        $tmp =~ s/%USERNAME%/$user/;
        $tmp =~ s/%FILENAME%/$name/;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
        if( $rcsError ) {   # oops, stderr was not empty, return error
            return $rcsError;
        }

        if( ( $doLogTopicSave ) && ( ! $dontNotify ) ) {
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
        $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
        if( $rcsError ) {   # oops, stderr was not empty, return error
            return $rcsError;
        }
        $tmp= $revDelRevCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>/dev/null`; # capture stderr  (S.Knutson)
        if( $rcsError ) {   # oops, stderr was not empty, return error
            return $rcsError;
        }
        $tmp= $revLockCmd;
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

        if( $doLogTopicSave ) {
            # write log entry
            writeLog( "cmd", "$webName.$topic", "delRev $rev" );
        }
    }
    return 0; # all is well
}

