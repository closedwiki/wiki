use strict;

use TWiki::Contrib::DBCache;
use TWiki::Contrib::Map;

use TWiki::Func;

package DBCacheTest;

my $testweb = "TemporaryTestWebDBCacheContrib";
use base qw(TWikiTestCase);
my $twiki;
sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

my $formTest = <<END;
%META:TOPICPARENT{name="WebHome"}%
CategoryForms
%META:FORM{name="ThisForm"}%
%META:FIELD{name="FieldOne" title="FieldOne" value="Value One"}%
%META:FIELD{name="FieldTwo" title="FieldTwo" value="Value Two"}%
%META:FIELD{name="FieldThree" title="FieldThree" value="7.1"}%
%META:FIELD{name="BackSlash" title="Back Slash" value="One"}%
%META:FILEATTACHMENT{name="conftest.val" attr="" comment="Bangra bingo" date="1091696180" path="conftest.val" size="8" user="guest" version="1.2"}%
"%META:FILEATTACHMENT{name="left.gif" attr="" comment="left arrer" date="1091696102" path="left.gif" size="107" user="guest" version="1.1"}%
"%META:FILEATTACHMENT{name="right.gif" attr="h" comment="" date="1091696127" path="right.gif" size="105" user="guest" version="1.1"}%
"%META:TOPICMOVED{by="guest" date="1091696242" from="$testweb.FormsTest" to="$testweb.FormTest"}%
END

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki( "TestUser1" );

    $twiki->{store}->createWeb($twiki->{user}, $testweb);
    $twiki->{store}->saveTopic( $twiki->{user}, $testweb, "FormTest",
                                $formTest, undef );

    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testweb);
}

sub test_loadSimple {
  my $this = shift;
  my $db = new TWiki::Contrib::DBCache($testweb);
  $this->assert_str_equals("0 2 0", $db->load());
  my $topic = $db->get("WebHome");
  $this->assert($topic);
  my $info = $topic->get("info");
  $this->assert_not_null($info);
  $this->assert_equals($topic, $info->get("_up"));
  $this->assert_str_equals("TestUser1", $info->get("author"));
  $this->assert_str_equals("1.1", $info->get("format"));

  $topic = $db->get("FormTest");
  $this->assert_not_null($topic);
  $info = $topic->get("info");
  $this->assert_not_null($info);
  $this->assert_equals($topic, $info->get("_up"));
  $this->assert_str_equals("TestUser1", $info->get("author"));
  $this->assert_str_equals("1.1", $info->get("format"));
  $this->assert_str_equals("1.1", $info->get("version"));
print STDERR $topic->toString();
  $this->assert_str_equals("WebHome", $topic->get("parent"));
  $this->assert_str_equals("CategoryForms\n\n", $topic->get("text"));
  $this->assert_str_equals("ThisForm", $topic->get("form"));
  my $form = $topic->get("ThisForm");
  $this->assert_not_null($form);
  $this->assert_equals($topic, $form->get("_up"));
  $this->assert_str_equals("Value One", $form->get("FieldOne"));
  $this->assert_str_equals("Value Two", $form->get("FieldTwo"));
  $this->assert_equals(7.1, $form->get("FieldThree"));
  $this->assert_str_equals("One", $form->get("BackSlash"));

  my $atts = $topic->get("attachments");
  $this->assert_not_null($atts);

  my $att = $atts->get("[0]");
  $this->assert_not_null($att);
  $this->assert_equals($topic, $att->get("_up"));
  $this->assert_str_equals("conftest.val", $att->get("name"));
  $this->assert_str_equals("", $att->get("attr"));
  $this->assert_str_equals("Bangra bingo", $att->get("comment"));
  $this->assert_equals("1091696180", $att->get("date"));
  $this->assert_str_equals("conftest.val", $att->get("path"));
  $this->assert_str_equals(8, $att->get("size"));
  $this->assert_str_equals("guest", $att->get("user"));
  $this->assert_equals(1.2, $att->get("version"));

  $att = $atts->get("[1]");
  $this->assert_not_null($att);
  $this->assert_equals($topic, $att->get("_up"));
  $this->assert_str_equals("left.gif", $att->get("name"));
  $this->assert_str_equals("", $att->get("attr"));
  $this->assert_str_equals("left arrer", $att->get("comment"));
  $this->assert_equals(1091696102, $att->get("date"));
  $this->assert_str_equals("left.gif", $att->get("path"));
  $this->assert_str_equals(107, $att->get("size"));
  $this->assert_str_equals("guest", $att->get("user"));
  $this->assert_equals(1.1, $att->get("version"));

  $att = $atts->get("[2]");
  $this->assert_not_null($att);
  $this->assert_equals($topic, $att->get("_up"));
  $this->assert_str_equals("right.gif", $att->get("name"));
  $this->assert_str_equals("h", $att->get("attr"));
  $this->assert_str_equals("", $att->get("comment"));
  $this->assert_equals(1091696127, $att->get("date"));
  $this->assert_str_equals("right.gif", $att->get("path"));
  $this->assert_str_equals(105, $att->get("size"));
  $this->assert_str_equals("guest", $att->get("user"));
  $this->assert_equals(1.1, $att->get("version"));

  my $moved = $topic->get("moved");
  $this->assert_not_null($moved);
  $this->assert_equals($topic, $moved->get("_up"));
  $this->assert_str_equals("guest", $moved->get("by"));
  $this->assert_equals(1091696242, $moved->get("date"));
  $this->assert_str_equals("$testweb.FormsTest", $moved->get("from"));
  $this->assert_str_equals("$testweb.FormTest", $moved->get("to"));
}

