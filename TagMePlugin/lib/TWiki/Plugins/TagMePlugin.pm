# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
# Copyright (c) 2006 Fred Morris, m3047-twiki@inwa.net
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
# =========================
#
# This Plugin publishes topics of a web as static HTML pages.

# =========================
package TWiki::Plugins::TagMePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName $debug
        $initialized $attachDir $attachUrl $logAction $tagLinkFormat $tagQueryFormat
        $alphaNum $doneHeader $normalizeTagInput
    );

$VERSION = '1.033';
$RELEASE = 'Any TWiki';
$pluginName = 'TagMePlugin';  # Name of this Plugin
$initialized = 0;

BEGIN {
    # I18N initialization
    if ( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.024 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "\U$pluginName\E_DEBUG" );
    $normalizeTagInput = TWiki::Func::getPreferencesFlag( 'NORMALIZE_TAG_INPUT' ) || TWiki::Func::getPluginPreferencesFlag( 'NORMALIZE_TAG_INPUT' );
    
    _writeDebug( "initPlugin( $web.$topic ) is OK" );
    $initialized = 0;
    $doneHeader = 0;
    
    return 1;
}

sub _initialize
{
    return if( $initialized );

    # Initialization
    $attachDir = TWiki::Func::getPubDir()     . "/$installWeb/$pluginName";
    $attachUrl = TWiki::Func::getPubUrlPath() . "/$installWeb/$pluginName";
    $logAction = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_LOGACTION" );
    $tagLinkFormat = '<a href="%SCRIPTURL%/view%SCRIPTSUFFIX%/'
                               . $installWeb
                               . '/TagMeSearch?tag=$tag;by=$by">$tag</a>';
    $tagQueryFormat = 
          '<table style="width:100%;" border="0" cellspacing="0" cellpadding="2"><tr>$n'
        . '<td style="width:50%;" bgcolor="#EEEEDD"> <b>[[$web.$topic][<nop>$topic]]</b> '
        . '<font size="-1" color="#666666">in <nop>$web web</font></td>$n'
        . '<td style="width:30%;" bgcolor="#EEEEDD">'
        . '[[%SCRIPTURL%/rdiff%SCRIPTSUFFIX%/$web/$topic][$date]] - r$rev </td>$n'
        . '<td style="width:20%;" bgcolor="#EEEEDD"> $wikiusername </td>$n'
        . '</tr></table>$n'
        . '<table style="width:100%;" border="0" cellspacing="0" cellpadding="2"><tr>$n'
        . '<td>&nbsp;</td>$n'
        . '<td style="width:99%;"><font size="-1" color="#666666">'
        . '$summary %BR% Tags: $taglist </font></td>$n'
        . '</tr><tr><td></td></tr></table>';
    $alphaNum = TWiki::Func::getRegularExpression( 'mixedAlphaNum' );

    _addHeader();
    
    $initialized = 1;
}

# =========================
sub _addHeader {
    return if $doneHeader;

    my $header = "\n<style type=\"text/css\" media=\"all\">\n\@import url(\"$attachUrl/tagme.css\");\n</style>\n";
    TWiki::Func::addToHEAD('TAGMEPLUGIN',$header);
    $doneHeader = 1;
}

# =========================
sub afterSaveHandler {
### my ( $text, $topic, $web, $error, $meta ) = @_;

    _writeDebug( "afterSaveHandler( $_[2].$_[1] )" );

    my $newTopic = $_[1];
    my $newWeb   = $_[2];
    if( "$newWeb.$newTopic" ne "$web.$topic" && $topic ne $TWiki::cfg{HomeTopicName} ) {
        # excluding WebHome due to TWiki 4 bug on statistics viewed as WebHome
        # and saved as WebStatistics
        _writeDebug( " - topic renamed from $web.$topic to $newWeb.$newTopic" );
        _initialize();
        renameTagInfo( "$web.$topic", "$newWeb.$newTopic" );
    }
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    _writeDebug( "commonTagsHandler( $_[2].$_[1] )" );
    $_[0] =~ s/%TAGME{(.*?)}%/_handleTagMe($1)/ge;
}

