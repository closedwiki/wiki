# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Crawford Currie, http://c-dot.co.uk
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
# This is a test plugin designed to interact with TWiki testcases.
# It should NOT be shipped with a release.
# It implements all possible plugin handlers, and generates selected
# results that interact with test cases in the TestCases web.
#
# To use this plugin, you will have to:
# 1 Have HTML::Diff installed
# 2 Create an empty topic in the "TWiki" web of your test installation,
#   called TestFixturePlugin.txt
#
# DO NOT USE THIS PLUGIN IN A USER INSTALLATION. IT IS DESIGNED FOR
# TWIKI CORE TESTING ONLY!!!
#
# The idea is that topics contain blocks marked by <!-- expected -->
# and <!-- actual --> tags. These blocks are compared in the
# endRenderingHandler. The comparison is only done when you provide
# the "test=compare" parameter on the URL.
#
# Stubs are provided for all the published handlers so you can hack
# the plugin to do other tests as well.
#
package TWiki::Plugins::TestFixturePlugin;

use strict;
use HTML::Diff;
use TWiki::Func;

use vars qw(
            $installWeb $VERSION $pluginName
            %called $topic $web $user $installWeb
           );

$VERSION = '1.021';
$pluginName = 'TestFixturePlugin';

# use HTML::Diff to compare the expected and actual brace contents
sub _compareExpectedWithActual {
    #my $text = shift;
    my @tokens = split( /(<!-- \/?(?:expected|actual) -->)/, $_[0] );
    my $errors = "";
    my $expected;
    my $actual;
    my $gather = "";
    my $gathering;

    while ( scalar( @tokens )) {
        my $tok = shift( @tokens );
        if ( $tok eq "<!-- (actual|expected) -->" ) {
            $gather = "";
            $gathering = $1;
        } elsif ( $tok eq "<!-- /expected -->" ) {
            $expected = $gather;
            undef $gathering;
        } elsif ( $tok eq "<!-- /actual -->" ) {
            $actual = $gather;
            undef $gathering;
        } else {
            $gather = $tok;
        }
        if ( defined( $actual ) && defined( $expected )) {
            $errors .= _compareResults( $expected, $actual );
            undef $actual;
            undef $expected;
        }
    }
    if ( $gathering && $gathering eq "actual" && defined( $expected )) {
        $actual = $gather;
    }
    if ( defined( $actual ) && defined( $expected )) {
        $errors .= _compareResults( $expected, $actual );
    }

    die $errors if $errors;
}

sub _compareResults {
    my ( $expected, $actual ) = @_;

    my $result = "";
    my $diffs = HTML::Diff::html_word_diff($expected, $actual);

    if ( scalar( @$diffs )) {
        my $diffc = 0;
        foreach my $diff ( @$diffs ) {
            if ( $diff->[0] ne 'u' &&
                 !( $diff->[1] =~ /^\s*$/ &&
                    $diff->[2] =~ /^\s*$/ )) {
                $result .= "*** $diff->[0]\n<EXPECTED>\n$diff->[1]\n</EXPECTED>\n<ACTUAL>\n$diff->[2]\n</ACTUAL>\n";
            }
        }
    }
    return $result;
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    die "initPlugin called twice" if $called{initPlugin};
    $called{initPlugin} = 1;

    die "Version $TWiki::Plugins::VERSION mismatch between $pluginName and Plugins.pm"
      if ( $TWiki::Plugins::VERSION < 1.025 );

    return 1;
}

#sub earlyInitPlugin {
#    die "unexpected call to earlyInitPlugin", join(",",@_);
#}

#sub initializeUserHandler {
#    die "unexpected call to initializeUserHandler", join(",",@_);
#}

sub registrationHandler {
    die "unexpected call to registrationHandler(", join(",",@_);
}

sub beforeCommonTagsHandler {
    # Replace the text "beforeCommonTagsHandler" with some
    # recognisable text.
    $_[0] =~ s/beforeCommonTagsHandler/BCT1\nBCT2 $_[2].$_[1]\nBCT3\n/g;
}

sub commonTagsHandler {
    # Replace the text "commonTagsHandler" with some
    # recognisable text.
    $_[0] =~ s/commonTagsHandler/CT1\nCT2 $_[2].$_[1]\nCT3\n/g;
}

sub afterCommonTagsHandler {
    # Replace the text "afterCommonTagsHandler" with some
    # recognisable text.
    $_[0] =~ s/afterCommonTagsHandler/ACT1\nACT2 $_[2].$_[1]\nACT3\n/g;
}

sub outsidePREHandler {
    # Replace the text "outsidePREHandler" with some
    # recognisable text.
    $_[0] =~ s/outsidePreHandler/OP1\nOP2\nOP3\n/g;
}

sub insidePREHandler {
    # Replace the text "insidePREHandler" with some
    # recognisable text.
    $_[0] =~ s/insidePreHandler/IP1\nIP2\nIP3\n/g;
}

sub startRenderingHandler {
    $called{startRenderingHandler} = join(",", @_);
}

sub endRenderingHandler {
    $called{endRenderingHandler} = join(",", @_);
    my $q = TWiki::Func::getCgiQuery();

    if ( $q->param( "test" ) eq "compare" ) {
        _compareExpectedWithActual( $_[0] );
    }
}

sub beforeEditHandler {
    $called{beforeEditHandler} = join(",", @_);
}

sub afterEditHandler {
    $called{afterEditHandler} = join(",", @_);
}

sub beforeSaveHandler {
    $called{beforeSaveHandler} = join(",", @_);
}

sub afterSaveHandler {
    $called{afterSaveHandler} = join(",", @_);
}

sub writeHeaderHandler {
    # This is the last opportunity we get in the 'view' cycle
    # to check what has happened. Compare expected and actual.
    return "";
}

sub redirectCgiQueryHandler {
    # This is the last opportunity we get in a rendering sequence that
    # ends in a redirect to check what happened. Redirects come at the
    # end of many scripts.
    return 0;
}

#sub getSessionValueHandler {
#    die "unexpected call to getSessionValueHandler ", join(",",@_);
#}

#sub setSessionValueHandler {
#    die "unexpected call to setSessionValueHandler ", join(",",@_);
#}

1;
