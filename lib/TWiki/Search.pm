# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Search engine of TWiki.
#
# Copyright (C) 2000-2003 Peter Thoeny, peter@thoeny.com
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
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
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

# 'Use locale' for internationalisation of Perl sorting and searching - 
# main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        require locale;
	import locale ();
    }
}

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
         $doShowLock, $noEmpty, $theTemplate, $theHeader, $theFormat,
         @junk ) = @_;

    ##TWiki::writeDebug "Search locale is $TWiki::siteLocale";

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

    my @webList = ();

    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called "All".)
    my $searchAllFlag = ( $theWebName =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );

    # Search what webs?  "" current web, list gets the list, all gets
    # all (unless marked in WebPrefs as NOSEARCHALL)

    if( $theWebName ) {
        foreach my $web ( split( /[\,\s]+/, $theWebName ) ) {
            # the web processing loop filters for valid web names, so don't do it here.

            if( $web =~ /^(all|on)$/i  ) {
                # get list of all webs by scanning $dataDir
                opendir DIR, $TWiki::dataDir;
                my @tmpList = readdir(DIR);
                closedir(DIR);
                @tmpList = sort
                   grep { s#^.+/([^/]+)$#$1# }
                   grep { -d }
                   map  { "$TWiki::dataDir/$_" }
                   grep { ! /^[._]/ } @tmpList;

                   # what that does (looking from the bottom up) is take the file
                   # list, filter out the dot directories and dot files, turn the
                   # list into full paths instead of just file names, filter out
                   # any non-directories, strip the path back off, and sort
                   # whatever was left after all that (which should be merely a
                   # list of directory's names.)

                foreach my $aweb ( @tmpList ) {
                    push( @webList, $aweb ) unless( grep { /^$aweb$/ } @webList );
                }

            } else {
                push( @webList, $web ) unless( grep { /^$web$/ } @webList );
            }
        }

    } else {
        #default to current web
        push @webList, $TWiki::webName;
    }

    my $tempVal = "";
    my $tmpl = "";
    my $topicCount = 0; # JohnTalintyre
    my $originalSearch = $theSearchVal;
    my $renameTopic;
    my $renameWeb = "";
    my $spacedTopic;
    $theTemplate = "searchformat" if( $theFormat );
    if( $theTemplate ) {
        $tmpl = &TWiki::Store::readTemplate( "$theTemplate" );
        # FIXME replace following with this @@@
    } elsif( $doBookView ) {
        $tmpl = &TWiki::Store::readTemplate( "searchbookview" );
    } elsif ($doRenameView ) {
        $tmpl = &TWiki::Store::readTemplate( "searchrenameview" ); # JohnTalintyre
        # Create full search string from topic name that is passed in
        my $renameTopic = $theSearchVal;
        if( $renameTopic =~ /(.*)\\\.(.*)/o ) {
            $renameWeb = $1;
            $renameTopic = $2;
        }
        $spacedTopic = spacedTopic( $renameTopic );
        $spacedTopic = $renameWeb . '\.' . $spacedTopic if( $renameWeb );
	# TODO: i18n fix
        $theSearchVal = "(^|[^A-Za-z0-9_])$theSearchVal" . '([^A-Za-z0-9_]|$)|' .
                        '(\[\[' . $spacedTopic . '\]\])';
    } else {
        $tmpl = &TWiki::Store::readTemplate( "search" );
    }

    $tmpl =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

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
#FIXME: The following regex changes the actual search string!
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

    # Construct command line with 'ls' and 'grep.  Note that 'ls' does not
    # need to be locale-aware as long as it does not transform filenames -
    # all results are sorted by Perl 'sort'.  However, 'grep' must use
    # locales if needed, for case-insensitive searching.
    my $cmd = "";
    if( $theScope eq "topic" ) {
        $cmd = "$TWiki::lsCmd %FILES% | %GREP% %SWITCHES% -- $TWiki::cmdQuote%TOKEN%$TWiki::cmdQuote";
    } else {
        $cmd = "%GREP% %SWITCHES% -l -- $TWiki::cmdQuote%TOKEN%$TWiki::cmdQuote %FILES%";
    }

    if( $caseSensitive ) {
        $tempVal = "";
    } else {
        $tempVal = "-i";
    }
    $cmd =~ s/%SWITCHES%/$tempVal/go;

    my @tokens;
    if( $theRegex ) {
        $tempVal = $TWiki::egrepCmd;
        @tokens = split( /;/, $theSearchVal );
        if( $theScope eq "topic" ) {
            # Fix for Codev.CantAnchorSearchREToEnd
            @tokens = map { s/\$$/\\\.txt\$/o; $_ } @tokens;
        }

    } else {
        $tempVal = $TWiki::fgrepCmd;
        @tokens = $theSearchVal;
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
        next if (   ( $searchAllFlag )
                 && ( ( $thisWebNoSearchAll =~ /on/i ) || ( $thisWebName =~ /^[\.\_]/ ) )
                 && ( $thisWebName ne $TWiki::webName ) );

        (my $baz = "foo") =~ s/foo//;  # reset search vars. defensive coding

        # 0501 kjk : vvv New var for accessing web dirs.
        my $sDir = "$TWiki::dataDir/$thisWebName";
        my @topicList = "";
        if( $theSearchVal ) {
            # do grep search
            chdir( "$sDir" );
            _traceExec( "chdir to $sDir", "" );
            @topicList = ( "*.txt" );
            foreach my $token ( @tokens ) {
                my $acmd = $cmd;
                $acmd =~ s/%TOKEN%/$token/o;
                $acmd =~ s/%FILES%/@topicList/;
                $acmd =~ /(.*)/;
                $acmd = "$1";       # untaint variable (NOTE: Needs a better check!)
                $tempVal = `$acmd`;
                _traceExec( $acmd, $tempVal );
                @topicList = split( /\n/, $tempVal );
                last if( ! @topicList );
            }
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
                my( $revdate, $revuser, $revnum ) = &TWiki::Store::getRevisionInfoFromMeta( $thisWebName, $tempVal, $meta, 1 );
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

        } elsif( $theOrder =~ m/^formfield\((.*)\)$/ ) {
            # sort by TWikiForm field
            my $sortfield = $1;
            my %fieldVals= ();
            # first we need to build the hashes for fields
            foreach( @topicList ) {
                $tempVal = $_;
                my( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $tempVal );
                my( $revdate, $revuser, $revnum ) = &TWiki::Store::getRevisionInfoFromMeta( $thisWebName, $tempVal, $meta, 1 );
                $topicRevUser{ $tempVal } = &TWiki::userToWikiName( $revuser );
                $topicRevDate{ $tempVal } = $revdate;
                $topicRevNum{ $tempVal } = $revnum;
                $topicAllowView{ $tempVal } = &TWiki::Access::checkAccessPermission( "view", $TWiki::wikiUserName, $text, $tempVal, $thisWebName );
                $fieldVals{ $tempVal } = getMetaFormField( $meta, $sortfield );
            }
 
            # sort by field, Schwartzian Transform
            if( $revSort ) {
                @topicList = map { $_->[1] }
                sort {$b->[0] cmp $a->[0] }
                map { [ $fieldVals{$_}, $_ ] }
                @topicList;
            } else {
                @topicList = map { $_->[1] }
                sort {$a->[0] cmp $b->[0] }
                map { [ $fieldVals{$_}, $_ ] }
                @topicList;
            }

        } else {
            # sort by filename, Schwartzian Transform
	    ##TWiki::writeDebug "Topic list before sort = @topicList";
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
	    ##TWiki::writeDebug "Topic list after sort = @topicList";
        }

        # output header of $thisWebName
        my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );
        if( $theHeader ) {
            $theHeader =~ s/\$n\(\)/\n/gos;          # expand "$n()" to new line
	    # TODO: i18n fix
            $theHeader =~ s/\$n([^a-zA-Z])/\n$1/gos; # expand "$n" to new line
            $theHeader =~ s/([^\n])$/$1\n/gos;
            $beforeText = $theHeader;
            $beforeText =~ s/\$web/$thisWebName/gos;
        }

        $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
        $beforeText =~ s/%WEB%/$thisWebName/go;
        $beforeText = &TWiki::handleCommonTags( $beforeText, $topic );
        $afterText  = &TWiki::handleCommonTags( $afterText, $topic );
        if( ! $noHeader ) {
            if( $doInline || $theFormat ) {
                # print at the end if formatted search because of table rendering
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
            
            my $meta = "";
            my $text = "";
            my $forceRendering = 0;
            
            # make sure we have date and author
            if( exists( $topicRevUser{$topic} ) ) {
                $revDate = $topicRevDate{$topic};
                $revUser = $topicRevUser{$topic};
                $revNum  = $topicRevNum{$topic};
                $allowView = $topicAllowView{$topic};
            } else {
                # lazy query, need to do it at last
                ( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $topic );
                $text =~ s/%WEB%/$thisWebName/gos;
                $text =~ s/%TOPIC%/$topic/gos;
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

            if( $theFormat ) {
                $tempVal = $theFormat;
                $tempVal =~ s/([^\n])$/$1\n/gos;       # cut last trailing new line
                $tempVal =~ s/\$n\(\)/\n/gos;          # expand "$n()" to new line
		# TODO: i18n fix
                $tempVal =~ s/\$n([^a-zA-Z])/\n$1/gos; # expand "$n" to new line
                $tempVal =~ s/\$web/$thisWebName/gos;
                $tempVal =~ s/\$topic\(([^\)]*)\)/breakName( $topic, $1 )/geos;
                $tempVal =~ s/\$topic/$topic/gos;
                $tempVal =~ s/\$locked/$locked/gos;
                $tempVal =~ s/\$date/$revDate/gos;
                $tempVal =~ s/\$isodate/&TWiki::revDate2ISO($revDate)/geos;
                $tempVal =~ s/\$rev/1.$revNum/gos;
                $tempVal =~ s/\$wikiusername/$revUser/gos;
                $tempVal =~ s/\$username/&TWiki::wikiToUserName($revUser)/geos;
                if( $tempVal =~ m/\$text/ ) {
                    # expand topic text
                    ( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $topic ) unless $text;
                    if( $topic eq $TWiki::topicName ) {
                        # defuse SEARCH in current topic to prevent loop
                        $text =~ s/%SEARCH{.*?}%/SEARCH{...}/go;
                    }
                    $tempVal =~ s/\$text/$text/gos;
                    $forceRendering = 1;
                }
            } else {
                $tempVal = $repeatText;
            }
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

            if( ( $doInline || $theFormat ) && ( ! ( $forceRendering ) ) ) {
                # print at the end if formatted search because of table rendering
                # do nothing
            } else {
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
                }
                $tempVal =~ s/%CHANGEABLE%/$changeable/o;

                $tempVal =~ s/%LABEL%/$doRenameView/go;
                my $reducedOutput = "";
                
                # Remove lines that don't contain the topic and highlight matched string
                my $insidePRE = 0;
                my $insideVERBATIM = 0;
                my $noAutoLink = 0;
                
                foreach( split( /\n/, $rawText ) ) {
                
                   next if( /^%META:TOPIC(INFO|MOVED)/ );
                   s/</&lt;/go;
                   s/>/&gt;/go;

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
                       # Case insensitive option is required to get [[spaced Word]] to match
		       # TODO: i18n fix
                       my $match =  "(^|[^A-Za-z0-9_.])($originalSearch)(?=[^A-Za-z0-9_]|\$)";
		       # FIXME: Should use /o here since $match is based on
		       # search string.
                       my $subs = s|$match|$1<font color="red">$2</font>&nbsp;|g;
                       $match = '(\[\[)' . "($spacedTopic)" . '(?=\]\])';
                       $subs += s|$match|$1<font color="red">$2</font>&nbsp;|gi;
                       if( $subs ) {
                           $topicCount++ if( ! $reducedOutput );
                           $reducedOutput .= "$_<br />\n" if( $subs );
                       }
                   }
                }
                $tempVal =~ s/%TOPIC_NUMBER%/$topicCount/go;
                $tempVal =~ s/%TEXTHEAD%/$reducedOutput/go;
                next if ( ! $reducedOutput );

            } elsif( $doBookView ) {
                # BookView, added PTh 20 Jul 2000
                if( ! $text ) {
                    ( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $topic );
                }

                $text = &TWiki::handleCommonTags( $text, $topic, $thisWebName );
                $text = &TWiki::getRenderedVersion( $text, $thisWebName );
                # FIXME: What about meta data rendering?
                $tempVal =~ s/%TEXTHEAD%/$text/go;

            } elsif( $theFormat ) {
                # free format, added PTh 10 Oct 2001
                if( ! $text ) {
                    ( $meta, $text ) = &TWiki::Store::readTopic( $thisWebName, $topic );
                    $text =~ s/%WEB%/$thisWebName/gos;
                    $text =~ s/%TOPIC%/$topic/gos;
                }
                $tempVal =~ s/\$summary/&TWiki::makeTopicSummary( $text, $topic, $thisWebName )/geos;
                $tempVal =~ s/\$formfield\(\s*([^\)]*)\s*\)/getMetaFormField( $meta, $1 )/geos;
                $tempVal =~ s/\$pattern\(\s*(.*?\s*\.\*)\)/getTextPattern( $text, $1 )/geos;
                $tempVal =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
                $tempVal =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
                $tempVal =~ s/\$percnt(\(\))?/\%/gos; # expand percent
                $tempVal =~ s/\$dollar(\(\))?/\$/gos; # expand dollar

            } elsif( $noSummary ) {
                $tempVal =~ s/%TEXTHEAD%//go;
                $tempVal =~ s/&nbsp;//go;

            } else {
                # regular search view
                if( $text ) {
                    $head = $text;
                } else {
                    $head = &TWiki::Store::readFileHead( "$TWiki::dataDir\/$thisWebName\/$topic.txt", 16 );
                }
                $head = &TWiki::makeTopicSummary( $head, $topic, $thisWebName );
                $tempVal =~ s/%TEXTHEAD%/$head/go;
            }

            if( $doInline || $theFormat ) {
                # print at the end if formatted search because of table rendering
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
        if( $doInline || $theFormat ) {
            # print at the end if formatted search because of table rendering
            $afterText =~ s/\n$//gos;  # remove trailing new line
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
            if( $doInline || $theFormat ) {
                # print at the end if formatted search because of table rendering
                $searchResult .= $thisNumber;
            } else {
                $thisNumber = &TWiki::getRenderedVersion( $thisNumber, $thisWebName );
                $thisNumber =~ s|</*nop/*>||goi;   # remove <nop> tag
                print $thisNumber;
            }
        }
    }

    if( $theFormat ) {
        $searchResult =~ s/\n$//gos;  # remove trailing new line
    }
    if( $doInline ) {
        # return formatted search result
        return $searchResult;

    } else {
        if( $theFormat ) {
            # finally print $searchResult which got delayed because of formatted search
            $tmplTail = "$searchResult$tmplTail";
        }

        # print last part of full HTML page
        $tmplTail = &TWiki::getRenderedVersion( $tmplTail );
        $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
        print $tmplTail;
    }
    return $searchResult;
}

#=========================
sub getMetaFormField
{
    my( $theMeta, $theParams ) = @_;

    my $name = $theParams;
    my $break = "";
    my @params = split( /\,\s*/, $theParams, 2 );
    if( @params > 1 ) {
        $name = $params[0] || "";
        $break = $params[1] || 1;
    }
    my $title = "";
    my $value = "";
    my @fields = $theMeta->find( "FIELD" );
    foreach my $field ( @fields ) {
        $title = $field->{"title"};
        $value = $field->{"value"};
        $value =~ s/^\s*(.*?)\s*$/$1/go;
        if( $title eq $name ) {
            $value = breakName( $value, $break );
            return $value;
        }
    }
    return "";
}

#=========================
sub getTextPattern
{
    my( $theText, $thePattern ) = @_;

    $thePattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/go;  # escape some special chars
    $thePattern =~ /(.*)/;     # untaint
    $thePattern = $1;
    $theText = "" unless( $theText =~ s/$thePattern/$1/is );

    return $theText;
}

#=========================
sub breakName
{
    my( $theText, $theParams ) = @_;

    my @params = split( /[\,\s]+/, $theParams, 2 );
    if( @params ) {
        my $len = $params[0] || 1;
        $len = 1 if( $len < 1 );
        my $sep = "- ";
        $sep = $params[1] if( @params > 1 );
        if( $sep =~ /^\.\.\./i ) {
            # make name shorter like "ThisIsALongTop..."
            $theText =~ s/(.{$len})(.+)/$1.../;

        } else {
            # split and hyphenate the topic like "ThisIsALo- ngTopic"
            $theText =~ s/(.{$len})/$1$sep/g;
            $theText =~ s/$sep$//;
        }
    }
    return $theText;
}

#=========================
sub spacedTopic
{
    my( $topic ) = @_;
    # FindMe -> Find\s*Me
    # TODO: i18n fix
    $topic =~ s/([a-z])([A-Z])/$1 *$2/go;
    return $topic;
}

#=========================

1;

# EOF
