#
# Tests for the PowerEdit server module. Tests the responses under
# various queries which would come from the applet.
#
use CGI;
use TWiki::Plugins::PowerEditAddon::PowerEdit;
use TWiki;
use Cwd 'chdir';

sub testQuery {
  my $query = shift;
  open(OLDOUT, ">&STDOUT");
  open(STDOUT, '>', "/tmp/test.txt");
  select(STDOUT); $| = 1;     # make unbuffered
  PowerEditAddon::PowerEdit::serverCommand($query);
  close STDOUT;
  open(STDOUT, ">&OLDOUT");
  my $ret = readFile("/tmp/test.txt");
  unlink("/tmp/test.txt");
  return $ret;
}

sub writeFile {
  my ($name, $text) = @_;
  open FH,">$name";
  print FH $text;
  close FH;
}

sub readFile {
  my $name = shift;
  my $res = "";
  open FH,"<$name";
  while ($line = <FH>) {
    $res .= $line;
  }
  close FH;
  return $res;
}

$web = "Trash";
$webbase =  TWiki::Func::getDataDir()."/$web";
$topic = "PowerEditTestTopi";
do {
  $topic .= "c";
  $topicbase = "$webbase/$topic";
} while (-f $topicbase.txt);

die unless ((! -f "$topicbase.txt") || unlink("$topicbase.txt"));
die unless ((! -f "$topicbase.txt,v") || unlink("$topicbase.txt,v"));
die unless ((! -f "$topicbase.lock") || unlink("$topicbase.lock"));

# Create the topic to be edited
writeFile("$topicbase.txt", "blah");

# Check that an unlocked topic can't be 'get'
$query = new CGI({'action'=>'get', 'topic'=>"$web.$topic"});
$res = testQuery($query);
die "Was able to get unlocked topic" if ($res !~ /^ERROR (.*) is not locking $topic/m);
$user = $1;

$server = TWiki::Func::getScriptUrl("$web", "$topic", "poweredit");

# Lock the topic
writeFile("$topicbase.lock", "$user\n1010699255\n");

# Check that the now-locked topic can be 'get'
$res = testQuery($query);
die "Locked topic can't be got" if ($res !~ /^OKblah/m);

# Check we can 'put'
$query->param(-name=>'action', -value=>'put');
$query->param(-name=>'text', -value=>'fneegle');
$res = testQuery($query);
die "put failed" if ($res !~ /^OK$server$/m);

$res = readFile("$topicbase.tmp");
die "put failed" if ($res !~ /^fneegle/m);

# Check we can commit what we put
$query->param(-name=>'action',-value=>'commit');
$query->param(-name=>'unlock', -value=>'on');
$res = testQuery($query);
$vsu = TWiki::Func::getScriptUrl("$web", "$topic", "view");
die "Wrong url $res" if ($res !~ /^Location: $vsu/m);
$res = readFile("$topicbase.txt");
die "commit failed" if ($res !~ /^fneegle/m);
# Make sure the ,v file has been updated
die "Not checked in" if (!-f "$topicbase.txt,v");
$res = readFile("$topicbase.txt,v");
die "No fneegle in ,v $res" if ($res !~ /^fneegle/m);

# Check the lock has gone
die "Lock still there" if (-f "$topicbase.lock");

# check that pref isn't already there in the user's topic, which
# is the most preferential
if( $TWiki::wikiUserName =~ /^(.*)\.(.*)$/ ) {
  my $grep = "Set POWEREDIT_CONTROLS";
  my $in = $TWiki::wikiUserName;
  $in =~ s/\./\//o;
  $in = TWiki::Func::getDataDir()."/$TWiki::mainWebName/$in.txt";
  my $cset = `grep "Set POWEREDIT_CONTROLS" $in`;
  die "POWEREDIT_CONTROLS already set - can't test" if ($cset ne "");
}

# variable not set; need to set it.
# We can safely use Trash.WebPreferences
$oldtxt = readFile("$webbase/$TWiki::webPrefsTopicname.txt");
$cset = "$web.PowerEditControls";
writeFile("$webbase/$TWiki::webPrefsTopicname.txt",
	  "$txt\n\t\t* Set POWEREDIT_CONTROLS = $cset");

# Check response on no controls topic
$query->param(-name=>'action', -value=>'controls');
$res = testQuery($query);
$bad = ($res !~ /^ERROR no such topic $web.PowerEditControls/m);

# If ok, check response when there _is_ a controls topic
if (!$bad) {
  writeFile("$webbase/PowerEditControls.txt", "These are the controls\n");
  $res = testQuery($query);
  unlink("$webbase/PowerEditControls.txt");
  $bad = ($res !~ /^OKThese are the controls/om);
}

# restore the old webpreferences topic
writeFile("$webbase/$TWiki::webPrefsTopicname.txt", $oldtxt);
die $res if ($bad);

unlink("$topicbase.txt");
unlink("$topicbase.txt,v");

1;
