# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package WysiwygPlugin

This plugin is responsible for translating TML to HTML before an edit starts
and translating the resultant HTML back into TML.

Note: In the case of a new topic, you might expect to see the "create topic"
screen in the editor when it goes back to twiki for the topic content. This
doesn't happen because the earliest possible handler is called on the topic
content and not the template. The template is effectively ignored and a blank
document is sent to the editor.

Attachment uploads can be handled by URL requests from the editor to the TWiki
upload script. If these uploads are done in an IFRAME, then the redirect at
the end of the upload is done in the IFRAME and the user doesn't see the
upload screens. This avoids the need to add any scripts to the bin dir.

=cut

package TWiki::Plugins::WysiwygPlugin;

use CGI qw( :cgi -any );

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use Assert;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $SECRET_ID );
use vars qw( $html2tml $tml2html $recursionBlock $imgMap );
use vars qw( %TWikiCompatibility @refs );

$SHORTDESCRIPTION = 'Translator framework for Wysiwyg editors';

$VERSION = '$Rev$';

$RELEASE = 'TWiki-4.2';

$SECRET_ID = 'WYSIWYG content - do not remove this comment, and never use this identical text in your topics';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # %OWEB%.%OTOPIC% is the topic where the initial content should be
    # grabbed from, as defined in templates/edit.skin.tmpl
    TWiki::Func::registerTagHandler('OWEB', \&_OWEBTAG);
    TWiki::Func::registerTagHandler('OTOPIC', \&_OTOPICTAG);
    TWiki::Func::registerTagHandler('WYSIWYG_TEXT', \&_WYSIWYG_TEXT);
    TWiki::Func::registerTagHandler('JAVASCRIPT_TEXT', \&_JAVASCRIPT_TEXT);
    TWiki::Func::registerTagHandler('WYSIWYG_SECRET_ID', sub { $SECRET_ID });

    TWiki::Func::registerRESTHandler('tml2html', \&_restTML2HTML);
    TWiki::Func::registerRESTHandler('html2tml', \&_restHTML2TML);

    # Plugin correctly initialized
    return 1;
}

sub _OWEBTAG {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $query = TWiki::Func::getCgiQuery();

    return "$theWeb" unless $query;

    if(defined($query->param('templatetopic'))) {
        my @split=split(/\./,$query->param('templatetopic'));

	if($#split==0) {
	  return $theWeb;
	} else {
	  return $split[0];
	}
    }

    return $theWeb;
}

