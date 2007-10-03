# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 WikiRing
# Author: Crawford Currie
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

=pod

---+ package TWiki::Plugins::SafeWikiPlugin

=cut

package TWiki::Plugins::SafeWikiPlugin;

use strict;
use Assert;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
             $URIFILTER $CODEFILTER );

$VERSION = '$Rev$';

$RELEASE = '1.0';

$SHORTDESCRIPTION = 'Secure your TWiki so it can\'t be used for mounting phishing attacks';

$NO_PREFS_IN_TOPIC = 1;

use vars qw( $parser  );
require TWiki::Plugins::SafeWikiPlugin::Parser;

sub initPlugin {
    #my( $topic, $web, $user, $installWeb ) = @_;

    unless( $parser ) {
        $parser = new TWiki::Plugins::SafeWikiPlugin::Parser();
    }

    return $parser ? 1 : 0;
}

# Handle the complete HTML page about to be sent to the browser
sub completePageHandler {
    #my($html, $httpHeaders) = @_;

    return unless $_[1] =~ m#^Content-type: text/html#m;

    # Parse the HTML and generate a parse tree
    # This handler can be patched into pre-4.2 revs of TWiki
    my $tree = $parser->parseHTML( $_[0] );

    # Now re-generate HTML, applying security constraints as we go.
    $_[0] = $tree->generate(\&filterURI, \&filterHandler);

    # For debugging the HTML parser, use a null filter
    #$_[0] = $tree->generate(\&dummyFilter, \&dummyFilter);
}

sub dummyFilter {
    return $_[0];
}

sub filterURI {
    my $uri = shift;
    return 0 unless $uri;
    unless (defined($URIFILTER)) {
        # the eval expands $TWiki::cfg vars
        $URIFILTER =
          join('|', map {s/(\$TWiki::cfg({.*?})+)/eval($1)/ge; "($_)" }
                 @{$TWiki::cfg{Plugins}{SafeWikiPlugin}{SafeURI}});
    }
    return $uri if $uri =~ /$URIFILTER/o;
    TWiki::Func::writeWarning("SafeWikiPlugin: Disarmed URI '$uri' on "
                                .$ENV{REQUEST_URI}.$ENV{QUERY_STRING});
    return $TWiki::cfg{Plugins}{SafeWikiPlugin}{DisarmURI};
}

sub filterHandler {
    my $code = shift;
    return 0 unless $code;
    unless (defined($CODEFILTER)) {
        # the eval expands $TWiki::cfg vars
        $CODEFILTER =
          join('|', map { s/(\$TWiki::cfg({.*?})+)/eval($1)/ge; "($_)" }
                 @{$TWiki::cfg{Plugins}{SafeWikiPlugin}{SafeHandler}});
    }
    return $code if $code =~ /$CODEFILTER/o;
    TWiki::Func::writeWarning("SafeWikiPlugin: Disarmed on* '$code' on "
                                .$ENV{REQUEST_URI}.$ENV{QUERY_STRING});
    return $TWiki::cfg{Plugins}{SafeWikiPlugin}{DisarmHandler};
}

1;