# =========================
sub _handleTagMe
{
    my ( $attr ) = @_;
    my $action = TWiki::Func::extractNameValuePair( $attr, 'tpaction' );
    my $text = '';
    _initialize();
    if( $action eq 'show' ) {
        $text = _showDefault();
    } elsif( $action eq 'showalltags' ) {
        $text = _showAllTags( $attr );
    } elsif( $action eq 'query' ) {
        $text = _queryTag( $attr );
    } elsif( $action eq 'newtag' ) {
        my $tag = TWiki::Func::extractNameValuePair( $attr, 'tag' );
        $text = _newTag( $tag );
    } elsif( $action eq 'add' ) {
        my $tag = TWiki::Func::extractNameValuePair( $attr, 'tag' );
        # Add param to suppress status. FWM, 03-Oct-2006
        my $noStatus = TWiki::Func::extractNameValuePair( $attr, 'nostatus' );
        $text = _addTag( $tag, $noStatus );
    } elsif( $action eq 'remove' ) {
        my $tag = TWiki::Func::extractNameValuePair( $attr, 'tag' );
        # Add param to suppress status. FWM, 03-Oct-2006
        my $noStatus = TWiki::Func::extractNameValuePair( $attr, 'nostatus' );
        $text = _removeTag( $tag, $noStatus );
    } elsif( $action eq 'nop' ) {
        # no operation
    } elsif( $action ) {
        $text = 'Unrecognized action';
    } else {
        $text = _showDefault();
    }
    return $text;
}

# =========================
sub _showDefault
{
    my( @tagInfo ) = @_;

    return '' unless( TWiki::Func::topicExists( $web, $topic ) );

    my $webTopic = "$web.$topic";
    @tagInfo = _readTagInfo( $webTopic ) unless( scalar( @tagInfo ) );
    my $text = '';
    my $tag = '';
    my $num = '';
    my $users = '';
    my $line = '';
    my %seen = ();
    foreach( @tagInfo ) {
        # Format:  3 digit number of users, tag, comma delimited list of users
        # Example: 004, usability, UserA, UserB, UserC, UserD
        # SMELL: This format is a quick hack for easy sorting, parsing, and for fast rendering
        if( /^0*([0-9]+), ([^,]+), (.*)/ ) {
            $num = $1;
            $tag = $2;
            $users = $3;
            $line = _printTagLink( $tag, '' ) . "<span class=\"tagMeVoteCount\">$num</span>";
            if( $users =~ /\b$user\b/ ) {
                $line .= _imgTag( 'tag_remove', 'Remove my vote on this tag', 'remove', $tag );
            } else {
                $line .= _imgTag( 'tag_add', 'Add my vote for this tag', 'add', $tag );
            }
            $seen{$tag} = _wrapHtmlTagControl( $line );
        }
    }
    if ( $normalizeTagInput ) {
        # plain sort can be used and should be just a little faster
        $text .= join( ', ', map{ $seen{$_} } sort keys( %seen ) );
    } else {
        # uppercase characters are possible, so sort with lowercase comparison
        $text .= join( ', ', map{ $seen{$_} } sort { lc $a cmp lc $b } keys( %seen ) );
    }
    $text .= ', ' if( scalar %seen );
    my @allTags = _readAllTags();
    my @notSeen = ();
    foreach( @allTags ) {
        push( @notSeen, $_ ) unless( $seen{$_} );
    }
    if( scalar @notSeen ) {
        my $selectControl .= '<select name="tag"> <option></option> ';
        foreach( @notSeen ) {
            $selectControl .= "<option>$_</option> ";
        }
        $selectControl .= '</select>';
        $selectControl .= '<input type="hidden" name="tpaction" value="add" />';
        $selectControl .= '<input type="image" src="' . $attachUrl . '/tag_addnew.gif" name="add" alt="Add" '
               . 'value="Select tag and add to topic" title="Select tag and add to topic" />, ';
        $text .= _wrapHtmlTagControl( $selectControl );
    }
    $text .= "<a href=\"%SCRIPTURL%/viewauth%SCRIPTSUFFIX%/$installWeb/TagMeManage"
           . "?from=$web.$topic#CreateTag\">create new tag</a>";
    return _wrapHtmlTagMeShowForm( $text );
}