sub _OTOPICTAG {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $query = TWiki::Func::getCgiQuery();

    return "$theTopic" unless $query;

    if(defined($query->param('templatetopic'))) {
        my @split=split(/\./,$query->param('templatetopic'));

	return $split[$#split];
    }

    return $theTopic;
}

sub startRenderingHandler {
    $_[0] =~ s#</?sticky>##g;
}

# This handler is used to determine whether the topic is editable by
# a WYSIWYG editor or not. The only thing it does is to redirect to a
# normal edit url if the skin is set to WYSIWYGPLUGIN_WYSIWYGSKIN and
# nasty content is found.
sub beforeEditHandler {
    #my( $text, $topic, $web, $meta ) = @_;

    my $skin = TWiki::Func::getPreferencesValue( 'WYSIWYGPLUGIN_WYSIWYGSKIN' );

    if( $skin && TWiki::Func::getSkin() =~ /\b$skin\b/o ) {
        if( notWysiwygEditable($_[0])) {

            # redirect
            my $query = TWiki::Func::getCgiQuery();
            foreach my $p qw( skin cover ) {
                my $arg = $query->param( $p );
                if( $arg && $arg =~ s/\b$skin\b// ) {
                    if( $arg =~ /^[\s,]*$/ ) {
                        $query->delete( $p );
                    } else {
                        $query->param( -name=>$p, -value=>$arg );
                    }
                }
            }
            my $url = $query->url( -full=>1, -path=>1, -query=>1 );
            TWiki::Func::redirectCgiQuery( $query, $url );
            # Bring this session to an untimely end
            exit 0;
        }
    }
}

# This handler is only invoked *after* merging is complete
sub beforeSaveHandler {
    #my( $text, $topic, $web ) = @_;
    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    return unless defined( $query->param( 'wysiwyg_edit' ));

    $_[0] = TranslateHTML2TML( @_ );
}

# This handler is invoked *before* a merge, and only from the edit
# script (so it's useless for a REST save)
sub afterEditHandler {
    #my( $text, $topic, $web ) = @_;
    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    return unless defined( $query->param( 'wysiwyg_edit' )) ||
      $_[0] =~ s/<!--$SECRET_ID-->//go;

    # Switch off wysiwyg_edit so it doesn't try to transform again in
    # the beforeSaveHandler
    $query->delete( 'wysiwyg_edit' );

    $_[0] = TranslateHTML2TML( @_ );
}

# Invoked to convert HTML to TML (best efforts)
sub TranslateHTML2TML {
    my( $text, $topic, $web ) = @_;

    unless( $html2tml ) {
        require TWiki::Plugins::WysiwygPlugin::HTML2TML;

        $html2tml = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    }

    # SMELL: really, really bad smell; bloody core should NOT pass text
    # with embedded meta to plugins! It is VERY BAD DESIGN!!!
    my $top = '';
    if ($text =~ s/^(%META:[A-Z]+{.*?}%\r?\n)//s) {
        $top = $1;
    }
    my $bottom = '';
    $text =~ s/^(%META:[A-Z]+{.*?}%\r?\n)/$bottom = "$1$bottom";''/gem;

    my $opts = {
        web => $web,
        topic => $topic,
        convertImage => \&_convertImage,
        rewriteURL => \&postConvertURL,
        very_clean => 1, # aggressively polish saved HTML
    };
    $text = $html2tml->convert( $text, $opts );

    $text =~ s/\s+$/\n/s;

    return $top.$text.$bottom;
}

# Handler used to process text in a =view= URL to generate text/html
# containing the HTML of the topic to be edited.
#
# Invoked when the selected skin is in use to convert the text to HTML
# We can't use the beforeEditHandler, because the editor loads up and then
# uses a URL to fetch the text to be edited. This handler is designed to
# provide the text for that request. It's a real struggle, because the
# commonTagsHandler is called so many times that getting the right
# call is hard, and then preventing a repeat call is harder!
sub beforeCommonTagsHandler {
    #my ( $text, $topic, $web, $meta )
    return if $recursionBlock;
    return unless TWiki::Func::getContext()->{body_text};

    my $query = TWiki::Func::getCgiQuery();

    return unless $query;

    return unless defined( $query->param( 'wysiwyg_edit' ));

    # stop it from processing the template without expanded
    # %TEXT% (grr; we need a better way to tell where we
    # are in the processing pipeline)
    return if( $_[0] =~ /^<!-- WysiwygPlugin Template/ );

    # Have to re-read the topic because verbatim blocks have already been
    # lifted out, and we need them.
    my $topic = $_[1];
    my $web = $_[2];
    my( $meta, $text );
    my $altText = $query->param( 'templatetopic' );
    if( $altText && TWiki::Func::topicExists( $web, $altText )) {
        ( $web, $topic ) = TWiki::Func::normalizeWebTopicName( $web, $altText );
    }

    $_[0] = _WYSIWYG_TEXT($TWiki::Plugins::SESSION, {}, $topic, $web);
}

# Handler used by editors that require pre-prepared HTML embedded in the
# edit template.
sub _WYSIWYG_TEXT {
    my ($session, $params, $topic, $web) = @_;

    # Have to re-read the topic because content has already been munged
    # by other plugins, or by the extraction of verbatim blocks.
    my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    $text = TranslateTML2HTML( $text, $web, $topic );

    # Lift out the text to protect it from further TWiki rendering. It will be
    # put back in the postRenderingHandler.
    return _liftOut( $text );
}

# Handler used to present the editable text in a javascript constant string
sub _JAVASCRIPT_TEXT {
    my ($session, $params, $topic, $web) = @_;

    my $html = _dropBack( _WYSIWYG_TEXT( @_ ));

    $html =~ s/([\\'])/\\$1/sg;
    $html =~ s/\r/\\r/sg;
    $html =~ s/\n/\\n/sg;
    $html =~ s/script/scri'+'pt/g;

    return _liftOut( "'$html'" );
}

# DEPRECATED in Dakar (postRenderingHandler does the job better)
$TWikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler {
    return postRenderingHandler( @_ );
}

# Dakar handler, replaces endRenderingHandler above
sub postRenderingHandler {
    return if( $recursionBlock || !$tml2html );

    # Replace protected content.
    $_[0] = _dropBack($_[0]);
}

# Commented out because of Bugs:Item1176
# DEPRECATED in Dakar (modifyHeaderHandler does the job better)
#$TWikiCompatibility{writeHeaderHandler} = 1.1;
#sub writeHeaderHandler {
#    my $query = shift;
#    if( $query->param( 'wysiwyg_edit' )) {
#        return "Expires: 0\nCache-control: max-age=0, must-revalidate";
#    }
#    return '';
#}

# Dakar modify headers.
sub modifyHeaderHandler {
    my( $headers, $query ) = @_;

    if( $query->param( 'wysiwyg_edit' )) {
        $headers->{Expires} = 0;
        $headers->{'Cache-control'} = 'max-age=0, must-revalidate';
    }
}

# callback passed to the TML2HTML convertor
sub getViewUrl {
    my( $web, $topic ) = @_;

    # the Cairo documentation says getViewUrl defaults the web. It doesn't.
    unless( defined $TWiki::Plugins::SESSION ) {
        $web ||= $TWiki::webName;
    }

    return TWiki::Func::getViewUrl( $web, $topic );
}

# The subset of vars for which bidirection transformation is supported
# in URLs only
use vars qw( @VARS );

# The set of variables that get "special treatment" in URLs
@VARS = (
    '%ATTACHURL%',
    '%ATTACHURLPATH%',
    '%PUBURL%',
    '%PUBURLPATH%',
    '%SCRIPTURLPATH{"view"}%',
    '%SCRIPTURLPATH%',
    '%SCRIPTURL{"view"}%',
    '%SCRIPTURL%',
    '%SCRIPTSUFFIX%', # bit dodgy, this one
   );

# Initialises the mapping from var to URL and back
sub _populateVars {
    my $opts = shift;

    return if( $opts->{exp} );

    local $recursionBlock = 1; # block calls to beforeCommonTagshandler

    my @exp = split(
        /\0/, TWiki::Func::expandCommonVariables(
            join("\0", @VARS), $opts->{topic}, $opts->{web} ));

    for my $i (0..$#VARS) {
        my $nvar = $VARS[$i];
        $opts->{match}[$i] = $nvar;
        $exp[$i] ||= '';
    }
    $opts->{exp} = \@exp;
}

# callback passed to the TML2HTML convertor on each
# variable in a URL used in a square bracketed link
sub expandVarsInURL {
    my( $url, $opts ) = @_;

    return '' unless $url;

    _populateVars( $opts );
    for my $i (0..$#VARS) {
        $url =~ s/$opts->{match}[$i]/$opts->{exp}->[$i]/g;
    }
    return $url;
}

# callback passed to the HTML2TML convertor
sub postConvertURL {
    my( $url, $opts ) = @_;
    #my $orig = $url; #debug

    local $recursionBlock = 1; # block calls to beforeCommonTagshandler

    my $anchor = '';
    if( $url =~ s/(#.*)$// ) {
        $anchor = $1;
    }
    my $parameters = '';
    if( $url =~ s/(\?.*)$// ) {
        $parameters = $1;
    }

    _populateVars( $opts );

    for my $i (0..$#VARS) {
        next unless $opts->{exp}->[$i];
        $url =~ s/^$opts->{exp}->[$i]/$VARS[$i]/;
    }

    if ($url =~ m#^%SCRIPTURL(?:PATH)?(?:{"view"}%|%/+view[^/]*)/+([/\w.]+)$#
          && !$parameters) {
        my $orig = $1;
        my( $web, $topic ) = TWiki::Func::normalizeWebTopicName(
            $opts->{web}, $orig);

        if( $web && $web ne $opts->{web} ) {
            print STDERR "$orig -> $web+$topic$anchor\n"; #debug
            return $web.'.'.$topic.$anchor;
        }
        #print STDERR "$orig -> $topic$anchor\n"; #debug
        return $topic.$anchor;
    }

    #print STDERR "$orig -> $url$anchor$parameters\n"; #debug
    return $url.$anchor.$parameters;
}

# Callback used to convert an image reference into a TWiki variable.
sub _convertImage {
    my( $src, $opts ) = @_;

    return undef unless $src;

    local $recursionBlock = 1; # block calls to beforeCommonTagshandler

    unless( $imgMap ) {
        $imgMap = {};
        my $imgs =
          TWiki::Func::getPreferencesValue( 'WYSIWYGPLUGIN_ICONS' );
        if( $imgs ) {
            while( $imgs =~ s/src="(.*?)" alt="(.*?)"// ) {
                my( $src, $alt ) = ( $1, $2 );
                $src = TWiki::Func::expandCommonVariables(
                    $src, $opts->{topic}, $opts->{web} );
                $alt .= '%' if $alt =~ /^%/;
                $imgMap->{$src} = $alt;
            }
        }
    }

    return $imgMap->{$src};
}

# Replace content with a marker to prevent it being munged by TWiki
sub _liftOut {
    my( $text ) = @_;
    my $n = scalar( @refs );
    push( @refs, $text );
    return "\05$n\05";
}

# Substitute marker
sub _dropBack {
    my( $text) = @_;
    # Restore everything that was lifted out
    while( $text =~ s/\05([0-9]+)\05/$refs[$1]/gi ) {
    }
    return $text;
}

=pod

---++ StaticMethod notWysiwygEditable($text) -> $boolean
Determine if the given =$text= is WYSIWYG editable, based on the topic content
and the value of the TWiki preferences WYSIWYG_EXCLUDE and
WYSIWYG_EDITABLE_CALLS. Returns a descriptive string if the text is not
editable, 0 otherwise.

=cut

sub notWysiwygEditable {
    #my ($text, $exclusions) = @_;

    my $exclusions = $_[1];
    unless( defined( $exclusions )) {
        $exclusions = TWiki::Func::getPreferencesValue('WYSIWYG_EXCLUDE')
          || '';
    }
    return 0 unless $exclusions;

    my $calls_ok = TWiki::Func::getPreferencesValue(
        'WYSIWYG_EDITABLE_CALLS' ) || '---';
    $calls_ok =~ s/\s//g;

    my $ok = 1;
    if( $exclusions =~ /calls/
          && $_[0] =~ /%((?!($calls_ok){)[A-Z_]+{.*?})%/s ) {
        #print STDERR "WYSIWYG_DEBUG: has calls $1 (not in $calls_ok)\n";
        return "Text contains calls";
    }
    if( $exclusions =~ /variables/ && $_[0] =~ /%([A-Z_]+)%/s ) {
        #print STDERR "$exclusions WYSIWYG_DEBUG: has variables $1\n";
        return "Text contains variables";
    }
    if( $exclusions =~ /html/ &&
          $_[0] =~ /<\/?((?!literal|verbatim|noautolink|nop|br)\w+)/ ) {
        #print STDERR "WYSIWYG_DEBUG: has html: $1\n";
        return "Text contains HTML";
    }
    if( $exclusions =~ /comments/ && $_[0] =~ /<[!]--/ ) {
        #print STDERR "WYSIWYG_DEBUG: has comments\n";
        return "Text contains comments";
    }
    if( $exclusions =~ /pre/ && $_[0] =~ /<pre\w/ ) {
        #print STDERR "WYSIWYG_DEBUG: has pre\n";
        return "Text contains PRE";
    }
    return 0;
}

sub TranslateTML2HTML {
    my ($text, $web, $topic) = @_;

    # Translate the topic text to pure HTML.
    unless( $tml2html ) {
        require TWiki::Plugins::WysiwygPlugin::TML2HTML;
        $tml2html = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
    }
    return $tml2html->convert(
        $_[0],
        {
            web => $web,
            topic => $topic,
            getViewUrl => \&getViewUrl,
            expandVarsInURL => \&expandVarsInURL,
        }
       );
}

# Rest handler for use from Javascript. The 'text' parameter is used to
# pass the text for conversion. The text must be URI-encoded (this is
# to support use of this handler from XMLHttpRequest, which gets it
# wrong). Example:
#
# var req = new XMLHttpRequest();
# req.open("POST", url, true);
# req.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
# var params = "text=" + encodeURIComponent(escape(text));
# request.req.setRequestHeader("Content-length", params.length);
# request.req.setRequestHeader("Connection", "close");
# request.req.onreadystatechange = ...;
# req.send(params);
#
# Note how the text has been double-encoded; once (encodeURIComponent) for
# the transfer encoding, and the second (escape) to protect it from unicode
# problems.
#
sub _restTML2HTML {
    my ($session) = @_;
    my $tml = TWiki::Func::getCgiQuery()->param('text');

    # Text is a assumed to be URL-encoded
    $tml = TWiki::urlDecode($tml);

    # if the secret ID is present, don't convert again. We are probably
    # going 'back' to this page (doesn't work on IE :-( )
    if ($tml =~ /<!--$SECRET_ID-->/) {
        return $tml;
    }

    my $html = TranslateTML2HTML(
        $tml, $session->{webName}, $session->{topicName} );

    # Add the secret id to trigger reconversion. Doesn't work if the
    # editor eats HTML comments, so the editor may need to put it back
    # in during final cleanup.
    return '<!--'.$SECRET_ID.'-->'.$html;
}

# Rest handler for use from Javascript
sub _restHTML2TML {
    my ($session) = @_;
    unless( $html2tml ) {
        require TWiki::Plugins::WysiwygPlugin::HTML2TML;

        $html2tml = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    }
    my $html = TWiki::Func::getCgiQuery()->param('text');
    $html =~ s/<!--$SECRET_ID-->//go;

    my $tml = $html2tml->convert(
        $html,
        {
            web => $session->{webName},
            topic => $session->{topicName},
            getViewUrl => \&getViewUrl,
            expandVarsInURL => \&expandVarsInURL,
            very_clean => 1,
        });
    return $tml;
}

# PACKAGE PRIVATE
# Determine if sticky attributes prevent a tag being converted to
# TML when this attribute is present.
my @protectedByAttr;
sub protectedByAttr {
    my ($tag, $attr) = @_;

    unless (scalar(@protectedByAttr)) {
        # See the WysiwygPluginSettings for information on stickybits
        my $protection =
          TWiki::Func::getPreferencesValue('WYSIWYGPLUGIN_STICKYBITS') ||
              <<'DEFAULT';
.*=id,lang,title,dir,on.*;
a=accesskey,coords,shape,target;
bdo=dir;
br=clear;
col=char,charoff,span,valign,width;
colgroup=align,char,charoff,span,valign,width;
dir=compact;
div=align;
dl=compact;
font=size,face;
h\d=align;
hr=align,noshade,size,width;
legend=accesskey,align;
li=value;
ol=compact,start,type;
p=align;
param=name,type,value,valuetype;
pre=width;
q=cite;
table=align,bgcolor,frame,rules,summary,width;
tbody=align,char,charoff,valign;
td=abbr,align,axis,bgcolor,char,charoff,headers,height,nowrap,rowspan,scope,valign,width;
tfoot=align,char,charoff,valign;
th=abbr,align,axis,bgcolor,char,charoff,height,nowrap,rowspan,scope,valign,width,headers;
thead=align,char,charoff,valign;
tr=bgcolor,char,charoff,valign;
ul=compact,type;
DEFAULT
        foreach my $def (split(/;\s*/s, $protection)) {
            my ($re, $ats) = split(/\s*=\s*/s, $def, 2);
            push(@protectedByAttr,
                 { tag => qr/$re/i,
                   attrs => join('|', split(/\s*,\s*/, $ats)) });
        }
    }
    foreach my $row (@protectedByAttr) {
        if ($tag =~ /^$row->{tag}$/i) {
            return 1 if ($attr =~ /^($row->{attrs})$/i);
        }
    }
    return 0;
}

1;

