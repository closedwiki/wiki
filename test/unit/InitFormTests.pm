use strict;

package InitFormTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::UI::Edit;
use TWiki::Form;
use CGI;
use Error qw( :try );

my $testweb = "TestWeb";
my $testtopic1 = "InitTestTopic1";
my $testtopic2 = "InitTestTopic2";
my $testform = "InitTestForm";
my $testtmpl = "InitTestTemplate";

my $twiki;
my $user;
my $testuser1 = "TestUser1";
my $testuser2 = "TestUser2";

my $aurl; # Holds the %ATTACHURL%
my $surl;# Holds the %SCRIPTURL%

my $testtmpl1 = <<'HERE';
%META:TOPICINFO{author="TWikiGuest" date="1124568292" format="1.1" version="1.2"}%

-- Main.TWikiGuest - 20 Aug 2005

%META:FORM{name="$testform"}%
%META:FIELD{name="IssueName" attributes="M" title="Issue Name" value="_An issue_"}%
%META:FIELD{name="IssueDescription" attributes="" title="Issue Description" value="---+ Example problem"}%
%META:FIELD{name="IssueType" attributes="" title="Issue Type" value="Defect"}%
%META:FIELD{name="History1" attributes="" title="History1" value="%SCRIPTURL%"}%
%META:FIELD{name="History2" attributes="" title="History2" value="%SCRIPTURL%"}%
%META:FIELD{name="History3" attributes="" title="History3" value="%<nop>SCRIPTURL%"}%
%META:FIELD{name="History4" attributes="" title="History4" value="%<nop>SCRIPTURL%"}%
HERE

my $testform1 = <<'HERE';
%META:TOPICINFO{author="guest" date="1025373031" format="1.0" version="1.3"}%
%META:TOPICPARENT{name="WebHome"}%
| *Name* | *Type* | *Size* | *Values* | *Tooltip messages* | *Mandatory* | 
| Issue Name | text | 73 | My first defect | Illustrative name of issue | M | 
| Issue Description | textarea | 55x5 | Simple description of problem | Short description of issue |  | 
| Issue Type | select | 1 | Defect, Enhancement, Other |  |  | 
| History1 | label | 1 | %ATTACHURL%	         	 |  | |
| History2 | text | 20 | %ATTACHURL%		         |  | |
| History3 | label | 1 | %<nop>ATTACHURL%		 |  | |
| History4 | text | 20 | %<nop>ATTACHURL%		 |  | |

HERE

my $testtext1 = <<'HERE';
%META:TOPICINFO{author="TWikiGuest" date="1159721050" format="1.1" reprev="1.3" version="1.3"}%
Needs the following
   * TestFormInitFormA - Form to be attached
Then call <a href="%SCRIPTURL{"edit"}%/%WEB%/%TOPIC%?formtemplate=$testform">Edit</a>

HERE

my $testtext2 = <<'HERE';
%META:TOPICINFO{author="TWikiGuest" date="1159721050" format="1.1" reprev="1.3" version="1.3"}%
Needs the following
   * TestFormInitFormA - Form to be attached
Then call <a href="%SCRIPTURL{"edit"}%/%WEB%/%TOPIC%?formtemplate=$testform">Edit</a>

%META:FORM{name="$testform"}%
%META:FIELD{name="IssueName" attributes="M" title="Issue Name" value="_An issue_"}%
%META:FIELD{name="IssueDescription" attributes="" title="Issue Description" value="---+ Example problem"}%
%META:FIELD{name="IssueType" attributes="" title="Issue Type" value="Defect"}%
%META:FIELD{name="History1" attributes="" title="History1" value="%SCRIPTURL%"}%
%META:FIELD{name="History2" attributes="" title="History2" value="%SCRIPTURL%"}%
%META:FIELD{name="History3" attributes="" title="History3" value="%<nop>SCRIPTURL%"}%
%META:FIELD{name="History4" attributes="" title="History4" value="%<nop>SCRIPTURL%"}%
HERE

my $edittmpl1 = <<'HERE';
%FORMFIELDS%
HERE

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $twiki = new TWiki();
    $user = $twiki->{user};

    $aurl = $twiki->getPubUrl(1, $testweb, $testform);
    $surl = $twiki->getScriptUrl(1);

    $twiki->{store}->createWeb($user, $testweb);


    $TWiki::Plugins::SESSION = $twiki;
    TWiki::Func::saveTopicText( $testweb, $testtopic1, $testtext1, 1, 1 );
    TWiki::Func::saveTopicText( $testweb, $testtopic2, $testtext2, 1, 1 );
    TWiki::Func::saveTopicText( $testweb, $testform, $testform1, 1, 1 );
    TWiki::Func::saveTopicText( $testweb, $testtmpl, $testtmpl1, 1, 1 );
    TWiki::Func::saveTopicText( $testweb, "MyeditTemplate", $edittmpl1, 1, 1 );
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($twiki, $testweb);
    $this->SUPER::tear_down();
}

# The right form values are created

sub get_formfield {
  my ($fld, @children) = @_;
  # Return HTML for field number $fld (an integer); the header row is 0
  my $form = (($children[$fld]->content_list())[1]->content_list())[0]->as_HTML();
  $form =~ s/\s*tabindex=\d+//gos;  # get rid of tabindex
  return $form;
}

