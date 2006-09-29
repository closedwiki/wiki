use strict;

package RenderFormTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::UI::Save;
use CGI;
use Error qw( :try );

my $testweb = "TestWeb";
my $testtopic = "TestTopic";

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
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($twiki, $testweb);
    $this->SUPER::tear_down();
}

# TML is rendered correctly in form fields
sub test_TML_in_forms {
    my $this = shift;
    my($meta, $text) = $twiki->{store}->readTopic(undef, $testweb, $testtopic);
    my $res = TWiki::Form::renderForDisplay($twiki->{templates},$meta);
    my $render = $twiki->{renderer};
    $res = $render->getRenderedVersion($res, $testweb, $testtopic);

    eval 'use HTML::TreeBuilder; use HTML::Element;';
    if( $@ ) {
        print STDERR "$@\nUNABLE TO RUN TEST\n";
        return;
    }

    my $tree = HTML::TreeBuilder->new_from_content($res);
    # Analyze the tree, could use find_by_tag_name
    my @children = $tree->content_list();
    @children = $children[1]->content_list();
    @children = $children[0]->content_list();
    @children = $children[0]->content_list();
    # Now we have 8 rows
    $text = (($children[0]->content_list())[0]->content_list())[0]->as_HTML();
    $this->assert_str_equals('<span class="twikiNewLink">InitializationForm<a href="' .$twiki->getScriptUrl( 0, "edit", $testweb, "InitializationForm" ) . '?topicparent=Main.WebHome" rel="nofollow" title="Create this topic"><sup>?</sup></a></span>
', $text);
    $text = (($children[1]->content_list())[1]->content_list())[0]->as_HTML();
    $this->assert_str_equals('<em>An issue</em>
', $text);
    $text = (($children[2]->content_list())[1]->content_list())[0]->as_HTML();
    $this->assert_str_equals('<h1><a name="Example_problem"></a> Example problem </h1>
', $text);
    $text = (($children[3]->content_list())[1]->content_list())[0]->as_HTML();
    $this->assert_str_equals('<strong>Defect</strong>
', $text);
    $text = (($children[4]->content_list())[1]->content_list())[0];
    $this->assert_str_equals(' Enhancement ', $text);
    $text = (($children[5]->content_list())[1]->content_list())[0];
    $this->assert_str_equals(' Defect, None ', $text);
    $text = (($children[6]->content_list())[1]->content_list())[0];
    $this->assert_str_equals(' Defect ', $text);
    $text = (($children[7]->content_list())[1]->content_list())[0];
    $this->assert_str_equals(" $testweb.GRRR ", $text);
    $tree->delete;
}

1;
