#
# TWiki WikiClone (see $wikiversion for version)
#
# Search engine of TWiki.
#
# Copyright (C) 2000 Peter Thoeny, TakeFive Software Inc., 
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
# - Latest version at http://www.mindspring.net/~peterthoeny/twiki/
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Files wikifcg.pm and wikisearch.pm are included by wiki.pm
#
# 20000501 Kevin Kinnell  : Many many many changes, best view is to
#                           run a diff.
# 20000605 Kevin Kinnell  : Bug hunting.  Fixed to allow web colors
#                           spec'd as "word" instead of hex only.
#                           Found a lovely bug that screwed up the
#                           search limits because Perl (as we all know
#                           but may forget) doesn't clear the $n match
#                           params if a match fails... *^&$#!!!

# =========================
sub searchWikiWeb
{
    ## 0501 kk : vvv Added params
    my ( $doInline, $theWebName, $theSearchVal, $theScope, $theOrder,
         $theRegex, $theLimit, $revSort, $caseSensitive, $noSummary,
         $noSearch, $noTotal, $doBookView, @junk ) = @_;

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
    } else {                       # if there's anything but a digit, zap!
	$theLimit = "";
    }
    ## #############

    my $searchResult = ""; 
    my $topic = $wiki::mainTopicname;

    ## #############
    ## 0501 kk : vvv An entire new chunk devoted to setting up mult-web
    ##               searches.

    my @webList;

    # A value of 'all' by itself gets all webs, otherwise ignored (unless
    # there is a web called "All".)
    my $searchAllFlag = ($theWebName =~ /^[Aa][Ll][Ll]$/);

    # Search what webs?  "" current web, list gets the list, all gets
    # all (unless marked in WebPrefs as NOSEARCHALL)

    if( ! $theWebName ) {

        #default to current web
        push @webList, $wiki::webName;

    } elsif ($searchAllFlag) {

        # get list of all webs by scanning $dataDir
        opendir DIR, $dataDir;
        my @tmpList = readdir(DIR);
        closedir(DIR);

        # this is not magic, it just looks like it.
        @webList = sort
	           grep { s#^.+/([^/]+)$#$1# }
                   grep { -d }
	           map  { "$dataDir/$_" }
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
    if( $doBookView ) {
        $tmpl = readTemplate( "searchbookview" );
    } else {
        $tmpl = readTemplate( "search" );
    }
    my( $tmplHead, $tmplSearch,
	$tmplTable, $tmplNumber, $tmplTail ) = split( /%SPLIT%/, $tmpl );
    $tmplHead = handleCommonTags( $tmplHead, $topic );
    $tmplSearch = handleCommonTags( $tmplSearch, $topic );
    $tmplNumber = handleCommonTags( $tmplNumber, $topic );
    $tmplTail = handleCommonTags( $tmplTail, $topic );

    if( ! $tmplTail ) {
        print "<html><body>";
        print "<h1>TWiki Installation Error</h1>";
        print "Incorrect format of search.tmpl (missing %SPLIT% parts)";
        print "</body></html>";
        return;
    }

    if( ! $doInline ) {
        # print first part of full HTML page
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
            print $tmplSearch;
        }
    }

    if( $theScope eq "topic" ) {
        $cmd = "$wiki::lsCmd *.txt | %GREP% %SWITCHES% '$theSearchVal'";
    } else {
        $cmd = "%GREP% %SWITCHES% -l '$theSearchVal' *.txt";
    }

    if( $caseSensitive ) {
        $tempVal = "";
    } else {
        $tempVal = "-i";
    }
    $cmd =~ s/%SWITCHES%/$tempVal/go;

    if( $theRegex ) {
        $tempVal = $wiki::egrepCmd;
    } else {
        $tempVal = $wiki::fgrepCmd;
    }
    $cmd =~ s/%GREP%/$tempVal/go;

    ## #############
    ## 0501 kk : vvv New web processing loop, does what the old straight
    ##               code did for each web the user requested.  Note that
    ##               '$theWebName' is mostly replaced by '$thisWebName'

    foreach my $thisWebName (@webList) {

        next unless webExists($thisWebName);  # can't process what ain't thar

        # make white the default
        my $thisWebBGColor = getPrefsValue( "WEBBGCOLOR" ) || "\#FF00FF";

        # this sucks, but it works for now -- brittle overkill
        # read the prefs topic for this web to get web specific settings.

        ## #############
        ## 0605 kk : vvv Made the match code more forgiving.
        # get $thisWebName 's color
	my $bar = &readWebTopic( $thisWebName, $webPrefsTopicname);
        $bar =~ /(WEBBGCOLOR\s*\=\s*)(\S+)/o;

        $thisWebBGColor = $2 ;

        # make sure we can report this web on an 'all' search
        my $tf = ( $bar =~ /(NOSEARCHALL\s*\=\s*)([Oo][Nn])/o );

        next if $searchAllFlag and $tf; # DON'T filter out unless it's
                                        # part of an 'all' search.

        (my $baz = "foo") =~ s/foo//;  # reset search vars. defensive coding

        ## #############
        ## 0501 kk : vvv Moved from search
        ## 20000517 pth : reverted to old behaviour,
        ##                e.g. do not log inline search
        if( ( $wiki::doLogTopicSearch ) && ( ! $doInline ) ) {
            # write log entry
            &wiki::writeLog( "search", $thisWebName, $theSearchVal );
        }
        ## 0501 kk : ^^^
        ## ##############

        ## 0501 kjk : vvv New var for accessing web dirs.
        # TODO  vvv  do the Right Thing to untaint, current method sucks.      
        my $sDir = "$dataDir/$thisWebName"; # lousy insecure way to remove
                                            # the taint.
        $sDir =~ m/(.+)/;                   #
        $sDir = $1;                         #

        my @topicList = "";
        if( $theSearchVal ) {
            # do grep search
            chdir( "$sDir" );
            $cmd =~ /(.*)/;
            $cmd = $1;       # untaint variable (NOTE: Needs a better check!)
            $tempVal = `$cmd`;
            @topicList = split( /\n/, $tempVal );
            # cut .txt extension
            @topicList = map { /(.*)\.txt$/; $_ = $1; } @topicList;
        }

        my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );
        $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/o;
        $beforeText =~ s/%WEB%/$thisWebName/o;
        $beforeText = handleCommonTags( $beforeText, $topic );
        $afterText = handleCommonTags( $afterText, $topic );

        if( $doInline ) {
            $searchResult .= $beforeText;
        } else {
            print $beforeText;
        }

        $lasttopic = "";
        $ntopics = 0;
        my (@unsorted, @sorted);  ## 0501 kk : <<< new vars
        foreach( @topicList ) {
            $filename = $_;
            if( $filename ne $lasttopic) {
                my $skey = "";  ## 0501 kk : <<< new
                my ( $revdate, $revuser ) = getRevisionInfo( $filename, "", 1, $thisWebName );
                $revuser = userToWikiName( $revuser );

                $tempVal = $repeatText;
                $tempVal =~ s/%WEB%/$thisWebName/go;
                $tempVal =~ s/%TOPICNAME%/$filename/go;
                $tempVal =~ s/%TIME%/$revdate/go;
                $tempVal =~ s/%AUTHOR%/$revuser/go;
                $tempVal = handleCommonTags( $tempVal, $filename );
	        $tempVal = getRenderedVersion( $tempVal );

                if( $noSummary ) {
                    $tempVal =~ s/%TEXTHEAD%//go;
                    $tempVal =~ s/&nbsp;//go;
                } elsif( $doBookView ) {  # added PTh 20 Jul 2000
                    $head = readFile( "$dataDir\/$thisWebName\/$filename.txt" );
                    $head = handleCommonTags( $head, $filename, $thisWebName );
                    $head = getRenderedVersion( $head, $thisWebName );
                    $tempVal =~ s/%TEXTHEAD%/$head/go;
                } else {
                    $head = readFileHead( "$dataDir\/$thisWebName\/$filename.txt", 12 );
                    $head =~ s/<[^>]*>//go;         # remove all HTML tags
                    $head =~ s/[\*\|=_]/ /go;       # remove all Wiki formatting
                    $head =~ s/%INCLUDE[^%]*%/ /go; # remove server side includes
                    $head =~ s/%SEARCH[^%]*%/ /go;  # remove inline search
                    $head =~ s/\n/ /go;
                    $head = handleCommonTags( $head, $filename );
                    $head =~ s/(.{162})([a-zA-Z0-9]*)(.*?)$/$1$2 \.\.\./go;
                    $tempVal =~ s/%TEXTHEAD%/$head/go;
                }

## 0501 kk : vvv Can't do this here if we want to sort, we'll have to iterate
##               over the sorted values after we get them.
#
#            if( $doInline ) {
#                $searchResult .= $tempVal;
#            } else {
#                print $tempVal;
#            }
##

               # Got the data, use a modified Schwartzian Transform to
               # sort.  First, save the key.

                if ($theOrder eq "date") {  # dates are tricky.
	            # $skey = (stat "$filename.txt")[9]; # not always accurate.
                    $skey = revDate2EpSecs($revdate);
                } elsif ($theOrder eq "editby") {
                    $skey = $revuser;
                } else {
                    $skey = $filename;
                }

                # Now add an anonymous array element to @unsorted. The
                # first anonymous element is the sort key, the next is
                # the data.

                $unsorted[$ntopics] = [ $skey, $tempVal ]; # end mod ---

                $lasttopic = $filename;
                $ntopics += 1;
	    }
        }

        # Finished gathering data, now sort it.  This is just the last
        # (first?) part of the Schwartzian Transform, see the Ram,
        # pg. 118.  The (ugly) twist here is the tests for numeric and
        # reverse-order sort.

        if (! $revSort) {
            if ($theOrder eq "date") {
                @sorted = map { $_->[1] }
	                  sort {$a->[0] <=> $b->[0] } @unsorted;
            } else {
                @sorted = map { $_->[1] }
	                  sort {$a->[0] cmp $b->[0] } @unsorted;
	    }
        } else {
            if ($theOrder eq "date") {
                @sorted = map { $_->[1] }
	                  sort {$b->[0] <=> $a->[0] } @unsorted;
            } else {
                @sorted = map { $_->[1] }
	                  sort {$b->[0] cmp $a->[0] } @unsorted;
    	    }
        }

        # Iterate back over the sorted data to get it into
        # $searchResult, but only as much as requested.

        my $thisLimit = $theLimit;
        if ($thisLimit ne "") { 
	    $thisLimit-- if $thisLimit > 0;                 # count from zero.
            $#sorted = $thisLimit if $thisLimit < $#sorted; # don't go nuts.
        }
    
        foreach my $dval (@sorted) {
            if( $doInline ) {
                $searchResult .= $dval;
            } else {
                print $dval;
            }
        }
    
        if( $doInline ) {
            $searchResult .= $afterText;
        } else {
            print $afterText;
        }

        if( ! $noTotal ) {
            # print "Number of topics:" part
            my $thisNumber = $tmplNumber;
            $thisNumber =~ s/%NTOPICS%/$ntopics/go;
            if( $doInline ) {
                $searchResult .= $thisNumber;
            } else {
                print $thisNumber;
            }
        }
    }
    if( ! $doInline ) {
        # print last part of full HTML page
        print $tmplTail;
    }
    return $searchResult;
}

