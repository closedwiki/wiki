=begin text

---++ Package TWiki::Func - test fixture
A test fixture module that provides an ultra-thin implementation of the
functions of the TWiki::Func module that are required by plugins and add-ons.

Only the methods encountered in testing to date are implemented.

For full details, read the code.

=cut

package TWiki::Func;

use BaseFixture;
use strict;

#$TWiki::Plugins::VERSION = 1; #Beijing
$TWiki::Plugins::VERSION = 1.020; #Cairo


sub getDataDir {
  return "$BaseFixture::testDir/data";
}

sub getSkin {
  return $BaseFixture::skin;
}

sub _handleTmplP {
    my( $theVar ) = @_;

    my $val = "";
    if( ( %TWiki::Store::templateVars ) &&
		( exists $TWiki::Store::templateVars{ $theVar } ) ) {
        $val = $TWiki::Store::templateVars{ $theVar };
        $val =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&_handleTmplP($1)/geo;
    }
    return $val;
}

sub redirectCgiQuery {
  my ($query, $url ) = @_;
  $BaseFixture::redirected = $url;
}

sub getCgiQuery {
  return $BaseFixture::query;
}

sub  getWikiName {
  return "TestRunner";
}

sub  getWikiUserName {
  return getMainWebname().".TestRunner";
}

sub userToWikiName {
  my $n = shift;
  return "TestRunner" if ($n && $n =~ /testrunner$/);
  return "TWikiGuest";
}

sub  wikiToUserName {
  my $n = shift;

  return "testrunner" if $n =~ /TestRunner$/;
  return undef;
}

sub  formatGmTime {
    my( $theTime, $theFormat ) = @_;

    return gmtime( $theTime );
}

sub  getUrlHost {
  return "host";
}

sub  getViewUrl {
  my ($w,$t) = @_;
  return getScriptUrl($w, $t, "view");
}

sub  getTwikiWebname {
  return "TWiki";
}

sub  getScriptUrlPath {
  return "$BaseFixture::pwd/../../../../../bin";
}

sub  getScriptUrl {
  my ($w,$t,$s) = @_;
  return "http://twiki/$s.cgi/$w/$t";
}

sub  getPubDir {
  return "$BaseFixture::pwd/../../../../../pub";
}

sub getMainWebname {
  return "Main";
}

sub saveFile {
    BaseFixture::saveFile(@_);
}

sub  getTopicList {
  my $web = shift;

  opendir(DH, getDataDir()."/$web");
  my @list = grep /^.*\.txt$/, readdir(DH);
  closedir(DH);
  foreach my $f (@list) {
    $f =~ s/\.txt$//o;
  }
  return @list;
}

sub  webExists {
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
    my $data = BaseFixture::readFile($lockf);
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
    BaseFixture::lockTopic($web, $topic, time());
  } else {
    BaseFixture::unlockTopic($web,$topic);
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
  my ( $web,$topic,$rev ) = @_;
  if (defined($rev) && $rev ne "") {
	my $cmd = "/usr/bin/co -q -p -r1.$rev ".getDataDir() . "/$web/$topic.txt";
	return `$cmd`;
  }
  return BaseFixture::readFile( getDataDir() . "/$web/$topic.txt" );
}

sub readFile {
    return BaseFixture::readFile( @_ ) if ( -e $_[0] );
    return undef;
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
  my $text = BaseFixture::readFile("$BaseFixture::pwd/../../../../../templates/$template.tmpl" );

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

sub  renderText {
  my ($text) = @_;
  return $text." RENDERED";
}

sub  expandCommonVariables {
  my ($text) = @_;
  my $wpd = getPubDir();
  my $wpu = "file:$wpd";
  $text =~ s/%ATTACHURL%/$wpu/eog;
  $text =~ s/%ATTACHURLPATH%/$wpd/eog;
  $text =~ s/%TMPL:P{\"?(.*?)\"?}%/&_handleTmplP($1)/geo;
  $text =~ s/%([A-Za-z0-9_]+)%/&_evbl($1)/ego;
  if ($BaseFixture::query) {
    $text =~ s/%URLPARAM{(.*?)}%/&_eurlp($1)/ego;
  }
  return $text;
}

sub _eurlp {
  my $ats = shift;
  my $vbl = extractNameValuePair($ats);
  my $repl = extractNameValuePair($ats, "newline");
  if ( $BaseFixture::query->param($vbl)) {
    my $val = $BaseFixture::query->param($vbl);
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

sub  getPreferencesValue {
  my $what = shift;

  return $BaseFixture::prefs{$what};
}

sub  getPreferencesFlag {
  my $what = shift;

  return $BaseFixture::prefs{$what};
}

sub writeDebug {
  my ($text) = @_;
  push(@BaseFixture::debug, $text);
}

sub writeWarning {
  my ($text) = @_;
  push(@BaseFixture::warning, $text);
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

  BaseFixture::writeTopic($web, $topic, $text);
}

sub formatTime {
  my ($t,$f,$s) = @_;
  my $st = "TIME";
  $st = "$st$f" if ($f);
  $st = "$st$s" if ($s);
  return $st;
}

sub getRegularExpression {
  my $name = shift;

  if ($name eq "webNameRegex") {
	return qr/[A-Z]+[A-Za-z0-9]*/;
  } elsif ($name eq "wikiWordRegex") {
	return qr/[A-Z]+[a-z]+[A-Z]\w*/;
  } elsif ($name eq "anchorRegex") {
	return qr/\#[A-Za-z0-9_]+/;
} elsif ($name eq "emailAddrRegex") {
    return qr/([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/;
  } else {
	die "$name is not usable";
  }
}

sub getPublicWebList {
    return BaseFixture::webList();
}

sub getWebTopicList {
    return BaseFixture::topicList(@_);
}

1;
