use strict;

package SaveScriptTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::UI::Save;
use CGI;
use Error qw( :try );

my $testweb = "TemporarySaveScriptTestsWeb";
my $testusersweb = "TemporarySaveScriptTestsUsersWeb";

my $twiki;
my $testuser1;
my $testuser2;

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

my $testform3 = <<'HERE';
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
| Select | select | 1 | Value_1, Value_2, *Value_3* |  |
| Radio | radio | 3 | 1, 2, 3 | |
| Checkbox | checkbox | 3 | red,blue,green | |
| Textfield | text | 60 | test | |
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

my $testtext_nometa = <<'HERE';

A guest of this TWiki web, not unlike yourself. You can leave your trace behind you, just add your name in %TWIKIWEB%.TWikiRegistration and create your own page.

HERE

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $TWiki::cfg{UsersWebName} = $testusersweb;

    $twiki = new TWiki();

    $twiki->{store}->createWeb($twiki->{user}, $testusersweb);

    $testuser1 = $twiki->{users}->findUser($this->createFakeUser($twiki));
    $testuser2 = $twiki->{users}->findUser($this->createFakeUser($twiki));

    $twiki->{store}->createWeb($testuser1, $testweb);

	$twiki->{store}->saveTopic( $testuser1, $testweb, 'TestForm1',
                                $testform1, undef );

	$twiki->{store}->saveTopic( $testuser2, $testweb, 'TestForm2',
                                $testform2, undef );

	$twiki->{store}->saveTopic( $testuser1, $testweb, 'TestForm3',
                                $testform3, undef );

	$twiki->{store}->saveTopic(
        $testuser2, $testweb, $TWiki::cfg{WebPrefsTopicName},
                                '
   * Set WEBFORMS = TestForm1,TestForm2,TestForm3
', undef );

    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($twiki, $testweb);
    $this->removeWebFixture($twiki, $testusersweb);
    $this->SUPER::tear_down();
}

# 10X
sub test_XXXXXXXXXX {
    my $this = shift;
    my $query = new CGI({
        action => [ 'save' ],
        text => [ 'nowt' ],
    });
    $query->path_info( $testweb.'.TestTopicXXXXXXXXXX' );
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    my $seen = 0;
    foreach my $t ($twiki->{store}->getTopicNames( $testweb)) {
        if($t eq 'TestTopic0') {
            $seen = 1;
        } elsif( $t !~ /^(Web.*|TestForm[123])$/) {
            $this->assert(0, $t);
        }
    }
    $this->assert($seen);
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki);
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
        text => [ 'nowt' ],
    });
    $query->path_info("$testweb/TestTopicXXXXXXXXX");
    $this->assert(
        !$twiki->{store}->topicExists($testweb,'TestTopic0'));
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki);
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
        text => [ 'nowt' ],
    });
    $query->path_info("/$testweb/TestTopicXXXXXXXXXXX");
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki);
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

sub test_emptySave {
    my $this = shift;
    my $query = new CGI({
        action => [ 'save' ],
        topic => [ $testweb.'.EmptyTestSaveScriptTopic' ]
       });
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                  'EmptyTestSaveScriptTopic');
    $this->assert_matches(qr/^\s*$/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub test_simpleTextSave {
    my $this = shift;
    my $query = new CGI({
        text => [ 'CORRECT' ],
        action => [ 'save' ],
        topic => [ $testweb.'.DeleteTestSaveScriptTopic' ]
       });
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                 'DeleteTestSaveScriptTopic');
    $this->assert_matches(qr/CORRECT/, $text);
    $this->assert_null($meta->get('FORM'));
}

sub test_templateTopicTextSave {
    my $this = shift;
    my $query = new CGI({
        text => [ 'Template Topic' ],
        action => [ 'save' ],
        topic => [ $testweb.'.TemplateTopic' ]
       });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    $query = new CGI({
        templatetopic => [ 'TemplateTopic' ],
        action => [ 'save' ],
        topic => [ $testweb.'.TemplateTopic' ]
       });
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'TemplateTopic');
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_null($meta->get('FORM'));
}

# Save over existing topic
sub test_prevTopicTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'WRONG' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.PrevTopicTextSave' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    $query = new CGI({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.PrevTopicTextSave' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'PrevTopicTextSave');
    $this->assert_matches(qr/CORRECT/, $text);
    $this->assert_null($meta->get('FORM'));
}

