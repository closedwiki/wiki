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

$VERSION = '1.000';
$pluginName = 'TestFixturePlugin';

# Parse a topic extracting bracketed subexpressions
sub _parse {
    my ( $text, $tag ) = @_;

    $text =~ s/\r//g;
    $text =~ s/\t/   /g;
    $text =~ s/[^ -~\n]/./g;

    my @list = ();
    my $opt;
    my $lastTok;
    my $gathering = 1;

    foreach my $tok ( split( /(<!--\s*\/?$tag\s*\S*\s*-->)/, $text ) ) {
        if ( $tok =~ /<!--\s*$tag\s*(\S*)\s*-->/ ) {
            $opt = $1;
            $gathering = 1;
        } elsif ( $tok =~ /<!--\s*\/$tag\s*-->/ ) {
            die "<!-- /$tag --> found without matching <!-- $tag -->"
              unless ( $gathering );
            push( @list, { text => $lastTok, options=> $opt } );
            $gathering = 0;
        } elsif ( $gathering &&
                  $tok =~ /^<!--\/?\s*(expected|actual).*?-->$/ ) {
            die "$tok encountered when in open <!-- $tag --> bracket";
        }
        $lastTok = $tok;
    }
    if ( $gathering ) {
        push( @list, { text => $lastTok, options=> $opt } );
    }

    return \@list;
}

# use HTML::Diff to compare the expected and actual contents
sub _compareExpectedWithActual {
    my ( $expected, $actual, $topic, $web ) = @_;
    my $errors = "";

    die "Numbers of actual ($#$actual) and expected ($#$expected) blocks don't match"
      unless $#$actual == $#$expected;

    for my $i ( 0..$#$actual ) {
        my $e = $expected->[$i];
        my $et = $e->{text};
        my $at = $actual->[$i]->{text};
        if ( $e->{options} =~ /\bexpand\b/ ) {
            $et = TWiki::Func::expandCommonVariables( $et, $topic, $web );
        }
        $errors .= _compareResults( $et, $at, $i + 1 );
    }

    return $errors;
}

sub _tidy {
    my $a = shift;
    $a =~ s/^\s+//;
    $a =~ s/\s+$//s;
    $a =~ s/&/&amp;/g;
    $a =~ s/</&lt;/g;
    return $a;
}

sub _compareResults {
    my ( $expected, $actual, $group ) = @_;

    my $result = "";
    my $diffs = HTML::Diff::html_word_diff( $expected, $actual );
    my $failed = 0;

    foreach my $diff ( @$diffs ) {
        my $a = _tidy( $diff->[1] );
        my $b = _tidy( $diff->[2] );

        if ( $diff->[0] eq 'u' || $a eq $b ) {
            $result .= "$a\n";
        } else {
            $result .= "<p /></code><font color=\"red\"><bold>$group: ";
            if ( $diff->[0] eq "+" ) {
                $result .= "UNEXPECTED: <code>'$b'";
            } elsif ( $diff->[0] eq "-" ) {
                $result .= "  EXPECTED: <code>'$a'";
            } else {
                $result .= "  EXPECTED <code>'$a'";
                $result .= "<br /></code>$group: UNEXPECTED <code>'$b'";
            }
            $result .= "</bold></font><p />";
            $failed = 1;
        }
    }
    return $failed ? "<pre>$result</pre>" : "";
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    die "initPlugin called twice" if $called{initPlugin};
    $called{initPlugin} = 1;

    return 1;
}

sub DISABLE_earlyInitPlugin {
    # There's a delicate relationship between this and initializeUserHandler
    die "unexpected call to earlyInitPlugin", join(",",@_);
}

sub DISABLE_initializeUserHandler {
    # There's a delicate relationship between this and earlyInitPlugin
    die "unexpected call to initializeUserHandler", join(",",@_);
}

sub DISABLE_registrationHandler {
    die "unexpected call to registrationHandler(", join(",",@_);
}

sub DISABLE_getSessionValueHandler {
    # this can only be enabled in one plugin
    die "unexpected call to getSessionValueHandler ", join(",",@_);
}

sub DISABLE_setSessionValueHandler {
    # this can only be enabled in one plugin
    die "unexpected call to setSessionValueHandler ", join(",",@_);
}

sub DISABLE_beforeCommonTagsHandler {
    # Replace the text "beforeCommonTagsHandler" with some
    # recognisable text.
    $_[0] =~ s/beforeCommonTagsHandler/BCT1\nBCT2 $_[2].$_[1]\nBCT3\n/g;
}

sub DISABLE_commonTagsHandler {
    # Replace the text "commonTagsHandler" with some
    # recognisable text.
    $_[0] =~ s/commonTagsHandler/CT1\nCT2 $_[2].$_[1]\nCT3\n/g;
}

sub DISABLE_afterCommonTagsHandler {
    # Replace the text "afterCommonTagsHandler" with some
    # recognisable text.
    $_[0] =~ s/afterCommonTagsHandler/ACT1\nACT2 $_[2].$_[1]\nACT3\n/g;
}

sub DISABLE_outsidePREHandler {
    # Replace the text "outsidePREHandler" with some
    # recognisable text.
    $_[0] =~ s/outsidePreHandler/OP1\nOP2\nOP3\n/g;
}

sub DISABLE_insidePREHandler {
    # Replace the text "insidePREHandler" with some
    # recognisable text.
    $_[0] =~ s/insidePreHandler/IP1\nIP2\nIP3\n/g;
}

sub DISABLE_startRenderingHandler {
    $called{startRenderingHandler} = join(",", @_);
}

sub endRenderingHandler {
    $called{endRenderingHandler} = join(",", @_);
    my $q = TWiki::Func::getCgiQuery();

    if ( $q->param( "test" ) eq "compare" && $_[0] =~ /<!--\s*actual\s*-->/ ) {
        my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
        my $res = _compareExpectedWithActual( _parse( $text, "expected" ),
                                              _parse( $_[0], "actual" ),
                                              $topic, $web);
        if ( $res ) {
            $res = "<font color=\"red\">TESTS FAILED</font><p />$res";
        } else {
            $res = "<font color=\"\green\">ALL TESTS PASSED</font>";
        }
        $_[0] = $res;
    }
}

sub DISABLE_beforeEditHandler {
    $called{beforeEditHandler} = join(",", @_);
}

sub DISABLE_afterEditHandler {
    $called{afterEditHandler} = join(",", @_);
}

sub DISABLE_beforeSaveHandler {
    $called{beforeSaveHandler} = join(",", @_);
}

sub DISABLE_afterSaveHandler {
    $called{afterSaveHandler} = join(",", @_);
}

sub DISABLE_writeHeaderHandler {
    # This is the last opportunity we get in the 'view' cycle
    # to check what has happened.
    return "";
}

sub DISABLE_redirectCgiQueryHandler {
    # This is the last opportunity we get in a rendering sequence that
    # ends in a redirect to check what happened. Redirects come at the
    # end of many scripts.
    return 0;
}

1;
