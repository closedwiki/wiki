# Copyright (C) 2005 Greg Abbas
require 5.006;
package MergeTests;

use base qw(TWikiTestCase);

use TWiki;
use strict;
use Assert;
use Error qw( :try );

use TWiki::Merge3;

#-----------------------------------------------------------------------------

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

#-----------------------------------------------------------------------------
# helper methods

sub _writeConflict {
    my($out, $aconf, $bconf, $cconf, $arev, $brev, $crev, $sep, $info) = @_;
    push @$out, "[";
    push @$out, $arev."{", grep( $_, @$aconf ), "} ";
    push @$out, $brev."{", grep( $_, @$bconf ), "} ";
    push @$out, $crev."{", grep( $_, @$cconf ), "}";
    push @$out, "]";
}

sub _merge {
    my ( $ia, $ib, $ic ) = @_;
    return TWiki::Merge3::merge(
        $ia, $ib, $ic, "a", "b", "c", " ", \&_writeConflict );
}

sub _readfile {
    my( $fn ) = @_;
    open(F, $fn) || die("could not open file $fn");
    my @data = <F>;
    close(F);
    return join('', @data);
}

#-----------------------------------------------------------------------------
# tests

sub test_shortStrings {
    
    my $this = shift;
    my ( $a, $b, $c, $d );
    
    $a = "";
    $b = "";
    $c = "1 2 3 4 5 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( $c, $d );
    
    $a = "1 2 3 4 5 ";
    $b = "1 2 3 4 5 ";
    $c = "";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( $c, $d );
    
    $a = "1 2 3 4 5 ";
    $b = "1 b 2 3 4 5 ";
    $c = "1 2 3 4 c 5 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 b 2 3 4 c 5 ", $d );
    
    $c = "1 c 2 3 4 c 5 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 [a{} b{b } c{c }]2 3 4 c 5 ", $d );

    $b = "1 3 4 5 6 ";
    $c = "1 2 3 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 3 6 ", $d );
    
    $b = $c = "1 2 4 5 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 2 4 5 ", $d );
    
    $b = $c = "1 2 change 4 5 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 2 change 4 5 ", $d );
    
    $c = "1 2 other 4 5 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 2 [a{3 } b{change } c{other }]4 5 ", $d );
}

sub test_text {

    my $this = shift;
    my ( $a, $b, $c, $d, $e );
    
    $a = <<"EOF";
Some text.<br>
The first version.<br>
Very nice.<br>
EOF

    $b = <<"EOF";
Some text.<br>
The first version.<br>
New text in version "b".<br>
Very nice.<br>
EOF

    $c = <<"EOF";
New first line in "c".<br>
The first version.<br>
Very nice.<br>
EOF

    $e = <<"EOF";
New first line in "c".<br>
The first version.<br>
New text in version "b".<br>
Very nice.<br>
EOF

    $d = TWiki::Merge3::merge($a, $b, $c, "r1", "r2", "r3");
    $this->assert_str_equals( $e, $d );
    
    $c = <<"EOF";
Some text.<br>
The first version.<br>
Alternatively, new text in version "c".<br>
Very nice.<br>
EOF

    $e = <<"EOF";
Some text.<br>
The first version.<br>
<div class=\"twikiConflict\"><b>CONFLICT</b> version r2:</div>
New text in version "b".<br>
<div class=\"twikiConflict\"><b>CONFLICT</b> version r3:</div>
Alternatively, new text in version "c".<br>
<div class=\"twikiConflict\"><b>CONFLICT</b> end</div>
Very nice.<br>
EOF

    $d = TWiki::Merge3::merge($a, $b, $c, "r1", "r2", "r3");
    $this->assert_str_equals( $e, $d );
}

