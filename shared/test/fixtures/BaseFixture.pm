use strict;

=begin text

---+ Package Base<nop>Fixture - test fixture
Basic class of all test fixtures. Sets up a very basic TWiki environment
suitable for testing plugins. As well as the standard =set_up= and
=tear_down=, provides functions for the generation of data (.txt) files
for tests and functions for asserting the contrents of generated HTML.

For full details, read the code.

=cut

package BaseFixture;

use base qw(Test::Unit::TestCase);

use vars qw( $pwd $testDir $testData $redirected $query %prefs $skin );

BEGIN {
  $pwd = `pwd`;
  chop($pwd);
  $testDir = "$pwd/testdata";
  $testData = "$testDir/data";
}

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

# Setup for basic text fixture
sub set_up {
  $redirected = undef;
  mkdir $testDir, 0777 || die "mkdir $testDir";
  `cp -r ../../../../../data $testDir && rm -rf $testDir/data/CVS`;
  $query = undef;
  $skin = undef;
  %prefs = ();
  $redirected = undef;
  setPreference("WIKITOOLNAME","wiki_tool_name");
  setPreference("WIKIWEBMASTER","wiki_web_master");
  setPreference("SCRIPTSUFFIX",".cgi");
  setPreference("SCRIPTURLPATH","scripturl");
}

sub tear_down {
  `rm -rf $testDir`;
}

sub writeFile {
  my ($web, $topic, $ext, $text) = @_;
  mkdir "$testData/$web", 0777 unless ( -d "$testDir/$web" );
  my $file = "$testData/$web/$topic.$ext";
  open(WF,">$file") || die;
  print WF $text;
  close(WF) || die;
  print STDERR "Not there $file\n" unless ( -e $file );
}

sub writeTopic {
  my ($web, $topic, $text) = @_;
  writeFile($web, $topic, "txt", $text);
  my $file = "$testData/$web/$topic.txt";
  `ci -q -l -mnone -t-none $file`;
}

sub lockTopic {
  my ( $web, $topic, $time ) = @_;
  writeFile($web, $topic, "lock", "locker\n$time");
}

sub unlockTopic {
  my ( $web, $topic ) = @_;
  my $file = "$testData/$web/$topic.lock";
  unlink($file);
}

sub deleteTopic {
  my ($web, $topic) = @_;
  my $file = "$testData/$web/$topic.txt";
  unlink($file);
  if ( -e "$file,v" ) {
    unlink("$file,v");
  }
}

# Write the RCS form of a topic. This is required for when we want
# to fake a history.
sub writeRcsTopic {
  my ($web, $topic, $text) = @_;
  writeFile($web, $topic, "txt,v", $text);
  my $file = "$testData/$web/$topic.txt";
  `co -q $file`;
}

sub readFile {
  my( $name ) = @_;
  my $data = "";
  undef $/; # set to read to EOF
  open( IN_FILE, "<$name" ) || die "Failed to open $name";
  $data = <IN_FILE>;
  $/ = "\n";
  close( IN_FILE );
  return $data;
}

sub loadPreferencesFor {
  my $plugin = shift;
  my $ucw = uc($plugin);
  my $pwd = `pwd`;
  chop($pwd);
  #print STDERR "*** Prefs loaded from $pwd/../../../../../data/TWiki/$plugin.txt\n";
  open PF,"<$pwd/../../../../../data/TWiki/$plugin.txt";
  while (<PF>) {
	if ($_ =~ /^\s+\* Set (\w+) = (.*)$/o) {
	  my $at = $1;
	  my $thng = $2;
	  $prefs{"${ucw}_$at"} = $thng;
	}
  }
  close PF;
}

sub setPreference {
  my ($what, $val) = @_;
  $prefs{$what} = $val;
}

sub callersCaller {
  my ($package, $filename, $line) = caller(1);
  return "$filename:$line: ";
}

sub redirected {
  return $redirected;
}

sub setCGIQuery {
  $query = shift;
}

sub setSkin {
  $skin = shift;
}

sub  getTemplatesDir {
  return "$pwd/../../../../../templates";
}

# escape regular expression chars in string
sub unregex {
  my ($re) = @_;
  $re =~ s/\\/\\\\/go;
  $re =~ s/\./\\./go;
  $re =~ s/\?/\\?/go;
  $re =~ s/\*/\\*/go;
  $re =~ s/\+/\\+/go;
  $re =~ s/\(/\\(/go;
  $re =~ s/\)/\\)/go;
  $re =~ s/\[/\\[/go;
  $re =~ s/\]/\\]/go;
  $re =~ s/\^/\\^/go;
  $re =~ s/\$/\\\$/go;
  $re =~ s/\@/\\\@/go;
  $re =~ s/\|/\\|/go;
  return $re;
}

# 'free' the format of html
sub unhtml {
  my ($re) = @_;
  $re = unregex($re);
  # make open tags with params case-insensitive
  $re =~ s/<(\w+)\s+(\w+)\s*=\s*([^>]+)>/<$1\\s+(?i)$2(?-i)\\s*=\\s*$3>/go;
  # make close tags and open tags without params case insensitive
  $re =~ s/<(\/?\w+)>/<(?i)$1(?-i)>/go;
  $re =~ s/<(\/?\w+)(\s+\/)>/<(?i)$1(?-i)$2>/go;
  # Make conditional spaces around tags
  $re =~ s/\s*(<[^>]+>)\s*/\\s*$1\\s*/go;
  # Turn whitespace into \s+
  $re =~ s/\s+/\\s+/go;
  # Collapse space sequences
  $re =~ s/\\s\*\\s([*+])/\\s$1/go;
  $re =~ s/\\s([*+])\\s\*/\\s$1/go;

  return $re;
}

sub assert_html_matches {
  my ($this, $expected, $test, $mess ) = @_;

  my $re = unhtml($expected);
  $mess = "$test\nmatches\n$expected" unless ($mess);
  my ($package, $filename, $line) = caller(0);
  $this->assert_matches(qr/$re/s, $test, "$mess at $filename:$line");
}

sub assert_html_matches_all {
  my ($this, $expected, $test, $mess ) = @_;

  my $re = unhtml($expected);
  $mess = "$test\nmatches\n$expected" unless ($mess);
  my ($package, $filename, $line) = caller(0);
  $this->assert_matches(qr/^\s*$re\s*$/s, $test, "at $filename:$line: $mess");
}

1;
