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
    my $wpd = TWiki::TestMaker::getPubDir();
    my $wpu = "file:$wpd";
    $text =~ s/%ATTACHURL%/ATTACHURL/eog;
    $text =~ s/%ATTACHURLPATH%/ATTACHURLPATH/eog;
    $text =~ s!%EDITURL%!PREFS(EDITURL)!ge;
    $text =~ s/%SEP%/SEP/ge;
    $text =~ s/%HTTP_HOST%/HTTP_HOST/ge;
    $text =~ s/%REMOTE_ADDR%/REMOTE_ADDR/ge;
    $text =~ s/%REMOTE_PORT%/REMOTE_PORT/ge;
    $text =~ s/%REMOTE_USER%/REMOTE_USER/ge;
    $text =~ s/%TOPIC%/TOPIC/g;
    $text =~ s/%BASETOPIC%/BASETOPIC/g;
    $text =~ s/%INCLUDINGTOPIC%/INCLUDINGTOPIC/g;
    $text =~ s/%SPACEDTOPIC%/SPACEDTOPIC/ge;
    $text =~ s/%WEB%/WEB/g;
    $text =~ s/%BASEWEB%/BASEWEB/g;
    $text =~ s/%INCLUDINGWEB%/INCLUDINGWEB/g;
    $text =~ s/%CHARSET%/CHARSET/g;
    $text =~ s/%WIKIHOMEURL%/WIKIHOMEURL/g;
    $text =~ s/%SCRIPTURL%/SCRIPTURL/g;
    $text =~ s/%SCRIPTURLPATH%/SCRIPTURLPATH/g;
    $text =~ s/%SCRIPTSUFFIX%/SCRIPTSUFFIX/g;
    $text =~ s/%PUBURL%/PUBURL/g;
    $text =~ s/%PUBURLPATH%/PUBURLPATH/g;
    $text =~ s/%ATTACHURL%/ATTACHURL/g;
    $text =~ s/%ATTACHURLPATH%/ATTACHURLPATH/g;
    $text =~ s/%DATE%/DATE/ge; 
    $text =~ s/%GMTIME%/GMTIME/ge;
    $text =~ s/%SERVERTIME%/SERVERTIME/ge;
    $text =~ s/%WIKIVERSION%/WIKIVERSION/g;
    $text =~ s/%USERNAME%/USERNAME/g;
    $text =~ s/%WIKINAME%/WIKINAME/g;
    $text =~ s/%WIKIUSERNAME%/WIKIUSERNAME/g;
    $text =~ s/%WIKITOOLNAME%/WIKITOOLNAME/g;
    $text =~ s/%MAINWEB%/MAINWEB/g;
    $text =~ s/%TWIKIWEB%/TWIKIWEB/g;
    $text =~ s/%HOMETOPIC%/HOMETOPIC/g;
    $text =~ s/%WIKIUSERSTOPIC%/WIKIUSERSTOPIC/g;
    $text =~ s/%WIKIPREFSTOPIC%/WIKIPREFSTOPIC/g;
    $text =~ s/%WEBPREFSTOPIC%/WEBPREFSTOPIC/g;
    $text =~ s/%NOTIFYTOPIC%/NOTIFYTOPIC/g;
    $text =~ s/%STATISTICSTOPIC%/STATISTICSTOPIC/g;
    $text =~ s/%STARTINCLUDE%/STARTINCLUDE/g;
    $text =~ s/%STOPINCLUDE%/STOPINCLUDE/g;

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