sub test_cache {
  my $this = shift;
  my $db = new TWiki::Contrib::DBCache($testweb);
  $this->assert_str_equals($testweb, $db->{_web});
  $this->assert_equals(0, $db->{loaded});

  # There should be no cache there
  $this->assert_str_equals("0 2 0", $db->load());
  $this->assert_equals(1, $db->{loaded});
  $this->assert_str_equals("0 0 0", $db->load());
  my $initial = $db;
  # There's a cache there now
  $db = new TWiki::Contrib::DBCache($testweb);
  $this->assert_equals(0, $db->{loaded});
  $this->assert_str_equals("2 0 0", $db->load());
  $this->assert_equals(1, $db->{loaded});
  $this->assert_str_equals("0 0 0", $db->load());
  $this->checkSameAs($initial,$db);

  sleep(1);# wait for clock tick
  $twiki->{store}->saveTopic( $twiki->{user}, $testweb, "FormTest",
                              $formTest, undef );
  # One file in the cache has been touched
  $db = new TWiki::Contrib::DBCache($testweb);
  $this->assert_str_equals("1 1 0", $db->load());
  $db = new TWiki::Contrib::DBCache($testweb);
  $this->assert_str_equals("2 0 0", $db->load());

  # A new file has been created
  $twiki->{store}->saveTopic( $twiki->{user}, $testweb, "NewFile",
                              "Blah", undef );

  $db = new TWiki::Contrib::DBCache($testweb);
  $this->assert_str_equals("2 1 0", $db->load());

  # One file in the cache has been deleted
  $twiki->{store}->moveTopic($testweb, "FormTest", "Trash", "FormTest$$",
                            $twiki->{user});
  $db = new TWiki::Contrib::DBCache($testweb);
  $this->assert_str_equals("2 0 1", $db->load());

  $twiki->{store}->moveTopic($testweb, "NewFile", "Trash", "NewFile$$",
                            $twiki->{user});
  $twiki->{store}->saveTopic( $twiki->{user}, $testweb, "FormTest",
                              $formTest, undef );
  $db = new TWiki::Contrib::DBCache($testweb);
  $this->assert_str_equals("1 1 1", $db->load());

  $this->checkSameAs($initial, $db);
}

sub checkSameAs {
  my ( $this, $first, $second, $cmping, $checked ) = @_;
  $cmping = "ROOT" unless ( defined($cmping ));
  $checked = {} unless ( defined( $checked ));
  return if ( $checked->{$first} );
  $checked->{$first} = 1;

  my $type = ref($first);

  $this->assert_str_equals($type,ref($second),$cmping);
  if ($type =~ /Map$/ || $type =~ /DBCache$/) {
    $this->checkSameAsMap($first, $second, $cmping, $checked);
  } elsif ($type =~ /Array$/) {
    $this->checkSameAsArray($first, $second, $cmping, $checked);
  } elsif ($type =~ /FileTime$/) {
    $this->checkSameAsFileTime($first, $second, $cmping, $checked);
  } else {
    $this->assert(0,ref($first));
  }
}

sub checkSameAsMap {
  my ( $this, $first, $second, $cmping, $checked ) = @_;

  foreach my $k ($first->getKeys()) {
      next if $k eq "_up";
    my $a = $first->fastget( $k ) || "";
    my $b = $second->fastget( $k ) || "";
    my $c = "$cmping.$k";
    if (ref($a)) {
      $this->checkSameAs($a, $b, $c, $checked );
    } elsif ( $k !~ /^_/ && $c !~ /\.date$/ ) {
      $this->assert_str_equals($a, $b, "$c $a $b");
    }
  }
}

sub checkSameAsArray {
  my ( $this, $first, $second, $cmping, $checked ) = @_;

  $this->assert_equals($first->size(), $second->size(), $cmping);
  my $i = 0;
  foreach my $a (@{$first->{values}}) {
    my $c = "$cmping\[$i\]";
    my $b = $second->get($i++);
    if ( ref( $a )) {
      $this->checkSameAs($a, $b, $c, $checked );
    } else {
      $this->assert_str_equals($a, $b, "$c ($a!=$b)");
    }
  }
}

sub checkSameAsFileTime {
  my ( $this, $first, $second, $cmping, $checked ) = @_;
  $this->assert_str_equals($first->{file}, $second->{file},$cmping);
}

1;
