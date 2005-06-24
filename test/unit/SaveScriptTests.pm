use strict;

package SaveScriptTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use strict;
use TWiki;
use TWiki::UI::Save;
use CGI;
use Error qw( :try );

my $testweb = "TestSaveScriptTestWeb";
my $testtopic = "TestSaveScriptTopic";

my $twiki;
my $user;
my $testuser1 = "TestUser1";
my $testuser2 = "TestUser2";

my $testform1 = <<'HERE';
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
| Select | select | 1 | Value_1, Value_2, *Value_3* |  |
| Radio | radio | 3 | 1, 2, 3 | |
| Checkbox | checkbox | 3 | red,blue,green | |
| Checkbox and Buttons | checkbox+buttons | 3 | dog,cat,bird,hamster,goat,horse | |
| Textfield | text | 60 | test | |
HERE

my $testform2 = $testform1 . <<'HERE';
| Mandatory | text | 60 | | | M |
| Field not in TestForm1 | text | 60 | text |
HERE

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $twiki = new TWiki();
    $user = $twiki->{user};

    $twiki->{store}->createWeb($user, $testweb);

	$twiki->{store}->saveTopic( $user, $testweb, 'TestForm1',
                                $testform1, undef );

	$twiki->{store}->saveTopic( $user, $testweb, 'TestForm2',
                                $testform2, undef );

	$twiki->{store}->saveTopic( $user, $testweb, 'WebPreferences',
                                '
   * Set WEBFORMS = TestForm1,TestForm2
', undef );

    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    $twiki->{store}->removeWeb($twiki->{user}, $testweb);
}

# 10X
sub test_XXXXXXXXXX {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.TestTopicXXXXXXXXXX', '', $query);
    TWiki::UI::Save::save($twiki);
    my $seen = 0;
    foreach my $t ($twiki->{store}->getTopicNames( $testweb)) {
        if($t eq 'TestTopic0') {
            $seen = 1;
        } elsif( $t !~ /^(Web.*|TestForm[12])$/) {
            $this->assert(0, $t);
        }
    }
    $this->assert($seen);
    $twiki = new TWiki('', $testuser1, $testweb.'.TestTopicXXXXXXXXXX', '', $query);
    TWiki::UI::Save::save($twiki);
    $seen = 0;
    foreach my $t ($twiki->{store}->getTopicNames( $testweb)) {
        if($t =~ /^TestTopic[01]$/) {
            $seen++;
        } elsif( $t !~ /^(Web.*|TestForm[12])$/) {
            $this->assert(0, $t);
        }
    }
    $this->assert_equals(2,$seen);
}

# 9X
sub test_XXXXXXXXX {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.TestTopicXXXXXXXXX', '', $query);
    TWiki::UI::Save::save($twiki);
    my $seen = 0;
    foreach my $t ($twiki->{store}->getTopicNames( $testweb)) {
        if($t eq 'TestTopicXXXXXXXXX') {
            $seen = 1;
        } elsif( $t !~ /^(Web.*|TestForm[12])$/) {
            $this->assert(0, $t);
        }
    }
    $this->assert($seen);
}

#11X
sub test_XXXXXXXXXXX {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.TestTopicXXXXXXXXXXXX', '', $query);
    TWiki::UI::Save::save($twiki);
    my $seen = 0;
    foreach my $t ($twiki->{store}->getTopicNames( $testweb)) {
        if($t eq 'TestTopic0') {
            $seen = 1;
        } elsif( $t !~ /^(Web.*|TestForm[12])$/) {
            $this->assert(0, $t);
        }
    }
    $this->assert($seen);
}

sub test_emptySave {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/^\s*$/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub test_simpleTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/CORRECT/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub test_templateTopicTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'Template Topic' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.TemplateTopic', '', $query);
    TWiki::UI::Save::save($twiki);
    $query = new CGI({
                         templatetopic => [ 'TemplateTopic' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_null($meta->get('FORM'));
}

# Save over existing topic
sub test_prevTopicTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'WRONG' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    $query = new CGI({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/CORRECT/, $text);
    $this->assert_null($meta->get('FORM'));
}

# Save over existing topic with no text (get defult from prev topic)
sub test_prevTopicEmptyTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    $query = new CGI({
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/^CORRECT\s*$/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub test_simpleFormSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'CORRECT' ],
                         formtemplate => [ 'TestForm1' ],
                         action => [ 'save' ],
                         TWiki::Form::cgiName(undef,'Textfield') =>
                         [ 'Flintstone' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    $this->assert($twiki->{store}->topicExists($testweb, $testtopic));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/^CORRECT\s*$/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    # field default values should be all ''
    $this->assert_str_equals('Flintstone', $meta->get('FIELD', 'Textfield' )->{value});
}

sub test_templateTopicFormSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'Template Topic' ],
                         formtemplate => [ 'TestForm1' ],
                         TWiki::Form::cgiName(undef,'Select') =>
                         [ 'Value_1' ],
                         TWiki::Form::cgiName(undef,'Textfield') =>
                         [ 'Fred' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.TemplateTopic', '', $query);
    TWiki::UI::Save::save($twiki);

    my($xmeta, $xtext) = $twiki->{store}->readTopic(undef, $testweb, 'TemplateTopic');
    $query = new CGI({
                         templatetopic => [ 'TemplateTopic' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});

    $this->assert_str_equals('Value_1', $meta->get('FIELD', 'Select' )->{value});
    $this->assert_str_equals('Fred', $meta->get('FIELD', 'Textfield' )->{value});
}

sub test_prevTopicFormSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'Template Topic' ],
                         formtemplate => [ 'TestForm1' ],
                         TWiki::Form::cgiName(undef,'Select') =>
                         [ 'Value_1' ],
                         TWiki::Form::cgiName(undef,'Textfield') =>
                         [ 'Rubble' ],
                         action => [ 'save' ],
                        });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    $query = new CGI({
                      action => [ 'save' ],
                      TWiki::Form::cgiName(undef,'Textfield') =>
                      [ 'Barney' ],
                     });
    $twiki = new TWiki('', $testuser1, $testweb.'.'.$testtopic, '', $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    $this->assert_str_equals('Value_1', $meta->get('FIELD','Select')->{value});
    $this->assert_str_equals('Barney', $meta->get('FIELD','Textfield')->{value});
}

#Mergeing is only enabled if the topic text comes from =text= and =originalrev= is &gt; 0 and is not the same as the revision number of the most recent revision. If mergeing is enabled both the topic and the meta-data are merged.

1;
