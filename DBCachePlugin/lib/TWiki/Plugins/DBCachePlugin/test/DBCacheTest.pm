use strict;

use TWiki::Plugins::DBCachePlugin::DBCache;
use TWiki::Plugins::DBCachePlugin::Map;

use TWiki::Func;

package DBCacheTest;

use base qw(BaseFixture);

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

my $webHome =
"\%META:TOPICINFO{author=\"guest\" date=\"1089644791\" format=\"1.0\" version=\"1.12\"}\%\n".
"\%META:TOPICPARENT{name=\"TWiki.TWikiPreferences\"}%\n";
my $formTest =
"\%META:TOPICINFO{author=\"gipper\" date=\"1091696467\" format=\"1.0\" version=\"1.5\"}\%\n".
"\%META:TOPICPARENT{name=\"WebHome\"}\%\n".
"CategoryForms\n".
"\%META:FORM{name=\"ThisForm\"}\%\n".
"\%META:FIELD{name=\"FieldOne\" title=\"FieldOne\" value=\"Value One\"}\%\n".
"\%META:FIELD{name=\"FieldTwo\" title=\"FieldTwo\" value=\"Value Two\"}\%\n".
"\%META:FIELD{name=\"FieldThree\" title=\"FieldThree\" value=\"7.1\"}\%\n".
"\%META:FIELD{name=\"BackSlash\" title=\"Back Slash\" value=\"One\"}\%\n".
"\%META:FILEATTACHMENT{name=\"conftest.val\" attr=\"\" comment=\"Bangra bingo\" date=\"1091696180\" path=\"conftest.val\" size=\"8\" user=\"guest\" version=\"1.2\"}\%\n".
"\%META:FILEATTACHMENT{name=\"left.gif\" attr=\"\" comment=\"left arrer\" date=\"1091696102\" path=\"left.gif\" size=\"107\" user=\"guest\" version=\"1.1\"}\%\n".
"\%META:FILEATTACHMENT{name=\"right.gif\" attr=\"h\" comment=\"\" date=\"1091696127\" path=\"right.gif\" size=\"105\" user=\"guest\" version=\"1.1\"}\%\n".
"\%META:TOPICMOVED{by=\"guest\" date=\"1091696242\" from=\"Test.FormsTest\" to=\"Test.FormTest\"}\%\n";

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();
  BaseFixture::writeTopic("Test", "WebHome", $webHome);
  BaseFixture::writeTopic("Test", "FormTest", $formTest);
}

sub test_loadSimple {
  my $this = shift;
  my $db = new DBCachePlugin::DBCache("Test");
  $this->assert_str_equals("0 2 0", $db->load());
  my $topic = $db->get("WebHome");
  $this->assert($topic);
  my $info = $topic->get("info");
  $this->assert_not_null($info);
  $this->assert_equals($topic, $info->get("_up"));
  $this->assert_str_equals("guest", $info->get("author"));
  $this->assert_equals(1089644791, $info->get("date"));
  $this->assert_str_equals("1.0", $info->get("format"));
  $this->assert_str_equals("1.12", $info->get("version"));
  $this->assert_str_equals("TWiki.TWikiPreferences", $topic->get("parent"));

  $topic = $db->get("FormTest");
  $this->assert_not_null($topic);
  $info = $topic->get("info");
  $this->assert_not_null($info);
  $this->assert_equals($topic, $info->get("_up"));
  $this->assert_str_equals("gipper", $info->get("author"));
  $this->assert_equals(1091696467, $info->get("date"));
  $this->assert_str_equals("1.0", $info->get("format"));
  $this->assert_str_equals("1.5", $info->get("version"));
  $this->assert_str_equals("WebHome", $topic->get("parent"));
  $this->assert_str_equals("CategoryForms\n", $topic->get("text"));
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
  $this->assert_str_equals("Test.FormsTest", $moved->get("from"));
  $this->assert_str_equals("Test.FormTest", $moved->get("to"));
}

sub test_cache {
  my $this = shift;
  my $db = new DBCachePlugin::DBCache("Test");
  $this->assert_str_equals("Test", $db->{_web});
  $this->assert_equals(0, $db->{loaded});

  # There should be no cache there
  $this->assert_str_equals("0 2 0", $db->load());
  $this->assert_equals(1, $db->{loaded});
  $this->assert_str_equals("0 0 0", $db->load());
  my $initial = $db;
  # There's a cache there now
  $db = new DBCachePlugin::DBCache("Test");
  $this->assert_equals(0, $db->{loaded});
  $this->assert_str_equals("2 0 0", $db->load());
  $this->assert_equals(1, $db->{loaded});
  $this->assert_str_equals("0 0 0", $db->load());
  $this->checkSameAs($initial,$db);

  sleep(1);# wait for clock tick
  BaseFixture::writeTopic("Test", "FormTest", $formTest."\nBlah");
  # One file in the cache has been touched
  $db = new DBCachePlugin::DBCache("Test");
  $this->assert_str_equals("1 1 0", $db->load());
  $db = new DBCachePlugin::DBCache("Test");
  $this->assert_str_equals("2 0 0", $db->load());

  # A new file has been created
  BaseFixture::writeTopic("Test", "NewFile", "Blah");
  $db = new DBCachePlugin::DBCache("Test");
  $this->assert_str_equals("2 1 0", $db->load());

  # One file in the cache has been deleted
  BaseFixture::deleteTopic("Test", "FormTest");
  $db = new DBCachePlugin::DBCache("Test");
  $this->assert_str_equals("2 0 1", $db->load());

  BaseFixture::deleteTopic("Test", "NewFile");
  BaseFixture::writeTopic("Test", "FormTest", $formTest);
  $db = new DBCachePlugin::DBCache("Test");
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

  $this->assert_equals($first->size(), $second->size(), $cmping);
  foreach my $k ($first->getKeys()) {
    my $a = $first->fastget( $k ) || "";
    my $b = $second->fastget( $k ) || "";
    my $c = "$cmping.$k";
    if (ref($a)) {
      $this->checkSameAs($a, $b, $c, $checked );
    } elsif ( $k !~ /^_/) {
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