# Save over existing topic with no text
sub test_prevTopicEmptyTextSave {
    my $this = shift;
    my $query = new CGI({
                         text => [ 'CORRECT' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.PrevTopicEmptyTextSave' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    $query = new CGI({
                         action => [ 'save' ],
                         topic => [ $testweb.'.PrevTopicEmptyTextSave' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'PrevTopicEmptyTextSave');
    $this->assert_matches(qr/^\s*CORRECT\s*$/, $text);
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
                         topic => [ $testweb.'.SimpleFormSave' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    $this->assert($twiki->{store}->topicExists($testweb, 'SimpleFormSave'));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'SimpleFormSave');
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
                         topic => [ $testweb.'.TemplateTopic' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);

    my($xmeta, $xtext) = $twiki->{store}->readTopic(undef, $testweb, 'TemplateTopic');
    $query = new CGI({
                         templatetopic => [ 'TemplateTopic' ],
                         action => [ 'save' ],
                         topic => [ $testweb.'.TemplateTopicAgain' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                  'TemplateTopicAgain');
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
                         topic => [ $testweb.'.PrevTopicFormSave' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    $query = new CGI({
                      action => [ 'save' ],
                      TWiki::Form::cgiName(undef,'Textfield') =>
                      [ 'Barney' ],
                      topic => [ $testweb.'.PrevTopicFormSave' ]
                     });
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'PrevTopicFormSave');
    $this->assert_matches(qr/Template Topic/, $text);
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    $this->assert_str_equals('Value_1', $meta->get('FIELD','Select')->{value});
    $this->assert_str_equals('Barney', $meta->get('FIELD','Textfield')->{value});
}

sub test_simpleFormSave1 {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'save' ],
			 text   => [ $testtext_nometa ],
                         formtemplate => [ 'TestForm1' ],
                         TWiki::Form::cgiName(undef,'Select') => [ 'Value_2' ],
                         TWiki::Form::cgiName(undef,'Radio') => [ '3' ],
                         TWiki::Form::cgiName(undef,'Checkbox') => [ 'red' ],
                         TWiki::Form::cgiName(undef,'CheckboxandButtons') => [ 'hamster' ],
                         TWiki::Form::cgiName(undef,'Textfield') => [ 'Test' ],
			 topic  => [ $testweb.'.SimpleFormTopic' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    $this->assert($twiki->{store}->topicExists($testweb, 'SimpleFormTopic'));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'SimpleFormTopic');
    $this->assert_str_equals('TestForm1', $meta->get('FORM')->{name});
    $this->assert_str_equals('Test', $meta->get('FIELD', 'Textfield' )->{value});

}

# Field values that do not have a corresponding definition in form
# are deleted.
sub test_simpleFormSave2 {
    my $this = shift;
    $twiki = new TWiki();

    my $oldmeta = new TWiki::Meta( $twiki, $testweb, 'SimpleFormSave2');
    my $oldtext = $testtext1;
    $twiki->{store}->extractMetaData( $oldmeta, \$oldtext );
    $twiki->{store}->saveTopic( $testuser1, $testweb, 'SimpleFormSave2',
                                $testform1, $oldmeta );
    my $query = new CGI({
                         action => [ 'save' ],
			 text   => [ $testtext_nometa ],
                         formtemplate => [ 'TestForm3' ],
                         TWiki::Form::cgiName(undef,'Select') => [ 'Value_2' ],
                         TWiki::Form::cgiName(undef,'Radio') => [ '3' ],
                         TWiki::Form::cgiName(undef,'Checkbox') => [ 'red' ],
                         TWiki::Form::cgiName(undef,'CheckboxandButtons') => [ 'hamster' ],
                         TWiki::Form::cgiName(undef,'Textfield') => [ 'Test' ],
			 topic  => [ $testweb.'.SimpleFormSave2' ]
                        });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    $this->assert($twiki->{store}->topicExists($testweb, 'SimpleFormSave2'));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'SimpleFormSave2');
    $this->assert_str_equals('TestForm3', $meta->get('FORM')->{name});
    $this->assert_str_equals('Test', $meta->get('FIELD', 'Textfield' )->{value});
    $this->assert_null($meta->get('FIELD', 'CheckboxandButtons' ));
}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is preserved
# during saves.
sub test_simpleFormSave3 {
    my $this = shift;
    $twiki = new TWiki();

    my $oldmeta = new TWiki::Meta( $twiki, $testweb, 'SimpleFormSave3');
    my $oldtext = $testtext1;
    $twiki->{store}->extractMetaData( $oldmeta, \$oldtext );
    $twiki->{store}->saveTopic( $testuser1, $testweb, 'SimpleFormSave3',
                                $testform1, $oldmeta );
    my $query = new CGI(
        {
            action => [ 'save' ],
            text   => [ $testtext_nometa ],
            formtemplate => [ 'TestForm1' ],
            TWiki::Form::cgiName(undef,'Select') => [ 'Value_2' ],
            TWiki::Form::cgiName(undef,'Radio') => [ '3' ],
            TWiki::Form::cgiName(undef,'Checkbox') => [ 'red' ],
            TWiki::Form::cgiName(undef,'CheckboxandButtons') => [ 'hamster' ],
            TWiki::Form::cgiName(undef,'Textfield') => [ 'Test' ],
            topic  => [ $testweb.'.SimpleFormSave3' ]
           });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);
    $this->assert($twiki->{store}->topicExists($testweb, 'SimpleFormSave3'));
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'SimpleFormSave3');
    $this->assert_str_equals('UserTopic', $meta->get('PREFERENCE', 'VIEW_TEMPLATE' )->{value});

}

# meta data (other than FORM, FIELD, TOPICPARENT, etc.) is inherited from
# templatetopic
sub test_templateTopicWithMeta {
    my $this = shift;

    TWiki::Func::saveTopicText($testweb,"TemplateTopic",$testtext1);
    my $query = new CGI(
        {
            templatetopic => [ 'TemplateTopic' ],
            action => [ 'save' ],
            topic => [ $testweb.'.TemplateTopicWithMeta' ]
           });
    $twiki = new TWiki( $testuser1->login(), $query );
    $this->capture( \&TWiki::UI::Save::save, $twiki );
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, 'TemplateTopicWithMeta');
    my $pref = $meta->get( 'PREFERENCE', 'VIEW_TEMPLATE' );
    $this->assert_not_null($pref);
    $this->assert_str_equals('UserTopic', $pref->{value});
}

