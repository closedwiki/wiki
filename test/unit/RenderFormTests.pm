use strict;

package RenderFormTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::UI::Save;
use CGI;
use Error qw( :try );

my $testweb = "TestWeb";
my $testtopic1 = "TestTopic1";
my $testtopic2 = "TestTopic2";

my $twiki;
my $user;
my $testuser1 = "TestUser1";
my $testuser2 = "TestUser2";

my $testtext1 = <<'HERE';
%META:TOPICINFO{author="TWikiGuest" date="1124568292" format="1.1" version="1.2"}%

-- Main.TWikiGuest - 20 Aug 2005

%META:FORM{name="InitializationForm"}%
%META:FIELD{name="IssueName" attributes="M" title="Issue Name" value="_An issue_"}%
%META:FIELD{name="IssueDescription" attributes="" title="Issue Description" value="---+ Example problem"}%
%META:FIELD{name="Issue1" attributes="" title="Issue 1" value="*Defect*"}%
%META:FIELD{name="Issue2" attributes="" title="Issue 2" value="Enhancement"}%
%META:FIELD{name="Issue3" attributes="" title="Issue 3" value="Defect, None"}%
%META:FIELD{name="Issue4" attributes="" title="Issue 4" value="Defect"}%
%META:FIELD{name="State" attributes="H" title="State" value="Invisible"}%
%META:FIELD{name="Anothertopic" attributes="" title="Another topic" value="GRRR "}%
HERE

my $testtext2 = <<'HERE';
%META:TOPICINFO{author="TWikiGuest" date="1124568292" format="1.1" version="1.2"}%

-- Main.TWikiGuest - 20 Aug 2005

%META:FORM{name="InitializationForm"}%
%META:FIELD{name="IssueName" attributes="M" title="Issue Name" value="_An issue_"}%
%META:FIELD{name="IssueDescription" attributes="" title="IssueDescription" value="| abc | 123 |%0d%0a| def | ghk |"}%
%META:FIELD{name="Issue1" attributes="" title="Issue1" value="*no web*"}%
%META:FIELD{name="Issue2" attributes="" title="Issue2" value="   * abc%0d%0a   * def%0d%0a      * geh%0d%0a   * ijk"}%
%META:FIELD{name="Issue3" attributes="" title="Issue3" value="_hello world_"}%
%META:FIELD{name="Issue4" attributes="" title="Issue4" value="   * high"}%
%META:FIELD{name="State" attributes="H" title="State" value="Invisible"}%
%META:FIELD{name="Anothertopic" attributes="" title="Another topic" value="GRRR "}%
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
    TWiki::Func::saveTopicText( $testweb, $testtopic1, $testtext1, 1, 1 );
    TWiki::Func::saveTopicText( $testweb, $testtopic2, $testtext2, 1, 1 );
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($twiki, $testweb);
    $twiki->finish();
    $this->SUPER::tear_down();
}

sub get_HTML_tree {
    my ($res) = @_;
    eval 'use HTML::TreeBuilder; use HTML::Element 3.23;';
    if( $@ ) {
        die "$@\nUNABLE TO RUN TEST\n";
    }

    my $tree = HTML::TreeBuilder->new_from_content($res);
    # Analyze the tree, could use find_by_tag_name
    return $tree->content_list();
    $tree->delete;
}

sub get_HTML_tree_from_form {
  return (((get_HTML_tree ( @_ ))[1]->content_list())[0]->content_list())[0]->content_list();
}

sub compare_field_from_form {
  my ($this, $res, $child, @children) = @_;
  my $text = (($children[$child]->content_list())[1]->content_list())[0];
  $this->assert_str_equals($res, $text);
}

sub compare_field_from_form_fmt {
  my ($this, $res, $child, @children) = @_;
  my $text = (($children[$child]->content_list())[1]->content_list())[0]->as_HTML();
  $this->assert_str_equals($res, $text);
}

