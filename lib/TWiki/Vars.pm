# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Walter Mundt, emage@spamcop.net
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

=begin twiki

---+ TWiki::Vars Module

This module provides a uniform method for handling %VARIABLES% 

=cut

package TWiki::Vars::Parser;

use strict;

use vars qw($varChars);

$varChars = qr/[-\w:_]/;

sub new {
    my $self = bless {}, $_[0];
    $self->{handlers} = {};
    $self->{level} = 0;
    return $self;
}

sub getHandler {
    my ($self, $varName) = @_;
    return $self->{handlers}{uc $varName};
}

sub registerHandler {
    my ($self, $varName, $handlerSub, $handlerInstance, $override) = @_;
    my $var = uc $varName;
    return undef if defined $self->{handlers}{$var} && !$override;

    return undef unless defined $handlerSub && defined $handlerInstance;
    return undef unless ref($handlerSub) eq "CODE";
    return undef unless $varName =~ /^[[:alpha:]]$varChars*$/;

    return $self->{handlers}{uc $varName} = {
	instance => $handlerInstance,
	function => $handlerSub
    };
}

sub _unescape_quotes {
    my ($val) = @_;
    $val =~ s/\\\"/\"/g;
    return $val;
}

sub parseArgs {
    my ($self, $args) = @_;
    my $quotedExpression = qr/\" ( (?: [^"]* \\\" )* [^"]* ) \"/ox;
    
    my $hash = {};
    return $hash unless defined $args;

    $hash->{'%'} = $args;

    if ($args =~ /^\s* (\w+) (\s+ .*)?$/x ||
        $args =~ /^\s* $quotedExpression (\s+ .*)?$/ox) {
	$args = $2 || "";
	$hash->{"*"} = _unescape_quotes($1);
    }
    
    while (
	$args =~ /^\s* (\w+) \s*=\s* (\w+) (\s+ (.*))?$/x ||
	$args =~ /^\s* (\w+) \s*=\s* $quotedExpression (\s+ (.*))?$/ox
	) {
	$args = $3 || "";
	$hash->{lc $1} = _unescape_quotes($2);
    }
    return $hash;
}

sub handleVar {
    my ($self, $varText, $varName, $varArgs) = @_;
    my $handler = $self->getHandler($varName);
    
    return $varText unless defined $handler;

    $varArgs = "" unless defined $varArgs;
    $varArgs =~ s/\\\}/}/gx;

        #print "handleVar('$varText', '$varName', '$varArgs')";

    return &{ $handler->{function} }($handler->{instance}, $varName, $varText, $self->parseArgs($varArgs), $self);
}

sub substitute {
    my ($self, $text) = @_;
	#print "Processing Text ($text):\n$$text\n---";

    return $text if ($self->{level} >= 25);

    $self->{level}++;
    
    my $args = qr/ \{ ( (?: [^}]* \\ \} )* [^}]* ) \} /x;
    $$text =~ s/\%  ($varChars*)  (?: $args )? \%/$self->handleVar($&, $1, $2)/gexo;

    $self->{level}--;
    return $text;
}

package TWiki::Vars::Internal;

=pod

---++ TWiki::Vars::Internal Package

This package is an incomplete attempt to reimplement handleInternalTags
functionality using TWiki::Vars::Parser.

=cut

use TWiki qw( %regex );

=pod
    # I18N: URL-encode full web, topic and filename to the native
    # $siteCharset for attachments viewed from browsers that use UTF-8 URL,
    # unless we are in UTF-8 mode or working on EBCDIC mainframe.
    # Include the filename suffixed to %ATTACHURLPATH% - a hack, but required
    # for migration purposes
    $_[0] =~ s!%ATTACHURLPATH%/($regex{filenameRegex})!&handleNativeUrlEncode("$pubUrlPath/$_[2]/$_[1]/$1",1)!ge;
=cut