#Mergeing is only enabled if the topic text comes from =text= and =originalrev= is &gt; 0 and is not the same as the revision number of the most recent revision. If mergeing is enabled both the topic and the meta-data are merged.

sub test_merge {
    my $this = shift;
    $twiki = new TWiki();

    my $oldmeta = new TWiki::Meta( $twiki, $testweb, 'MergeSave');
    my $oldtext = $testtext1;
    $twiki->{store}->extractMetaData( $oldmeta, \$oldtext );
    $twiki->{store}->saveTopic( $testuser2, $testweb, 'MergeSave',
                                $testform1, $oldmeta );
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                  'MergeSave');
    my( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    my $original = "${orgRev}_$orgDate";

    my $query1 = new CGI(
        {
            action => [ 'save' ],
            text   => [ "Soggy bat" ],
            originalrev => $original,
            formtemplate => [ 'TestForm1' ],
            TWiki::Form::cgiName(undef,'Select') => [ 'Value_2' ],
            TWiki::Form::cgiName(undef,'Radio') => [ '3' ],
            TWiki::Form::cgiName(undef,'Checkbox') => [ 'red' ],
            TWiki::Form::cgiName(undef,'CheckboxandButtons') => [ 'hamster' ],
            TWiki::Form::cgiName(undef,'Textfield') => [ 'Bat' ],
            topic  => [ $testweb.'.MergeSave' ]
           });
    $twiki = new TWiki( $testuser1->login(), $query1);
    $this->capture( \&TWiki::UI::Save::save, $twiki);

    ($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                  'MergeSave');
    ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    my $query2 = new CGI(
        {
            action => [ 'save' ],
            text   => [ "Wet rat" ],
            originalrev => $original,
            formtemplate => [ 'TestForm1' ],
            TWiki::Form::cgiName(undef,'Select') => [ 'Value_2' ],
            TWiki::Form::cgiName(undef,'Radio') => [ '3' ],
            TWiki::Form::cgiName(undef,'Checkbox') => [ 'red' ],
            TWiki::Form::cgiName(undef,'CheckboxandButtons') => [ 'hamster' ],
            TWiki::Form::cgiName(undef,'Textfield') => [ 'Rat' ],
            topic  => [ $testweb.'.MergeSave' ]
           });
    $twiki = new TWiki( $testuser2->login(), $query2);
    try {
        $this->capture( \&TWiki::UI::Save::save, $twiki);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals('merge_notice', $e->{def});
    } otherwise {
        $this->assert(0, shift);
    };
    ($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                  'MergeSave');
    my $e = <<'END';
<div class="twikiConflict"><b>CONFLICT</b> original 1:</div>
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* |
<div class="twikiConflict"><b>CONFLICT</b> version 2:</div>
Soggy bat
<div class="twikiConflict"><b>CONFLICT</b> version new:</div>
Wet rat
<div class="twikiConflict"><b>CONFLICT</b> end</div>
END
    $this->assert_str_equals($e, $text);

    my $v = $meta->get('FIELD', 'Select');
    $this->assert_str_equals('Value_2', $v->{value});
    $v = $meta->get('FIELD', 'Radio');
    $this->assert_str_equals('3', $v->{value});
    $v = $meta->get('FIELD', 'Checkbox');
    $this->assert_str_equals('red', $v->{value});
    $v = $meta->get('FIELD', 'CheckboxandButtons');
    $this->assert_str_equals('hamster', $v->{value});
    $v = $meta->get('FIELD', 'Textfield');
    $this->assert_str_equals('<del>Bat</del><ins>Rat</ins>', $v->{value});
}

