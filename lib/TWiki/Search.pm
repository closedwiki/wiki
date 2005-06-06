# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::Search

This module implements all the search functionality.

=cut

package TWiki::Search;

use strict;
use Assert;
use TWiki::Sandbox;
use TWiki::User;
use TWiki::Time;

my $emptySearch =   "something.Very/unLikelyTo+search-for;-)";

=pod

---++ ClassMethod new ($session)

Constructor for the singleton Search engine object.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );

    # 'Use locale' for internationalisation of Perl sorting and searching - 
    # main locale settings are done in TWiki::setupLocale
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
    }

    ASSERT($session->isa( 'TWiki')) if DEBUG;
    $this->{session} = $session;

    return $this;
}

# Untaints the search value (text string, regex or search expression) by
# 'filtering in' valid characters only.
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
    my $unsafePlatform = ( not ($this->{session}->{sandbox}->{SAFE} ) );

    # FIXME: Use of new global
    my $useFilterIn = ($unsafePlatform and not $TWiki::cfg{ForceUnsafeRegexes});

    #$this->{session}->writeDebug("unsafePlatform = $unsafePlatform");
    #$this->{session}->writeDebug("useFilterIn = $useFilterIn");

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

    if( $theType eq 'regex' ) {
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

    } elsif( $theType eq 'literal' ) {
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

---++ StaticMethod getTextPattern (  $theText, $thePattern  )

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
    $theText = '' unless( $OK );

    return $theText;
}