sub new
{
    my ($class) = @_;
    
    my $self = bless {}, $class;

    $self->{currentWeb} = $TWiki::webName;     # these shouldn't need default values,
    $self->{currentTopic} = $TWiki::topicName; # but we'll set sane ones just in case
    $self->{topicStack} = [[$TWiki::webName, $TWiki::topicName]];

    my $parser = TWiki::Vars::Parser->new();
    $self->{parser} = $parser;

    # Make Edit URL unique for every edit - fix for RefreshEditPage.
    $parser->registerHandler("EDITURL", \&handleEditUrl, $self);

    $parser->registerHandler("NOP", \&handleNop, $self);
    $parser->registerHandler("TMPL:P", \&handleTmplP, $self);

    $parser->registerHandler("SEP", $self->generateCall(\&TWiki::handleTmplP, '"sep"'), $self);

    for my $envVar (qw(HTTP_HOST REMOTE_ADDR REMOTE_PORT REMOTE_USER)) {
	$parser->registerHandler($envVar, \&handleEnvVariable, $self);
    }

    $parser->registerHandler("TOPIC", \&handleTopicVar, $self);
    $parser->registerHandler("BASETOPIC", sub { return $TWiki::topicName; }, $self);
    $parser->registerHandler("INCLUDINGTOPIC", sub { return $TWiki::includingTopicName; }, $self);
    $parser->registerHandler("SPACEDTOPIC", \&handleTopicVar, $self);
    $parser->registerHandler("WEB", \&handleWebVar, $self);
    $parser->registerHandler("BASEWEB", sub { return $TWiki::webName; }, $self);
    $parser->registerHandler("INCLUDINGWEB", sub { return $TWiki::includingWebName; }, $self);

    # I18N information
    $parser->registerHandler("CHARSET", sub { return $TWiki::siteCharset; }, $self);
    $parser->registerHandler("SHORTLANG", sub { return $TWiki::siteLang; }, $self);
    $parser->registerHandler("LANG", sub { return $TWiki::siteFullLang; }, $self);

    $parser->registerHandler("TOPICLIST", \&handleWebAndTopicList, $self);
    $parser->registerHandler("WEBLIST", \&handleWebAndTopicList, $self);

    # URLs and paths
    $parser->registerHandler("WIKIHOMEURL", sub { return $TWiki::wikiHomeUrl; }, $self);
    $parser->registerHandler("SCRIPTURL", sub { return $TWiki::urlHost . $TWiki::distScriptUrlPath; }, $self);
    $parser->registerHandler("SCRIPTURLPATH", sub { return $TWiki::distScriptUrlPath; }, $self);
    $parser->registerHandler("SCRIPTSUFFIX", sub { return $TWiki::scriptSuffix; }, $self);
    $parser->registerHandler("PUBURL", sub { return $TWiki::urlHost . $TWiki::pubUrlPath; }, $self);
    $parser->registerHandler("PUBURLPATH", sub { return $TWiki::pubUrlPath; }, $self);
    $parser->registerHandler("RELATIVETOPICPATH", \&handleRelativeTopicPath, $self);

    # URL encoding
    $parser->registerHandler("URLPARAM", \&handleUrlParam, $self);
    $parser->registerHandler("URLENCODE", \&handleUrlEncode, $self);
    $parser->registerHandler("ENCODE", \&handleUrlEncode, $self);
    $parser->registerHandler("INTURLENCODE", \&handleIntUrlEncode, $self);

    # Dates and times
    $parser->registerHandler("DATE", \&handleDate, $self);
    for my $timeVar (qw(GMTIME SERVERTIME DISPLAYTIME)) {
	$parser->registerHandler($timeVar, \&handleTime, $self);
    }

    $parser->registerHandler("WIKIVERSION", sub { return $TWiki::wikiversion; }, $self);
    $parser->registerHandler("USERNAME", sub { return $TWiki::userName; }, $self);
    $parser->registerHandler("WIKINAME", sub { return $TWiki::wikiName; }, $self);
    $parser->registerHandler("WIKIUSERNAME", sub { return $TWiki::wikiUserName; }, $self);
    $parser->registerHandler("WIKITOOLNAME", sub { return $TWiki::wikiToolName; }, $self);
    $parser->registerHandler("MAINWEB", sub { return $TWiki::mainWebname; }, $self);
    $parser->registerHandler("TWIKIWEB", sub { return $TWiki::twikiWebname; }, $self);
    $parser->registerHandler("HOMETOPIC", sub { return $TWiki::mainTopicname; }, $self);
    $parser->registerHandler("WIKIUSERSTOPIC", sub { return $TWiki::wikiUsersTopicname; }, $self);
    $parser->registerHandler("WIKIPREFSTOPIC", sub { return $TWiki::wikiPrefsTopicname; }, $self);
    $parser->registerHandler("WEBPREFSTOPIC", sub { return $TWiki::webPrefsTopicname; }, $self);
    $parser->registerHandler("NOTIFYTOPIC", sub { return $TWiki::notifyTopicname; }, $self);
    $parser->registerHandler("STATISTICSTOPIC", sub { return $TWiki::statisticsTopicname; }, $self);

    my $nullSub = sub { return ""; };

    foreach my $noDisplayVar (qw(STARTINCLUDE STOPINCLUDE SECTION ENDSECTION)) {
	$parser->registerHandler($noDisplayVar, $nullSub, $self);
    }

    # Attachments
    $parser->registerHandler("SEARCH", \&handleSearch, $self);
    $parser->registerHandler("METASEARCH", \&handleMetaSearch, $self);
    $parser->registerHandler("FORMFIELD", \&handleFormField, $self);
    $parser->registerHandler("GROUPS", \&handleGroups, $self);

    $parser->registerHandler("ICON", \&handleIcon, $self);
    $parser->registerHandler("ATTACHURL", \&handleAttachUrl);
    $parser->registerHandler("ATTACHURLPATH", \&handleAttachUrlPath, $self);
}