# =========================
sub _showAllTags
{
    my( $attr ) = @_;
    my $qWeb      = TWiki::Func::extractNameValuePair( $attr, 'web' );
    my $qTopic    = TWiki::Func::extractNameValuePair( $attr, 'topic' );
    my $exclude   = TWiki::Func::extractNameValuePair( $attr, 'exclude' );
    my $by        = TWiki::Func::extractNameValuePair( $attr, 'by' );
    my $format    = TWiki::Func::extractNameValuePair( $attr, 'format' );
    my $separator = TWiki::Func::extractNameValuePair( $attr, 'separator' );
    my $minSize   = TWiki::Func::extractNameValuePair( $attr, 'minsize' );
    my $maxSize   = TWiki::Func::extractNameValuePair( $attr, 'maxsize' );
    my $minCount  = TWiki::Func::extractNameValuePair( $attr, 'mincount' );

    my $topicsRegex = '';
    if( $qTopic ) {
        $topicsRegex = $qTopic;
        $topicsRegex =~ s/, */\|/go;
        $topicsRegex =~ s/\*/\.\*/go;
        $topicsRegex = '^.*\.(' . $topicsRegex . ')$';
    }
    my $excludeRegex = '';
    if( $exclude ) {
        $excludeRegex = $exclude;
        $excludeRegex =~ s/, */\|/go;
        $excludeRegex =~ s/\*/\.\*/go;
        $excludeRegex = '^(' . $excludeRegex . ')$';
    }
    my $hasSeparator = $separator ne '';
    my $hasFormat = $format ne '';
    
    $separator = ', ' unless ($hasSeparator || $hasFormat);
    $separator =~ s/\$n/\n/go;
    
    $format = '$tag' unless $hasFormat;
    $format .= "\n" unless $hasSeparator;
    $format =~ s/\$n/\n/go;
    
    $by = $user if( $by eq 'me' );
    $by = '' if( $by eq 'all' );
    $maxSize = 180 unless( $maxSize ); # Max % size of font
    $minSize =  90 unless( $minSize );
    my $text = '';
    my $line = '';
    unless( $format =~ /\$size/ || $by || $qWeb || $qTopic || $exclude ) {
        # fast processing
        $text = join( $separator,
                    map{
                        $line = $format;
                        $line =~ s/\$tag/$_/go;
                        $line;
                    } _readAllTags() );
    } else {
        # slow processing
        # SMELL: Quick hack, should be done with nice data structure
        my %tagCount = ();
        my %allTags = ();
        my %myTags = ();
        my $webTopic = '';
        foreach $webTopic ( _getTagInfoList() ) {
            next if( $qWeb && $webTopic !~ /^$qWeb\./  );
            next if( $topicsRegex && $webTopic !~ /$topicsRegex/ );
            my @tagInfo = _readTagInfo( $webTopic );
            my $tag = '';
            my $num = '';
            my $users = '';
            foreach $line ( @tagInfo ) {
                if( $line =~ /^0*([0-9]+), ([^,]+), (.*)/ ) {
                    $num = $1;
                    $tag = $2;
                    $users = $3;
                    unless( $excludeRegex && $tag =~ /$excludeRegex/ ) {
                        $tagCount{$tag} += $num unless( $by && $users !~ /$by/ );
                        $allTags{$tag} = 1;
                        $myTags{$tag} = 1 if( $users =~ /$by/ );
                    }
                }
            }
        }
        
        if ( $minCount ) {
            # remove items below the threshold
            foreach my $item (keys %allTags) {
                delete $allTags{$item} if ( $tagCount{$item} < $minCount );
            }
        }

		my $temp = join ( ";", keys( %allTags ) );
        &TWiki::Func::writeDebug("allTags = " . $temp . "\n");
        
        my @tags = ();
        if( $by ) {
            if ( $normalizeTagInput) {
                @tags = sort keys( %myTags );
            } else {
                @tags = sort { lc $a cmp lc $b} keys( %myTags );
            }
        } else {
            if ( $normalizeTagInput) {
                @tags = sort keys( %allTags );
            } else {
                @tags = sort { lc $a cmp lc $b} keys( %allTags );
            }
        }
        if( $by && ! scalar @tags ) {
            return "__Note:__ You haven't yet added any tags. To add a tag, go to "
                 . "a topic of interest, and add a tag from the list, or put your "
                 . "vote on an existing tag.";
        }
        my $max = 1;
        
        my %order = map{ ($_, $max++) }
                    sort{ $tagCount{$a} <=> $tagCount{$b} }
                    keys( %tagCount );
        my $size = 0;
        my $tmpSep = '_#_';
        $text = join( $separator,
                    map{
                        $size = int( $maxSize * ( $order{$_} + 1 ) / $max );
                        $size = $minSize if( $size < $minSize );
                        $line = $format;
                        $line =~ s/(tag\=)\$tag/$1$tmpSep\$tag$tmpSep/go;
                        $line =~ s/$tmpSep\$tag$tmpSep/&_urlEncode($_)/geo;
                        $line =~ s/\$tag/$_/go;
                        $line =~ s/\$size/$size/go;
                        $line;
                    } @tags );
    }
    return $text;
}