# Split the search string into tokens depending on type of search.
# Search is an 'AND' of all tokens - various syntaxes implemented
# by this routine.
sub _tokensFromSearchString
{
    my( $this, $theSearchVal, $theType ) = @_;

    my @tokens = ();
    if( $theType eq 'regex' ) {
        # Regular expression search Example: soap;wsdl;web service;!shampoo
        @tokens = split( /;/, $theSearchVal );

    } elsif( $theType eq 'literal' ) {
        # Literal search (old style)
        $tokens[0] = $theSearchVal;

    } else {
        # Keyword search (Google-style) - implemented by converting
        # to regex format. Example: soap +wsdl +"web service" -shampoo

        # Prevent tokenizing on spaces in "literal string" 
        $theSearchVal =~ s/(\".*?)\"/&_translateSpace($1)/geo;  
        $theSearchVal =~ s/[\+\-]\s+//go;

        # Build pattern of stop words
        my $prefs = $this->{session}->{prefs};
        my $stopWords = $prefs->getPreferencesValue( 'SEARCHSTOPWORDS' ) || '';
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

# Convert spaces into translation token characters (typically NULs),
# preventing tokenization.
#
# FIXME: Terminology confusing here!
sub _translateSpace
{
    my( $theText ) = @_;
    $theText =~ s/\s+/$TWiki::TranslationToken/go;
    return $theText;
}


# Search a single web based on parameters - @theTokens is a list of search terms
# to be ANDed together, $theTopic is list of one or more topics.  
#
# Executes external command to do the search.
sub _searchTopicsInWeb
{
    my( $this, $theWeb, $theTopic, $theScope, $theType, $caseSensitive, @theTokens ) = @_;

    my @topicList = ();
    return @topicList unless( @theTokens );                        # bail out if no search string
    my $store = $this->{session}->{store};

    if( $theTopic ) {                                              # limit search to topic list
        if( $theTopic =~ /^\^\([$TWiki::regex{mixedAlphaNum}\|]+\)\$$/ ) { # topic list without wildcards
            my $topics = $theTopic;                                # for speed, do not get all topics in web
            $topics =~ s/^\^\(//o;                                 # but convert topic pattern into topic list
            $topics =~ s/\)\$//o;                                  #
            @topicList = split( /\|/, $topics );                   # build list from topic pattern
        } else {                                                   # topic list with wildcards
            @topicList = $store->getTopicNames( $theWeb );                 # get all topics in web
            if( $caseSensitive ) {
                @topicList = grep( /$theTopic/, @topicList );      # limit by topic name,
            } else {                                               # Codev.SearchTopicNameAndTopicText
                @topicList = grep( /$theTopic/i, @topicList );
            }
        }
    } else {
        @topicList = $store->getTopicNames( $theWeb );                     # get all topics in web
    }

    $theScope = 'text' unless( $theScope =~ /^(topic|all)$/ );     # default scope is 'text'

    # AND search - search once for each token, ANDing result together
    foreach my $token ( @theTokens ) {                             # search on each token
        my $invertSearch = ( $token =~ s/^\!//o );                 # flag for AND NOT search
        my @scopeTextList = ();
        my @scopeTopicList = ();
        return @topicList unless( @topicList );                    # bail out if no topics left

        # scope can be 'topic' (default), 'text' or "all"
        # scope='text', e.g. Perl search on topic name:
        unless( $theScope eq 'text' ) {
            my $qtoken = $token;
            $qtoken = quotemeta( $qtoken ) if( $theType ne 'regex' ); # FIXME I18N
            if( $caseSensitive ) {                                 # fix for Codev.SearchWithNoPipe
                @scopeTopicList = grep( /$qtoken/, @topicList );
            } else {
                @scopeTopicList = grep( /$qtoken/i, @topicList );
            }
        }

        # scope='text', e.g. grep search on topic text:
        unless( $theScope eq 'topic' ) {
            # search only for the topic name, ignoring matching lines.
            # We will make a mess of reporting the matches later on.
            my $matches = $store->searchInWebContent
              ( $token, $theWeb, \@topicList,
                { type => $theType, casesensitive => $caseSensitive,
                  files_without_match => 1 } );
            @scopeTextList = keys %$matches;
        }

        if( @scopeTextList && @scopeTopicList ) {
            push( @scopeTextList, @scopeTopicList );       # join 'topic' and 'text' lists
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

sub _makeTopicPattern
{
    my( $theTopic ) = @_ ;
    return '' unless( $theTopic );
    # 'Web*, FooBar' ==> ( 'Web*', 'FooBar' ) ==> ( 'Web.*', "FooBar" )
    my @arr = map { s/[^\*\_$TWiki::regex{mixedAlphaNum}]//go; s/\*/\.\*/go; $_ }
              split( /,\s*/, $theTopic );
    return '' unless( @arr );
    # ( 'Web.*', 'FooBar' ) ==> "^(Web.*|FooBar)$"
    return '^(' . join( "|", @arr ) . ')$';
}

=pod

---++ ObjectMethod searchWeb (...)

Search one or more webs according to the parameters.

If =_callback= is set, that means the caller wants results as
soon as they are ready. =_callback_ should be set to a reference
to a function which takes =_cbdata= as the first parameter and
remaining parameters the same as 'print'.

If =_callback= is set, the result is always undef. Otherwise the
result is a string containing the rendered search results.

If =inline= is set, then the results are *not* decorated with
the search template head and tail blocks.

SMELL: If =format= is set, =template= will be ignored.

SMELL: If =regex= is defined, it will force type='regex'

SMELL: If =template= is defined =bookview= will not work

=cut

sub searchWeb {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Search')) if DEBUG;
    my %params = @_;
    my $callback =      $params{_callback};
    my $cbdata =        $params{_cbdata};
    my $baseTopic =     $params{basetopic} || $this->{session}->{topicName};
    my $baseWeb =       $params{baseweb}   || $this->{session}->{webName};
    my $doBookView =    TWiki::isTrue( $params{bookview} );
    my $caseSensitive = TWiki::isTrue( $params{casesensitive} );
    my $theExclude =    $params{excludetopic} || '';
    my $doExpandVars =  TWiki::isTrue( $params{expandvariables} );
    my $theFormat =     $params{format} || '';
    my $theHeader =     $params{header} || '';
    my $inline =        $params{inline};
    my $theLimit =      $params{limit} || '';
    my $doMultiple =    TWiki::isTrue( $params{multiple} );
    my $nonoise =       TWiki::isTrue( $params{nonoise} );
    my $noEmpty =       TWiki::isTrue( $params{noempty}, $nonoise );
    my $noHeader =      TWiki::isTrue( $params{noheader}, $nonoise );
    my $noSearch =      TWiki::isTrue( $params{nosearch}, $nonoise );
    my $noSummary =     TWiki::isTrue( $params{nosummary}, $nonoise );
    my $noZeroResults = TWiki::isTrue( $params{nozeroresults}, $nonoise );
    my $noTotal =       TWiki::isTrue( $params{nototal}, $nonoise );
    my $newLine =       $params{newline} || '';
    my $theOrder =      $params{order} || '';
    my $theRegex =      $params{regex} || '';
    my $revSort =       TWiki::isTrue( $params{reverse} );
    my $theScope =      $params{scope} || '';
    my $theSearchVal =  $params{search} || $emptySearch;
    my $theSeparator =  $params{separator};
    my $theTemplate =   $params{template} || '';
    my $theTopic =      $params{topic} || '';
    my $theType =       $params{type} || '';
    my $theWebName =    $params{web} || '';
    my $theDate =       $params{date} || "";
    my $finalTerm =     ($inline)?($params{"nofinalnewline"} || 0):0;

    my $session = $this->{session};
    my $renderer = $session->{renderer};

    ##$session->writeDebug "Search locale is $TWiki::cfg{SiteLocale}";

    # Limit search results
    if ($theLimit =~ /(^\d+$)/o) { # only digits, all else is the same as
        $theLimit = $1;            # an empty string.  "+10" won't work.
    } else {
        $theLimit = 0;             # change 'all' to 0, then to big number
    }
    if (! $theLimit ) {            # PTh 03 Nov 2000:
        $theLimit = 32000;         # Big number, needed for performance improvements
    }

    $theType = 'regex' if( $theRegex );

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

    my $searchResult = '';
    my $homeWeb = $session->{webName};
    my $homeTopic = $TWiki::cfg{HomeTopicName};
    my $store = $session->{store};

    my @webList = ();
    my @excludedWebList = (); # temporary stores the webs to be excluded from search
    
    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called 'All'.)
    my $searchAllFlag = ( $theWebName =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );

    # Search what webs?  '' current web, list gets the list, all gets
    # all (unless marked in WebPrefs as NOSEARCHALL) - build up list of
    # webs to be searched in @webList.
    if( $theWebName ) {
        foreach my $web ( split( /[\,\s]+/, $theWebName ) ) {
            # the web processing loop filters for valid web names,
            # so don't do it here.
            
            # check if web is excluded - store and remove it later from the webs list 
            if ( $web =~ /^-/i ) {
               $web =~ s/^-//; # removes minus character from name
                push ( @excludedWebList, $web );
                next;
            }
            
            if( $web =~ /^(all|on)$/i  ) {
                # Get list of all webs
                my @tmpList = $store->getListOfWebs( 'user' );

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
        push @webList, $session->{webName};
    }
    
    # Remove exluded webs from the web list
    if ( @excludedWebList ) {        
        foreach my $excludeWeb ( @excludedWebList ) {
            my $i = 0;
            foreach my $web ( @webList ) {
                if( $web eq $excludeWeb ) {
                    splice (@webList, $i, 1);
                    next;
                }
                $i++;
            }
        }
    }

    $theTopic   = _makeTopicPattern( $theTopic );    # E.g. "Bug*, *Patch" ==> "^(Bug.*|.*Patch)$"
    $theExclude = _makeTopicPattern( $theExclude );  # E.g. "Web*, FooBar" ==> "^(Web.*|FooBar)$"

    my $output = '';
    my $tmpl = '';
    #my $topicCount = 0; # SMELL: not used??

    my $originalSearch = $theSearchVal;
    my $spacedTopic;

    if( $theFormat ) {
        $theTemplate = 'searchformat';
    } elsif( $theTemplate ) {
        # template definition overrides book and rename views
    } elsif( $doBookView ) {
        $theTemplate = 'searchbookview';
    } else {
        $theTemplate = 'search';
    }
    $tmpl = $session->{templates}->readTemplate( $theTemplate );

    # SMELL: the only META tags in a template will be METASEARCH
    # Why the heck are they being filtered????
    $tmpl =~ s/\%META{.*?}\%//go;  # remove %META{'parent'}%

    # Split template into 5 sections
    my( $tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail ) =
      split( /%SPLIT%/, $tmpl );

    # Invalid template?
    if( ! $tmplTail ) {
        my $mess =
          CGI::h1('TWiki Installation Error') .
              'Incorrect format of '.$theTemplate.' template (missing sections? There should be 4 %SPLIT% tags)';
        if ( defined $callback ) {
            &$callback( $cbdata, $mess );
            return undef;
        } else {
            return $mess;
        }
    }

    # Expand tags in template sections
    $tmplSearch = $session->handleCommonTags( $tmplSearch,
                                              $homeWeb,
                                              $homeTopic );
    $tmplNumber = $session->handleCommonTags( $tmplNumber,
                                              $homeWeb,
                                              $homeTopic );

    # If not inline search, also expand tags in head and tail sections
    unless( $inline ) {
        $tmplHead = $session->handleCommonTags( $tmplHead,
                                                $homeWeb,
                                                $homeTopic );

        if( defined $callback ) {
            $tmplHead = $renderer->getRenderedVersion( $tmplHead,
                                                       $homeWeb,
                                                       $homeTopic );
            $tmplHead =~ s|</*nop/*>||goi;   # remove <nop> tags
            &$callback( $cbdata, $tmplHead );
        } else {
            # don't getRenderedVersion; this will be done by a single
            # call at the end.
            $searchResult .= $tmplHead;
        }
    }

    # Generate 'Search:' part showing actual search string used
    unless( $noSearch ) {
        my $searchStr = $theSearchVal;
        $searchStr = '' if( $theSearchVal eq $emptySearch );
        $searchStr =~ s/&/&amp;/go;
        $searchStr =~ s/</&lt;/go;
        $searchStr =~ s/>/&gt;/go;
        $searchStr =~ s/^\.\*$/Index/go;
        $tmplSearch =~ s/%SEARCHSTRING%/$searchStr/go;
        if( defined $callback ) {
            $tmplSearch = $renderer->getRenderedVersion( $tmplSearch,
                                                         $homeWeb,
                                                         $homeTopic );
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
    if( ( $TWiki::cfg{Log}{search} ) && ( ! $inline ) ) {
        my $t = join( ' ', @webList );
        $session->writeLog( 'search', $t, $theSearchVal );
    }

    # Loop through webs
    foreach my $web ( @webList ) {
        $web =~ s/$TWiki::cfg{NameFilter}//go;
        $web = TWiki::Sandbox::untaintUnchecked( $web );

        next unless $store->webExists( $web );  # can't process what ain't thar

        my $prefs = $session->{prefs};
        my $thisWebNoSearchAll = $prefs->getPreferencesValue( 'NOSEARCHALL', $web );

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        next if ( $searchAllFlag
                  && ( $thisWebNoSearchAll =~ /on/i || $web =~ /^[\.\_]/ )
                  && $web ne $session->{webName} );

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
        if( $theOrder eq 'modified' ) {
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
                          map { [ $store->getTopicLatestRevTime( $web, $_ ), $_ ] }
                            @topicList;
                } else {
                    @tmpList =
                      map { $_->[1] }
                        sort {$a->[0] <=> $b->[0] }
                          map { [ $store->getTopicLatestRevTime( $web, $_ ), $_ ] }
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
                 || $theOrder eq 'editby'                  # sort by author
                 || $theOrder =~ s/^formfield\((.*)\)$/$1/ # sort by TWikiForm field
               ) {
            $topicInfo = $this->_sortTopics( $web, \@topicList, $theOrder, $revSort );
        } else {
            # simple sort, suggested by RaymondLutz in Codev.SchwartzianTransformMisused
            # note no extraction of topic info here, as not needed for the sort. Instead it
            # will be read lazily, later on.
            ##$session->writeDebug 'Topic list before sort = @topicList';
            if( $revSort ) {
                @topicList = sort {$b cmp $a} @topicList;
            } else {
                @topicList = sort {$a cmp $b} @topicList;
            }
            ##$session->writeDebug 'Topic list after sort = @topicList';
        }

        if( $theDate ){
            use TWiki::Time;
            my @ends = &TWiki::Time::parseInterval($theDate);
            my @resultList=();
            foreach my $topic (@topicList){
                # if date falls out of interval: exclude topic from result
                my $topicdate = $store->getTopicLatestRevTime( $web, $topic );
                push(@resultList, $topic) unless (($topicdate<$ends[0]) || ($topicdate>$ends[1]));
            }
            @topicList = @resultList;   
        }

        # header and footer of $web
        my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );
        if( $theHeader ) {
            $theHeader =~ s/\$n\(\)/\n/gos;          # expand '$n()' to new line
            $theHeader =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos; # expand '$n' to new line
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
                  $this->_extractTopicInfo( $web, $topic, 0, undef );
            }
            my $epochSecs = $topicInfo->{$topic}->{modified};
            my $revDate = TWiki::Time::formatTime( $epochSecs );
            my $isoDate = TWiki::Time::formatTime( $epochSecs, '$iso', 'gmtime');

            my $revUser = $topicInfo->{$topic}->{editby} || 'UnknownUser';
            my $ru = $session->{users}->findUser( $revUser );
            my $revNum  = $topicInfo->{$topic}->{revNum} || 0;

            # Check security
            # FIXME - how do we deal with user login not being available if
            # coming from search script?
            my $allowView = $topicInfo->{$topic}->{allowView};
            next unless $allowView;

            my ( $meta, $text );

            # Special handling for format='...'
            if( $theFormat ) {
                ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic );

                if( $doExpandVars ) {
                    if( $web eq $baseWeb && $topic eq $baseTopic ) {
                        # primitive way to prevent recursion
                        $text =~ s/%SEARCH/%<nop>SEARCH/g;
                    }
                    $text = $session->handleCommonTags( $text, $web, $topic );
                }
            }

            my @multipleHitLines = ();
            if( $doMultiple ) {
                my $pattern = $tokens[$#tokens]; # last token in an AND search
                $pattern = quotemeta( $pattern ) if( $theType ne 'regex' );
                ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic ) unless $text;
                if( $caseSensitive ) {
                    @multipleHitLines = reverse grep { /$pattern/ } split( /[\n\r]+/, $text );
                } else {
                    @multipleHitLines = reverse grep { /$pattern/i } split( /[\n\r]+/, $text );
                }
            }

            do {    # multiple=on loop

                my $out = '';

                $text = pop( @multipleHitLines ) if( scalar( @multipleHitLines ) );

                if( $theFormat ) {
                    $out = $theFormat;
                    $out =~ s/\$web/$web/gos;
                    $out =~ s/\$topic\(([^\)]*)\)/TWiki::Render::breakName( $topic, $1 )/geos;
                    $out =~ s/\$topic/$topic/gos;
                    $out =~ s/\$date/$revDate/gos;
                    $out =~ s/\$isodate/$isoDate/gs;
                    $out =~ s/\$rev/$revNum/gos;
                    $out =~ s/\$wikiusername/$ru->webDotWikiName()/geos;
                    $out =~ s/\$wikiname/$ru->wikiName()/geos;
                    $out =~ s/\$username/$ru->login()/geos;
                    my $r1info = {};
                    $out =~ s/\$createdate/$this->_getRev1Info( $web, $topic, 'date', $r1info )/geos;
                    $out =~ s/\$createusername/$this->_getRev1Info( $web, $topic, 'username', $r1info )/geos;
                    $out =~ s/\$createwikiname/$this->_getRev1Info( $web, $topic, 'wikiname', $r1info )/geos;
                    $out =~ s/\$createwikiusername/$this->_getRev1Info( $web, $topic, 'wikiusername', $r1info )/geos;
                    if( $out =~ m/\$text/ ) {
                        ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic ) unless $text;
                        if( $topic eq $session->{topicName} ) {
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
                $out =~ s/%TIME%/$revDate/o;

                my $srev = 'r' . $revNum;
                if( $revNum eq '0' || $revNum eq '1' ) {
                    $srev = CGI::span( { class => 'twikiNew' }, 'NEW' );
                }
                $out =~ s/%REVISION%/$srev/o;
                $out =~ s/%AUTHOR%/$revUser/o;

                if( ( $inline || $theFormat ) && ( ! ( $forceRendering ) ) ) {
                    # do nothing
                } else {
                    # don't callback yet because of table
                    # rendering
                    $out = $session->handleCommonTags( $out, $web, $topic );
                    $out = $renderer->getRenderedVersion( $out, $web, $topic );
                }

                if( $doBookView ) {
                    # BookView
                    ( $meta, $text ) = $this->_getTextAndMeta( $topicInfo, $web, $topic ) unless $text;
                    if( $web eq $baseWeb && $topic eq $baseTopic ) {
                        # primitive way to prevent recursion
                        $text =~ s/%SEARCH/%<nop>SEARCH/g;
                    }
                    $text = $session->handleCommonTags( $text, $web, $topic );
                    $text = $session->{renderer}->getRenderedVersion
                      ( $text, $web, $topic );
                    # FIXME: What about meta data rendering?
                    $out =~ s/%TEXTHEAD%/$text/go;

                } elsif( $theFormat ) {
                    $out =~ s/\$summary\(([^\)]*)\)/$renderer->makeTopicSummary( $text, $topic, $web, $1 )/geos;
                    $out =~ s/\$summary/$renderer->makeTopicSummary( $text, $topic, $web )/geos;
                    $out =~ s/\$parent\(([^\)]*)\)/TWiki::Render::breakName( $meta->getParent(), $1 )/geos;
                    $out =~ s/\$parent/$meta->getParent()/geos;
                    $out =~ s/\$formfield\(\s*([^\)]*)\s*\)/TWiki::Render::renderFormFieldArg( $meta, $1 )/geos;
                    $out =~ s/\$formname/$meta->getFormName()/geos;
                    # FIXME: Allow all regex characters but escape them
                    $out =~ s/\$pattern\((.*?\s*\.\*)\)/getTextPattern( $text, $1 )/geos;
                    $out =~ s/\r?\n/$newLine/gos if( $newLine );
                    if( defined( $theSeparator ) ) {
                        $out .= $theSeparator;
                    } else {
                        $out =~ s/([^\n])$/$1\n/os;    # add new line at end if needed
                    }
                    $out =~ s/\$n\(\)/\n/gos;          # expand '$n()' to new line
                    $out =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos; # expand '$n' to new line
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
                    $text = $renderer->makeTopicSummary( $text, $topic, $web );
                    $out =~ s/%TEXTHEAD%/$text/go;
                }

                # lazy output of header (only if needed for the first time)
                unless( $headerDone || $noHeader ) {
                    $headerDone = 1;
                    my $prefs = $session->{prefs};
                    my $thisWebBGColor = $prefs->getPreferencesValue( 'WEBBGCOLOR', $web ) || '\#FF00FF';
                    $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
                    $beforeText =~ s/%WEB%/$web/go;
                    $beforeText = $session->handleCommonTags
                      ( $beforeText, $web, $topic );
                    if ( defined $callback ) {
                        $beforeText =
                          $renderer->getRenderedVersion( $beforeText,
                                                                 $web,
                                                                 $topic );
                        $beforeText =~ s|</*nop/*>||goi;   # remove <nop> tag
                        &$callback( $cbdata, $beforeText );
                    } else {
                        $searchResult .= $beforeText;
                    }
                }

                # output topic (or line if multiple=on)
                unless( $inline || $theFormat ) {
                    $out =
                      $renderer->getRenderedVersion( $out, $web,
                                                             $topic );
                    $out =~ s|</*nop/*>||goi;   # remove <nop> tag
                }

                if ( defined $callback ) {
                    &$callback( $cbdata, $out );
                } else {
                    $searchResult .= $out;
                }

            } while( @multipleHitLines ); # multiple=on loop

            $ntopics += 1;

            # delete topic info to clear any cached data
            undef $topicInfo->{$topic};

            last if( $ntopics >= $theLimit );
        } # end topic loop

        # output footer only if hits in web
        if( $ntopics ) {
            # output footer of $web
            $afterText  = $session->handleCommonTags( $afterText,
                                                      $web,
                                                      $homeTopic );
            if( $inline || $theFormat ) {
                $afterText =~ s/\n$//os;  # remove trailing new line
            }

            if ( defined $callback ) {
                $afterText = 
                  $renderer->getRenderedVersion( $afterText,
                                                         $web,
                                                         $homeTopic );
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
                      $renderer->getRenderedVersion( $thisNumber,
                                                             $web,
                                                             $homeTopic );
                    $thisNumber =~ s|</*nop/*>||goi;   # remove <nop> tag
                    &$callback( $cbdata, $thisNumber );
                } else {
                    $searchResult .= $thisNumber;
                }
            }
        }
        
        return '' if ( $ntopics == 0 && $noZeroResults );
    }

    if( $theFormat  && ! $finalTerm ) {
        if( $theSeparator ) {
            $searchResult =~ s/$theSeparator$//s;  # remove separator at end
        } else {
            $searchResult =~ s/\n$//os;            # remove trailing new line
        }
    }

    unless( $inline ) {
        $tmplTail = $session->handleCommonTags( $tmplTail,
                                                $homeWeb,
                                                $homeTopic );

        if( defined $callback ) {
            $tmplTail = $renderer->getRenderedVersion( $tmplTail,
                                                       $homeWeb,
                                                       $homeTopic );
            $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
            &$callback( $cbdata, $tmplTail );
        } else {
            $searchResult .= $tmplTail;
        }
    }

    return undef if ( defined $callback );
    return $searchResult if $inline;

    $searchResult = $session->handleCommonTags( $searchResult,
                                                $homeWeb,
                                                $homeTopic );
    $searchResult = $renderer->getRenderedVersion( $searchResult,
                                                   $homeWeb,
                                                   $homeTopic );

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
          sort { _compare( $b->[0], $a->[0] ) }
            map { [ $topicInfo->{$_}->{$sortfield}, $_ ] }
              @$topics;
    } else {
        @$topics = map { $_->[1] }
          sort { _compare( $a->[0], $b->[0] ) }
            map { [ $topicInfo->{$_}->{$sortfield}, $_ ] }
              @$topics;
    }

    return $topicInfo;
}

my $number = qr/^[-+]?[0-9]+(\.[0-9]*)?([Ee][-+]?[0-9]+)?$/;

sub _compare {
    if( $_[0] =~ /$number/ && $_[1] =~ /$number/ ) {
        # when sorting numbers do it largest first; this is just because
        # this is what date comparisons need.
        return $_[1] <=> $_[0];
    } else {
        return $_[0] cmp $_[1];
    }
}

# extract topic info
sub _extractTopicInfo {
    my ( $this, $web, $topic, $sortfield ) = @_;
    my $info = {};
    my $session = $this->{session};
    my $store = $session->{store};

    my ( $meta, $text ) = $this->_getTextAndMeta( undef, $web, $topic );

    $info->{text} = $text;
    $info->{meta} = $meta;

    my ( $revdate, $revuser, $revnum ) = $meta->getRevisionInfo();
    $info->{editby}     = $revuser ? $revuser->webDotWikiName() : '';
    $info->{modified}   = $revdate;
    $info->{revNum}     = $revnum;

    $info->{allowView} =
      $session->{security}->
        checkAccessPermission( 'view',
                               $session->{user},
                               $text, $topic,
                               $web );

    return $info unless $sortfield;

    if ( $sortfield =~ /^creat/ ) {
        ( $info->{$sortfield} ) = $meta->getRevisionInfo( 1 );
    } elsif ( !defined( $info->{$sortfield} )) {
        $info->{$sortfield} = TWiki::Render::renderFormFieldArg( $meta, $sortfield );
    }

    return $info;
}

# get the text and meta for a topic
sub _getTextAndMeta {
    my( $this, $topicInfo, $web, $topic ) = @_;
    my ( $meta, $text );
    my $store = $this->{session}->{store};

    # read from cache if it's there
    if ( $topicInfo ) {
        $text = $topicInfo->{$topic}->{text};
        $meta = $topicInfo->{$topic}->{meta};
    }

    unless( defined $text ) {
        ( $meta, $text ) =
          $store->readTopic( undef, $web, $topic, undef );
        $text =~ s/%WEB%/$web/gos;
        $text =~ s/%TOPIC%/$topic/gos;
    }
    return ( $meta, $text );
}

# Returns the topic revision info of the base version,
# attributes are 'date', 'username', 'wikiname',
# 'wikiusername'. Revision info is cached in the search
# object for speed.
sub _getRev1Info {
    my( $this, $theWeb, $theTopic, $theAttr, $info ) = @_;
    my $key = $theWeb.'.'.$theTopic;
    my $store = $this->{session}->{store};

    unless( $info->{webTopic} eq $key ) {
        my $meta = new TWiki::Meta( $this->{session}, $theWeb, $theTopic );
        my ( $d, $u ) = $meta->getRevisionInfo( 1 );
        $info->{date} = $d;
        $info->{user} = $u;
    }
    if( $theAttr eq 'username' ) {
        return $info->{user}->login();
    }
    if( $theAttr eq 'wikiname' ) {
        return $info->{user}->wikiName();
    }
    if( $theAttr eq 'wikiusername' ) {
        return $info->{user}->webDotWikiName();
    }
    if( $theAttr eq 'date' ) {
        return TWiki::Time::formatTime( $info->{date} );
    }

    return 1;
}

1;

# EOF