sub handleInternalVars
{
    my ($self, $text, $web, $topic) = @_;

    push @{ $self->{topicStack} }, [$web, $topic];
    $self->{currentWeb} = $web;
    $self->{currentTopic} = $topic;

    $self->{parser}->substitute(\$text);

    my $lastWebTopic = pop @{ $self->{topicStack} };
    $self->{currentWeb} = $lastWebTopic->[0];
    $self->{currentTopic} = $lastWebTopic->[1];
}

sub generateCall
{
    my ($self, $subRef, @args) = @_;
    return sub{ goto &$subRef( @args ); }
}

sub handleEditUrl
{
    return "$TWiki::dispScriptUrlPath/edit$TWiki::scriptSuffix/%WEB%/%TOPIC%\?t=" . time();
}

sub handleNop
{
    my ($self, $varName, $text, $args) = @_;

    return $args->{'%'} if $args->{'%'};
    return "<nop>";
}

sub handleTmplP
{
    my ($self, $varName, $text, $args) = @_;

    return TWiki::handleTmplP($args->{'*'});
}

sub handleEnvVariable
{
    my ($self, $varName, $text, $args, $parser) = @_;
    return $ENV{$varName} || "";
}

sub handleTopicVar
{
    my ($self, $varName, $text, $args, $parser) = @_;
    return $self->{currentTopic} if ($varName eq "TOPIC");

    # SPACEDTOPIC
    my $spacedTopic = $self->{currentTopic};
    # "%20*" is " *" - I18N: only in ASCII-derived charsets
    $spacedTopic =~ s/($regex{singleLowerAlphaRegex}+)($regex{singleUpperAlphaNumRegex}+)/$1%20*$2/go;

    return $spacedTopic;
}

sub handleWebVar
{
    my ($self, $varName, $text, $args, $parser) = @_;

    return $self->{currentWeb};
}

=pod Not done yet !!!

