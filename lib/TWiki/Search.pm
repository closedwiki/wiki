# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Search engine of TWiki.
#
# Copyright (C) 2000-2004 Peter Thoeny, peter@thoeny.com
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

=begin twiki

---+ TWiki::Search Module

This module implements all the search functionality.

=cut

package TWiki::Search;

use strict;
use Assert;
use TWiki::Sandbox;

# 'Use locale' for internationalisation of Perl sorting and searching - 
# main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        eval 'require locale; import locale ();';
    }
}

=pod

---++ sub new ()

Constructor for the singleton Search engine object.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );

    assert(ref($session) eq "TWiki") if DEBUG;
    $this->{session} = $session;

    $this->{cacheRev1webTopic} = undef;
    $this->{cacheRev1date} = undef;
    $this->{cacheRev1user} = undef;

    return $this;
}

sub users { my $this = shift; return $this->{session}->{users}; }
sub store { my $this = shift; return $this->{session}->{store}; }
sub prefs { my $this = shift; return $this->{session}->{prefs}; }
sub sandbox { my $this = shift; return $this->{session}->{sandbox}; }
sub security { my $this = shift; return $this->{session}->{security}; }
sub templates { my $this = shift; return $this->{session}->{templates}; }
sub renderer { my $this = shift; return $this->{session}->{renderer}; }

sub writeDebug { my $this = shift; $this->{session}->writeDebug($_[0]); }

# ===========================

=pod

---++ sub _traceExec (  $cmd, $result  )

Normally writes no output, uncomment writeDebug line to get output of all external commands and chdirs to debug file

=cut

sub _traceExec
{
   my( $this, $cmd, $result ) = @_;
   
   $this->writeDebug( "Search exec: $cmd -> $result" );
}

=pod


---++ sub _filterSearchString ( $this, $searchString, $theType ) -> $searchString

Untaints the search value (text string, regex or search expression) by
'filtering in' valid characters only.

=cut

sub _filterSearchString {
    my $this = shift;
    my $searchString = shift;
    my $theType = shift;

    # Use filtering-out of regexes only if (1) on a safe sandbox platform
    # OR (2) administrator has explicitly configured $forceUnsafeRegexes == 1.
    #
    # Only well-secured intranet sites, authenticated for all access
    # (view, edit, attach, search, etc), AND forced to use unsafe
    # platforms, should use the $forceUnsafeRegexes flag.
    my $unsafePlatform = ( not ($this->sandbox()->{SAFE} ) );

    # FIXME: Use of new global
    my $useFilterIn = ($unsafePlatform and not $TWiki::forceUnsafeRegexes);

    $this->writeDebug("unsafePlatform = $unsafePlatform");
    $this->writeDebug("useFilterIn = $useFilterIn");

    # Non-alphabetic language sites (e.g. Japanese and Chinese) cannot use
    # filtering-in and must use safe pipes, since TWiki does not currently
    # support Unicode, required for filtering-in.  Alphabetic languages such
    # as English, French, Russian, Greek and most European languages are
    # handled by filtering-in.
    if ( not $TWiki::langAlphabetic and $unsafePlatform ) {
        # Best option is to upgrade Perl.
        die "You are using a non-alphabetic language on a non-safe-pipes platform.  This is a serious SECURITY RISK,\nso TWiki cannot be used as it is currently installed - please\nread TWiki:Codev/SafePipes for options to avoid or remove this risk.";
    }

    my $mixedAlphaNum = $TWiki::regex{mixedAlphaNum};

    my $validChars;            # String of valid characters or POSIX
                               # regex elements (e.g. [:alpha:] from 
                               # _setupRegexes) - designed to
                               # be used within a character class.

    if( $theType eq "regex" ) {
        # Regular expression search - example: soap;wsdl;web service;!shampoo;[Ff]red
        if ( $useFilterIn ) {
            # Filter in
            $validChars = "${mixedAlphaNum} " . 
                    '!;' .      # TWiki search syntax 
                    '.[]\\*\\+';    # Limited regex syntax
        } else {
            # Filter out - only for use on safe pipe platform or
            # if forced by admin
            # FIXME: Review and test since first versions were broken
            # SMELL: CC commented out next two lines as they escape escape chars in REs
            #$searchString =~ s/(^|[^\\])(['"`\\])/$1\\$2/g;    # Escape all types of quotes and backslashes
            #$searchString =~ s/([\@\$])\(/$1\\\(/g;          # Escape @( ... ) and $( ... )
        }

    } elsif( $theType eq "literal" ) {
        # Filter in
        # Literal search - search for exactly what was typed in (old style TWiki non-regex search)
        $validChars = "${mixedAlphaNum} " . '\.';      # Alphanumeric, spaces, selected punctuation

    } else {
        # FIXME: spaces not working - url encoded in search pattern
        # Filter in
        # Keyword search (new style, Google-like). Example: soap +wsdl +"web service" -shampoo
        $validChars = "${mixedAlphaNum} +\"\-";   # Alphanumeric, spaces and search syntax 
    }

    if ( $useFilterIn ) {
        # Clean up - delete all invalid characters
        # FIXME: be sure to escape special characters in literal
        $searchString =~ s/[^${validChars}]+//go;
    }

    # Untaint - same for filtering in and out since already sanitised
    $searchString =~ /^(.*)$/;
    $searchString = $1;

    # Limit string length
    $searchString = substr($searchString, 0, 1500); 
}

=pod

---++ sub getTextPattern (  $theText, $thePattern  )

Sanitise search pattern - currently used for FormattedSearch only

=cut

sub getTextPattern
{
    my( $theText, $thePattern ) = @_;

    $thePattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/go;  # escape some special chars
    $thePattern = TWiki::Sandbox::untaintUnchecked( $thePattern );

    my $OK = 0;
    eval {
       $OK = ( $theText =~ s/$thePattern/$1/is );
    };
    $theText = "" unless( $OK );

    return $theText;
}