# =========================
sub _queryTag
{
    my( $attr ) = @_;
    my $qWeb      = TWiki::Func::extractNameValuePair( $attr, 'web' );
    my $qTopic    = TWiki::Func::extractNameValuePair( $attr, 'topic' );
    my $qTag      = _urlDecode(TWiki::Func::extractNameValuePair( $attr, 'tag' ));
    my $qBy       = TWiki::Func::extractNameValuePair( $attr, 'by' );
    my $noRelated = TWiki::Func::extractNameValuePair( $attr, 'norelated' );
    my $noTotal   = TWiki::Func::extractNameValuePair( $attr, 'nototal' );
    my $sort      = TWiki::Func::extractNameValuePair( $attr, 'sort' ) || 'tagcount';
    my $format    = TWiki::Func::extractNameValuePair( $attr, 'format' ) || $tagQueryFormat;
    my $separator = TWiki::Func::extractNameValuePair( $attr, 'separator' ) || "\n";
    my $minSize   = TWiki::Func::extractNameValuePair( $attr, 'minsize' );
    my $maxSize   = TWiki::Func::extractNameValuePair( $attr, 'maxsize' );

    return '__Note:__ Please select a tag' unless( $qTag );

    my $topicsRegex = '';
    if( $qTopic ) {
        $topicsRegex = $qTopic;
        $topicsRegex =~ s/, */\|/go;
        $topicsRegex =~ s/\*/\.\*/go;
        $topicsRegex = '^.*\.(' . $topicsRegex . ')$';
    }
    $qBy = '' unless( $qBy );
    $qBy = '' if( $qBy eq 'all' );
    my $by = $qBy;
    $by = $user if( $by eq 'me' );
    $format =~ s/([^\\])\"/$1\\\"/go;
    $separator =~ s/\$n\b/\n/go;
    $separator =~ s/\$n\(\)/\n/go;
    $maxSize = 180 unless( $maxSize ); # Max % size of font
    $minSize =  90 unless( $minSize );

    # SMELL: Quick hack, should be done with nice data structure
    my $text = '';
    my %tagVotes = ();
    my %topicTags = ();
    my %related = ();
    my $tag = '';
    my $num = '';
    my $users = '';
    my @tags = ();
    my $webTopic = '';
    foreach $webTopic ( _getTagInfoList() ) {
        next if( $qWeb && $webTopic !~ /^$qWeb\./  );
        next if( $topicsRegex && $webTopic !~ /$topicsRegex/ );
        my @tagInfo = _readTagInfo( $webTopic );
        @tags = ();
        foreach $line ( @tagInfo ) {
            if( $line =~ /^0*([0-9]+), ([^,]+), (.*)/ ) {
                $num = $1;
                $tag = $2;
                $users = $3;
                push( @tags, $tag );
                if( $tag eq $qTag ) {
                    $tagVotes{$webTopic} = $num unless( $by && $users !~ /$by/ );
                }
            }
        }
        if( $tagVotes{$webTopic} ) {
            $topicTags{$webTopic} = [ sort( @tags ) ];
            foreach $tag ( @tags ) {
                $num = $related{$tag} || 0;
                $related{$tag} = $num + 1;
            }
        }
    }

    return "__Note:__ No topics found tagged with \"$qTag\"" unless( scalar keys( %tagVotes ) );

    # related tags
    unless( $noRelated ) {
        # TODO: should be conditional sort
        $text .= "__%MAKETEXT{\"Related tags\"}%:__ "
               . join( ', ',
                       map{ _printTagLink( $_, $qBy ) }
                       grep{ !/^\Q$qTag\E$/ }
                       sort { lc $a cmp lc $b} keys( %related )
                     )
               . "\n\n";
    }
    if ( $normalizeTagInput) {
        @tags = sort keys( %allTags );
    } else {
        @tags = sort { lc $a cmp lc $b} keys( %allTags );
    }
    my @topics = ();
    if( $sort eq 'tagcount' ) {
        # Sort topics by tag count
        @topics = sort{ $tagVotes{$b} <=> $tagVotes{$a} } keys( %tagVotes );
    } elsif( $sort eq 'topic' ) {
        # Sort topics by topic name
        @topics = sort{ substr($a, rindex($a, '.')) cmp substr($b, rindex($b, '.')) }
                  keys( %tagVotes );
    } else {
        # Sort topics by web, then topic
        @topics = sort keys( %tagVotes );
    }
    if( $format =~ /\$size/ ) {
        # handle formatting with $size (slower)
        my %order = ();
        my $max = 1;
        my $size = 0;
        %order = map{ ($_, $max++) }
                 sort{ $tagVotes{$a} <=> $tagVotes{$b} }
                 keys( %tagVotes );
        foreach $webTopic ( @topics ) {
            $size = int( $maxSize * ( $order{$webTopic} + 1 ) / $max );
            $size = $minSize if( $size < $minSize );
            $text .= _printWebTopic( $webTopic, $topicTags{$webTopic}, $qBy,
                                    $format, $tagVotes{$webTopic}, $size );
            $text .= $separator;
        }
    } else {
        # normal formatting without $size (faster)
        foreach $webTopic ( @topics ) {
            $text .= _printWebTopic( $webTopic, $topicTags{$webTopic}, $qBy,
                                    $format, $tagVotes{$webTopic} );
            $text .= $separator;
        }
    }
    $text =~ s/\Q$separator\E$//s;
    $text .= "\n%MAKETEXT{\"Number of topics\"}%: "
           . scalar( keys( %tagVotes ) ) unless( $noTotal );
    _handleMakeText( $text );
    return $text;
}