sub handleWebAndTopicList
{
    my ($self, $varName, $text, $args, $parser) = @_;

    my $isWeb = ($varName eq "WEBLIST");
    
    my $format    = $args->{'*'} || $args->{format};
    my $separator = $args->{separator} || "\n";
    my $web       = $args->{web} || "";
    my $selection = $args->{selection} || "";
    my $marker    = $args->{marker} || 'selected="selected"';

    $format .= '$name' unless( $format =~ /\$name/ );
    $selection =~ tr/\,/ /;
    $selection = ' ' .$selection . ' ';
    
    my @list = ();
    if( $isWeb ) {
	my @webslist  = split( /,\s?/, $args->{webs} ) || qw(public);
        foreach my $aweb ( @webslist ) {
            if( $aweb eq "public" ) {
                push( @list, getPublicWebList() );
            } elsif( $aweb eq "webtemplate" ) {
                push( @list, grep { /^\_/ } &TWiki::Store::getAllWebs( "" ) );
            } else {
                push( @list, $aweb ) if( &TWiki::Store::webExists( $aweb ) );
            }
        }
    } else {
        $web = $webName if( ! $web );
        my $hidden = &TWiki::Prefs::getPreferencesValue( "NOSEARCHALL", $web );
        if( ( $web eq $TWiki::webName  ) || ( ! $hidden ) ) {
            @list = &TWiki::Store::getTopicNames( $web );
        }
    }
    my $text = "";
    my $item = "";
    my $line = "";
    my $mark = "";
    foreach $item ( @list ) {
        $line = $format;
        $line =~ s/\$web/$web/gi;
        $line =~ s/\$name/$item/gi;
        $line =~ s/\$qname/"$item"/gi;
        $mark = ( $selection =~ / $item / ) ? $marker : "";
        $line =~ s/\$marker/$mark/gi;
        $text .= "$line$separator";
    }
    $text =~ s/$separator$//s;  # remove last separator
    return $text;
}

sub handleRelativeTopicPath
{
    my ($self, $varName, $text, $args, $parser) = @_;

    my $theStyleTopic = $args->{'*'};

    return "" unless $theStyleTopic;
    
    my $theRelativePath;
    # if there is no dot in $theStyleTopic, no web has been specified
    if ( index( $theStyleTopic, "." ) == -1 ) {
	# add local web
	$theRelativePath = $self->{currentWeb} . "/" . $theStyleTopic;
    } else {
	$theRelativePath = $theStyleTopic; #including dot
    }
    # replace dot by slash is not necessary; TWiki.MyTopic is a valid url
    # add ../ if not already present to make a relative file reference
    if ( index( $theRelativePath, "../" ) == -1 ) {
	$theRelativePath = "../" . $theRelativePath;
    }
    return $theRelativePath;
}

sub handleUrlParam
{
    my ($self, $varName, $text, $args, $parser) = @_;
    my( $theArgs ) = @_;

    my $param     = $args->{'*'};
    my $newLine   = $args->{newline} || "";
    my $encode    = $args->{encode} || "";
    my $multiple  = $args->{multiple} || ""; 
    my $separator = $args->{separator} || "\n"; 
    my $value = "";
    
    $multiple = 0 if ($multiple eq "off" || $multiple eq "no");

    if( $TWiki::cgiQuery ) {
        if( $multiple ) {
            my @valueArray = $TWiki::cgiQuery->param( $param );
            if( @valueArray ) {
                unless( $multiple =~ m/^on$/i ) {
                    my $item = "";
                    @valueArray = map {
                        $item = $_;
                        $_ = $multiple;
                        $_ .= $item unless( s/\$item/$item/go );
                        $_
                    } @valueArray;
                }
                $value = join ( $separator, @valueArray );
            }
        } else {
            $value = $TWiki::cgiQuery->param( $param );
            $value = "" unless( defined $value );
        }
    }
    $value =~ s/\r?\n/$newLine/go if( $newLine );
    $value = TWiki::handleUrlEncode( $value, 0, $encode ) if( $encode );

    return $args->{default} || "" unless $value;
    return $value;

}

=cut

1;

