# Used for generating test data
# Use with fake TWiki::Func

{ package TWiki::TestMaker;

  use vars qw ( %prefs );

  my $pwd = undef;

  sub init {
    my $plugin = shift;
    $pwd = `pwd`;
    chop($pwd);
    purge();
    mkdir pwd()."/testdata", 0777 unless -d pwd()."/testdata";
    mkdir pwd()."/testdata/data", 0777 unless -d pwd()."/testdata/data";
    TWiki::testinit();
    setPreferencesValue("WIKITOOLNAME","wiki_tool_name");
    setPreferencesValue("WIKIWEBMASTER","wiki_web_master");
    setPreferencesValue("SCRIPTSUFFIX",".cgi");
    setPreferencesValue("SCRIPTURLPATH","scripturl");
    loadPreferencesFor($plugin);
  }

  sub setPreferencesValue {
    my ($thing, $val) = @_;
    $prefs{$thing}=$val;
  }

  sub loadPreferencesFor {
    my $plugin = shift;
    my $ucw = uc($plugin);
    my $pwd = `pwd`;
    chop($pwd);
    my ($p,$f,$l) = caller(1);
    print STDERR "*** Prefs loaded from $pwd/../../../../../data/TWiki/$plugin.txt\n";
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

  sub pwd {
    die "must call TestMaker::init first" unless defined($pwd);
    return $pwd;
  }

  sub getDataDir {
    return pwd() . "/testdata/data";
  }

  sub getPubDir {
    return pwd()."/testdata/pub";
  }

  sub purge {
    my $td = pwd()."/testdata";
    `rm -rf $td`;
  }

  sub writeTopic {
    my ($web, $topic, $text) = @_;
    writeFile($web, $topic, "txt", $text);
    my $file = pwd()."/testdata/data/$web/$topic.txt";
    `ci -q -l -mnone -t-none $file`;
  }

  sub writeFile {
    my ($web, $topic, $ext, $text) = @_;
    mkdir pwd()."/testdata/data/$web", 0777 unless -d pwd()."/testdata/data/$web";
    my $file = pwd()."/testdata/data/$web/$topic.$ext";
    open(WF,">$file") || die;
    print WF $text;
    close(WF) || die;
    if ( -e $file ) {
      #print STDERR "TestMaker wrote $file\n";
    } else {
      die "Not there $file\n";
    }
  }

  sub writeRcsTopic {
    my ($web, $topic, $text) = @_;
    writeFile($web, $topic, "txt,v", $text);
    my $file = pwd()."/testdata/data/$web/$topic.txt";
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
}

1;
