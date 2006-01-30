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
The flow of control is as follows:
   1 User hits "edit"
   2 The kupu 'edit' template is instantiated with all the js and css
   3 kupu editor invokes view URL with the 'wysiwyg_edit=1' parameter to
     obtain the clean document
      * The earliest possible handler is implemented by the plugin in this
        mode. This handler formats the text and then saves it so the rest
        of twiki rendering can't do anything to it. At the end of rendering
        it drops the saved text back in.
   4 User edits
   5 editor saves by posting to 'save' with the 'wysiwyg_edit=1' parameter
   6 the beforeSaveHandler sees this and converts the HTML back to tml
Note: In the case of a new topic, you might expect to see the "create topic"
screen in the editor when it goesback to twiki for the topic content. This
doesn't happen because the earliest possible handler is called on the topic
content and not the template. The template is effectively ignored and a blank
document is sent to the editor.

Attachment uploads can be handled by URL requests from the editor to the TWiki
upload script. If these uploads are done in an IFRAME, then the redirect at
the end of the upload is done in the IFRAME and the user doesn't see the
upload screens. This avoids the need to add any scripts to the bin dir.

=cut

package TWiki::Plugins::WysiwygPlugin;

use CGI qw( -any );
use strict;
use TWiki::Func;

use vars qw( $VERSION $RELEASE $MODERN $SKIN );
use vars qw( $html2tml $tml2html $recursionBlock $imgMap $cairoCalled );
use vars qw( %TWikiCompatibility );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    if( defined( &TWiki::Func::normalizeWebTopicName )) {
        $MODERN = 1;
    } else {
        # SMELL: nasty global var needed for Cairo
        $cairoCalled = 0;
    }

    $SKIN = TWiki::Func::getPreferencesValue( 'WYSIWYGPLUGIN_WYSIWYGSKIN' );

    # Plugin correctly initialized
    return 1;
}

