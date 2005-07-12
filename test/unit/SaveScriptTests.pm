use strict;

package SaveScriptTests;

use base qw(TWikiTestCase);

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
| Textfield | text | 60 | detest | |
HERE

my $testform2 = $testform1 . <<'HERE';
| Mandatory | text | 60 | | | M |
| Field not in TestForm1 | text | 60 | text |
HERE

my $testform3 = <<'HERE';
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
| Select | select | 1 | Value_1, Value_2, *Value_3* |  |
| Radio | radio | 3 | 1, 2, 3 | |
| Checkbox | checkbox | 3 | red,blue,green | |
| Textfield | text | 60 | detest | |
HERE

my $testtext1 = <<'HERE';
%META:TOPICINFO{author="TWikiContributor" date="1111931141" format="1.0" version="$Rev: 4579 $"}%

A guest of this TWiki web, not unlike yourself. You can leave your trace behind you, just add your name in %TWIKIWEB%.TWikiRegistration and create your own page.

%META:FORM{name="TestForm1"}%
%META:FIELD{name="Select" attributes="" title="Select" value="Value_2"}%
%META:FIELD{name="Radio" attributes="" title="Radio" value="3"}%
%META:FIELD{name="Checkbox" attributes="" title="Checkbox" value="red"}%
%META:FIELD{name="Textfield" attributes="" title="Textfield" value="Test"}%
%META:FIELD{name="CheckboxandButtons" attributes="" title="CheckboxandButtons" value=""}%
%META:PREFERENCE{name="VIEW_TEMPLATE" title="VIEW_TEMPLATE" value="UserTopic"}%
HERE

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the detest fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $twiki = new TWiki();
    $user = $twiki->{user};

    $twiki->{store}->createWeb($user, $testweb);

	$twiki->{store}->saveTopic( $user, $testweb, 'TestForm1',
                                $testform1, undef );

	$twiki->{store}->saveTopic( $user, $testweb, 'TestForm2',
                                $testform2, undef );

	$twiki->{store}->saveTopic( $user, $testweb, 'TestForm3',
                                $testform3, undef );

	$twiki->{store}->saveTopic( $user, $testweb, $TWiki::cfg{WebPrefsTopicName},
                                '
   * Set WEBFORMS = TestForm1,TestForm2,TestForm3
', undef );

    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testweb);
}

