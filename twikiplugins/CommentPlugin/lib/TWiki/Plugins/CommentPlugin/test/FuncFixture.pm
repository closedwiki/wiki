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
my $redirected;
$TWiki::webNameRegex = "[A-Z]+[A-Za-z0-9]*";
$TWiki::anchorRegex = "\#[A-Za-z0-9_]+";
$TWiki::Plugins::VERSION = 1;

sub new {
  my $self = shift()->SUPER::new(@_);
  $pwd = `pwd`;
  chop($pwd);
  $testDir = "$pwd/testdata";
  $redirected = undef;
  return $self;
}

sub getDataDir {
  return "$testDir/data";
}

sub getSkin {
  return "";
}

sub set_up {
  mkdir $testDir, 0777 || die "mkdir $testDir";
  `cp -r ../../../../../data $testDir`;
}

sub tear_down {
  `rm -rf $testDir`;
  $redirected = undef;
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

sub TESTlockTopic {
  my ( $web, $topic, $time ) = @_;
  TESTwriteFile($web, $topic, "lock", "locker\n$time");
}

sub TESTunlockTopic {
  my ( $web, $topic ) = @_;
  my $file = getDataDir()."/$web/$topic.lock";
  unlink($file);
}

sub TESTdeleteTopic {
  my ($web, $topic) = @_;
  my $file = getDataDir()."/$web/$topic.txt";
  unlink($file);
  if ( -e "$file,v" ) {
    unlink("$file,v");
  }
}

# Write the RCS form of a topic. This is required for when we want
# to fake a history.
sub TESTwriteRcsTopic {
  my ($web, $topic, $text) = @_;
  TESTwriteFile($web, $topic, "txt,v", $text);
  my $file = getDataDir()."/$web/$topic.txt";
  `co -q $file`;
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

sub TESTsetPreference {
  my ($what, $val) = @_;
  $prefs{$what} = $val;
}

my %prefs;

sub TESTcallersCaller {
  my ($package, $filename, $line) = caller(1);
  return "$filename:$line: ";
}

sub _handleTmplP {
    my( $theVar ) = @_;

    my $val = "";
    if( ( %TWiki::Store::templateVars ) && ( exists $TWiki::Store::templateVars{ $theVar } ) ) {
        $val = $TWiki::Store::templateVars{ $theVar };
        $val =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&_handleTmplP($1)/geo;
    }
    return $val;
}

sub TESTredirected {
  return $redirected;
}

sub redirectCgiQuery {
  my ($query, $url ) = @_;
  $redirected = $url;
}

my $query = undef;

sub TESTsetCGIQuery {
  $query = shift;
}

sub getCgiQuery {
  return $query;
}

sub getMainWebname {
  return "Main";
}

sub getWikiName {
  return "TestRunner";
}

sub getWikiUserName {
  return "Main.TestRunner";
}

sub wikiToUserName {
  my $n = shift;

  return "testrunner" if $n =~ /TestRunner$/;
  return "unknown";
}

sub formatGmTime {
    my( $theTime, $theFormat ) = @_;

    return gmtime( $theTime );
}

sub getUrlHost {
  return "host";
}

sub getViewUrl {
  my ($w,$t) = @_;
  return getScriptUrl($w, $t, "view");
}

sub getTwikiWebname {
  return "TWiki";
}

sub getScriptUrlPath {
  return "$pwd/../../../../../bin";
}

sub getScriptUrl {
  my ($w,$t,$s) = @_;
  return "http://twiki/$s.cgi/$w/$t";
}

sub getPubDir {
  return "$pwd/../../../../../pub";
}

sub TESTgetTemplatesDir {
  return "$pwd/../../../../../templates";
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

sub checkTopicEditLock {
  my ( $web, $topic ) = @_;
  my $lockf = getDataDir()."/$web/$topic.lock";
  if ( -f $lockf ) {
    my $data = TESTreadFile($lockf);
    $data =~ m/^(.*)\n(.*)$/s;
    return ("OOPSLOCKED", $1, $2);
  }
  return (undef, undef, 0);
}

sub setTopicEditLock {
  my( $web, $topic, $lock ) = @_;
  die unless ($web);
  die unless ($topic);
  if ($lock) {
    TESTlockTopic($web, $topic, time());
  } else {
    TESTunlockTopic($web,$topic);
  }
}

sub checkAccessPermission {
  my ($type, $wikiName, $text, $topic, $web) = @_;

  die unless ($type =~ /^(view|change|create)$/i);
  die unless ($wikiName);
  die unless ($web);
  return 1;
}

sub readTopicText {
  my ( $web,$topic ) = @_;
  return TESTreadFile( getDataDir() . "/$web/$topic.txt" );
}

sub readTopic {
  my ($web, $topic) = @_;

  my $text = readTopicText($web, $topic);
  $text =~ s/^%META.*?$//g;
  return (undef, $text);
}

sub readTemplate {
  my ($template,$skin) = @_;
  $template .= ".$skin" if ($skin);
  my $text = TESTreadFile("$pwd/../../../../../templates/$template.tmpl" );

  my $result = "";
  my $key  = "";
  my $val  = "";
  my $delim = "";
  foreach( split( /(%TMPL\:)/, $text ) ) {
    if( /^(%TMPL\:)$/ ) {
      $delim = $1;
    } elsif( ( /^DEF{[\s\"]*(.*?)[\"\s]*}%[\n\r]*(.*)/s ) && ( $1 ) ) {
      # handle %TMPL:DEF{"key"}%
      if( $key ) {
	$TWiki::Store::templateVars{ $key } = $val;
      }
      $key = $1;
      $val = $2 || "";
    } elsif( /^END%[\n\r]*(.*)/s ) {
      $TWiki::Store::templateVars{ $key } = $val;
      $key = "";
      $val = "";
      $result .= $1 || "";
    } elsif( $key ) {
      $val    .= "$delim$_";
    } else {
      $result .= "$delim$_";
    }
  }

  # handle %TMPL:P{"..."}% recursively
  $result =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&handleTmplP($1)/geo;
  $result =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom;  # leading spaces to tabs
  return $result;
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
  $text =~ s/%TMPL:P{\"?(.*?)\"?}%/&_handleTmplP($1)/geo;
  $text =~ s/%([A-Za-z0-9_]+)%/&_evbl($1)/ego;
  if ($query) {
    $text =~ s/%URLPARAM{(.*?)}%/&_eurlp($1)/ego;
  }
  return $text;
}

sub _eurlp {
  my $ats = shift;
  my $vbl = extractNameValuePair($ats);
  my $repl = extractNameValuePair($ats, "newline");
  if ( $query->param($vbl)) {
    my $val = $query->param($vbl);
    $val =~ s/\n/$repl/go if ($repl);
    return $val;
  }
  return "%URLPARAM{\"$vbl\"}%";
}

sub _evbl {
  my $vbl = shift;

  my $var = getPreferencesValue($vbl);
  if ($var) {
    return $var
  } else {
    return "%".$vbl."%";
  }
}

sub getPreferencesValue {
  my $what = shift;

  return $prefs{$what};
}

sub writeDebug {
  my ($text) = @_;
  print STDERR TESTcallersCaller()."TWikiDebug: $text\n";
}

sub writeWarning {
  my ($text) = @_;
  print STDERR TESTcallersCaller()."TWikiWarning: $text\n";
}

sub extractNameValuePair
{
    my( $str, $name ) = @_;
    my $TranslationToken= "\0";

    my $value = "";
    return $value unless( $str );
    $str =~ s/\\\"/\\$TranslationToken/g;  # escape \"

    if( $name ) {
        # format is: %VAR{ ... name = "value" }%
        if( $str =~ /(^|[^\S])$name\s*=\s*\"([^\"]*)\"/ ) {
            $value = $2 if defined $2;  # distinguish between "" and "0"
        }

    } else {
        # test if format: { "value" ... }
        if( $str =~ /(^|\=\s*\"[^\"]*\")\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/ ) {
            # is: %VAR{ "value" }%
            # or: %VAR{ "value" param="etc" ... }%
            # or: %VAR{ ... = "..." "value" ... }%
            # Note: "value" may contain embedded double quotes
            $value = $2 if defined $2;  # distinguish between "" and "0";

        } elsif( ( $str =~ /^\s*\w+\s*=\s*\"([^\"]*)/ ) && ( $1 ) ) {
            # is: %VAR{ name = "value" }%
            # do nothing, is not a standalone var

        } else {
            # format is: %VAR{ value }%
            $value = $str;
        }
    }
    $value =~ s/\\$TranslationToken/\"/go;  # resolve \"
    return $value;
}

sub saveTopicText {
  my ( $web, $topic, $text, $ignorePermissions, $dontNotify ) = @_;

  die unless ($web);
  die unless ($topic);
  die unless ($text);

  TESTwriteTopic($web, $topic, $text);
}

1;
