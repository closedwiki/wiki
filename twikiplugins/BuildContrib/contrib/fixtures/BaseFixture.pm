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

my $htmltags = 
qr/A|ABBR|ACRONYM|ADDRESS|APPLET|AREA|B|BASE|BASEFONT|BDO|BIG|BLOCKQUOTE|BODY|BR|BUTTON|CAPTION|CENTER|CITE|CODE|COL|COLGROUP|DD|DEL|DFN|DIR|DIV|DL|DT|EM|FIELDSET|FONT|FORM|FRAME|FRAMESET|H1|H2|H3|H4|H5|H6|HEAD|HR|HTML|I|IFRAME|IMG|INPUT|INS|ISINDEX|KBD|LABEL|LEGEND|LI|LINK|MAP|MENU|META|NOFRAMES|NOSCRIPT|OBJECT|OL|OPTGROUP|OPTION|P|PARAM|PRE|Q|S|SAMP|SCRIPT|SELECT|SMALL|SPAN|STRIKE|STRONG|STYLE|SUB|SUP|TABLE|TBODY|TD|TEXTAREA|TFOOT|TH|THEAD|TITLE|TR|TT|U|UL|VAR/i;

# 'free' the format of html. REs can be embedded by encasing them in {* *}
sub unhtml {
  my ($re) = @_;

  # Lift out REs protected by {* *}
  my $i = 0;
  my %prot;
  while ( $re =~ s/{\*(.*?)\*}/PROTECTED$i/) {
      $prot{$i} = $1;
      $i++;
  }
  # lift out strings
#  while ( $re =~ s/("[^"]*")/PROTECTED$i/) {
#      $prot{$i} = $1;
#      $i++;
#  }
#  while ( $re =~ s/('[^']+')/PROTECTED$i/) {
#      $prot{$i} = $1;
#      $i++;
#  }
  $re = unregex($re);
  # Open tags
  $re =~ s/(<($htmltags).*?>)/&_openTag($1)/geo;

  # close tags lower case (XHTML)
  $re =~ s/(<\/$htmltags>)/&_closeTag($1)/geo;

  # Turn whitespace into \s+
  $re =~ s/\s+/\\s+/go;

  # Collapse space sequences
  $re =~ s/\\s\*\\s([*+])/\\s$1/g;
  $re =~ s/\\s([*+])\\s\*/\\s$1/g;
  $re =~ s/\\s\+\\s\+/\\s+/g;

  while ($re =~ s/PROTECTED(\d+)/$prot{$1}/g) {
  }

  return $re;
}

sub _openTag {
    my $tag = shift;

    # make open tag and param names lower case (XHTML compatibility)
    $tag =~ s/(<\w+)\b/&_lower($1)/e;
    $tag =~ s/\/>$/\\s*\/>/;
    $tag =~ s/\s([a-zA-Z]+)=/&_tagParam($1)/ge;

    return "\\s*$tag\\s*";
}

sub _closeTag {
    my $tag = lc(shift);

    return "\\s*$tag\\s*";
}

sub _tagParam {
    return lc("\\s+$_[0]\\s*=\\s*");
}

sub _lower {
    return lc($_[0]);
}

sub assert_html_matches {
  my ($this, $expected, $test, $mess ) = @_;

  my $re = unhtml($expected);
  $mess = "$test\ndoes not match\n$expected" unless ($mess);
  my ($package, $filename, $line) = caller(0);
  unless ($test =~ s/$re//s) {
      $this->assert(0, "$mess at $filename:$line\nRE was $re");
  }
  return $test;
}

sub assert_html_matches_all {
  my ($this, $expected, $test, $mess ) = @_;

  my $re = unhtml($expected);
  $mess = "$test\n does not match\n$expected" unless ($mess);
  my ($package, $filename, $line) = caller(0);
  $this->assert_matches(qr/^\s*$re\s*$/s, $test, "at $filename:$line: $mess");
}

1;