# 10X
sub detest_XXXXXXXXXX {
    my $this = shift;
    my $query = new CGI({
        action => [ 'save' ],
    });
    $query->path_info( $testweb.'.TestTopicXXXXXXXXXX' );
    $twiki = new TWiki( $testuser1, $query );
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
    $twiki = new TWiki( $testuser1, $query );
    TWiki::UI::Save::save($twiki);
    $seen = 0;
    foreach my $t ($twiki->{store}->getTopicNames( $testweb)) {
        if($t =~ /^TestTopic[01]$/) {
            $seen++;
        } elsif( $t !~ /^(Web.*|TestForm[123])$/) {
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
    $query->path_info("$testweb/TestTopicXXXXXXXXX");
    $this->assert(
        !$twiki->{store}->topicExists($testweb,'TestTopic0'));
    $twiki = new TWiki( $testuser1, $query );
    TWiki::UI::Save::save($twiki);
    $this->assert(!$twiki->{store}->topicExists($testweb,'TestTopic0'));
    my $seen = 0;
    foreach my $t ($twiki->{store}->getTopicNames( $testweb)) {
        if($t eq 'TestTopicXXXXXXXXX') {
            $seen = 1;
        } elsif( $t !~ /^(Web.*|TestForm[123])$/) {
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
    $query->path_info("/$testweb/TestTopicXXXXXXXXXXX");
    $twiki = new TWiki( $testuser1, $query );
    TWiki::UI::Save::save($twiki);
    my $seen = 0;
    foreach my $t ($twiki->{store}->getTopicNames( $testweb)) {
        if($t eq 'TestTopic0') {
            $seen = 1;
        } elsif( $t !~ /^(Web.*|TestForm[123])$/) {
            $this->assert(0, $t);
        }
    }
    $this->assert($seen);
}

sub detest_emptySave {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query );
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/^\s*$/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub detest_simpleTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query );
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/CORRECT/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub detest_templateTopicTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'Template Topic' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.TemplateTopic' ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    $query = new CGI({
                         templatetopic => [ 'TemplateTopic' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query );
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_null($meta->get('FORM'));
}

# Save over existing topic
sub detest_prevTopicTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'WRONG' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    $query = new CGI({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/CORRECT/, $text);
    $this->assert_null($meta->get('FORM'));
}

# Save over existing topic with no text (get defult from prev topic)
sub detest_prevTopicEmptyTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    $query = new CGI({
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/^CORRECT\s*$/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub detest_simpleFormSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'CORRECT' ],
                         formtemplate => [ 'TestForm1' ],
                         action => [ 'save' ],
                         TWiki::Form::cgiName(undef,'Textfield') =>
                         [ 'Flintstone' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    $this->assert($twiki->{store}->topicExists($testweb, $testtopic));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/^CORRECT\s*$/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    # field default values should be all ''
    $this->assert_str_equals('Flintstone', $meta->get('FIELD', 'Textfield' )->{value});
}

sub detest_templateTopicFormSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'Template Topic' ],
                         formtemplate => [ 'TestForm1' ],
                         TWiki::Form::cgiName(undef,'Select') =>
                         [ 'Value_1' ],
                         TWiki::Form::cgiName(undef,'Textfield') =>
                         [ 'Fred' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.TemplateTopic' ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);

    my($xmeta, $xtext) = $twiki->{store}->readTopic(undef, $testweb, 'TemplateTopic');
    $query = new CGI({
                         templatetopic => [ 'TemplateTopic' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});

    $this->assert_str_equals('Value_1', $meta->get('FIELD', 'Select' )->{value});
    $this->assert_str_equals('Fred', $meta->get('FIELD', 'Textfield' )->{value});
}

sub detest_prevTopicFormSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'Template Topic' ],
                         formtemplate => [ 'TestForm1' ],
                         TWiki::Form::cgiName(undef,'Select') =>
                         [ 'Value_1' ],
                         TWiki::Form::cgiName(undef,'Textfield') =>
                         [ 'Rubble' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    $query = new CGI({
                      action => [ 'save' ],
                      TWiki::Form::cgiName(undef,'Textfield') =>
                      [ 'Barney' ],
                      topic => [ $testweb.'.'.$testtopic ]
                     });
    $twiki = new TWiki( $testuser1, $query );
    TWiki::UI::Save::save($twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    $this->assert_str_equals('Value_1', $meta->get('FIELD','Select')->{value});
    $this->assert_str_equals('Barney', $meta->get('FIELD','Textfield')->{value});
}

#Mergeing is only enabled if the topic text comes from =text= and =originalrev= is &gt; 0 and is not the same as the revision number of the most recent revision. If mergeing is enabled both the topic and the meta-data are merged.

sub test_simpleFormSave1 {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'save' ],
			 text   => [ $testtext1 ],
                         formtemplate => [ 'TestForm1' ],
                         TWiki::Form::cgiName(undef,'Select') => [ 'Value_2' ],
                         TWiki::Form::cgiName(undef,'Radio') => [ '3' ],
                         TWiki::Form::cgiName(undef,'Checkbox') => [ 'red' ],
                         TWiki::Form::cgiName(undef,'CheckboxandButtons') => [ 'hamster' ],
                         TWiki::Form::cgiName(undef,'Textfield') => [ 'Test' ],
			 topic  => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    $this->assert($twiki->{store}->topicExists($testweb, $testtopic));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    $this->assert_str_equals('Test', $meta->get('FIELD', 'Textfield' )->{value});

}

# Field values that do not have a corresponding definition in form
# are deleted.
sub test_simpleFormSave2 {
    my $this = shift;
    $twiki = new TWiki();
    $user = $twiki->{user};
    my $oldmeta = new TWiki::Meta( $twiki, $testweb, $testtopic);
    my $oldtext = $testtext1;
    $twiki->{store}->extractMetaData( $oldmeta, \$oldtext );
    $twiki->{store}->saveTopic( $user, $testweb, $testtopic,
                                $testform1, $oldmeta );
    my $query = new CGI({
                         action => [ 'save' ],
			 text   => [ $testtext1 ],
                         formtemplate => [ 'TestForm3' ],
                         TWiki::Form::cgiName(undef,'Select') => [ 'Value_2' ],
                         TWiki::Form::cgiName(undef,'Radio') => [ '3' ],
                         TWiki::Form::cgiName(undef,'Checkbox') => [ 'red' ],
                         TWiki::Form::cgiName(undef,'CheckboxandButtons') => [ 'hamster' ],
                         TWiki::Form::cgiName(undef,'Textfield') => [ 'Test' ],
			 topic  => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    $this->assert($twiki->{store}->topicExists($testweb, $testtopic));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_str_equals('TestForm3', $meta->get('FORM')->{name});
    $this->assert_str_equals('Test', $meta->get('FIELD', 'Textfield' )->{value});
    $this->assert_null($meta->get('FIELD', 'CheckboxandButtons' ));
}

# meta data (other than FORM, FIELD, TOPICPARENT, etc., is preserved
# during saves.
sub test_simpleFormSave3 {
    my $this = shift;
    $twiki = new TWiki();
    $user = $twiki->{user};
    my $oldmeta = new TWiki::Meta( $twiki, $testweb, $testtopic);
    my $oldtext = $testtext1;
    $twiki->{store}->extractMetaData( $oldmeta, \$oldtext );
    $twiki->{store}->saveTopic( $user, $testweb, $testtopic,
                                $testform1, $oldmeta );
    my $query = new CGI({
                         action => [ 'save' ],
			 text   => [ $testtext1 ],
                         formtemplate => [ 'TestForm1' ],
                         TWiki::Form::cgiName(undef,'Select') => [ 'Value_2' ],
                         TWiki::Form::cgiName(undef,'Radio') => [ '3' ],
                         TWiki::Form::cgiName(undef,'Checkbox') => [ 'red' ],
                         TWiki::Form::cgiName(undef,'CheckboxandButtons') => [ 'hamster' ],
                         TWiki::Form::cgiName(undef,'Textfield') => [ 'Test' ],
			 topic  => [ $testweb.'.'.$testtopic ]
                        });
    $twiki = new TWiki( $testuser1, $query);
    TWiki::UI::Save::save($twiki);
    $this->assert($twiki->{store}->topicExists($testweb, $testtopic));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    $this->assert_str_equals('UserTopic', $meta->get('PREFERENCE', 'VIEW_TEMPLATE' )->{value});

}


1;