=pod

---++ sub _tokensFromSearchString ( $this, $theSearchVal, $theType  )

Split the search string into tokens depending on type of search.
Search is an 'AND' of all tokens - various syntaxes implemented
by this routine.

=cut

sub _tokensFromSearchString
{
    my( $this, $theSearchVal, $theType ) = @_;

    my @tokens = ();
    if( $theType eq "regex" ) {
        # Regular expression search Example: soap;wsdl;web service;!shampoo
        @tokens = split( /;/, $theSearchVal );

    } elsif( $theType eq "literal" ) {
        # Literal search (old style)
        $tokens[0] = $theSearchVal;

    } else {
        # Keyword search (Google-style) - implemented by converting
        # to regex format. Example: soap +wsdl +"web service" -shampoo

        # Prevent tokenizing on spaces in "literal string" 
        $theSearchVal =~ s/(\".*?)\"/&_translateSpace($1)/geo;  
        $theSearchVal =~ s/[\+\-]\s+//go;

        # Build pattern of stop words
        my $stopWords = $this->prefs()->getPreferencesValue( "SEARCHSTOPWORDS" ) || "";
        $stopWords =~ s/[\s\,]+/\|/go;
        $stopWords =~ s/[\(\)]//go;

        # Tokenize string taking account of literal strings, then remove
        # stop words and convert '+' and '-' syntax.
        @tokens =
            map { s/^\+//o; s/^\-/\!/o; s/^\"//o; $_ }    # remove +, change - to !, remove "
            grep { ! /^($stopWords)$/i }                  # remove stopwords
            map { s/$TWiki::TranslationToken/ /go; $_ }   # restore space
            split( /[\s]+/, $theSearchVal );              # split on spaces
    }

    return @tokens;
}

=pod

---++ sub _translateSpace (  $theText  )

Convert spaces into translation token characters (typically NULs),
preventing tokenization.  

FIXME: Terminology confusing here!

=cut

sub _translateSpace
{
    my( $theText ) = @_;
    $theText =~ s/\s+/$TWiki::TranslationToken/go;
    return $theText;
}


=pod

---++ sub _searchTopicsInWeb (  $theWeb, $theTopic, $theScope, $theType, $caseSensitive, @theTokens  )

Search a single web based on parameters - @theTokens is a list of search terms
to be ANDed together, $theTopic is list of one or more topics.  

Executes external command to do the search.

=cut

sub _searchTopicsInWeb
{
    my( $this, $theWeb, $theTopic, $theScope, $theType, $caseSensitive, @theTokens ) = @_;

    my @topicList = ();
    return @topicList unless( @theTokens );                        # bail out if no search string
    

    if( $theTopic ) {                                              # limit search to topic list
        if( $theTopic =~ /^\^\([$TWiki::regex{mixedAlphaNum}\|]+\)\$$/ ) { # topic list without wildcards
            my $topics = $theTopic;                                # for speed, do not get all topics in web
            $topics =~ s/^\^\(//o;                                 # but convert topic pattern into topic list
            $topics =~ s/\)\$//o;                                  #
            @topicList = split( /\|/, $topics );                   # build list from topic pattern
        } else {                                                   # topic list with wildcards
            @topicList = $this->store()->getTopicNames( $theWeb );                 # get all topics in web
            if( $caseSensitive ) {
                @topicList = grep( /$theTopic/, @topicList );      # limit by topic name,
            } else {                                               # Codev.SearchTopicNameAndTopicText
                @topicList = grep( /$theTopic/i, @topicList );
            }
        }
    } else {
        @topicList = $this->store()->getTopicNames( $theWeb );                     # get all topics in web
    }

    my $sDir = "$TWiki::dataDir/$theWeb";
    $theScope = "text" unless( $theScope =~ /^(topic|all)$/ );     # default scope is "text"

    # AND search - search once for each token, ANDing result together
    foreach my $token ( @theTokens ) {                             # search on each token
        my $invertSearch = ( $token =~ s/^\!//o );                 # flag for AND NOT search
        my @scopeTextList = ();
        my @scopeTopicList = ();
        return @topicList unless( @topicList );                    # bail out if no topics left

        # scope can be "topic" (default), "text" or "all"
        # scope="text", e.g. Perl search on topic name:
        unless( $theScope eq "text" ) {
            my $qtoken = $token;
            $qtoken = quotemeta( $qtoken ) if( $theType ne "regex" ); # FIXME I18N
            if( $caseSensitive ) {                                 # fix for Codev.SearchWithNoPipe
                @scopeTopicList = grep( /$qtoken/, @topicList );
            } else {
                @scopeTopicList = grep( /$qtoken/i, @topicList );
            }
        }

        # scope="text", e.g. grep search on topic text:
        unless( $theScope eq "topic" ) {
            # Construct command line with 'grep'.
            # I18N: 'grep' must use locales if needed,
            # for case-insensitive searching.  See TWiki::setupLocale.
            my $program = "";
            # FIXME: For Cygwin grep, do something about -E and -F switches
            # - best to strip off any switches after first space in
            # $egrepCmd etc and apply those as argument 1.
            if( $theType eq "regex" ) {
                $program = $TWiki::egrepCmd;
            } else {
                $program = $TWiki::fgrepCmd;
            }
            my $template = '';
            $template .= ' -i' unless( $caseSensitive );
            $template .= ' -l -- %TOKEN|U% %FILES|F%';

            if( $sDir ) {
                chdir( "$sDir" );
                $this->_traceExec( "chdir to $sDir", "" );
                $sDir = "";  # chdir only once
            }

            # process topics in sets, fix for Codev.ArgumentListIsTooLongForSearch
            my $maxTopicsInSet = 512;                      # max number of topics for a grep call
            my @take = @topicList;
            my @set = splice( @take, 0, $maxTopicsInSet );
            while( @set ) {
                @set = map { "$_.txt" } @set;              # add ".txt" extension to topic names
                @set =
                  $this->sandbox()->readFromProcessArray ($program, $template,
                                               TOKEN => $token,
                                               FILES => \@set);
                @set = map { $_ =~ s/\.txt$//; $_ } @set;  # cut ".txt" extension
                my %seen = ();
                foreach my $topic ( @set ) {
                    $seen{$topic}++;                     # make topics unique
                }
                push( @scopeTextList, sort keys %seen ); # add hits to found list
                @set = splice( @take, 0, $maxTopicsInSet );
            }
        }

        if( @scopeTextList && @scopeTopicList ) {
            push( @scopeTextList, @scopeTopicList );       # join "topic" and "text" lists
            my %seen = ();
            @scopeTextList = sort grep { ! $seen{$_} ++ } @scopeTextList;  # make topics unique
        } elsif( @scopeTopicList ) {
            @scopeTextList =  @scopeTopicList;
        }

        if( $invertSearch ) {                              # do AND NOT search
            my %seen = ();
            foreach my $topic ( @scopeTextList ) {
                $seen{$topic} = 1;
            }
            @scopeTextList = ();
            foreach my $topic ( @topicList ) {
                push( @scopeTextList, $topic ) unless( $seen{$topic} );
            }
        }
        @topicList = @scopeTextList;                               # reduced topic list for next token
    }
    return @topicList;
}

=pod

---++ sub _makeTopicPattern (  $theTopic  )

Not yet documented.

=cut

sub _makeTopicPattern
{
    my( $theTopic ) = @_ ;
    return "" unless( $theTopic );
    # "Web*, FooBar" ==> ( "Web*", "FooBar" ) ==> ( "Web.*", "FooBar" )
    my @arr = map { s/[^\*\_$TWiki::regex{mixedAlphaNum}]//go; s/\*/\.\*/go; $_ }
              split( /,\s*/, $theTopic );
    return "" unless( @arr );
    # ( "Web.*", "FooBar" ) ==> "^(Web.*|FooBar)$"
    return '^(' . join( "|", @arr ) . ')$';
}

=pod

---++ sub revDate2ISO ()

Not yet documented.

=cut

sub revDate2ISO
{
    my $epochSec = TWiki::Store::RcsFile::revDate2EpSecs( $_[0] );
    return &TWiki::formatTime( $epochSec, "\$iso", "gmtime");
}

=pod

---++ sub searchWeb (...)

Search one or more webs according to the parameters.

If =_callback= is set, that means the caller wants results as
soon as they are ready. =_callback_ should be set to a reference
to a function which takes identical parameters to "print".

If =_callback= is set, the result is always undef. Otherwise the
result is a string containing the rendered search results.

If =inline= is set, then the results are *not* decorated with
the search template head and tail blocks.

=cut

sub searchWeb {
    my $this = shift;
    assert(ref($this) eq "TWiki::Search") if DEBUG;
    my %params = @_;
    my $callback =      $params{_callback};
    my $inline =        $params{inline};
    my $baseWeb =       $params{"baseweb"}   || $this->{session}->{webName};
    my $baseTopic =     $params{"basetopic"} || $this->{session}->{topicName};
    my $emptySearch =   "something.Very/unLikelyTo+search-for;-)";
    my $theSearchVal =  $params{"search"} || $emptySearch;
    my $theWebName =    $params{"web"} || "";
    my $theTopic =      $params{"topic"} || "";
    my $theExclude =    $params{"excludetopic"} || "";
    my $theScope =      $params{"scope"} || "";
    my $theOrder =      $params{"order"} || "";
    my $theType =       $params{"type"} || "";
    my $theRegex =      $params{"regex"} || "";
    my $theLimit =      $params{"limit"} || "";
    my $revSort =       $params{"reverse"} || "";
    my $caseSensitive = $params{"casesensitive"} || "";
    my $noSummary =     $params{"nosummary"} || "";
    my $noSearch =      $params{"nosearch"} || "";
    my $noHeader =      $params{"noheader"} || "";
    my $noTotal =       $params{"nototal"} || "";
    my $doBookView =    $params{"bookview"} || "";
    my $doRenameView =  $params{"renameview"} || "";
    my $doShowLock =    $params{"showlock"} || "";
    my $doExpandVars =  $params{"expandvariables"} || "";
    my $noEmpty =       $params{"noempty"} || "";
    my $theTemplate =   $params{"template"} || "";
    my $theHeader =     $params{"header"} || "";
    my $theFormat =     $params{"format"} || "";
    my $doMultiple =    $params{"multiple"} || "";
    my $theSeparator =  $params{"separator"} || "";
    my $newLine =       $params{"newline"} || "";

    ##$this->writeDebug "Search locale is $TWiki::siteLocale";

    # Limit search results
    if ($theLimit =~ /(^\d+$)/o) { # only digits, all else is the same as
        $theLimit = $1;            # an empty string.  "+10" won't work.
    } else {
        $theLimit = 0;             # change "all" to 0, then to big number
    }
    if (! $theLimit ) {            # PTh 03 Nov 2000:
        $theLimit = 32000;         # Big number, needed for performance improvements
    }

    $theType = "regex" if( $theRegex );

    # Filter the search string for security and untaint it 
    $theSearchVal = $this->_filterSearchString( $theSearchVal, $theType );

    my $mixedAlpha = $TWiki::regex{mixedAlpha};
    if( $theSeparator ) {
        $theSeparator =~ s/\$n\(\)/\n/gos;  # expand "$n()" to new line
        $theSeparator =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }
    if( $newLine ) {
        $newLine =~ s/\$n\(\)/\n/gos;  # expand "$n()" to new line
        $newLine =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }

    my $searchResult = "";
    my $topic = $TWiki::mainTopicname;

    my @webList = ();

    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called "All".)
    my $searchAllFlag = ( $theWebName =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );

    # Search what webs?  "" current web, list gets the list, all gets
    # all (unless marked in WebPrefs as NOSEARCHALL) - build up list of
    # webs to be searched in @webList.
    if( $theWebName ) {
        foreach my $web ( split( /[\,\s]+/, $theWebName ) ) {
            # the web processing loop filters for valid web names, so don't do it here.

            if( $web =~ /^(all|on)$/i  ) {
                # Get list of all webs - first scan $dataDir
                opendir DIR, $TWiki::dataDir;
                my @tmpList = readdir(DIR);
                closedir(DIR);

                # Now get list of pathnames to web directories
                @tmpList = sort
                   grep { s#^.+/([^/]+)$#$1# }
                   grep { -d }
                   map  { "$TWiki::dataDir/$_" }
                   grep { ! /^[._]/ } @tmpList;

                   # what the above does (looking from the bottom up) is
                   # take the file list, filter out the dot directories and
                   # dot files, turn the list into full paths instead of
                   # just file names, filter out any non-directories, strip
                   # the path back off, and sort whatever was left after
                   # all that (which should be merely a list of directory's
                   # names.)

                # Build list of webs, without duplicates
                foreach my $aweb ( @tmpList ) {
                    push( @webList, $aweb ) unless( grep { /^$aweb$/ } @webList );
                }

            } else {
                push( @webList, $web ) unless( grep { /^$web$/ } @webList );
            }
        }

    } else {
        #default to current web
        push @webList, $this->{session}->{webName};
    }

    $theTopic   = _makeTopicPattern( $theTopic );    # E.g. "Bug*, *Patch" ==> "^(Bug.*|.*Patch)$"
    $theExclude = _makeTopicPattern( $theExclude );  # E.g. "Web*, FooBar" ==> "^(Web.*|FooBar)$"

    my $tempVal = "";
    my $tmpl = "";
    my $topicCount = 0; # JohnTalintyre

    my $originalSearch = $theSearchVal;
    my $renameTopic;
    my $renameWeb = "";
    my $spacedTopic;
    $theTemplate = "searchformat" if( $theFormat );     # FormattedSearch

    # Handle normal, book view and rename cases
    if( $theTemplate ) {
        $tmpl = $this->templates()->readTemplate( "$theTemplate" );
        # FIXME replace following with this @@@
    } elsif( $doBookView ) {
        $tmpl = $this->templates()->readTemplate( "searchbookview" );
    } elsif ($doRenameView ) {
	# Rename view, showing where topics refer to topic being renamed.
        $tmpl = $this->templates()->readTemplate( "searchrenameview" ); # JohnTalintyre

        # Create full search string from topic name that is passed in
        $renameTopic = $theSearchVal;
        if( $renameTopic =~ /(.*)\\\.(.*)/o ) {
            $renameWeb = $1;
            $renameTopic = $2;
        }
        $spacedTopic = TWiki::searchableTopic( $renameTopic );
        $spacedTopic = $renameWeb . '\.' . $spacedTopic if( $renameWeb );

	# I18N: match non-alpha before and after topic name in renameview searches
	# This regex must work under grep, i.e. if using Perl 5.6 or higher
	# the POSIX character classes will be used in grep as well.
        my $mixedAlphaNum = $TWiki::regex{mixedAlphaNum};
        $theSearchVal = "(^|[^${mixedAlphaNum}_])$theSearchVal" . 
			"([^${mixedAlphaNum}_]" . '|$)|' .
                        '(\[\[' . $spacedTopic . '\]\])';
    } else {
        $tmpl = $this->templates()->readTemplate( "search" );
    }

    $tmpl =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

    # Split template into 5 sections
    my( $tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail ) =
          split( /%SPLIT%/, $tmpl );

    # Invalid template?
    if( ! $tmplTail ) {
        my $mess = "<html><body>" .
          "<h1>TWiki Installation Error</h1>" .
            # Might not be search.tmpl FIXME
            "Incorrect format of search.tmpl (missing sections? There should be 4 %SPLIT% tags.)" .
              "</body></html>";
        if ( $callback ) {
            &$callback( $mess );
            return undef;
        } else {
            return $mess;
        }
    }

    # Expand tags in template sections
    $tmplSearch = $this->{session}->handleCommonTags( $tmplSearch, $topic );
    $tmplNumber = $this->{session}->handleCommonTags( $tmplNumber, $topic );

    # If not inline search, also expand tags in head and tail sections
    unless( $inline ) {
        $tmplHead = $this->{session}->handleCommonTags( $tmplHead, $topic );

        if( $callback) {
            $tmplHead = $this->renderer()->getRenderedVersion( $tmplHead );
            $tmplHead =~ s|</*nop/*>||goi;   # remove <nop> tags
            &$callback( $tmplHead );
        } else {
            # don't getRenderedVersion; this will be done by a single
            # call at the end.
            $searchResult .= $tmplHead;
        }
    }

    # Generate "Search:" part showing actual search string used
    unless( $noSearch ) {
        my $searchStr = $theSearchVal;
        $searchStr = "" if( $theSearchVal eq $emptySearch );
        $searchStr =~ s/&/&amp;/go;
        $searchStr =~ s/</&lt;/go;
        $searchStr =~ s/>/&gt;/go;
        $searchStr =~ s/^\.\*$/Index/go;
        $tmplSearch =~ s/%SEARCHSTRING%/$searchStr/go;
        if( $callback) {
            $tmplSearch = $this->renderer()->getRenderedVersion( $tmplSearch );
            $tmplSearch =~ s|</*nop/*>||goi;   # remove <nop> tag
            &$callback( $tmplSearch );
        } else {
            # don't getRenderedVersion; will be done later
            $searchResult .= $tmplSearch;
        }
    }

    # Split the search string into tokens depending on type of search -
    # each token is ANDed together by actual search
    my @tokens = $this->_tokensFromSearchString( $theSearchVal, $theType );

    # Write log entry
    # FIXME: Move log entry further down to log actual webs searched
    if( ( $TWiki::doLogTopicSearch ) && ( ! $inline ) ) {
        $tempVal = join( ' ', @webList );
        $this->{session}->writeLog( "search", $tempVal, $theSearchVal );
    }

    # Loop through webs
    foreach my $thisWebName ( @webList ) {
        $thisWebName =~ s/$TWiki::securityFilter//go;
        $thisWebName = TWiki::Sandbox::untaintUnchecked( $thisWebName );

        next unless $this->store()->webExists( $thisWebName );  # can't process what ain't thar

        my $thisWebBGColor = $this->prefs()->getPreferencesValue( "WEBBGCOLOR", $thisWebName ) || "\#FF00FF";
        my $thisWebNoSearchAll = $this->prefs()->getPreferencesValue( "NOSEARCHALL", $thisWebName );

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        # PTh 18 Aug 2000: Need to include if it is the current web
        next if (   ( $searchAllFlag )
                 && ( ( $thisWebNoSearchAll =~ /on/i ) || ( $thisWebName =~ /^[\.\_]/ ) )
                 && ( $thisWebName ne $this->{session}->{webName} ) );

        # Run the search on topics in this web
        my @topicList = $this->_searchTopicsInWeb( $thisWebName, $theTopic, $theScope, $theType, $caseSensitive, @tokens );

        # exclude topics, Codev.ExcludeWebTopicsFromSearch
        if( $caseSensitive ) {
            @topicList = grep( !/$theExclude/, @topicList ) if( $theExclude );
        } else {
            @topicList = grep( !/$theExclude/i, @topicList ) if( $theExclude );
        }
        next if( $noEmpty && ! @topicList ); # Nothing to show for this web

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
                $tempVal = $_;
                # Permission check done below, so force this read to succeed with "internal" parameter
                my( $meta, $text ) =
                  $this->store()->readTopic( $this->{session}->{wikiUserName}, $thisWebName, $tempVal, undef, 1 );
                my ( $revdate, $revuser, $revnum ) = $meta->getRevisionInfo( $thisWebName, $tempVal );
                $topicRevUser{ $tempVal }   = $this->users()->userToWikiName( $revuser );
                $topicRevDate{ $tempVal }   = $revdate;  # keep epoc sec for sorting
                $topicRevNum{ $tempVal }    = $revnum;
                $topicAllowView{ $tempVal } =
                  $this->security()->
                    checkAccessPermission( "view",
                                           $this->{session}->{wikiUserName},
                                           $text, $tempVal,
                                           $thisWebName );
            }

            # sort by date (second time if exercise), Schwartzian Transform
            my $dt = "";
            if( $revSort ) {
                @topicList = map { $_->[1] }
                             sort {$b->[0] <=> $a->[0] }
                             map { $dt = $topicRevDate{$_}; $topicRevDate{$_} = TWiki::formatTime( $dt ); [ $dt, $_ ] }
                             @topicList;
            } else {
                @topicList = map { $_->[1] }
                             sort {$a->[0] <=> $b->[0] }
                             map { $dt = $topicRevDate{$_}; $topicRevDate{$_} = TWiki::formatTime( $dt ); [ $dt, $_ ] }
                             @topicList;
            }

        } elsif( $theOrder =~ /^creat/ ) {
            # sort by topic creation time

            # first we need to build the hashes for modified date, author, creation time
            my %topicCreated = (); # keep only temporarily for sort
            foreach( @topicList ) {
                $tempVal = $_;
                # Permission check done below, so force this read to succeed with "internal" parameter
                my( $meta, $text ) =
                  $this->store()->readTopicRaw
                    ( $this->{session}->{wikiUserName},
                      $thisWebName, $tempVal, undef, 1 );
                my( $revdate, $revuser, $revnum ) = $meta->getRevisionInfo( $thisWebName, $tempVal );
                $topicRevUser{ $tempVal }   = $this->users()->userToWikiName( $revuser );
                $topicRevDate{ $tempVal }   = &TWiki::formatTime( $revdate );
                $topicRevNum{ $tempVal }    = $revnum;
                $topicAllowView{ $tempVal } =
                  $this->security()->checkAccessPermission( "view",
                                                           $this->{session}->{wikiUserName},
                                                           $text, $tempVal,
                                                           $thisWebName );
                my ( $createdate ) = $this->store()->getRevisionInfo( $thisWebName, $tempVal, 1 );
                $topicCreated{ $tempVal } = $createdate;  # Sortable epoc second format
            }

            # sort by creation time, Schwartzian Transform
            if( $revSort ) {
                @topicList = map { $_->[1] }
                             sort {$b->[0] <=> $a->[0] }
                             map { [ $topicCreated{$_}, $_ ] }
                             @topicList;
            } else {
                @topicList = map { $_->[1] }
                             sort {$a->[0] <=> $b->[0] }
                             map { [ $topicCreated{$_}, $_ ] }
                             @topicList;
            }

        } elsif( $theOrder eq "editby" ) {
            # sort by author

            # first we need to build the hashes for date and author
            foreach( @topicList ) {
                $tempVal = $_;
                # Permission check done below, so force this read to succeed with "internal" parameter
                my( $meta, $text ) =
                  $this->store()->readTopic( $this->{session}->{wikiUserName}, $thisWebName, $tempVal, undef, 1 );
                my( $revdate, $revuser, $revnum ) = $meta->getRevisionInfo( $thisWebName, $tempVal );
                $topicRevUser{ $tempVal }   = $this->users()->userToWikiName( $revuser );
                $topicRevDate{ $tempVal }   = &TWiki::formatTime( $revdate );
                $topicRevNum{ $tempVal }    = $revnum;
                $topicAllowView{ $tempVal } =
                  $this->security()->checkAccessPermission( "view",
                                                           $this->{session}->{wikiUserName},
                                                           $text, $tempVal,
                                                           $thisWebName );
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
                # Permission check done below, so force this read to succeed with "internal" parameter
                my( $meta, $text ) =
                  $this->store()->readTopic( $this->{session}->{wikiUserName}, $thisWebName, $tempVal, undef, 1 );
                my( $revdate, $revuser, $revnum ) = $meta->getRevisionInfo( $thisWebName, $tempVal );
                $topicRevUser{ $tempVal }   = $this->users()->userToWikiName( $revuser );
                $topicRevDate{ $tempVal }   = &TWiki::formatTime( $revdate );
                $topicRevNum{ $tempVal }    = $revnum;
                $topicAllowView{ $tempVal } =
                  $this->security()->checkAccessPermission( "view",
                                                           $this->{session}->{wikiUserName},
                                                           $text, $tempVal,
                                                           $thisWebName );
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
            # simple sort, suggested by RaymondLutz in Codev.SchwartzianTransformMisused
	    ##$this->writeDebug "Topic list before sort = @topicList";
            if( $revSort ) {
                @topicList = sort {$b cmp $a} @topicList;
            } else {
                @topicList = sort {$a cmp $b} @topicList;
            }
	    ##$this->writeDebug "Topic list after sort = @topicList";
        }

        # header and footer of $thisWebName
        my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );
        if( $theHeader ) {
            $theHeader =~ s/\$n\(\)/\n/gos;          # expand "$n()" to new line
           $theHeader =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos; # expand "$n" to new line
            $beforeText = $theHeader;
            $beforeText =~ s/\$web/$thisWebName/gos;
            if( $theSeparator ) {
                $beforeText .= $theSeparator;
            } else {
                $beforeText =~ s/([^\n])$/$1\n/os;  # add new line at end if needed
            }
        }

        # output the list of topics in $thisWebName
        my $ntopics = 0;
        my $headerDone = 0;
        my $topic = "";
        my $head = "";
        my $revDate = "";
        my $revUser = "";
        my $revNum = "";
        my $revNumText = "";
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
              ( $meta, $text ) =
                $this->store()->readTopic( $this->{session}->{wikiUserName}, $thisWebName, $topic, undef, 1 );
              $text =~ s/%WEB%/$thisWebName/gos;
              $text =~ s/%TOPIC%/$topic/gos;
              $allowView =
                $this->security()->checkAccessPermission( "view",
                                                         $this->{session}->{wikiUserName},
                                                         $text, $topic,
                                                         $thisWebName );
              ( $revDate, $revUser, $revNum ) = $meta->getRevisionInfo( $thisWebName, $topic );
              $revDate = &TWiki::formatTime( $revDate );
              $revUser = $this->users()->userToWikiName( $revUser );
          }

          $locked = "";
          if( $doShowLock ) {
              ( $tempVal ) =
                $this->store()->topicIsLockedBy( $thisWebName, $topic );
              if( $tempVal ) {
                  $revUser = $this->users()->userToWikiName( $tempVal );
                  $locked = "(LOCKED)";
              }
          }

          # Check security
          # FIXME - how do we deal with user login not being available if
          # coming from search script?
          if( ! $allowView ) {
              next;
          }

          # Special handling for format="..."
          if( $theFormat ) {
              unless( $text ) {
                  ( $meta, $text ) = $this->store()->readTopic( $this->{session}->{wikiUserName}, $thisWebName, $topic, undef, 1 );
                  $text =~ s/%WEB%/$thisWebName/gos;
                  $text =~ s/%TOPIC%/$topic/gos;
              }
              if( $doExpandVars ) {
                  if( "$thisWebName.$topic" eq "$baseWeb.$baseTopic" ) {
                      # primitive way to prevent recursion
                      $text =~ s/%SEARCH/%<nop>SEARCH/g;
                  }
                  $text = $this->{session}->handleCommonTags( $text, $topic, $thisWebName );
              }
          }

          my @multipleHitLines = ();
          if( $doMultiple ) {
              my $pattern = $tokens[$#tokens]; # last token in an AND search
              $pattern = quotemeta( $pattern ) if( $theType ne "regex" );
              ( $meta, $text ) = $this->store()->readTopic( $this->{session}->{wikiUserName}, $thisWebName, $topic, undef, 1 ) unless $text;
              if( $caseSensitive ) {
                  @multipleHitLines = reverse grep { /$pattern/ } split( /[\n\r]+/, $text );
              } else {
                  @multipleHitLines = reverse grep { /$pattern/i } split( /[\n\r]+/, $text );
              }
          }

          do {    # multiple=on loop

            $text = pop( @multipleHitLines ) if( scalar( @multipleHitLines ) );

            if( $theFormat ) {
                $tempVal = $theFormat;
                $tempVal =~ s/\$web/$thisWebName/gos;
                $tempVal =~ s/\$topic\(([^\)]*)\)/breakName( $topic, $1 )/geos;
                $tempVal =~ s/\$topic/$topic/gos;
                $tempVal =~ s/\$locked/$locked/gos;
                $tempVal =~ s/\$date/$revDate/gos;
                $tempVal =~ s/\$isodate/&revDate2ISO($revDate)/geos;
                $tempVal =~ s/\$rev/$revNum/gos;
                $tempVal =~ s/\$wikiusername/$revUser/gos;
                $tempVal =~ s/\$wikiname/wikiName($revUser)/geos;
                $tempVal =~ s/\$username/$this->users()->wikiToUserName($revUser)/geos;
                $tempVal =~ s/\$createdate/$this->_getRev1Info( $thisWebName, $topic, "date" )/geos;
                $tempVal =~ s/\$createusername/$this->_getRev1Info( $thisWebName, $topic, "username" )/geos;
                $tempVal =~ s/\$createwikiname/$this->_getRev1Info( $thisWebName, $topic, "wikiname" )/geos;
                $tempVal =~ s/\$createwikiusername/$this->_getRev1Info( $thisWebName, $topic, "wikiusername" )/geos;
                if( $tempVal =~ m/\$text/ ) {
                    # expand topic text
                    ( $meta, $text ) = $this->store()->readTopic( $this->{session}->{wikiUserName}, $thisWebName, $topic, undef, 1 ) unless $text;
                    if( $topic eq $this->{session}->{topicName} ) {
                        # defuse SEARCH in current topic to prevent loop
                        $text =~ s/%SEARCH{.*?}%/SEARCH{...}/go;
                    }
                    $tempVal =~ s/\$text/$text/gos;
                    $forceRendering = 1 unless( $doMultiple );
                }
            } else {
                $tempVal = $repeatText;
            }
            $tempVal =~ s/%WEB%/$thisWebName/go;
            $tempVal =~ s/%TOPICNAME%/$topic/go;
            $tempVal =~ s/%LOCKED%/$locked/o;
            $tempVal =~ s/%TIME%/$revDate/o;
            if( $revNum > 1 ) {
                $revNumText = $revNum;
            } else {
                $revNumText = "<span class=\"twikiNew\"><b>NEW</b></span>";
            }
            $tempVal =~ s/%REVISION%/$revNumText/o;
            $tempVal =~ s/%AUTHOR%/$revUser/o;

            if( ( $inline || $theFormat ) && ( ! ( $forceRendering ) ) ) {
                # do nothing
            } else {
                # don't callback yet because of table
                # rendering
                $tempVal = $this->{session}->handleCommonTags( $tempVal, $topic );
                $tempVal = $this->renderer()->getRenderedVersion( $tempVal );
            }

            if( $doRenameView ) { # added JET 19 Feb 2000
                # Permission check done below, so force this read to succeed with "internal" parameter
                my $rawText = $this->store()->readTopicRaw( $this->{session}->{wikiUserName}, $thisWebName, $topic, undef, 1 );
                my $changeable = "";
                my $changeAccessOK =
                  $this->security()->checkAccessPermission( "change",
                                                          $this->{session}->{wikiUserName},
                                                          $text, $topic,
                                                          $thisWebName );
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
		       # I18N: match non-alpha before and after topic name in renameview searches
		       my $mixedAlphaNum = $TWiki::regex{mixedAlphaNum};
                       my $match =  "(^|[^${mixedAlphaNum}_.])($originalSearch)(?=[^${mixedAlphaNum}]|\$)";
		       # NOTE: Must *not* use /o here, since $match is based on
		       # search string that will vary during lifetime of
		       # compiled code with mod_perl.
                       my $subs = s|$match|$1<font color="red"><span class="twikiAlert">$2</span></font>&nbsp;|g;
                       $match = '(\[\[)' . "($spacedTopic)" . '(?=\]\])';
                       $subs += s|$match|$1<font color="red"><span class="twikiAlert">$2</span></font>&nbsp;|gi;
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
                    ( $meta, $text ) =
                      $this->store()->readTopic( $this->{session}->{wikiUserName}, $thisWebName, $topic, undef, 1 );
                }
                if( "$thisWebName.$topic" eq "$baseWeb.$baseTopic" ) {
                    # primitive way to prevent recursion
                    $text =~ s/%SEARCH/%<nop>SEARCH/g;
                }
                $text = $this->{session}->handleCommonTags( $text, $topic, $thisWebName );
                $text = $this->renderer()->getRenderedVersion( $text, $thisWebName );
                # FIXME: What about meta data rendering?
                $tempVal =~ s/%TEXTHEAD%/$text/go;

            } elsif( $theFormat ) {
                # free format, added PTh 10 Oct 2001
                $tempVal =~ s/\$summary\(([^\)]*)\)/$this->renderer()->makeTopicSummary( $text, $topic, $thisWebName, $1 )/geos;
                $tempVal =~ s/\$summary/$this->renderer()->makeTopicSummary( $text, $topic, $thisWebName )/geos;
                $tempVal =~ s/\$parent\(([^\)]*)\)/breakName( getMetaParent( $meta ), $1 )/geos;
                $tempVal =~ s/\$parent/getMetaParent( $meta )/geos;
                $tempVal =~ s/\$formfield\(\s*([^\)]*)\s*\)/getMetaFormField( $meta, $1 )/geos;
                $tempVal =~ s/\$formname/_getMetaFormName( $meta )/geos;
                # FIXME: Allow all regex characters but escape them
                $tempVal =~ s/\$pattern\((.*?\s*\.\*)\)/getTextPattern( $text, $1 )/geos;
                $tempVal =~ s/\r?\n/$newLine/gos if( $newLine );
                if( $theSeparator ) {
                    $tempVal .= $theSeparator;
                } else {
                    $tempVal =~ s/([^\n])$/$1\n/os;    # add new line at end if needed
                }
                $tempVal =~ s/\$n\(\)/\n/gos;          # expand "$n()" to new line
                $tempVal =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos; # expand "$n" to new line
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
                    $head = $this->store()->readTopicRaw
                      ( $this->{session}->{wikiUserName},
                        $thisWebName, $topic, undef, 1
                      );
                }
                $head = $this->renderer()->makeTopicSummary( $head, $topic, $thisWebName );
                $tempVal =~ s/%TEXTHEAD%/$head/go;
            }

            # lazy output of header (only if needed for the first time)
            unless( $headerDone || $noHeader ) {
                $headerDone = 1;
                $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
                $beforeText =~ s/%WEB%/$thisWebName/go;
                $beforeText = $this->{session}->handleCommonTags( $beforeText,
                                                       $topic );
                if ( $callback) {
                    $beforeText =
                      $this->renderer()->getRenderedVersion( $beforeText,
                                                         $thisWebName );
                    $beforeText =~ s|</*nop/*>||goi;   # remove <nop> tag
                    &$callback( $beforeText );
                } else {
                    $searchResult .= $beforeText;
                }
            }

            # output topic (or line if multiple=on)
            if( !( $inline || $theFormat )) {
                $tempVal =
                  $this->renderer()->getRenderedVersion( $tempVal, $thisWebName );
                $tempVal =~ s|</*nop/*>||goi;   # remove <nop> tag
            }

            if ( $callback) {
                &$callback( $tempVal );
            } else {
                $searchResult .= $tempVal;
            }

          } while( @multipleHitLines ); # multiple=on loop

          $ntopics += 1;
          last if( $ntopics >= $theLimit );
        } # end topic loop in a web

        # output footer only if hits in web
        if( $ntopics ) {
            # output footer of $thisWebName
            $afterText  = $this->{session}->handleCommonTags( $afterText, $topic );
            if( $inline || $theFormat ) {
                $afterText =~ s/\n$//os;  # remove trailing new line
            }

            if ( $callback) {
                $afterText = 
                  $this->renderer()->getRenderedVersion( $afterText,
                                                     $thisWebName );
                $afterText =~ s|</*nop/*>||goi;   # remove <nop> tag
                &$callback( $afterText );
            } else {
                $searchResult .= $afterText;
            }
        }

        # output number of topics (only if hits in web or if search only one web)
        if( $ntopics || @webList < 2 ) {
            unless( $noTotal ) {
                my $thisNumber = $tmplNumber;
                $thisNumber =~ s/%NTOPICS%/$ntopics/go;
                if ( $callback) {
                    $thisNumber =
                      $this->renderer()->getRenderedVersion( $thisNumber,
                                                         $thisWebName );
                    $thisNumber =~ s|</*nop/*>||goi;   # remove <nop> tag
                    &$callback( $thisNumber );
                } else {
                    $searchResult .= $thisNumber;
                }
            }
        }
    }

    if( $theFormat ) {
        if( $theSeparator ) {
            $searchResult =~ s/$theSeparator$//s;  # remove separator at end
        } else {
            $searchResult =~ s/\n$//os;            # remove trailing new line
        }
    }

    unless( $inline ) {
        $tmplTail = $this->{session}->handleCommonTags( $tmplTail, $topic );

        if( $callback ) {
            $tmplTail = $this->renderer()->getRenderedVersion( $tmplTail );
            $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
            &$callback( $tmplTail );
        } else {
            $searchResult .= $tmplTail;
        }
    }

    return undef if ( $callback );
    $searchResult = $this->{session}->handleCommonTags( $searchResult, $topic );
    $searchResult = $this->renderer()->getRenderedVersion( $searchResult );
#    $searchResult =~ s|</*nop/*>||goi;   # remove <nop> tag
    return $searchResult;
}

=pod

---++ sub _getRev1Info( $theWeb, $theTopic, $theAttr )

Returns the topic revision info of the base version,
attributes are "date", "username", "wikiname",
"wikiusername". Revision info is cached for speed

=cut

sub _getRev1Info
{
    my( $this, $theWeb, $theTopic, $theAttr ) = @_;

    unless( $this->{cacheRev1webTopic} eq "$theWeb.$theTopic" ) {
        # refresh cache
        $this->{cacheRev1webTopic} = "$theWeb.$theTopic";
        my ( $d, $u ) =
          $this->store()->getRevisionInfo( $theWeb, $theTopic, 1 );
        $this->{cacheRev1date} = $d;
        $this->{cacheRev1user} = $u;
    }
    if( $theAttr eq "username" ) {
        return $this->{cacheRev1user};
    }
    if( $theAttr eq "wikiname" ) {
        return $this->users()->userToWikiName( $this->{cacheRev1user}, 1 );
    }
    if( $theAttr eq "wikiusername" ) {
        return $this->users()->userToWikiName( $this->{cacheRev1user} );
    }
    if( $theAttr eq "date" ) {
        return &TWiki::formatTime( $this->{cacheRev1date} );
    }
    # else assume attr "key"
    return 1;
}

#=========================
=pod

---++ sub getMetaParent( $theMeta )

Not yet documented.

=cut

sub getMetaParent
{
    my( $theMeta ) = @_;

    my $value = "";
    my %parent = $theMeta->findOne( "TOPICPARENT" );
    $value = $parent{"name"} if( %parent );
    return $value;
}

#=========================
=pod

---++ sub getMetaFormField (  $theMeta, $theParams  )

Not yet documented.

=cut

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
    my $value = "";
    my @fields = $theMeta->find( "FIELD" );
    foreach my $field ( @fields ) {
        $value = $field->{"value"};
        $value =~ s/^\s*(.*?)\s*$/$1/go;
        if( $name =~ /^($field->{"name"}|$field->{"title"})$/ ) {
            $value = breakName( $value, $break );
            return $value;
        }
    }
    return "";
}

#=========================
=pod

---++ sub _getMetaFormName (  $theMeta )

Returns the name of the form attached to the topic

=cut

sub _getMetaFormName
{
    my( $theMeta ) = @_;

    my %aForm = $theMeta->findOne( "FORM" );
    if( %aForm ) {
        return $aForm{"name"};
    }
    return "";
}

=pod

---++ sub wikiName (  $theWikiUserName  )

Not yet documented.

=cut

sub wikiName
{
    my( $theWikiUserName ) = @_;

    $theWikiUserName =~ s/^.*\.//o;
    return $theWikiUserName;
}

=pod

---++ sub breakName (  $theText, $theParams  )

Not yet documented.

=cut

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
            $theText =~ s/(.{$len})(.+)/$1.../s;

        } else {
            # split and hyphenate the topic like "ThisIsALo- ngTopic"
            $theText =~ s/(.{$len})/$1$sep/gs;
            $theText =~ s/$sep$//;
        }
    }
    return $theText;
}



#=========================

1;

# EOF