# test interaction with reprev. Testcase:
#
# 1. A edits and saves (rev 1 now on disc)
# 2. B hits the EDIT button. (originalrev=1)
# 3. A hits the EDIT button. (originalrev=1)
# 5. A saves the SimultaneousEdit (repRevs rev 1)
# 6. B saves the SimultaneousEdit (no change, so no merge)
#

sub test_1897 {
    my $this = shift;

    # make sure we have time to complete the test
    $TWiki::cfg{ReplaceIfEditedAgainWithin} = 7200;

    $twiki = new TWiki();

    my $oldmeta = new TWiki::Meta( $twiki, $testweb, 'MergeSave');
    my $oldtext = $testtext1;
    my $query;
    $twiki->{store}->extractMetaData( $oldmeta, \$oldtext );

    # First, user A saves to create rev 1
    $twiki->{store}->saveTopic( $testuser1, $testweb, 'MergeSave',
                                "Smelly\ncat", $oldmeta );
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                  'MergeSave');
    my( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();

    $this->assert_equals(1, $orgRev);
    $this->assert_str_equals("Smelly\ncat", $text);

    my $original = "${orgRev}_$orgDate";
    sleep(1); # tick the clock to ensure the date changes

    # A saves again, reprevs to create rev 1 again
    $query = new CGI(
        {
            action => [ 'save' ],
            text   => [ "Sweaty\ncat" ],
            originalrev => $original,
            topic  => [ $testweb.'.MergeSave' ]
           });
    $twiki = new TWiki( $testuser1->login(), $query);
    $this->capture( \&TWiki::UI::Save::save, $twiki);

    # make sure it's still rev 1 as expected
    ($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                'MergeSave');
    ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    $this->assert_equals(1, $orgRev);
    $this->assert_str_equals("Sweaty\ncat\n", $text);

    # User B saves; make sure we get a merge notice.
    $query = new CGI(
        {
            action => [ 'save' ],
            text   => [ "Smelly\nrat" ],
            originalrev => $original,
            topic  => [ $testweb.'.MergeSave' ]
           });
    $twiki = new TWiki( $testuser2->login(), $query);
    try {
        $this->capture( \&TWiki::UI::Save::save, $twiki);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals('merge_notice', $e->{def});
    } otherwise {
        $this->assert(0, shift);
    };

    ($meta, $text) = $twiki->{store}->readTopic(undef, $testweb,
                                                'MergeSave');
    ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
    $this->assert_equals(2, $orgRev);
    $this->assert_str_equals("<del>Sweaty\n</del><ins>Smelly\n</ins><del>cat\n</del><ins>rat\n</ins>", $text);
}

1;
