# Used for generating test data
# Use with fake TWiki::Func

{ package TWiki::TestMaker;

  my $pwd = undef;

  sub init {
    $pwd = `pwd`;
    chop($pwd);
    purge();
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
    mkdir pwd()."/testdata", 0777 unless -d pwd()."/testdata";
    mkdir pwd()."/testdata/data", 0777 unless -d pwd()."/testdata/data";
    mkdir pwd()."/testdata/data/$web", 0777 unless -d pwd()."/testdata/data/$web";
    my $file = pwd()."/testdata/data/$web/$topic.$ext";
    open(WF,">$file") || die;
    print WF $text;
    close(WF) || die;
    print STDERR "Not there $file\n" unless ( -e $file );
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
