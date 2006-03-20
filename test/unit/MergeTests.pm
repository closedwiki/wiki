# Copyright (C) 2005 Greg Abbas
require 5.006;

package MergeTests;

use base qw(TWikiTestCase);

use TWiki;
use strict;
use Assert;
use Error qw( :try );

use TWiki::Merge;

#-----------------------------------------------------------------------------

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use vars qw( $info @mudge );

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    @mudge = ();
}

#-----------------------------------------------------------------------------
# helper methods

{
    package HackJob;

    sub new {
        return bless( {}, shift );
    }

    sub mergeHandler {
        my($this, $c, $a, $b, $i) = @_;

        die "$i.$MergeTests::info" unless $i eq $MergeTests::info;
        push( @MergeTests::mudge, "$c#$a#$b" );
        return undef;
    }
}

my $session = { plugins => new HackJob() };
$info = { argle => "bargle" };

sub _merge {
    my ( $ia, $ib, $ic ) = @_;
    return TWiki::Merge::merge3(
        'a', $ia,
        'b', $ib,
        'c', $ic,
        ' ',
        $session,
        $info );
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

sub test_shortStrings1 {
    my $this = shift;
    my ( $a, $b, $c, $d );
    $a = "";
    $b = "";
    $c = "1 2 3 4 5 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( $c, $d );
    $this->assert_str_equals(
        ' ##: #1 #1 : ##: #2 #2 : ##: #3 #3 : ##: #4 #4 : ##: #5 #5 ',
        join(':', @mudge ));
}

sub test_shortStrings2 {
    my $this = shift;
    my ( $a, $b, $c, $d );
    $a = "1 2 3 4 5 ";
    $b = "1 2 3 4 5 ";
    $c = "";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( $c, $d );
}

sub test_shortStrings3 {
    my $this = shift;
    my ( $a, $b, $c, $d );
    $a = "1 2 3 4 5 ";
    $b = "1 b 2 3 4 5 ";
    $c = "1 2 3 4 c 5 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 b 2 3 4 c 5 ", $d );
}

sub test_shortStrings4 {
    my $this = shift;
    my ( $a, $b, $c, $d );
    $a = "1 2 3 4 5 ";
    $b = "1 b 2 3 4 5 ";
    $c = "1 c 2 3 4 c 5 ";
    $d = _merge($a, $b, $c)."\n";

    $this->assert_str_equals( <<'END',
1 <div class="twikiConflict"><b>CONFLICT</b> version b:</div>
b <div class="twikiConflict"><b>CONFLICT</b> version c:</div>
c <div class="twikiConflict"><b>CONFLICT</b> end</div>
2 3 4 c 5 
END
                              $d );
    $this->assert_str_equals(
        ' ##: #1 #1 : ##:c#b #c : ##: #4 #4 : ##: #c #c : ##: #5 #5 ',
        join(':', @mudge ));
}

sub test_shortStrings5 {
    my $this = shift;
    my ( $a, $b, $c, $d );
    $a = "1 2 3 4 5 ";
    $b = "1 3 4 5 6 ";
    $c = "1 2 3 ";
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 3 6 ", $d );
}

sub test_shortStrings6 {
    my $this = shift;
    my ( $a, $b, $c, $d );
    $a = "1 2 3 4 5 ";
    $b = "1 2 4 5 ";
    $c = $b;
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 2 4 5 ", $d );
}

sub test_shortStrings7 {
    my $this = shift;
    my ( $a, $b, $c, $d );
    $a = "1 2 3 4 5 ";
    $b = "1 2 change 4 5 ";
    $c = $b;
    $d = _merge($a, $b, $c);
    $this->assert_str_equals( "1 2 change 4 5 ", $d );
}

sub test_shortStrings8 {
    my $this = shift;
    my ( $a, $b, $c, $d );
    $a = "1 2 3 4 5 ";
    $b = "1 2 change 4 5 ";
    $c = "1 2 other 4 5 ";
    $d = _merge($a, $b, $c)."\n";
    $this->assert_str_equals( <<'END',
1 2 <div class="twikiConflict"><b>CONFLICT</b> original a:</div>
3 <div class="twikiConflict"><b>CONFLICT</b> version b:</div>
change <div class="twikiConflict"><b>CONFLICT</b> version c:</div>
other <div class="twikiConflict"><b>CONFLICT</b> end</div>
4 5 
END
                              $d );
    $this->assert_str_equals(
        ' ##: #1 #1 : ##: #2 #2 : ##:c#change #other ',
        join(':', @mudge ));
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

    $d = TWiki::Merge::merge3("r1", $a, "r2", $b, "r3", $c, '\n',
                             $session, $info);
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

    $d = TWiki::Merge::merge3("r1", $a, "r2", $b, "r3", $c, '\n',
                              $session, $info);
    $this->assert_str_equals( $e, $d );
}