# =========================
sub _printWebTopic
{
    my( $webTopic, $tagsRef, $qBy, $format, $voteCount, $size ) = @_;
    $webTopic =~ /^(.*)\.(.)(.*)$/;
    my $qWeb = $1;
    my $qT1 = $2; # Workaround for core bug Bugs:Item2625, fixed in SVN 11484, hotfix-4.0.4-4
    my $qTopic = quotemeta( "$2$3" );
    my $text = '%SEARCH{ '
        . "\"^$qTopic\$\" scope=\"topic\" web=\"$qWeb\" topic=\"$qT1\*\" "
        . 'regex="on" limit="1" nosearch="on" nototal="on" '
        . "format=\"$format\""
        . ' }%';
    $text = TWiki::Func::expandCommonVariables( $text, $qTopic, $qWeb );
    # TODO: should be conditional sort
    $text =~ s/\$taglist/join( ', ', map{ _printTagLink( $_, $qBy ) } sort { lc $a cmp lc $b} @{$tagsRef} )/geo;
    $text =~ s/\$size/$size/go if( $size );
    $text =~ s/\$votecount/$voteCount/go;
    return $text;
}

# =========================
sub _printTagLink
{
    my( $tag, $by ) = @_;
    my $text = $tagLinkFormat;
    if( !$normalizeTagInput) {
        my $tmpSep = '_#_';
        $text =~ s/(tag\=)\$tag/$1$tmpSep\$tag$tmpSep/go;
        $text =~ s/$tmpSep\$tag$tmpSep/&_urlEncode($tag)/geo;
    }
    $text =~ s/\$tag/$tag/go;
    $text =~ s/\$by/$by/go;
    return $text;
}

