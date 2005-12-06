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

use vars qw( $VERSION $RELEASE $MODERN $MARKVARS );
use vars qw( $html2tml $tml2html $convertingImage $imgMap $cairoCalled );
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

    my $mv = TWiki::Func::getPreferencesValue(
        'WYSIWYGPLUGIN_MARK_VARIABLES' );
    $MARKVARS = ( $mv && $mv eq 'on' );

    # Plugin correctly initialized
    return 1;
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

    # undo the munging that has already been done (grrrrrrrrrr!!!!)
    $_[0] =~ s/\t/   /g;

    $_[0] = $html2tml->convert(
        $_[0],
        {
            context => { web => $_[2], topic => $_[1] },
            convertImage => \&convertImage,
            rewriteURL => \&rewriteURL,
        }
       );

    $_[0] =~ s/<!--META_(\d+)_META-->/$rescue[$1-1]/g;

    # NOTE: we're not finished yet. We had to leave markers in to protect
    # some constructs, such as variables, from further expansion. They
    # will be mopped up in the postRenderingHandler.
}

# Invoked when the selected skin is in use to convert the text to HTML
# We can't use the beforeEditHandler, because the editor loads up and then
# uses a URL to fetch the text to be edited. This handler is designed to
# provide the text for that request. It's a real struggle, because the
# commonTagsHandler is called so many times that getting the right
# call is hard, and then preventing a repeat call is harder!
sub beforeCommonTagsHandler {
    #my ( $text, $topic, $web )
    return if $convertingImage;
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
            getViewUrl => \&getViewUrl,
            markvars => $MARKVARS,
        }
       );
}

# DEPRECATED in Dakar (postRenderingHandler does the job better)
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
$TWikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler {
    return if( $TWiki::Plugins::VERSION >= 1.1 ||
                 $convertingImage || !$tml2html );

    return $tml2html->cleanup( @_ );
}

# Dakar handler, replaces endRenderingHandler above
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
# Would prefer to use the postRenderingHandler
sub postRenderingHandler {
    return if( $convertingImage || !$tml2html );

    return $tml2html->cleanup( @_ );
}

# DEPRECATED in Dakar (modifyHeaderHandler does the job better)
$TWikiCompatibility{writeHeaderHandler} = 1.1;
sub writeHeaderHandler {
    return '' if $MODERN;

    my $query = shift;
    return "Expires: 0\nCache-control: max-age=0, must-revalidate\n";

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

# general URL rewriter
# callback passed to the HTML2TML convertor
sub rewriteURL {
    my( $url, $opts ) = @_;
    #my $orig = $url; #debug

    my $anchor = '';
    if( $url =~ s/(#.*)$// ) {
        $anchor = $1;
    }
    my $parameters = '';
    if( $url =~ s/(\?.*)$// ) {
        $parameters = $1;
    }

    my @vars = (
        '%ATTACHURL%',
        '%PUBURL%',
        '%PUBURLPATH%',
        '%MAINWEB%',
        '%TWIKIWEB%',
        '%SCRIPTURL{"view"}%',
        '%SCRIPTURL%',
        '%SCRIPTURLPATH%',
       );

    my @exp = split(
        /\0/, TWiki::Func::expandCommonVariables(
            join("\0", @vars), $opts->{topic}, $opts->{web} ));

    for my $i (0..$#vars) {
        $url =~ s/^$exp[$i]/$vars[$i]/;
    }

    if ($url =~ m#^(?:%SCRIPTURL{"view"}%|%SCRIPTURL%/view[^/]*)/(\w+)(?:/(\w+))?$# && !$parameters) {
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
    local $convertingImage = 1; # override in stack below here

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
