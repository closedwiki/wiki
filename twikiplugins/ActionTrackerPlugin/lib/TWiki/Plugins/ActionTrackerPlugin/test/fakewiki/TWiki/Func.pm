# Fake TWiki::Func for testing only
use TWiki::TestMaker;

{ package TWiki::Func;

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
    return TWiki::TestMaker::pwd()."/../../../../../bin";
  }

  sub getDataDir {
    return TWiki::TestMaker::getDataDir();
  }

  sub getPreferencesValue {
    my $thing = shift;
    if ($TWiki::TestMaker::prefs{$thing}) {
      return $TWiki::TestMaker::prefs{$thing};
    } else {
      return "PREFS($thing)";
    }
  }

  sub getPreferencesFlag {
    my $thing = shift;
    if ($TWiki::TestMaker::prefs{$thing}) {
      return $TWiki::TestMaker::prefs{$thing};
    } else {
      return "PREFS($thing)";
    }
  }

  sub webExists {
    my $web = shift;
    return ( -d getDataDir() . "/$web" );
  }

  sub topicExists {
    my ( $web, $topic ) = @_;
    return -f getDataDir() . "/$web/$topic.txt";
  }

  sub readTopicText {
    my ( $web,$topic,$rev ) = @_;
    if ("$rev" ne "") {
      my $cmd = "/usr/bin/co -q -p -r1.$rev ".getDataDir() . "/$web/$topic.txt";
      return `$cmd`;
    }
    return TWiki::TestMaker::readFile( getDataDir() . "/$web/$topic.txt" );
  }

#  sub readTopic {
#    my ( $web,$topic ) = @_;
#    return TWiki::TestMaker::readFile( getDataDir() . "/$web/$topic.txt" );
#  }

  sub readTemplate {
    my $template = shift;
    return TWiki::TestMaker::readFile( TWiki::TestMaker::pwd()."/../../../../../templates/$template.tmpl" );
  }

  sub renderText {
    my ($text) = @_;
    return $text." RENDERED";
  }

  sub expandCommonVariables {
    my ($text) = @_;
    my $wpd = TWiki::TestMaker::getPubDir();
    my $wpu = "file:$wpd";
    $text =~ s/%ATTACHURL%/$wpu/eog;
    $text =~ s/%ATTACHURLPATH%/$wpd/eog;
    while ($text =~ /%([A-Za-z0-9_]+)%/) {
      my $var = TWiki::Func::getPreferencesValue($1);
      if ($var) {
	$text =~ s/%([A-Za-z0-9_]+)%/$var/o;
      } else {
	$text =~ s/%([A-Za-z0-9_]+)%/!!UNKNOWNVAR!!/o;
      }
    }

    return $text;
  }

  sub writeDebug {
    my ($text) = @_;
    print STDERR "TWikiDebug: $text\n";
  }

  sub writeWarning {
    my ($text) = @_;
    print STDERR "TWikiWarning: $text\n";
  }
}

1;