# This handler is used to determine whether the topic is editable by
# Wysiwyg or not. The only thing it does is to redirect to a normal edit
# url if the skin is set to $SKIN and nasty content is found.
sub beforeEditHandler {
    #my( $text, $topic, $web, $meta ) = @_;
    return unless $SKIN;

    if( TWiki::Func::getSkin() =~ /\b$SKIN\b/o ) {
        my $exclusions = TWiki::Func::getPreferencesValue(
            'WYSIWYG_EXCLUDE' );
        return unless $exclusions;
        if(( $exclusions =~ /\bcalls\b/
               && $_[0] =~ /%[A-Z_]+{.*?}%/s )
             || ( $exclusions =~ /\bvariables\b/ &&
                    $_[0] =~ /%[A-Z_]+%/s)
             || ( $exclusions =~ /\bhtml\b/ &&
                    $_[0] =~ /<\/?(?!verbatim|noautolink|nop|br)\w+/ )
             || ( $exclusions =~ /\bcomments\b/ &&
                    $_[0] =~ /<[!]--/ )
             || ( $exclusions =~ /\bpre\b/ &&
                    $_[0] =~ /<pre\w/ )
	  ) {
            # redirect
            my $query = TWiki::Func::getCgiQuery();
            foreach my $p qw( skin cover ) {
                my $arg = $query->param( $p );
                if( $arg && $arg =~ s/\b$SKIN\b//o ) {
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

# Invoked when the selected skin is in use to convert HTML to
# TML (best offorts)
sub beforeSaveHandler {
    #my( $text, $topic, $web ) = @_;
    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    return unless defined( $query->param( 'wysiwyg_edit' ));

    unless( $html2tml ) {
        require TWiki::Plugins::WysiwygPlugin::HTML2TML;

        $html2tml = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    }

    my @rescue;

    # SMELL: really, really bad smell; bloody core should NOT pass text
    # with embedded meta to plugins! It is VERY BAD DESIGN!!!
    $_[0] =~ s/^(%META:[A-Z]+{.*?}%)\s*$/push(@rescue,$1);'<!--META_'.
      scalar(@rescue).'_META-->'/gem;

    unless( $MODERN ) {
        # undo the munging that has already been done (grrrrrrrrrr!!!!)
        $_[0] =~ s/\t/   /g;
    }

    $_[0] = $html2tml->convert(
        $_[0],
        {
            web => $_[2],
            topic => $_[1],
            convertImage => \&convertImage,
            rewriteURL => \&postConvertURL,
        }
       );

    unless( $MODERN ) {
        # redo the munging
        $_[0] =~ s/   /\t/g;
    }

    $_[0] =~ s/<!--META_(\d+)_META-->/$rescue[$1-1]/g;
}

# Invoked when the selected skin is in use to convert the text to HTML
# We can't use the beforeEditHandler, because the editor loads up and then
# uses a URL to fetch the text to be edited. This handler is designed to
# provide the text for that request. It's a real struggle, because the
# commonTagsHandler is called so many times that getting the right
# call is hard, and then preventing a repeat call is harder!
sub beforeCommonTagsHandler {
    #my ( $text, $topic, $web )
    return if $recursionBlock;
    if( $MODERN ) {
        return unless TWiki::Func::getContext()->{body_text};
    } else {
        # DANGEROUS SMELL: only way to tell what we are processing is
        # the order of the calls to commonTagsHandler - the first call after
        # initPlugin is the body text in Cairo. We only want to process the
        # body text.
        return if( $cairoCalled );
        $cairoCalled = 1;
    }

    my $query = TWiki::Func::getCgiQuery();

    return unless $query;

    return unless defined( $query->param( 'wysiwyg_edit' ));

    # stop it from processing the template without expanded
    # %TEXT% (grr; we need a better way to tell where we
    # are in the processing pipeline)
    return if( $_[0] =~ /^<!-- WysiwygPlugin Template/ );

    # Translate the topic text to pure HTML.
    unless( $tml2html ) {
        require TWiki::Plugins::WysiwygPlugin::TML2HTML;
        $tml2html = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
    }

    # Have to re-read the topic because verbatim blocks have already been
    # lifted out, and we need them.
    my( $meta, $text ) = TWiki::Func::readTopic( $_[2], $_[1] );

    $_[0] = $tml2html->convert(
        $text,
        {
            web => $_[2],
            topic => $_[1],
            getViewUrl => \&getViewUrl,
            expandVarsInURL => \&expandVarsInURL,
        }
       );
}

# DEPRECATED in Dakar (postRenderingHandler does the job better)
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
$TWikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler {
    return postRenderingHandler( @_ );
}

# Dakar handler, replaces endRenderingHandler above
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
# Would prefer to use the postRenderingHandler
sub postRenderingHandler {
    return if( $recursionBlock || !$tml2html );

    return $tml2html->cleanup( @_ );
}

# DEPRECATED in Dakar (modifyHeaderHandler does the job better)
$TWikiCompatibility{writeHeaderHandler} = 1.1;
sub writeHeaderHandler {
    my $query = shift;
    if( $query->param( 'wysiwyg_edit' )) {
        return "Expires: 0\nCache-control: max-age=0, must-revalidate";
    }
    return '';
}

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
        if($opts->{markvars}) {
            # SMELL: this is clunky.... but the markvars transformation has
            # already happened by the time this is used.
            $nvar =~ s/^%(.*)%$/CGI::span({class=>"TMLvariable"}, $1)/e;
        }
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

    if ($url =~ m#^%SCRIPTURL(?:PATH)?(?:{"view"}%|%/view[^/]*)/(\w+)(?:/(\w+))?$# && !$parameters) {
        my( $web, $topic );

        if( $2 ) {
            ($web, $topic) = ($1, $2);
        } else {
            $topic = $1;
        }

        if( $web && $web ne $opts->{web} ) {
            #print STDERR "$orig -> $web.$topic$anchor\n"; #debug
            return $web.'.'.$topic.$anchor;
        }
        #print STDERR "$orig -> $topic$anchor\n"; #debug
        return $topic.$anchor;
    }

    #print STDERR "$orig -> $url$anchor$parameters\n"; #debug
    return $url.$anchor.$parameters;
}

# callback used to convert an image reference into a TWiki variable
# callback passed to the HTML2TML convertor
sub convertImage {
    my( $x, $opts ) = @_;

    return undef unless $x;

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

    return $imgMap->{$x};
}

1;