# =========================
# Add new tag to system
sub _newTag
{
    my( $tag ) = @_;
    
    return _wrapHtmlErrorFeedbackMessage( "<nop>$user cannot add new tags" ) if( $user =~ /^(TWikiGuest|guest)$/ );
    if ( $normalizeTagInput ) {
        $tag =~ s/[- \/]/_/go;
        $tag = lc( $tag );
        $tag =~ s/[^${alphaNum}_]//go;
    } else {
        $tag =~ s/[\x01-\x1f^\#\,\'\"]//go; # make safe
    }
    $tag =~ s/^(.{30}).*/$1/; # limit to 30 characters
    $tag =~ s/^\s*//; # trim spaces at start
    $tag =~ s/\s*$//; # trim spaces at end
    return _wrapHtmlErrorFeedbackMessage( "Please enter a tag" ) unless( $tag );
    my @allTags = _readAllTags();
    if( grep( /^\Q$tag\E$/, @allTags ) ) {
        return _wrapHtmlErrorFeedbackMessage( "Tag \"$tag\" already exists" );
    } else {
        push( @allTags, $tag );
        writeAllTags( @allTags );
        _writeLog( "New tag '$tag'" );
        return _wrapHtmlFeedbackMessage( "Tag \"$tag\" is successfully added!" );
    }
}

# =========================
# Add tag to topic
sub _addTag
{
    my( $addTag, $noStatus ) = @_;

    my $webTopic = "$web.$topic";
    my @tagInfo = _readTagInfo( $webTopic );
    my $text = '';
    my $tag = '';
    my $num = '';
    my $users = '';
    my @result = ();
    if( TWiki::Func::topicExists( $web, $topic ) ) {
        foreach my $line ( @tagInfo ) {
            if( $line =~ /^0*([0-9]+), ([^,]+), (.*)/ ) {
                $num = $1;
                $tag = $2;
                $users = $3;
                if( $tag eq $addTag ) {
                    if( $users =~ /\b$user\b/ ) {
                        $text .= _wrapHtmlFeedbackErrorInline( "you already added this tag" );
                    } else {
                        # add user to existing tag
                        $line = sprintf( '%03d', $num+1 );
                        $line .= ", $tag, $users, $user";
                        $text .= _wrapHtmlFeedbackInline( "added tag vote on \"$tag\"" );
                        _writeLog( "Added tag vote on '$tag'" );
                    }
                }
            }
            push( @result, $line );
        }
        unless( $text ) {
            # tag does not exist yet
            if( $addTag ) {
                push( @result, "001, $addTag, $user" );
                $text .= _wrapHtmlFeedbackInline(" added tag \"$addTag\"" );
                _writeLog( "Added tag '$addTag'" );
            } else {
                $text .= " (please select a tag)";
            }
        }
        @tagInfo = reverse sort( @result );
        _writeTagInfo( $webTopic, @tagInfo );
    } else {
        $text .= _wrapHtmlFeedbackErrorInline( "tag not added, topic does not exist" );
    }
    # Suppress status? FWM, 03-Oct-2006
    return _showDefault( @tagInfo ) . (( $noStatus ) ? '' : $text);
}

# =========================
# Remove my tag vote from topic
sub _removeTag
{
    my( $removeTag, $noStatus ) = @_;

    my $webTopic = "$web.$topic";
    my @tagInfo = _readTagInfo( $webTopic );
    my $text = '';
    my $tag = '';
    my $num = '';
    my $users = '';
    my $found = 0;
    my @result = ();
    foreach my $line ( @tagInfo ) {
        if( $line =~ /^0*([0-9]+), ([^,]+)(, .*)/ ) {
            $num = $1;
            $tag = $2;
            $users = $3;
            if( $tag eq $removeTag ) {
                if( $users =~ s/, $user\b// ) {
                    $found = 1;
                    $num--;
                    if( $num ) {
                        $line = sprintf( '%03d', $num );
                        $line .= ", $tag$users";
                        $text .= _wrapHtmlFeedbackInline( "removed my tag vote on \"$tag\"" );
                        _writeLog( "Removed tag vote on '$tag'" );
                        push( @result, $line );
                    } else {
                        $text .= _wrapHtmlFeedbackInline( "removed tag \"$tag\"" );
                        _writeLog( "Removed tag '$tag'" );
                    }
                }
            } else {
                push( @result, $line );
            }
        } else {
            push( @result, $line );
        }
    }
    if( $found ) {
        @tagInfo = reverse sort( @result );
        _writeTagInfo( $webTopic, @tagInfo );
    } else {
        $text .= _wrapHtmlFeedbackErrorInline( "tag \"$removeTag\" not found" );
    }
    # Suppress status? FWM, 03-Oct-2006
    return _showDefault( @tagInfo ) . (( $noStatus ) ? '' : $text);
}

# =========================
sub _imgTag
{
    my( $image, $title, $action, $tag ) = @_;
    my $text = '';
    if( $tag ) {
        $text = "<a href=\"%SCRIPTURL%/viewauth%SCRIPTSUFFIX%/%BASEWEB%/%BASETOPIC%?"
              . "tpaction=$action;tag=" . _urlEncode($tag) . "\">";
    }
    $text .= "<img src=\"$attachUrl/$image.gif\" alt=\"$title\" title=\"$title\" "
           . "width=\"12\" height=\"10\" border=\"0\" />";
    $text .= "</a>" if( $tag );
    return $text;
}

# =========================
sub _getTagInfoList
{
    my @list = ();
    if( opendir( DIR, "$attachDir" ) ) {
        @files = grep{ !/^_tags_all\.txt$/ } grep{ /^_tags_.*\.txt$/ } readdir( DIR );
        closedir DIR;
        @list = map{ s/^_tags_(.*)\.txt$/$1/; $_ } @files;
    }
    return sort @list;
}

# =========================
sub _readTagInfo
{
    my( $webTopic ) = @_;
    $webTopic =~ s/[\/\\]/\./g;
    _writeDebug( "_readTagInfo( $webTopic )" );
    my $text = TWiki::Func::readFile( "$attachDir/_tags_$webTopic.txt" );
    my @info = grep{ /^[0-9]/ } split( /\n/, $text );
    return @info;
}

# =========================
sub _writeTagInfo
{
    my( $webTopic, @info ) = @_;
    $webTopic =~ s/[\/\\]/\./g;
    my $file = "$attachDir/_tags_$webTopic.txt";
    if( scalar @info ) {
        my $text = "# This file is generated, do not edit\n"
                 . join( "\n", reverse sort @info ) . "\n";
        TWiki::Func::saveFile( $file, $text );
    } elsif( -e $file ) {
        unlink( $file );
    }
}

# =========================
sub renameTagInfo
{
    my( $oldWebTopic, $newWebTopic ) = @_;
    _writeDebug( "renameTagInfo( $oldWebTopic, $newWebTopic )" );
    $oldWebTopic =~ s/[\/\\]/\./g;
    $newWebTopic =~ s/[\/\\]/\./g;
    my $oldFile = "$attachDir/_tags_$oldWebTopic.txt";
    my $newFile = "$attachDir/_tags_$newWebTopic.txt";
    if( -e $oldFile ) {
        my $text = TWiki::Func::readFile( $oldFile );
        TWiki::Func::saveFile( $newFile, $text );
        unlink( $oldFile );
    }
}

# =========================
sub _readAllTags
{
     my $text = TWiki::Func::readFile( "$attachDir/_tags_all.txt" );
     #my @tags = grep{ /^[${alphaNum}_]/ } split( /\n/, $text );
     # we assume that this file has been written by TagMe, so tags should be
     # valid, and we only need to filter out the comment line
     my @tags = grep { !/^\#.*/ } split( /\n/, $text );
     return @tags;
}

# =========================
# Sorting of tags (lowercase comparison) is done just before writing of
# the _tags_all file.
sub writeAllTags
{
    my( @tags ) = @_;
    my $text = "# This file is generated, do not edit\n"
             . join( "\n", sort { lc $a cmp lc $b} @tags ) . "\n";
    TWiki::Func::saveFile( "$attachDir/_tags_all.txt", $text );
}

# =========================
sub _writeDebug
{
    my( $text ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}: $text" ) if $debug;
}

# =========================
sub _writeLog
{
    my ( $theText ) = @_;
    if( $logAction ) {
        $TWiki::Plugins::SESSION
          ? $TWiki::Plugins::SESSION->writeLog( "tagme", "$web.$topic", $theText )
          : TWiki::Store::writeLog( "tagme", "$web.$topic", $theText );
        _writeDebug( "TAGME action, $web.$topic, $theText" );
    }
}

# =========================
sub _handleMakeText
{
### my( $text ) = @_; # do not uncomment, use $_[0] instead

    # for compatibility with TWiki 3
    return unless( $TWiki::Plugins::VERSION < 1.1 );

    # very crude hack to remove MAKETEXT{"...."}
    # Note: parameters are _not_ supported!
    $_[0] =~ s/[%]MAKETEXT{ *\"(.*?)." *}%/$1/go;
}

# =========================
sub _wrapHtmlFeedbackMessage {
    my( $text ) = @_;
    return "<div class=\"tagMeNotification\">$text<div>%URLPARAM{\"note\"}\%</div></div>";
}

# =========================
sub _wrapHtmlErrorFeedbackMessage {
    my( $text ) = @_;
    return _wrapHtmlFeedbackMessage( "<span class=\"twikiAlert\">$text</span>" );
}

# =========================
sub _wrapHtmlFeedbackInline {
    my( $text ) = @_;
    return " <span class=\"tagMeNotification\">$text</span>";
}

# =========================
sub _wrapHtmlFeedbackErrorInline {
    my( $text ) = @_;
    return _wrapHtmlFeedbackInline( "<span class=\"twikiAlert\">$text</span>" );
}

# =========================
sub _wrapHtmlTagControl {
    my( $text ) = @_;
    return "<span class=\"tagMeControl\">$text</span>";
}

# =========================
sub _wrapHtmlTagMeShowForm {
    my( $text ) = @_;
    return "<form name=\"tagmeshow\" action=\"%SCRIPTURL%/viewauth%SCRIPTSUFFIX%/%BASEWEB%/%BASETOPIC%\" method=\"post\">$text</form>";
}

# =========================
sub _urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    return $text;
}

# =========================
sub _urlDecode {
    my $text = shift;
    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    return $text;
}

# =========================
1;
