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

my $emptySearch =   "something.Very/unLikelyTo+search-for;-)";

=pod

---++ sub new ()

Constructor for the singleton Search engine object.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );

    assert(ref($session) eq "TWiki") if DEBUG;
    $this->{session} = $session;

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

    #$this->writeDebug("unsafePlatform = $unsafePlatform");
    #$this->writeDebug("useFilterIn = $useFilterIn");

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
            # search only for the topic name, ignoring matching lines.
            # We will make a mess of reporting the matches later on.
            my $matches = $this->store()->searchInWebContent( $theWeb, $theType, $caseSensitive, 1, $token, \@topicList );
            @scopeTextList = keys %$matches;
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
to a function which takes =_cbdata= as the first parameter and
remaining parameters the same as "print".

If =_callback= is set, the result is always undef. Otherwise the
result is a string containing the rendered search results.

If =inline= is set, then the results are *not* decorated with
the search template head and tail blocks.

SMELL: If =format= is set, =template= will be ignored.

SMELL: If =regex= is defined, it will force type="regex"

SMELL: If =template= is defined neither =bookview= nor =renameview= will work

=cut

sub searchWeb {
    my $this = shift;
    assert(ref($this) eq "TWiki::Search") if DEBUG;
    my %params = @_;
    my $callback =      $params{_callback};
    my $cbdata =        $params{_cbdata};
    my $baseTopic =     $params{basetopic} || $this->{session}->{topicName};
    my $baseWeb =       $params{baseweb}   || $this->{session}->{webName};
    my $doBookView =    $params{bookview} || "";
    my $caseSensitive = $params{casesensitive} || "";
    my $theExclude =    $params{excludetopic} || "";
    my $doExpandVars =  $params{expandvariables} || "";
    my $theFormat =     $params{format} || "";
    my $theHeader =     $params{header} || "";
    my $inline =        $params{inline};
    my $theLimit =      $params{limit} || "";
    my $doMultiple =    $params{multiple} || "";
    my $noEmpty =       $params{noempty} || "";
    my $noHeader =      $params{noheader} || "";
    my $noSearch =      $params{nosearch} || "";
    my $noSummary =     $params{nosummary} || "";
    my $noTotal =       $params{nototal} || "";
    my $newLine =       $params{newline} || "";
    my $theOrder =      $params{order} || "";
    my $theRegex =      $params{regex} || "";
    my $doRenameView =  $params{renameview} || ""; # undocumented
    my $revSort =       $params{reverse} || "";
    my $theScope =      $params{scope} || "";
    my $theSearchVal =  $params{search} || $emptySearch;
    my $theSeparator =  $params{separator};
    my $doShowLock =    $params{showlock} || "";
    my $theTemplate =   $params{template} || "";
    my $theTopic =      $params{topic} || "";
    my $theType =       $params{type} || "";
    my $theWebName =    $params{web} || "";

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
    if( defined( $theSeparator )) {
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
            # the web processing loop filters for valid web names,
            # so don't do it here.

            if( $web =~ /^(all|on)$/i  ) {
                # Get list of all webs
                my @tmpList = grep { ! /^_/ } $this->store()->getAllWebs();

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

    my $output = "";
    my $tmpl = "";
    my $topicCount = 0;

    my $originalSearch = $theSearchVal;
    my $spacedTopic;

    if( $theFormat ) {
        $theTemplate = "searchformat";
    } elsif( $theTemplate ) {
        # template definition overrides book and rename views
    } elsif( $doBookView ) {
        $theTemplate = "searchbookview";
    } elsif ($doRenameView ) {
        # Rename view, showing where topics refer to topic being renamed.
        $theTemplate = "searchbookview";

        # Create full search string from topic name that is passed in
        my $renameWeb = "";
        my $renameTopic = $theSearchVal;
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
        $theTemplate = "search";
    }
    $tmpl = $this->templates()->readTemplate( $theTemplate );

    # SMELL: the only META tags in a template will be METASEARCH
    # Why the heck are they being filtered????
    $tmpl =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

    # Split template into 5 sections
    my( $tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail ) =
      split( /%SPLIT%/, $tmpl );

    # Invalid template?
    if( ! $tmplTail ) {
        my $mess = "<html><body>" .
          "<h1>TWiki Installation Error</h1>" .
            "Incorrect format of $theTemplate template (missing sections? There should be 4 %SPLIT% tags.)" .
              "</body></html>";
        if ( defined $callback ) {
            &$callback( $cbdata, $mess );
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

        if( defined $callback ) {
            $tmplHead = $this->renderer()->getRenderedVersion( $tmplHead );
            $tmplHead =~ s|</*nop/*>||goi;   # remove <nop> tags
            &$callback( $cbdata, $tmplHead );
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
        if( defined $callback ) {
            $tmplSearch = $this->renderer()->getRenderedVersion( $tmplSearch );
            $tmplSearch =~ s|</*nop/*>||goi;   # remove <nop> tag
            &$callback( $cbdata, $tmplSearch );
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
        my $t = join( ' ', @webList );
        $this->{session}->writeLog( "search", $t, $theSearchVal );
    }

    # Loop through webs
    foreach my $web ( @webList ) {
        $web =~ s/$TWiki::securityFilter//go;
        $web = TWiki::Sandbox::untaintUnchecked( $web );

        next unless $this->store()->webExists( $web );  # can't process what ain't thar

        my $thisWebNoSearchAll = $this->prefs()->getPreferencesValue( "NOSEARCHALL", $web );

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        # PTh 18 Aug 2000: Need to include if it is the current web
        next if (   ( $searchAllFlag )
                    && ( ( $thisWebNoSearchAll =~ /on/i ) || ( $web =~ /^[\.\_]/ ) )
                    && ( $web ne $this->{session}->{webName} ) );

        # Run the search on topics in this web
        my @topicList = $this->_searchTopicsInWeb( $web, $theTopic, $theScope, $theType, $caseSensitive, @tokens );

        # exclude topics, Codev.ExcludeWebTopicsFromSearch
        if( $caseSensitive ) {
            @topicList = grep( !/$theExclude/, @topicList ) if( $theExclude );
        } else {
            @topicList = grep( !/$theExclude/i, @topicList ) if( $theExclude );
        }
        next if( $noEmpty && ! @topicList ); # Nothing to show for this web

        my $topicInfo = {};

        # sort the topic list by date, author or topic name, and cache the
        # info extracted to do the sorting
        if( $theOrder eq "modified" ) {
            # Dates are tricky. For performance we do not read, say,
            # 2000 records of author/date, sort and then use only 50.
            # Rather we 
            #   * sort by approx time (to get a rough list)
            #   * shorten list to the limit + some slack
            #   * sort by rev date on shortened list to get the acurate list

            # Do performance exercise only if it pays off
            if(  $theLimit + 20 < scalar(@topicList) ) {
                # sort by approx latest rev time, Schwartzian Transform
                my @tmpList = ();
                if( $revSort ) {
                    @tmpList =
                      map { $_->[1] }
                        sort {$b->[0] <=> $a->[0] }
                          map { $this->store()->getTopicLatestRevTime( $web, $_ ) }
                            @topicList;
                } else {
                    @tmpList =
                      map { $_->[1] }
                        sort {$a->[0] <=> $b->[0] }
                          map { $this->store()->getTopicLatestRevTime( $web, $_ ) }
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

            $topicInfo = $this->_sortTopics( $web, \@topicList, $theOrder, $revSort );
        } elsif( $theOrder =~ /^creat/                     # sort by topic creation time
                 || $theOrder eq "editby"                  # sort by author
                 || $theOrder =~ s/^formfield\((.*)\)$/$1/ # sort by TWikiForm field
               ) {
            $topicInfo = $this->_sortTopics( $web, \@topicList, $theOrder, $revSort );
        } else {
            # simple sort, suggested by RaymondLutz in Codev.SchwartzianTransformMisused
            # note no extraction of topic info here, as not needed for the sort. Instead it
            # will be read lazily, later on.
            ##$this->writeDebug "Topic list before sort = @topicList";
            if( $revSort ) {
                @topicList = sort {$b cmp $a} @topicList;
            } else {
                @topicList = sort {$a cmp $b} @topicList;
            }
            ##$this->writeDebug "Topic list after sort = @topicList";
        }

        # header and footer of $web
        my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );
        if( $theHeader ) {
            $theHeader =~ s/\$n\(\)/\n/gos;          # expand "$n()" to new line
            $theHeader =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos; # expand "$n" to new line
            $beforeText = $theHeader;
            $beforeText =~ s/\$web/$web/gos;
            if( defined( $theSeparator )) {
                $beforeText .= $theSeparator;
            } else {
                $beforeText =~ s/([^\n])$/$1\n/os;  # add new line at end if needed
            }
        }

        # output the list of topics in $web
        my $ntopics = 0;
        my $headerDone = 0;
        foreach my $topic ( @topicList ) {
            my $forceRendering = 0;

            unless( exists( $topicInfo->{$topic} ) ) {
                # not previously cached
                $topicInfo->{$topic} =
                  $this->_extractTopicInfo( $web, $topic, 1, 0, undef );
            }
            my $revDate = TWiki::formatTime( $topicInfo->{$topic}->{modified} );
            my $revUser = $topicInfo->{$topic}->{editby};
            my $revNum  = $topicInfo->{$topic}->{revNum};

            # Check security
            # FIXME - how do we deal with user login not being available if
            # coming from search script?
            my $allowView = $topicInfo->{$topic}->{allowView};
            next unless $allowView;

            my $locked = "";
            if( $doShowLock ) {
                my ( $l ) =
                  $this->store()->topicIsLockedBy( $web, $topic );
                if( $l ) {
                    $revUser = $this->users()->userToWikiName( $l );
                    $locked = "(LOCKED)";
                }
            }

            my ( $meta, $text );

            # Special handling for format="..."
            if( $theFormat ) {
                ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic );

                if( $doExpandVars ) {
                    if( "$web.$topic" eq "$baseWeb.$baseTopic" ) {
                        # primitive way to prevent recursion
                        $text =~ s/%SEARCH/%<nop>SEARCH/g;
                    }
                    $text = $this->{session}->handleCommonTags( $text, $topic, $web );
                }
            }

            my @multipleHitLines = ();
            if( $doMultiple ) {
                my $pattern = $tokens[$#tokens]; # last token in an AND search
                $pattern = quotemeta( $pattern ) if( $theType ne "regex" );
                ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic ) unless $text;
                if( $caseSensitive ) {
                    @multipleHitLines = reverse grep { /$pattern/ } split( /[\n\r]+/, $text );
                } else {
                    @multipleHitLines = reverse grep { /$pattern/i } split( /[\n\r]+/, $text );
                }
            }

            do {    # multiple=on loop

                my $out = "";

                $text = pop( @multipleHitLines ) if( scalar( @multipleHitLines ) );

                if( $theFormat ) {
                    $out = $theFormat;
                    $out =~ s/\$web/$web/gos;
                    $out =~ s/\$topic\(([^\)]*)\)/breakName( $topic, $1 )/geos;
                    $out =~ s/\$topic/$topic/gos;
                    $out =~ s/\$locked/$locked/gos;
                    $out =~ s/\$date/$revDate/gos;
                    $out =~ s/\$isodate/&revDate2ISO($revDate)/geos;
                    $out =~ s/\$rev/$revNum/gos;
                    $out =~ s/\$wikiusername/$revUser/gos;
                    $out =~ s/\$wikiname/wikiName($revUser)/geos;
                    $out =~ s/\$username/$this->users()->wikiToUserName($revUser)/geos;
                    my $r1info = {};
                    $out =~ s/\$createdate/$this->_getRev1Info( $web, $topic, "date", $r1info )/geos;
                    $out =~ s/\$createusername/$this->_getRev1Info( $web, $topic, "username", $r1info )/geos;
                    $out =~ s/\$createwikiname/$this->_getRev1Info( $web, $topic, "wikiname", $r1info )/geos;
                    $out =~ s/\$createwikiusername/$this->_getRev1Info( $web, $topic, "wikiusername", $r1info )/geos;
                    if( $out =~ m/\$text/ ) {
                        ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic ) unless $text;
                        if( $topic eq $this->{session}->{topicName} ) {
                            # defuse SEARCH in current topic to prevent loop
                            $text =~ s/%SEARCH{.*?}%/SEARCH{...}/go;
                        }
                        $out =~ s/\$text/$text/gos;
                        $forceRendering = 1 unless( $doMultiple );
                    }
                } else {
                    $out = $repeatText;
                }
                $out =~ s/%WEB%/$web/go;
                $out =~ s/%TOPICNAME%/$topic/go;
                $out =~ s/%LOCKED%/$locked/o;
                $out =~ s/%TIME%/$revDate/o;
                my $revNumText;
                if( $revNum > 1 ) {
                    $revNumText = $revNum;
                } else {
                    $revNumText = "<span class=\"twikiNew\"><b>NEW</b></span>";
                }
                $out =~ s/%REVISION%/$revNumText/o;
                $out =~ s/%AUTHOR%/$revUser/o;

                if( ( $inline || $theFormat ) && ( ! ( $forceRendering ) ) ) {
                    # do nothing
                } else {
                    # don't callback yet because of table
                    # rendering
                    $out = $this->{session}->handleCommonTags( $out, $topic );
                    $out = $this->renderer()->getRenderedVersion( $out );
                }

                if( $doRenameView ) {
                    # Permission check done below, so force this read to succeed with "internal" parameter
                    my $rawText = $this->store()->readTopicRaw( $this->{session}->{wikiUserName}, $web, $topic, undef, 1 );
                    my $changeable = "";
                    my $changeAccessOK =
                      $this->security()->checkAccessPermission( "change",
                                                                $this->{session}->{wikiUserName},
                                                                $text, $topic,
                                                                $web );
                    if( ! $changeAccessOK ) {
                        $changeable = "(NO CHANGE PERMISSION)";
                        $out =~ s/%SELECTION%.*%SELECTION%//o;
                    } else {
                        $out =~ s/%SELECTION%//go;
                    }
                    $out =~ s/%CHANGEABLE%/$changeable/o;

                    $out =~ s/%LABEL%/$doRenameView/go;
                    my $reducedOutput = "";
                    # Remove lines that don't contain the topic and highlight matched string
                    # SMELL: this would be better done using the full power of Store::searchWebContent
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
                    $out =~ s/%TOPIC_NUMBER%/$topicCount/go;
                    $out =~ s/%TEXTHEAD%/$reducedOutput/go;
                    next if ( ! $reducedOutput );
                } elsif( $doBookView ) {
                    # BookView
                    ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic ) unless $text;
                    if( "$web.$topic" eq "$baseWeb.$baseTopic" ) {
                        # primitive way to prevent recursion
                        $text =~ s/%SEARCH/%<nop>SEARCH/g;
                    }
                    $text = $this->{session}->handleCommonTags( $text, $topic, $web );
                    $text = $this->renderer()->getRenderedVersion( $text, $web );
                    # FIXME: What about meta data rendering?
                    $out =~ s/%TEXTHEAD%/$text/go;

                } elsif( $theFormat ) {
                    $out =~ s/\$summary\(([^\)]*)\)/$this->renderer()->makeTopicSummary( $text, $topic, $web, $1 )/geos;
                    $out =~ s/\$summary/$this->renderer()->makeTopicSummary( $text, $topic, $web )/geos;
                    $out =~ s/\$parent\(([^\)]*)\)/breakName( getMetaParent( $meta ), $1 )/geos;
                    $out =~ s/\$parent/getMetaParent( $meta )/geos;
                    $out =~ s/\$formfield\(\s*([^\)]*)\s*\)/getMetaFormField( $meta, $1 )/geos;
                    $out =~ s/\$formname/_getMetaFormName( $meta )/geos;
                    # FIXME: Allow all regex characters but escape them
                    $out =~ s/\$pattern\((.*?\s*\.\*)\)/getTextPattern( $text, $1 )/geos;
                    $out =~ s/\r?\n/$newLine/gos if( $newLine );
                    if( defined( $theSeparator ) ) {
                        $out .= $theSeparator;
                    } else {
                        $out =~ s/([^\n])$/$1\n/os;    # add new line at end if needed
                    }
                    $out =~ s/\$n\(\)/\n/gos;          # expand "$n()" to new line
                    $out =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos; # expand "$n" to new line
                    $out =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
                    $out =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
                    $out =~ s/\$percnt(\(\))?/\%/gos; # expand percent
                    $out =~ s/\$dollar(\(\))?/\$/gos; # expand dollar

                } elsif( $noSummary ) {
                    $out =~ s/%TEXTHEAD%//go;
                    $out =~ s/&nbsp;//go;

                } else {
                    # regular search view
                    ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic ) unless $text;
                    $text = $this->renderer()->makeTopicSummary( $text, $topic, $web );
                    $out =~ s/%TEXTHEAD%/$text/go;
                }

                # lazy output of header (only if needed for the first time)
                unless( $headerDone || $noHeader ) {
                    $headerDone = 1;
                    my $thisWebBGColor = $this->prefs()->getPreferencesValue( "WEBBGCOLOR", $web ) || "\#FF00FF";
                    $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
                    $beforeText =~ s/%WEB%/$web/go;
                    $beforeText = $this->{session}->handleCommonTags( $beforeText,
                                                                      $topic );
                    if ( defined $callback ) {
                        $beforeText =
                          $this->renderer()->getRenderedVersion( $beforeText,
                                                                 $web );
                        $beforeText =~ s|</*nop/*>||goi;   # remove <nop> tag
                        &$callback( $cbdata, $beforeText );
                    } else {
                        $searchResult .= $beforeText;
                    }
                }

                # output topic (or line if multiple=on)
                if( !( $inline || $theFormat )) {
                    $out =
                      $this->renderer()->getRenderedVersion( $out, $web );
                    $out =~ s|</*nop/*>||goi;   # remove <nop> tag
                }

                if ( defined $callback ) {
                    &$callback( $cbdata, $out );
                } else {
                    $searchResult .= $out;
                }

            } while( @multipleHitLines ); # multiple=on loop

            $ntopics += 1;
            last if( $ntopics >= $theLimit );
        } # end topic loop

        # output footer only if hits in web
        if( $ntopics ) {
            # output footer of $web
            $afterText  = $this->{session}->handleCommonTags( $afterText, $topic );
            if( $inline || $theFormat ) {
                $afterText =~ s/\n$//os;  # remove trailing new line
            }

            if ( defined $callback ) {
                $afterText = 
                  $this->renderer()->getRenderedVersion( $afterText,
                                                         $web );
                $afterText =~ s|</*nop/*>||goi;   # remove <nop> tag
                &$callback( $cbdata, $afterText );
            } else {
                $searchResult .= $afterText;
            }
        }

        # output number of topics (only if hits in web or if search only one web)
        if( $ntopics || @webList < 2 ) {
            unless( $noTotal ) {
                my $thisNumber = $tmplNumber;
                $thisNumber =~ s/%NTOPICS%/$ntopics/go;
                if ( defined $callback ) {
                    $thisNumber =
                      $this->renderer()->getRenderedVersion( $thisNumber,
                                                             $web );
                    $thisNumber =~ s|</*nop/*>||goi;   # remove <nop> tag
                    &$callback( $cbdata, $thisNumber );
                } else {
                    $searchResult .= $thisNumber;
                }
            }
        }

        # delete topic info to clear any cached data
        undef $topicInfo->{$topic};
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

        if( defined $callback ) {
            $tmplTail = $this->renderer()->getRenderedVersion( $tmplTail );
            $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
            &$callback( $cbdata, $tmplTail );
        } else {
            $searchResult .= $tmplTail;
        }
    }

    return undef if ( defined $callback );
    $searchResult = $this->{session}->handleCommonTags( $searchResult, $topic );
    $searchResult = $this->renderer()->getRenderedVersion( $searchResult );
#    $searchResult =~ s|</*nop/*>||goi;   # remove <nop> tag
    return $searchResult;
}

# extract topic info required for sorting and sort.
sub _sortTopics{
    my ( $this, $web, $topics, $sortfield, $revSort ) = @_;

    my $topicInfo = {};

    foreach my $topic ( @$topics ) {
        $topicInfo->{$topic} = $this->_extractTopicInfo( $web, $topic, $sortfield );
    }

    if( $revSort ) {
        @$topics = map { $_->[1] }
          sort {$b->[0] <=> $a->[0] }
            map { [ $topicInfo->{$_}->{$sortfield}, $_ ] }
              @$topics;
    } else {
        @$topics = map { $_->[1] }
          sort {$b->[0] <=> $a->[0] }
            map { [ $topicInfo->{$_}->{$sortfield}, $_ ] }
              @$topics;
    }

    return $topicInfo;
}

# extract topic info
sub _extractTopicInfo {
    my ( $this, $web, $topic, $cacheText, $sortfield ) = @_;
    my $info = {};

    my ( $meta, $text ) = $this->_getTextAndMeta( undef, $web, $topic );

    $info->{text} = $text;
    $info->{meta} = $meta;

    my ( $revdate, $revuser, $revnum ) = $meta->getRevisionInfo( $web, $topic );
    $info->{editby}     = $this->users()->userToWikiName( $revuser );
    $info->{modified}   = $revdate;
    $info->{revNum}     = $revnum;

    $info->{allowView} =
      $this->security()->
        checkAccessPermission( "view",
                               $this->{session}->{wikiUserName},
                               $text, $topic,
                               $web );

    if ( $sortfield =~ /^creat/ ) {
        ( $info->{$sortfield} ) = $this->store()->getRevisionInfo( $web, $topic, 1 );
    } elsif ( !defined( $info->{$sortfield} )) {
        $info->{$sortfield} = getMetaFormField( $meta, $sortfield );
    }

    return $info;
}

# get the text and meta for a topic
sub _getTextAndMeta {
    my( $this, $topicInfo, $web, $topic ) = @_;
    my ( $meta, $text );

    # read from cache if it's there
    if ( $topicInfo ) {
        $text = $topicInfo->{$topic}->{text};
        $meta = $topicInfo->{$topic}->{meta};
    }

    unless( defined $text ) {
        ( $meta, $text ) =
          $this->store()->readTopic( $this->{session}->{wikiUserName}, $web, $topic, undef, 1 );
        $text =~ s/%WEB%/$web/gos;
        $text =~ s/%TOPIC%/$topic/gos;
    }
    return ( $meta, $text );
}

=pod

---++ sub _getRev1Info( $theWeb, $theTopic, $theAttr, $info )

Returns the topic revision info of the base version,
attributes are "date", "username", "wikiname",
"wikiusername". Revision info is cached in the search
object for speed.

=cut

sub _getRev1Info {
    my( $this, $theWeb, $theTopic, $theAttr, $info ) = @_;
    my $key = "$theWeb.$theTopic";

    unless( $info->{webTopic} eq $key ) {
        my ( $d, $u ) =
          $this->store()->getRevisionInfo( $theWeb, $theTopic, 1 );
        $info->{date} = $d;
        $info->{user} = $u;
    }
    if( $theAttr eq "username" ) {
        return $info->{user};
    }
    if( $theAttr eq "wikiname" ) {
        return $this->users()->userToWikiName( $info->{user}, 1 );
    }
    if( $theAttr eq "wikiusername" ) {
        return $this->users()->userToWikiName( $info->{user} );
    }
    if( $theAttr eq "date" ) {
        return &TWiki::formatTime( $info->{date} );
    }

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
