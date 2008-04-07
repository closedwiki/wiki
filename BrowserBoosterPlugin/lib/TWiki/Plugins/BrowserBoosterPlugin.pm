# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 Oliver Krueger, Wiki++
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
# For more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.
package TWiki::Plugins::BrowserBoosterPlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4.2';
$SHORTDESCRIPTION = 'Embeds js and css files into the page to reduce the number of http objects.';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'BrowserBoosterPlugin';

sub DEBUG { 0; } # toggle me

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.2 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub completePageHandler {
    #my ( $text, $header ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::completePageHandler()" ) if DEBUG;

    # import javascript
    $_[0] =~ s/(<script\s+type=.text\/javascript.\s+src=[^>]+><\/script>)/&importJavascript($1)/gei;

    # import css via <link>
    my $prefix = '<style type="text/css"><!-- ' . "\n";
    my $suffix  = "\n--></style>";
    $_[0] =~ s/<link\s+rel=.stylesheet.\s+href=["']?(.*?)["']?\s+type=["']?text\/css["']?[^>]*?>/&importStylesheet($1,$prefix,$suffix)/gei;

    # search <style>-tags for @import directives
    $_[0] =~ s/(<style[^>]*?>)(.*?)(<\/style>)/&doStyleContainer($2,$1,$3)/geism;
    # might be done better with recursive regexes
}

sub readFile {
    my $name = shift;
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef;
    my $data = <IN_FILE>;
    close( IN_FILE );
    $data = '' unless( defined( $data ));
    return $data;
}


sub importJavascript {
    my $text = $_[0];

    # determine filename from url
    $text    =~ m/src=["'](.*?)["']/i;
    my $file = $1;
    my $src  = $1;
    $file    =~ s/($TWiki::cfg{DefaultUrlHost})?$TWiki::cfg{PubUrlPath}/$TWiki::cfg{PubDir}/ge;

    # read file
    my $fileContent = readFile( $file );

    # return container
    return $text unless $fileContent; # just to make sure

    $fileContent =~ s/<(\/?script)/&lt;$1/go;
    return "\n" . '<!-- ' . $src . ' -->' ."\n" . '<script type="text/javascript">'."\n" . $fileContent . "\n</script>\n";

}

sub parseStylesheet {
    my $css = $_[0];
    $css =~ s/(.*?)\@import\s+url\(["']?(.*?)["']?\).*?;(.*)/&importStylesheet($2,$1,$3)/ge;
    return $css;
}

sub rewriteUrls {
    my ( $css, $base ) = @_;
    my $host = $TWiki::cfg{DefaultUrlHost};
    my $pub  = $TWiki::cfg{PubUrlPath};

    # rewrite /my/path/file.css
    $css =~ s/url\(["']?\/([^;]*?)["']?\)/url('$host\/$1')/g;

    # rewrite file.css
    $css =~ s/url\(["']?([^\/][^:]*?)["']?\)/url('$base$1')/g;

    return $css;
}

sub importStylesheet {
    my ( $url, $prefix, $suffix ) = @_;
    my $retval = "";
    my $file   = "";
    my $dir    = $TWiki::cfg{PubDir};

    if ( $url =~ m/^http/ ) {
      # url with host
      $file             = $url;
      my $twiki_pub_url = $TWiki::cfg{DefaultUrlHost} . $TWiki::cfg{PubUrlPath};
      $file             =~ s/$twiki_pub_url/$dir/ge;
    } else {
      # url without host
      $file             = $url;
      my $twiki_pub_url = $TWiki::cfg{PubUrlPath};
      $file             =~ s/$twiki_pub_url/$dir/ge;
    }

    if ( $file ) {
      my $fileContent = readFile( $file );

      # determine current base path and rewrite urls
      $url    =~ m/^(.*\/)[^\/]+$/;
      $retval = rewriteUrls( $fileContent, $1 );

      # recursion
      $retval = parseStylesheet( $retval );
      # SMELL: We should maintain a list of visited urls to prevent loops
    }

    return $prefix . $retval . $suffix;
}

sub doStyleContainer {
    my ( $content, $prefix, $suffix ) = @_;

    # import css via @import
    $content =~ s/\@import\s+url\(["']?(.*?)["']?\).*?;/&importStylesheet($1,"","")/gei;

    # $prefix = "\n<!-- " . $1 . " -->\n" . $prefix;

    return $prefix . $content . $suffix;
}

1;