# TML is rendered correctly in form fields
sub test_TML_in_forms {
    my $this = shift;
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic1);
    my $res = $meta->renderFormForDisplay();
    my $render = $twiki->{renderer};
    $res = $render->getRenderedVersion($res, $testweb, $testtopic1);

    my @children = get_HTML_tree_from_form( $res );
    # Now we have 8 rows
    # first is the header row
    $this->assert_str_equals(((($children[0]->content_list())[0]->content_list())[0]->content_list())[0], 'InitializationForm');
    $this->compare_field_from_form_fmt('<em>An issue</em>
', 1, @children);
    $this->compare_field_from_form_fmt('<h1><a name="Example_problem"></a> Example problem </h1>
', 2, @children);
    $this->compare_field_from_form_fmt('<strong>Defect</strong>
', 3, @children);
    $this->compare_field_from_form(' Enhancement ', 4, @children);
    $this->compare_field_from_form(' Defect, None ', 5, @children);
    $this->compare_field_from_form(' Defect ', 6, @children);
    $this->compare_field_from_form(" $testweb.GRRR ", 7, @children);
}

sub test_formatted_TML_in_forms {
    my $this = shift;
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic2);
    my $res = $meta->renderFormForDisplay();
    my $render = $twiki->{renderer};
    $res = $render->getRenderedVersion($res, $testweb, $testtopic2);

    my @children = get_HTML_tree_from_form( $res );
    # Now we have 8 rows
#### Why is access these fields different from above?
    $this->compare_field_from_form_fmt('<em>An issue</em>
', 1, @children);
    $this->compare_field_from_form_fmt('<table border="1" cellpadding="0" cellspacing="0" class="twikiTable"><tr class="twikiTableEven"><td bgcolor="#ffffff" class="twikiFirstCol" valign="top"> abc </td><td bgcolor="#ffffff" valign="top"> 123 </td></tr><tr class="twikiTableOdd"><td bgcolor="#edf4f9" class="twikiFirstCol twikiLast" valign="top"> def </td><td bgcolor="#edf4f9" class="twikiLast" valign="top"> ghk </td></tr></table>
', 2, @children);
    $this->compare_field_from_form_fmt('<strong>no web</strong>
', 3, @children);
    $this->compare_field_from_form_fmt('<ul><li> abc <li> def <ul><li> geh </ul><li> ijk </ul>
', 4, @children);
    $this->compare_field_from_form_fmt('<em>hello world</em>
', 5, @children);
    $this->compare_field_from_form_fmt('<ul><li> high </ul>
', 6, @children);
  }

sub get_HTML_tree_from_field {
  return (((get_HTML_tree ( @_ ))[1]->content_list())[0]->content_list())[0]->content_list();
}

sub compare_formfield {
  my ($this, $res, $compare) = @_;
  my @children = get_HTML_tree($res);
  my $text = ($children[1]->content_list())[0]->as_HTML();
  $this->assert_str_equals($compare, $text);
}

sub test_render_formfield_raw {

    my $this = shift;
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic2);
    my $render = $twiki->{renderer};
    my $res;

    $res = $render->renderFormField( $meta, new TWiki::Attrs('name="IssueDescription" newline="$n" bar="|"') );
    $res = $render->getRenderedVersion($res, $testweb, $testtopic2);
    $this->compare_formfield($res,'<table border="1" cellpadding="0" cellspacing="0" class="twikiTable"><tr class="twikiTableEven"><td bgcolor="#ffffff" class="twikiFirstCol" valign="top"> abc </td><td bgcolor="#ffffff" valign="top"> 123 </td></tr><tr class="twikiTableOdd"><td bgcolor="#edf4f9" class="twikiFirstCol twikiLast" valign="top"> def </td><td bgcolor="#edf4f9" class="twikiLast" valign="top"> ghk </td></tr></table>
');
    $res = $render->renderFormField( $meta, new TWiki::Attrs('name="Issue1" newline="$n" bar="|"') );
    $res = $render->getRenderedVersion($res, $testweb, $testtopic2);
    $this->compare_formfield($res,'<strong>no web</strong>
');
    $res = $render->renderFormField( $meta, new TWiki::Attrs('name="Issue2" newline="$n" bar="|"') );
    $res = $render->getRenderedVersion($res, $testweb, $testtopic2);
    $this->compare_formfield($res,'<ul><li> abc <li> def <ul><li> geh </ul><li> ijk </ul>
');
    $res = $render->renderFormField( $meta, new TWiki::Attrs('name="Issue3" newline="$n" bar="|"') );
    $res = $render->getRenderedVersion($res, $testweb, $testtopic2);
    $this->compare_formfield($res,'<em>hello world</em>
');
    $res = $render->renderFormField( $meta, new TWiki::Attrs('name="Issue4" newline="$n" bar="|"') );
    $res = $render->getRenderedVersion($res, $testweb, $testtopic2);
    $this->compare_formfield($res,'<ul><li> high </ul>
');
    return 0;

    
}

1;
