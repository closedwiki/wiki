# Fake TWiki::Func for testing only
use TWiki::TestMaker;
require CGI;

{ package TWiki::Func;

  use vars qw ($query);

  sub getMainWebname {
    return "Main";
  }

  sub getWikiName {
    return "TestRunner";
  }

  sub getWikiUserName {
    return "testrunner";
  }

  sub getUrlHost {
    return "host";
  }

  sub getViewUrl {
    my ($w,$t) = @_;
    return "http://host/view/$w/$t";
  }

  sub getScriptUrlPath {
    return TWiki::TestMaker::pwd()."/../../../../../bin";
  }

  sub getDataDir {
    return TWiki::TestMaker::getDataDir();
  }

  sub setQuery {
    $query = shift;
  }

  sub getCgiQuery {
    return $query;
  }

  sub getSkin {
    return "action";
  }

  sub getPreferencesValue {
    my $thing = shift;
    if (defined($TWiki::TestMaker::prefs{$thing})) {
      return $TWiki::TestMaker::prefs{$thing};
    } else {
      return "%$thing%";
    }
  }

  sub getPreferencesFlag {
    my $thing = shift;
    if ($TWiki::TestMaker::prefs{$thing}) {
      return $TWiki::TestMaker::prefs{$thing};
    } else {
      return "%$thing%";
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
    if (defined($rev) && $rev ne "") {
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

    $text =~ s/%([A-Z]+)%/&getPreferencesValue($1)/eog;

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
