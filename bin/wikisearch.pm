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


# =========================
sub searchWikiWeb
{
    my ( $doInline, $theWebName, $theSearchVal, $theScope, $theRegex,
         $caseSensitive, $noSummary, $noSearch, $noTotal ) = @_;

    my $searchResult = "";

    if( ! $theWebName ) {
        $theWebName = $wiki::webName;
    }

    my $tempVal = "";
    my $tmpl = readTemplate( "search" );
    my( $tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail ) = split( /%SPLIT%/, $tmpl );
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

    if( $theScope eq "topic" ) {
        $cmd = "ls *.txt | %GREP% %SWITCHES% '$theSearchVal'";
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
        $tempVal = "egrep";
    } else {
        $tempVal = "fgrep";
    }
    $cmd =~ s/%GREP%/$tempVal/go;

    my $topicList = "";
    if( $theSearchVal ) {
        # do grep search
        $topicList = `cd $dataDir/$theWebName;$cmd`;
        $topicList =~ s/\.txt//go;
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

    my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );
    $beforeText = handleCommonTags( $beforeText, $topic );
    $afterText = handleCommonTags( $afterText, $topic );

    if( $doInline ) {
        $searchResult .= $beforeText;
    } else {
        print $beforeText;
    }

    $lasttopic = "";
    $ntopics = 0;
    foreach( split( /\n/, $topicList ) ) {
        $filename = $_;
        if( $filename ne $lasttopic) {
            my ( $revdate, $revuser ) = getRevisionInfo( $filename, "", 1, $theWebName );
            $revuser = userToWikiName( $revuser );

            $tempVal = $repeatText;
            $tempVal =~ s/%WEB%/$theWebName/go;
            $tempVal =~ s/%TOPICNAME%/$filename/go;
            $tempVal =~ s/%TIME%/$revdate/go;
            $tempVal =~ s/%AUTHOR%/$revuser/go;
            $tempVal = handleCommonTags( $tempVal, $filename );
	    $tempVal = getRenderedVersion( $tempVal );

            if( $noSummary ) {
                $tempVal =~ s/%TEXTHEAD%//go;
                $tempVal =~ s/&nbsp;//go;
            } else {
                $head = readFileHead( "$dataDir\/$theWebName\/$filename.txt", 12 );
                $head =~ s/<[^>]*>//go;         # remove all HTML tags
                $head =~ s/[\*\|=_]/ /go;       # remove all Wiki formatting
                $head =~ s/%INCLUDE[^%]*%/ /go; # remove server side includes
                $head =~ s/%SEARCH[^%]*%/ /go;  # remove inline search
                $head =~ s/\n/ /go;
                $head = handleCommonTags( $head, $filename );
                $head =~ s/(.{162})([a-zA-Z0-9]*)(.*?)$/$1$2 \.\.\./go;
                $tempVal =~ s/%TEXTHEAD%/$head/go;
            }
            if( $doInline ) {
                $searchResult .= $tempVal;
            } else {
                print $tempVal;
            }
            $lasttopic = $filename;
            $ntopics += 1;
        }
    }
    if( $doInline ) {
        $searchResult .= $afterText;
    } else {
        print $afterText;
    }

    if( ! $noTotal ) {
        # print "Number of topics:" part
        $tmplNumber =~ s/%NTOPICS%/$ntopics/go;
        if( $doInline ) {
            $searchResult .= $tmplNumber;
        } else {
            print $tmplNumber;
        }
    }

    if( ! $doInline ) {
        # print last part of full HTML page
        print $tmplTail;
    }
    return $searchResult;
}
