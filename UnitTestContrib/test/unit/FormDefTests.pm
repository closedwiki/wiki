# Copyright (C) 2006 WikiRing http://wikiring.com
# Tests for form def parser
require 5.006;
package FormDefTests;

use base qw(TWikiTestCase);

use TWiki;
use TWiki::Prefs;
use TWiki::Form;
use strict;
use Assert;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $prefix = 'TemporaryTestFormDefs';
my $testSysWeb = $prefix.'SystemWeb';
my $testNormalWeb = $prefix.'NormalWeb';
my $testUsersWeb = $prefix.'UsersWeb';
my $testTopic = $prefix.'TestTopic';
my $testUser;

my $twiki;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki();
    $twiki->{store}->createWeb($twiki->{user}, $testNormalWeb);
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture($twiki, $testNormalWeb);
    eval {$twiki->finish()};
    $this->SUPER::tear_down();
}

sub test_minimalForm {
    my $this = shift;

    $twiki->{store}->saveTopic(
        $twiki->{user}, $testNormalWeb, 'TestForm', <<FORM);
| *Name* | *Type* | *Size* |
| Date | date | 30 |
FORM
    my $def = TWiki::Form->new($twiki, $testNormalWeb, 'TestForm');

    $this->assert_equals(1, scalar @{$def->getFields()});
    my $f = $def->getField('Date');
    $this->assert_str_equals('date', $f->{type});
    $this->assert_str_equals('Date', $f->{name});
    $this->assert_str_equals('Date', $f->{title});
    $this->assert_str_equals('30', $f->{size});
    $this->assert_str_equals('', $f->{value});
    $this->assert_str_equals('', $f->{tooltip});
    $this->assert_str_equals('', $f->{attributes});
    $this->assert_str_equals('', $f->{definingTopic});
}

sub test_allCols {
    my $this = shift;

    $twiki->{store}->saveTopic(
        $twiki->{user}, $testNormalWeb, 'TestForm', <<FORM);
| *Name*     | *Type*   | *Size* | *Value* | *Tooltip* | *Attributes* |
| Select     | select   | 2..4   | a,b,c   | Tippity   | M            |
| Checky Egg | checkbox | 1      | 1,2,3,4   | Blip      |              |
FORM
    my $def = new TWiki::Form($twiki, $testNormalWeb, 'TestForm');

    $this->assert_equals(2, scalar @{$def->getFields()});
    my $f = $def->getField('Select');
    $this->assert_str_equals('select', $f->{type});
    $this->assert_str_equals('Select', $f->{name});
    $this->assert_str_equals('Select', $f->{title});
    $this->assert_equals(2, $f->{minSize});
    $this->assert_equals(4, $f->{maxSize});
    $this->assert_equals(3, scalar(@{$f->getOptions()}));
    $this->assert_str_equals('a,b,c', join(',',@{$f->getOptions()}));
    $this->assert_str_equals('Tippity', $f->{tooltip});
    $this->assert_str_equals('M', $f->{attributes});
    $this->assert_str_equals('', $f->{definingTopic});
    $f = $def->getField('CheckyEgg');
    $this->assert_str_equals('checkbox', $f->{type});
    $this->assert_str_equals('CheckyEgg', $f->{name});
    $this->assert_str_equals('Checky Egg', $f->{title});
    $this->assert_equals(1, $f->{size});
    $this->assert_str_equals('1;2;3;4', join(';',@{$f->getOptions()}));
    $this->assert_str_equals('Blip', $f->{tooltip});
    $this->assert_str_equals('', $f->{attributes});
    $this->assert_str_equals('', $f->{definingTopic});
}

sub test_valsFromOtherTopic {
    my $this = shift;

    $twiki->{store}->saveTopic(
        $twiki->{user}, $testNormalWeb, 'TestForm', <<FORM);
| *Name*         | *Type* | *Size* | *Value*   |
| Vals Elsewhere | select |        |           |
FORM
    $twiki->{store}->saveTopic(
        $twiki->{user}, $testNormalWeb, 'ValsElsewhere', <<FORM);
| *Name* |
| ValOne |
| RowName |
| Age |
FORM
    my $def = new TWiki::Form($twiki, $testNormalWeb, 'TestForm');

    $this->assert_equals(1, scalar @{$def->getFields()});
    my $f = $def->getField('ValsElsewhere');
    $this->assert_str_equals('select', $f->{type});
    $this->assert_str_equals('ValsElsewhere', $f->{name});
    $this->assert_str_equals('Vals Elsewhere', $f->{title});
    $this->assert_equals(1, $f->{minSize});
    $this->assert_equals(1, $f->{maxSize});
    $this->assert_equals(3, scalar(@{$f->getOptions()}));
    $this->assert_str_equals('ValOne,RowName,Age', join(',', @{$f->getOptions()}));
    $this->assert_str_equals('', $f->{definingTopic});
}

sub test_squabValRef {
    my $this = shift;

    $twiki->{store}->saveTopic(
        $twiki->{user}, $testNormalWeb, 'TestForm', <<FORM);
| *Name*         | *Type* | *Size* | *Value*   |
| [[$testNormalWeb.Splodge][Vals Elsewhere]] | select |        |           |
FORM
    $twiki->{store}->saveTopic(
        $twiki->{user}, $testNormalWeb, 'Splodge', <<FORM);
| *Name* |
| ValOne |
| RowName |
| Age |
FORM
    my $def = new TWiki::Form($twiki, $testNormalWeb, 'TestForm');

    $this->assert_equals(1, scalar @{$def->getFields()});
    my $f = $def->getField('ValsElsewhere');
    $this->assert_str_equals('select', $f->{type});
    $this->assert_str_equals('ValsElsewhere', $f->{name});
    $this->assert_str_equals('Vals Elsewhere', $f->{title});
    $this->assert_str_equals('ValOne,RowName,Age',
                             join(',', @{$f->getOptions()}));
    $this->assert_str_equals($testNormalWeb.'.Splodge', $f->{definingTopic});
}

1;
