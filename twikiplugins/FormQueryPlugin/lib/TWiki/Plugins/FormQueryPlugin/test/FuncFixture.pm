#
# Test fixture that implements the "Func" interface of TWiki. It can't
# override the actual "TWiki::Func" methods themselves, but instead
# provides blanks for the methods so that if the fixture is used in place
# of a class object "TWiki::Func" it can step in. Note that additional
# fixture methods are provided for the creation of test topics.
#

package TWiki::Func;

use base qw(Test::Unit::TestCase);

my $pwd = undef;
my $testDir;

sub new {
  my $self = shift()->SUPER::new(@_);
  $pwd = `pwd`;
  chop($pwd);
  $testDir = "$pwd/testdata";
  return $self;
}

sub getDataDir {
  return "$testDir/data";
}

sub set_up {
  mkdir $testDir, 0777 || die "mkdir $testDir";
  mkdir getDataDir(), 0777 || die "mkdir ".getDataDir();
}
  
sub tear_down {
  `rm -rf $testDir`;
}

sub TESTwriteFile {
  my ($web, $topic, $ext, $text) = @_;
  mkdir getDataDir()."/$web", 0777 unless ( -d getDataDir()."/$web" );
  my $file = getDataDir()."/$web/$topic.$ext";
  open(WF,">$file") || die;
  print WF $text;
  close(WF) || die;
  print STDERR "Not there $file\n" unless ( -e $file );
}

sub TESTwriteTopic {
  my ($web, $topic, $text) = @_;
  TESTwriteFile($web, $topic, "txt", $text);
  my $file = getDataDir()."/$web/$topic.txt";
  `ci -q -l -mnone -t-none $file`;
}

# Write the RCS form of a topic. This is required for when we want
# to fake a history.
sub TESTwriteRcsTopic {
  my ($web, $topic, $text) = @_;
  TESTwriteFile($web, $topic, "txt,v", $text);
  my $file = getDataDir()."/$web/$topic.txt";
  `co -q $file`;
}

sub getMainWebname {
  return "Main";
}

sub getWikiName {
  return "TestRunner";
}

sub getUrlHost {
  return "host";
}

sub getViewUrl {
  my ($w,$t) = @_;
  return "$w.$t";
}

sub getScriptUrlPath {
  return "$pwd/../../../../../bin";
}

sub getTopicList {
  my $web = shift;

  opendir(DH, getDataDir()."/$web");
  my @list = grep /^.*\.txt$/, readdir(DH);
  closedir(DH);
  foreach my $f (@list) {
    $f =~ s/\.txt$//o;
  }
  return @list;
}

sub webExists {
  my $web = shift;
  return ( -d getDataDir() . "/$web" );
}

sub topicExists {
  my ( $web, $topic ) = @_;
  return 0 unless webExists($web);
  return -f getDataDir() . "/$web/$topic.txt";
}

sub TESTreadFile {
  my( $name ) = @_;
  my $data = "";
  undef $/; # set to read to EOF
  open( IN_FILE, "<$name" ) || die "Failed to open $name";
  $data = <IN_FILE>;
  $/ = "\n";
  close( IN_FILE );
  return $data;
}

sub readTopicText {
  my ( $web,$topic ) = @_;
  return TESTreadFile( getDataDir() . "/$web/$topic.txt" );
}

sub readTemplate {
  my ($template,$skin) = @_;
  $template .= ".$skin" if ($skin);
  return TESTreadFile("$pwd/../../../../../templates/$template.tmpl" );
}

sub renderText {
  my ($text) = @_;
  return $text." RENDERED";
}

sub expandCommonVariables {
  my ($text) = @_;
  my $wpd = getPubDir();
  my $wpu = "file:$wpd";
  $text =~ s/%ATTACHURL%/$wpu/eog;
  $text =~ s/%ATTACHURLPATH%/$wpd/eog;
  while ($text =~ /%([A-Za-z0-9_]+)%/) {
    my $var = getPreferencesValue($1);
    if ($var) {
      $text =~ s/%([A-Za-z0-9_]+)%/$var/o;
    } else {
      $text =~ s/%([A-Za-z0-9_]+)%/!!UNKNOWNVAR!!/o;
    }
  }
  
  return $text;
}

my %prefs;

sub getPreferencesValue {
  my $what = shift;

  return $prefs{$what};
}

sub TESTsetPreference {
  my ($what, $val) = @_;
  $prefs{$what} = $val;
}

sub TESTcallersCaller {
  my ($package, $filename, $line) = caller(1);
  return "$filename:$line: ";
}

sub writeDebug {
  my ($text) = @_;
  print STDERR TESTcallersCaller()."TWikiDebug: $text\n";
}

sub writeWarning {
  my ($text) = @_;
  print STDERR TESTcallersCaller()."TWikiWarning: $text\n";
}

1;