sub setup_formtests {
  my ( $web, $topic, $params ) = @_;

  $twiki->{webName} = $web;
  $twiki->{topicName} = $topic;
  my $render = $twiki->{renderer};

  use TWiki::Attrs;
  my $attr = new TWiki::Attrs( $params );
  foreach my $k ( keys %$attr ) {
    next if $k eq '_RAW';
    $twiki->{cgiQuery}->param( -name=>$k, -value=>$attr->{$k});
  }

  # Now generate the form. We pass a template which throws everything away
  # but the form to allow for simpler analysis.
  my ( $text, $tmpl ) = TWiki::UI::Edit::init_edit( $twiki, 'myedit' );

  eval 'use HTML::TreeBuilder; use HTML::Element;';
  if( $@ ) {
    print STDERR "$@\nUNABLE TO RUN TEST\n";
    return;
  }

  return HTML::TreeBuilder->new_from_content($tmpl);

}

sub test_edit1 {
  my $this = shift;
  
  my $tree = setup_formtests( $testweb, $testtopic1, "formtemplate=\"$testweb.$testform\"" );

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 type="text" value="My first defect">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5>
Simple description of problem</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option>Defect</option><option>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $aurl . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 type="text" value="' . $aurl . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%ATTACHURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 type="text" value="%ATTACHURL%">
', get_formfield(7, @children));

}

sub test_edit2 {
  # Pass formTemplate and templateTopic
  my $this = shift;
  
  my $tree = setup_formtests( $testweb, $testtopic1, "formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\"" );

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 type="text" value="My first defect">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5>
Simple description of problem</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option>Defect</option><option>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $aurl . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 type="text" value="' . $aurl . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%ATTACHURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 type="text" value="%ATTACHURL%">
', get_formfield(7, @children));

}

sub test_edit3 {
  # Pass formTemplate and templateTopic to empty topic
  my $this = shift;
  
  my $tree = setup_formtests( $testweb, "${testtopic1}XXXXXXXXXX", "formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\"" );

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 type="text" value="_An issue_">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5>
---+ Example problem</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option selected>Defect</option><option>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $surl . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 type="text" value="' . $surl . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%SCRIPTURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 type="text" value="%SCRIPTURL%">
', get_formfield(7, @children));

}

sub test_edit4 {
  # Pass formTemplate and templateTopic to empty topic
  my $this = shift;
  
  my $tree = setup_formtests( $testweb, "$testtopic2", "formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\"" );

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 type="text" value="_An issue_">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5>
---+ Example problem</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option selected>Defect</option><option>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $surl . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 type="text" value="' . $surl . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%SCRIPTURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 type="text" value="%SCRIPTURL%">
', get_formfield(7, @children));

}

sub test_edit5 {
  # Pass query parameters
  my $this = shift;
  
  my $tree = setup_formtests( $testweb, "$testtopic1", "formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\" IssueName=\"_An issue_\" IssueDescription=\"---+ Example problem\" IssueType=\"Defect\" History1=\"%SCRIPTURL%\" History2=\"%SCRIPTURL%\" History3=\"%<nop>SCRIPTURL%\" History4=\"%<nop>SCRIPTURL%\" " );

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 type="text" value="_An issue_">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5>
---+ Example problem</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option selected>Defect</option><option>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $surl . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 type="text" value="' . $surl . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%SCRIPTURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 type="text" value="%SCRIPTURL%">
', get_formfield(7, @children));

}

sub test_edit6 {
  # Pass query parameters, with field values present
  my $this = shift;
  
  my $tree = setup_formtests( $testweb, "$testtopic2", "formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\" IssueName=\"My first defect\" IssueDescription=\"Simple description of problem\" IssueType=\"Enhancement\" History1=\"%ATTACHURL%\" History2=\"%ATTACHURL%\" History3=\"%<nop>ATTACHURL%\" History4=\"%<nop>ATTACHURL%\" " );

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 type="text" value="My first defect">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5>
Simple description of problem</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option>Defect</option><option selected>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $aurl . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 type="text" value="' . $aurl . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%ATTACHURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 type="text" value="%ATTACHURL%">
', get_formfield(7, @children));

}

sub test_edit7 {
  # Pass query parameters, new topic
  my $this = shift;
  
  my $tree = setup_formtests( $testweb, "${testtopic1}XXXXXXXXXX", "formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\" IssueName=\"My first defect\" IssueDescription=\"Simple description of problem\" IssueType=\"Enhancement\" History1=\"%ATTACHURL%\" History2=\"%ATTACHURL%\" History3=\"%<nop>ATTACHURL%\" History4=\"%<nop>ATTACHURL%\" " );

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 type="text" value="My first defect">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5>
Simple description of problem</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option>Defect</option><option selected>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $aurl . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 type="text" value="' . $aurl . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%ATTACHURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 type="text" value="%ATTACHURL%">
', get_formfield(7, @children));

}

sub test_edit8 {
  # Pass query parameters, no text
  my $this = shift;
  
  my $tree = setup_formtests( $testweb, "", "formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\" IssueName=\"My first defect\" IssueDescription=\"Simple description of problem\" IssueType=\"Enhancement\" History1=\"%ATTACHURL%\" History2=\"%ATTACHURL%\" History3=\"%<nop>ATTACHURL%\" History4=\"%<nop>ATTACHURL%\" text=\"\"" );

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 type="text" value="My first defect">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5>
Simple description of problem</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option>Defect</option><option selected>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $aurl . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 type="text" value="' . $aurl . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%ATTACHURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 type="text" value="%ATTACHURL%">
', get_formfield(7, @children));

}

1;
