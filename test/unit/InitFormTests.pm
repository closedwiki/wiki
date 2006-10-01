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
my $testtopic = "TestTopic";
my $testform = "TestForm";

my $twiki;
my $user;
my $testuser1 = "TestUser1";
my $testuser2 = "TestUser2";

my $testform1 = <<'HERE';
%META:TOPICINFO{author="guest" date="1025373031" format="1.0" version="1.3"}%
%META:TOPICPARENT{name="WebHome"}%
| *Name* | *Type* | *Size* | *Values* | *Tooltip messages* | *Mandatory* | 
| Issue Name | text | 73 |  | Illustrative name of issue | M | 
| Issue Description | textarea | 55x5 |  | Short description of issue |  | 
| Issue Type | select | 1 | , Defect, Enhancement, Other |  |  | 
| History1 | label | 1 | %ATTACHURL%	         	 |  | |
| History2 | text | 20 | %ATTACHURL%		         |  | |
| History3 | label | 1 | %<nop>ATTACHURL%		 |  | |
| History4 | text | 20 | %<nop>ATTACHURL%		 |  | |

HERE

my $testtext1 = <<'HERE';
%META:TOPICINFO{author="TWikiGuest" date="1159721050" format="1.1" reprev="1.3" version="1.3"}%
Needs the following
   * TestFormInitFormA - Form to be attached
Then call <a href="%SCRIPTURL{"edit"}%/%WEB%/%TOPIC%?formtemplate=TestForm">Edit</a>

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

    $twiki->{store}->createWeb($user, $testweb);

    $TWiki::Plugins::SESSION = $twiki;
    TWiki::Func::saveTopicText( $testweb, $testtopic, $testtext1, 1, 1 );
    TWiki::Func::saveTopicText( $testweb, $testform, $testform1, 1, 1 );
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
  return (($children[$fld]->content_list())[1]->content_list())[0]->as_HTML()
}

sub test_edit1 {
  my $this = shift;
  $twiki->{webName} = $testweb;
  $twiki->{topicName} = $testtopic;
  my $render = $twiki->{renderer};

  $twiki->{cgiQuery}->param( -name=>"formtemplate", -value=>"$testweb.$testform");

  # Now generate the form. We pass a template which throws everything away
  # but the form to allow for simpler analysis.
  my ( $text, $tmpl ) = TWiki::UI::Edit::init_edit( $twiki, 'myedit' );

  eval 'use HTML::TreeBuilder; use HTML::Element;';
  if( $@ ) {
    print STDERR "$@\nUNABLE TO RUN TEST\n";
    return;
  }

  my $tree = HTML::TreeBuilder->new_from_content($tmpl);

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  @children = $children[1]->content_list();
  @children = $children[0]->content_list();
  @children = $children[0]->content_list();

  # Now we found the form!
  # 0 is the header of the form
  # 1...n are the rows, each has title (0) and value (1)

  $this->assert_str_equals('<input class="twikiEditFormTextField" name="IssueName" size=73 tabindex=1 type="text">
', get_formfield(1, @children));
  $this->assert_str_equals('<textarea class="twikiEditFormTextAreaField" cols=55 name="IssueDescription" rows=5 tabindex=2>
</textarea>
', get_formfield(2, @children));
  $this->assert_str_equals('<select name="IssueType" size=1><option></option><option>Defect</option><option>Enhancement</option><option>Other</option></select>
', get_formfield(3, @children));
  my $url = $twiki->getPubUrl(1, $testweb, $testform);
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History1" type="hidden" value="' . $url . '">
', get_formfield(4, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History2" size=20 tabindex=3 type="text" value="' . $url . '">
', get_formfield(5, @children));
  $this->assert_str_equals('<input class="twikiEditFormLabelField" name="History3" type="hidden" value="%ATTACHURL%">
', get_formfield(6, @children));
  $this->assert_str_equals('<input class="twikiEditFormTextField" name="History4" size=20 tabindex=4 type="text" value="%ATTACHURL%">
', get_formfield(7, @children));

}

1;
