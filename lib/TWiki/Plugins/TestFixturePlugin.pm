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
package TWiki::Plugins::TestFixturePlugin;

use strict;
use HTML::Diff;
use TWiki::Func;

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
    $text =~ s/<nop>//g;

    my @list = ();
    my $opt;
    my $lastTok;
    my $gathering = 1;

    foreach my $tok ( split( /(<!--\s*\/?$tag.*?-->)/, $text ) ) {
        if ( $tok =~ /<!--\s*$tag(.*?)-->/ ) {
            $opt = $1;
            $gathering = 1;
        } elsif ( $tok =~ /<!--\s*\/$tag\s*-->/ ) {
            throw Error::Simple("<!-- /$tag --> found without matching <!-- $tag --> $lastTok")
              unless ( $gathering );
            push( @list, { text => $lastTok, options=> $opt } );
            $gathering = 0;
        } elsif ( $gathering &&
                  $tok =~ /^<!--\/?\s*(expected|actual).*?-->$/ ) {
            throw Error::Simple("$tok encountered when in open <!-- $tag --> bracket");
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

    unless( $#$actual == $#$expected ) {
        my $mess = "Numbers of actual ($#$actual) and expected ($#$expected) blocks don't match<table width=\"100%\"><th>Expected</th><th>Actual</th></tr>";
        for my $i ( 0..$#$actual ) {
            my $e = $expected->[$i];
            my $et = $e->{text};
            my $at = $actual->[$i]->{text};
            $et =~ s/&/&amp;/g;
            $et =~ s/</&lt;/g;
            $at =~ s/&/&amp;/g;
            $at =~ s/</&lt;/g;
            $mess .= "<tr><td>$et</td><td>$at</td></tr>";
        }
        return "$mess</table>";;
    }

    for my $i ( 0..$#$actual ) {
        my $e = $expected->[$i];
        my $et = $e->{text};
        if ( $e->{options} =~ /\bagain\b/ ) {
            my $prev = $expected->[$i-1];
            $et = $prev->{text};
            # inherit the text so that the next "again" will see the
            # previous text
            $e->{text} = $et;
        }
        if ( $e->{options} =~ /\bexpand\b/ ) {
            $et = TWiki::Func::expandCommonVariables( $et, $topic, $web );
        }
        my $at = $actual->[$i]->{text};
        $errors .= _compareResults( $et, $at, $i + 1, $e->{options} );
    }

    return $errors;
}

sub _tidy {
    my $a = shift;
    $a =~ s/&/&amp;/g;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

sub _compareResults {
    my ( $expected, $actual, $group, $opts ) = @_;

    my $result = "";
    my $diffs = HTML::Diff::html_word_diff( $expected, $actual );
    my $failed = 0;
    my $rex = ( $opts =~ /\brex\b/ );

    foreach my $diff ( @$diffs ) {
        my $a = $diff->[1];
        $a =~ s/^\s+//;
        $a =~ s/\s+$//s;
        my $b = $diff->[2];
        $b =~ s/^\s+//;
        $b =~ s/\s+$//s;
        my $ok = 0;

        if ( $diff->[0] eq 'u' || $a eq $b || $rex && _rexeq( $a, $b )) {
            $ok = 1;
        }
        if ($a =~ /Sushi/) {
            print STDERR "X${a}X${b}X\n";
        }
        $a = _tidy( $a );
        $b = _tidy( $b );
        if ( $ok ) {
            $result .= "<tr bgcolor='8fff8f'><td valign=top><pre>$a</pre></td><td><pre>$a</pre></td></td></tr>\n";
        } else {
            $result .= "<tr valign=top bgcolor='#ff8f8f'><td width=50%><pre>$a</pre></td><td width=50%><pre>$b</pre></td></tr>\n";
            $failed = 1;
        }
    }
    return $failed ? "<table border=1><tr><th>Expected $opts</th><th>Actual</th></tr>$result</table>" : "";
}

sub _rexeq {
    my ( $a, $b ) = @_;

    my @res;
    while ( $a =~ s/\@REX\((.*?)\)/!REX@res!/ ) {
        push( @res, $1 );
    }
    # escape regular expression chars
    $a =~ s/([\[\]\(\)\\\?\*\+\.\/\^\$])/\\$1/g;
    $a =~ s/\@DATE/[0-3]\\d [JFMASOND][aepuco][nbrylgptvc] [12][09]\\d\\d/g;
    $a =~ s/\@TIME/[012]\\d:[0-5]\\d/g;
    $a =~ s/\@WIKINAME/[A-Z]+[a-z]+[A-Z]+[a-z]+/g;
    $a =~ s/!REX(\d+)!/$res[$1]/g;

    return $b =~ /^$a$/;
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    #throw Error::Simple( "initPlugin called twice" ) if $called{initPlugin};

    undef %called;
    $called{initPlugin} = 1;

    return 1;
}

sub DISABLE_earlyInitPlugin {
    # There's a delicate relationship between this and initializeUserHandler
    throw Error::Simple( "unexpected call to earlyInitPlugin", join(",",@_));
}

sub DISABLE_initializeUserHandler {
    # There's a delicate relationship between this and earlyInitPlugin
    throw Error::Simple( "unexpected call to initializeUserHandler", join(",",@_));
}

sub DISABLE_registrationHandler {
    throw Error::Simple( "unexpected call to registrationHandler(", join(",",@_));
}

sub DISABLE_getSessionValueHandler {
    # this can only be enabled in one plugin
    throw Error::Simple( "unexpected call to getSessionValueHandler ", join(",",@_));
}

sub DISABLE_setSessionValueHandler {
    # this can only be enabled in one plugin
    throw Error::Simple( "unexpected call to setSessionValueHandler ", join(",",@_));
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

sub outsidePREHandler {
    # Replace the text "%outsidePREHandler%" with some
    # recognisable text.
    my $n = ++$called{outsidePreHandler};
    $_[0] =~ s/%outsidePreHandler%/OPH${n}_line1\nOPH${n}_line2\nOPH${n}_line3\n/g;
}

sub insidePREHandler {
    # Replace the text "%insidePREHandler%" with some
    # recognisable text.
    my $n = ++$called{insidePreHandler};
    $_[0] =~ s/%insidePreHandler%/IPH${n}_line1\nIPH${n}_line2\nIPH${n}_line3\n/g;
}

sub startRenderingHandler {
    $called{startRenderingHandler} = join( ",", @_||() );
    $called{insidePreHandler} = 0;
    $called{outsidePreHandler} = 0;
}

sub endRenderingHandler {
    $called{endRenderingHandler} = join( ",", @_||() );
    my $q = TWiki::Func::getCgiQuery();
    my $t;
    $t = $q->param( "test" ) if ( $q );
    $t = "" unless $t;

    if ( $t eq "compare" && $_[0] =~ /<!--\s*actual\s*-->/ ) {
        my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
        my $res = _compareExpectedWithActual( _parse( $text, "expected" ),
                                              _parse( $_[0], "actual" ),
                                              $topic, $web);
        if ( $res ) {
            $res = "<font color=\"red\">TESTS FAILED</font><p />$res";
        } else {
            $res = "<font color=\"green\">ALL TESTS PASSED</font>";
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
