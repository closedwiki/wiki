#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Search engine of TWiki.
#
# Copyright (C) 2000 Peter Thoeny, Peter@Thoeny.com
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
# - Files wiki[a-z]+.pm are included by wiki.pm
#
# 20000501 Kevin Kinnell  : Many many many changes, best view is to
#                           run a diff.
# 20000605 Kevin Kinnell  : Bug hunting.  Fixed to allow web colors
#                           spec'd as "word" instead of hex only.
#                           Found a lovely bug that screwed up the
#                           search limits because Perl (as we all know
#                           but may forget) doesn't clear the $n match
#                           params if a match fails... *^&$#!!!
# PTh 03 Nov 2000: Performance improvements

package TWiki::Search;

use strict;

##use vars qw(
##        $lsCmd $egrepCmd $fgrepCmd
##);

# ===========================
# Normally writes no output, uncomment writeDebug line to get output of all RCS etc command to debug file
sub _traceExec
{
   my( $cmd, $result ) = @_;
   
   #TWiki::writeDebug( "Search exec: $cmd -> $result" );
}

# =========================
sub searchWeb
{
    ## 0501 kk : vvv Added params
    my ( $doInline, $theWebName, $theSearchVal, $theScope, $theOrder,
         $theRegex, $theLimit, $revSort, $caseSensitive, $noSummary,
         $noSearch, $noHeader, $noTotal, $doBookView, $doRenameView,
         $doShowLock, $noEmpty, $template, @junk ) = @_;

    ## 0501 kk : vvv new option to limit results
    # process the result limit here, this is the 'global' limit for
    # all webs in a multi-web search

    ## #############
    ## 0605 kk : vvv This code broke due to changes in the wiki.pm
    ##               file; it used to rely on the value of $1 being
    ##               a null string if there was no match.  What a pity
    ##               Perl doesn't do The Right Thing, but whatever--it's
    ##               fixed now.
    if ($theLimit =~ /(^\d+$)/o) { # only digits, all else is the same as
        $theLimit = $1;            # an empty string.  "+10" won't work.
    } else {
        $theLimit = 0;             # change "all" to 0, then to big number
    }
    if (! $theLimit ) {            # PTh 03 Nov 2000:
        $theLimit = 32000;         # Big number, needed for performance improvements
    }

    my $searchResult = ""; 
    my $topic = $TWiki::mainTopicname;

    ## #############
    ## 0501 kk : vvv An entire new chunk devoted to setting up mult-web
    ##               searches.

    my @webList;

    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called "All".)
    my $searchAllFlag = ( $theWebName =~ /^(([Aa][Ll][Ll])||([Oo][Nn]))$/ );

    # Search what webs?  "" current web, list gets the list, all gets
    # all (unless marked in WebPrefs as NOSEARCHALL)

    if( ! $theWebName ) {

        #default to current web
        push @webList, $TWiki::webName;

    } elsif ($searchAllFlag) {

        # get list of all webs by scanning $dataDir
        opendir DIR, $TWiki::dataDir;
        my @tmpList = readdir(DIR);
        closedir(DIR);

        # this is not magic, it just looks like it.
        @webList = sort
	           grep { s#^.+/([^/]+)$#$1# }
                   grep { -d }
	           map  { "$TWiki::dataDir/$_" }
                   grep { ! /^\.\.?$/ } @tmpList;

        # what that does (looking from the bottom up) is take the file
        # list, filter out the dot directories and dot files, turn the
        # list into full paths instead of just file names, filter out
        # any non-directories, strip the path back off, and sort
        # whatever was left after all that (which should be merely a
        # list of directory's names.)

    } else {

        # use whatever the user sent
        @webList = split(" ", $theWebName); # the web processing loop filters
                                            # for valid web names, so don't
                                            # do it here.
    }
    ## 0501 kk : ^^^
    ## ##############

    my $tempVal = "";
    my $tmpl = "";
    my $topicCount = 0; # JohnTalintyre
    if( $template ) {
        $tmpl = &TWiki::Store::readTemplate( "$template" );
        # FIXME replace following with this @@@
    } elsif( $doBookView ) {
        $tmpl = &TWiki::Store::readTemplate( "searchbookview" );
    } elsif ($doRenameView ) {
        $tmpl = &TWiki::Store::readTemplate( "searchrenameview" ); # JohnTalintyre
    } else {
        $tmpl = &TWiki::Store::readTemplate( "search" );
    }
    my( $tmplHead, $tmplSearch,
	$tmplTable, $tmplNumber, $tmplTail ) = split( /%SPLIT%/, $tmpl );
    $tmplHead   = &TWiki::handleCommonTags( $tmplHead, $topic );
    $tmplSearch = &TWiki::handleCommonTags( $tmplSearch, $topic );
    $tmplNumber = &TWiki::handleCommonTags( $tmplNumber, $topic );
    $tmplTail   = &TWiki::handleCommonTags( $tmplTail, $topic );

    if( ! $tmplTail ) {
        print "<html><body>";
        print "<h1>TWiki Installation Error</h1>";
        # Might not be search.tmpl FIXME
        print "Incorrect format of search.tmpl (missing %SPLIT% parts)";
        print "</body></html>";
        return;
    }

    if( ! $doInline ) {
        # print first part of full HTML page
        $tmplHead = &TWiki::getRenderedVersion( $tmplHead );
        $tmplHead =~ s|</*nop/*>||goi;   # remove <nop> tags (PTh 06 Nov 2000)
        print $tmplHead;
    }

    if( ! $noSearch ) {
        # print "Search:" part
        $theSearchVal =~ s/&/&amp;/go;
        $theSearchVal =~ s/</&lt;/go;
        $theSearchVal =~ s/>/&gt;/go;
        $theSearchVal =~ s/^\.\*$/Index/go;
        $tmplSearch =~ s/%SEARCHSTRING%/$theSearchVal/go;
        if( $doInline ) {
            $searchResult .= $tmplSearch;
        } else {
            $tmplSearch = &TWiki::getRenderedVersion( $tmplSearch );
            $tmplSearch =~ s|</*nop/*>||goi;   # remove <nop> tag
            print $tmplSearch;
        }
    }

    my $cmd = "";
    if( $theScope eq "topic" ) {
        $cmd = "$TWiki::lsCmd *.txt | %GREP% %SWITCHES% $TWiki::cmdQuote$theSearchVal$TWiki::cmdQuote";
    } else {
        $cmd = "%GREP% %SWITCHES% -l $TWiki::cmdQuote$theSearchVal$TWiki::cmdQuote *.txt";
    }

    if( $caseSensitive ) {
        $tempVal = "";
    } else {
        $tempVal = "-i";
    }
    $cmd =~ s/%SWITCHES%/$tempVal/go;

    if( $theRegex ) {
        $tempVal = $TWiki::egrepCmd;
    } else {
        $tempVal = $TWiki::fgrepCmd;
    }
    $cmd =~ s/%GREP%/$tempVal/go;

    # write log entry
    if( ( $TWiki::doLogTopicSearch ) && ( ! $doInline ) ) {
        # 0501 kk : vvv Moved from search
        # PTh 17 May 2000: reverted to old behaviour,
        #     e.g. do not log inline search
        # PTh 03 Nov 2000: Moved out of the 'foreach $thisWebName' loop
        my $tempVal = join( ' ', @webList );
        &TWiki::Store::writeLog( "search", $tempVal, $theSearchVal );
    }

    ## #############
    ## 0501 kk : vvv New web processing loop, does what the old straight
    ##               code did for each web the user requested.  Note that
    ##               '$theWebName' is mostly replaced by '$thisWebName'

    foreach my $thisWebName (@webList) {

        # PTh 03 Nov 2000: Add security check
        $thisWebName =~ s/$TWiki::securityFilter//go;
        $thisWebName =~ /(.*)/;
        $thisWebName = $1;  # untaint variable

        next unless &TWiki::Store::webExists( $thisWebName );  # can't process what ain't thar

        my $thisWebBGColor     = &TWiki::Prefs::getPreferencesValue( "WEBBGCOLOR", $thisWebName ) || "\#FF00FF";
        my $thisWebNoSearchAll = &TWiki::Prefs::getPreferencesValue( "NOSEARCHALL", $thisWebName );

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        # PTh 18 Aug 2000: Need to include if it is the current web
        next if ( ( $searchAllFlag ) &&
                  ( $thisWebNoSearchAll =~ /on/i ) &&
                  ( $thisWebName ne $TWiki::webName ) );

        (my $baz = "foo") =~ s/foo//;  # reset search vars. defensive coding

        # 0501 kjk : vvv New var for accessing web dirs.
        my $sDir = "$TWiki::dataDir/$thisWebName";
        my @topicList = "";
        if( $theSearchVal ) {
            # do grep search
            chdir( "$sDir" );
            _traceExec( "chdir to $sDir", "" );
            $cmd =~ /(.*)/;
            $cmd = $1;       # untaint variable (NOTE: Needs a better check!)
            $tempVal = `$cmd`;
            _traceExec( $cmd, $tempVal );
            @topicList = split( /\n/, $tempVal );
            # cut .txt extension
            my @tmpList = map { /(.*)\.txt$/; $_ = $1; } @topicList;
            @topicList = ();
            my $lastTopic = "";
            foreach( @tmpList ) {
                $tempVal = $_;
                # make topic unique
                if( $tempVal ne $lastTopic ) {
                    push @topicList, $tempVal;
                }
            }
        }
        
        next if ( $noEmpty && ! @topicList ); # Nothing to show for this topic

        # use hash tables for date, author, rev number and view permission
        my %topicRevDate = ();
        my %topicRevUser = ();
        my %topicRevNum = ();
        my %topicAllowView = ();

        # sort the topic list by date, author or topic name
        if( $theOrder eq "modified" ) {
            # PTh 03 Nov 2000: Performance improvement
            # Dates are tricky. For performance we do not read, say,
            # 2000 records of author/date, sort and then use only 50.
            # Rather we 
            #   * sort by file timestamp (to get a rough list)
            #   * shorten list to the limit + some slack
            #   * sort by rev date on shortened list to get the acurate list

            # Do performance exercise only if it pays off
            if(  $theLimit + 20 < scalar(@topicList) ) {
                # sort by file timestamp, Schwartzian Transform
                my @tmpList = ();
                if( $revSort ) {
                    @tmpList = map { $_->[1] }
                               sort {$b->[0] <=> $a->[0] }
                               map { [ (stat "$TWiki::dataDir\/$thisWebName\/$_.txt")[9], $_ ] }
                               @topicList;
                } else {
                    @tmpList = map { $_->[1] }
                               sort {$a->[0] <=> $b->[0] }
                               map { [ (stat "$TWiki::dataDir\/$thisWebName\/$_.txt")[9], $_ ] }
                               @topicList;
                }

                # then shorten list and build the hashes for date and author
                my $idx = $theLimit + 10;  # slack on limit
                @topicList = ();
                foreach( @tmpList ) {
                    push( @topicList, $_ );
                    $idx -= 1;
                    last if $idx <= 0;
                }
            }

            # build the hashes for date and author
            foreach( @topicList ) {
                my $tempVal = $_;
                # FIXME should be able to get data from topic
                my( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $tempVal );
                my ( $revdate, $revuser, $revnum ) = &TWiki::Store::getRevisionInfoFromMeta( $thisWebName, $tempVal, $meta, 1 );
                $topicRevUser{ $tempVal } = &TWiki::userToWikiName( $revuser );
                $topicRevDate{ $tempVal } = $revdate;
                $topicRevNum{ $tempVal } = $revnum;
                $topicAllowView{ $tempVal } = &TWiki::Access::checkAccessPermission( "view", $TWiki::wikiUserName, $text, $tempVal, $thisWebName );
            }

            # sort by date (second time if exercise), Schwartzian Transform
            if( $revSort ) {
                @topicList = map { $_->[1] }
                             sort {$b->[0] <=> $a->[0] }
                             map { [ &TWiki::revDate2EpSecs( $topicRevDate{$_} ), $_ ] }
                             @topicList;
            } else {
                @topicList = map { $_->[1] }
                             sort {$a->[0] <=> $b->[0] }
                             map { [ &TWiki::revDate2EpSecs( $topicRevDate{$_} ), $_ ] }
                             @topicList;
            }

        } elsif( $theOrder eq "editby" ) {
            # sort by author

            # first we need to build the hashes for date and author
            foreach( @topicList ) {
                $tempVal = $_;
                my( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $tempVal );
                my ( $revdate, $revuser, $revnum ) = &TWiki::Store::getRevisionInfoFromMeta( $thisWebName, $tempVal, $meta, 1 );
                $topicRevUser{ $tempVal } = &TWiki::userToWikiName( $revuser );
                $topicRevDate{ $tempVal } = $revdate;
                $topicRevNum{ $tempVal } = $revnum;
                $topicAllowView{ $tempVal } = &TWiki::Access::checkAccessPermission( "view", $TWiki::wikiUserName, $text, $tempVal, $thisWebName );
            }

            # sort by author, Schwartzian Transform
            if( $revSort ) {
                @topicList = map { $_->[1] }
                             sort {$b->[0] cmp $a->[0] }
                             map { [ $topicRevUser{$_}, $_ ] }
                             @topicList;
            } else {
                @topicList = map { $_->[1] }
                             sort {$a->[0] cmp $b->[0] }
                             map { [ $topicRevUser{$_}, $_ ] }
                             @topicList;
    	    }

        } else {
            # sort by filename, Schwartzian Transform
            if( $revSort ) {
                @topicList = map { $_->[1] }
                             sort {$b->[0] cmp $a->[0] }
                             map { [ $_, $_ ] }
                             @topicList;
            } else {
                @topicList = map { $_->[1] }
                             sort {$a->[0] cmp $b->[0] }
                             map { [ $_, $_ ] }
                             @topicList;
    	    }
        }

        # output header of $thisWebName
        my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );
        $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/o;
        $beforeText =~ s/%WEB%/$thisWebName/o;
        $beforeText = &TWiki::handleCommonTags( $beforeText, $topic );
        $afterText  = &TWiki::handleCommonTags( $afterText, $topic );
        if( ! $noHeader ) {
            if( $doInline ) {
                $searchResult .= $beforeText;
            } else {
                $beforeText = &TWiki::getRenderedVersion( $beforeText, $thisWebName );
                $beforeText =~ s|</*nop/*>||goi;   # remove <nop> tag
                print $beforeText;
            }
        }

        # output the list of topics in $thisWebName
        my $ntopics = 0;
        my $topic = "";
        my $head = "";
        my $revDate = "";
        my $revUser = "";
        my $revNum = "";
        my $allowView = "";
        my $locked = "";
        foreach( @topicList ) {
            $topic = $_;
            
            my $text = "";
            
            # make sure we have date and author
            if( exists( $topicRevUser{$topic} ) ) {
                $revDate = $topicRevDate{$topic};
                $revUser = $topicRevUser{$topic};
                $revNum  = $topicRevNum{$topic};
                $allowView = $topicAllowView{$topic};
            } else {
                # lazy query, need to do it at last
                my $meta = "";
                ( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $topic );
                $allowView = &TWiki::Access::checkAccessPermission( "view", $TWiki::wikiUserName, $text, $topic, $thisWebName );
                ( $revDate, $revUser, $revNum ) = &TWiki::Store::getRevisionInfoFromMeta( $thisWebName, $topic, $meta, 1 );
                $revUser = &TWiki::userToWikiName( $revUser );
            }

            $locked = "";
            if( $doShowLock ) {
                ( $tempVal ) = &TWiki::Store::topicIsLockedBy( $thisWebName, $topic );
                if( $tempVal ) {
                    $revUser = &TWiki::userToWikiName( $tempVal );
                    $locked = "(LOCKED)";
                }
            }
            
            # Check security
            # FIXME - how deal with user login not available if coming from search script?
            if( ! $allowView ) {
                next;
            }

            $tempVal = $repeatText;
            $tempVal =~ s/%WEB%/$thisWebName/go;
            $tempVal =~ s/%TOPICNAME%/$topic/go;
            $tempVal =~ s/%LOCKED%/$locked/o;
            $tempVal =~ s/%TIME%/$revDate/o;
            if( $revNum > 1 ) {
                $revNum = "r1.$revNum";
            } else {
                $revNum = "<b>NEW</b>";
            }
            $tempVal =~ s/%REVISION%/$revNum/o;
            $tempVal =~ s/%AUTHOR%/$revUser/o;
            if( ! $doInline ) {
                $tempVal = &TWiki::handleCommonTags( $tempVal, $topic );
                $tempVal = &TWiki::getRenderedVersion( $tempVal );
            }

            if( $doRenameView ) { # added JET 19 Feb 2000
                my $rawText = &TWiki::Store::readTopicRaw( $thisWebName, $topic );
                my $changeable = "";
                my $changeAccessOK = &TWiki::Access::checkAccessPermission( "change", $TWiki::wikiUserName, $text, $topic, $thisWebName );
                if( ! $changeAccessOK ) {
                   $changeable = "(NO CHANGE PERMISSION)";
                   $tempVal =~ s/%SELECTION%.*%SELECTION%//o;
                } else {
                   $tempVal =~ s/%SELECTION%//go;
                   $topicCount++;
                }
                $tempVal =~ s/%CHANGEABLE%/$changeable/o;

                $tempVal =~ s/%TOPIC_NUMBER%/$topicCount/go;
                $tempVal =~ s/%LABEL%/$doRenameView/go;
                my $reducedOutput = "";
                
                # Remove lines that don't contain the topic and highlight matched string
                my $insidePRE = 0;
                my $insideVERBATIM = 0;
                my $noAutoLink = 0;
                
                foreach( split( /\n/, $rawText ) ) {
                
                   next if( /^%META:TOPIC(INFO|MOVED)/ );

                   # This code is in far too many places
                   m|<pre>|i  && ( $insidePRE = 1 );
                   m|</pre>|i && ( $insidePRE = 0 );
                   if( m|<verbatim>|i ) {
                       $insideVERBATIM = 1;
                   }
                   if( m|</verbatim>|i ) {
                       $insideVERBATIM = 0;
                   }
                   m|<noautolink>|i   && ( $noAutoLink = 1 );
                   m|</noautolink>|i  && ( $noAutoLink = 0 );

                   if( ! ( $insidePRE || $insideVERBATIM || $noAutoLink ) ) {
                       # This can incorrectly show matches becuase of case insenstive option, required to get [[spaced Word]] to match
                       my $subs = s|$theSearchVal|$1<font color="red">$2</font>&nbsp;|ig;
                       $reducedOutput .= "$_<br>\n" if( $subs );
                   }
                }
                $tempVal =~ s/%TEXTHEAD%/$reducedOutput/go;
                next if ( ! $reducedOutput );
            } elsif( $noSummary ) {
                $tempVal =~ s/%TEXTHEAD%//go;
                $tempVal =~ s/&nbsp;//go;
            } elsif( $doBookView ) {  # added PTh 20 Jul 2000
                if( ! $text ) {
                    my $meta = "";
                    ( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $topic );
                }

                $text = &TWiki::handleCommonTags( $text, $topic, $thisWebName );
                $text = &TWiki::getRenderedVersion( $text, $thisWebName );
                # FIXME: What about meta data rendering?
                $tempVal =~ s/%TEXTHEAD%/$text/go;
            } else {
                if( $text ) {
                    $head = $text;
                } else {
                    $head = &TWiki::Store::readFileHead( "$TWiki::dataDir\/$thisWebName\/$topic.txt", 16 );
                }
                $head = &TWiki::makeTopicSummary( $head, $topic, $thisWebName );
                $tempVal =~ s/%TEXTHEAD%/$head/go;
            }

            if( $doInline ) {
                $searchResult .= $tempVal;
            } else {
                $tempVal = &TWiki::getRenderedVersion( $tempVal, $thisWebName );
                $tempVal =~ s|</*nop/*>||goi;   # remove <nop> tag
                print $tempVal;
            }

            $ntopics += 1;
            last if $ntopics >= $theLimit;
        }
    
        # output footer of $thisWebName
        if( $doInline ) {
            $searchResult .= $afterText;
        } else {
            $afterText = &TWiki::getRenderedVersion( $afterText, $thisWebName );
            $afterText =~ s|</*nop/*>||goi;   # remove <nop> tag
            print $afterText;
        }

        if( ! $noTotal ) {
            # print "Number of topics:" part
            my $thisNumber = $tmplNumber;
            $thisNumber =~ s/%NTOPICS%/$ntopics/go;
            if( $doInline ) {
                $searchResult .= $thisNumber;
            } else {
                $thisNumber = &TWiki::getRenderedVersion( $thisNumber, $thisWebName );
                $thisNumber =~ s|</*nop/*>||goi;   # remove <nop> tag
                print $thisNumber;
            }
        }
    }
    if( ! $doInline ) {
        # print last part of full HTML page
        $tmplTail = &TWiki::getRenderedVersion( $tmplTail );
        $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
        print $tmplTail;
    }
    return $searchResult;
}

# =========================

1;

# EOF

