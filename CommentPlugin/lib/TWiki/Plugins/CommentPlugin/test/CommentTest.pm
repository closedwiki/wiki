use strict;

package CommentTest;

use TWiki::Plugins::CommentPlugin::Comment;
require 'FuncFixture.pm';
import TWiki::Func;

use CGI;
use base qw(TWiki::Func);
my $query;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;
  
  $this->SUPER::set_up();
}

sub trim {
  my $s = shift;
  $s =~ s/^\s*(.*?)\s*$/$1/sgo;
  return $s;
}

sub inputTest {
  my ($this, $type, $web, $topic, $anchor, $locked) = @_;
  
  my $eidx = 1;
  my $url = "http://twiki/save.cgi/";
  my $sattrs = "target=\"";
  
  if ($web) {
    $sattrs .= "$web.";
  } else {
    $web = "TESTWEB";
  }
  $url .= "$web/";
  
  if ( $topic) {
    $sattrs .= $topic;
  } else {
    $topic = "TESTTOPIC";
  }
  $url .= "$topic";
  
  if ( $anchor) {
    $anchor = "#$anchor";
    $sattrs .= $anchor;
  } else {
    $anchor = "";
  }
  
  my $disabled = "";
  if ($locked) {
    $url = "disabled";
    $disabled = " disabled";
  }
  
  $sattrs .= "\" ";
  $type = "bottom" unless ($type);
  $sattrs .= "type=\"$type\" ";
  
  # Make sure the target topic is there, with anchor. If the target
  # is TESTWEB/TESTTOPIC, then insert the %COMMENT as well
  my $sample = "TOF\nBefore anchor\n$anchor\nAfter anchor\n";
  if ("$web.$topic" eq "TESTWEB.TESTTOPIC" || $anchor eq "") {
    $sample .= "%COMMENT{type=$type}%\n";
    $sample .= "%COMMENT{type=$type}%\n";
  }
  $sample .= "EOF\n";
  TWiki::Func::TESTwriteTopic($web, $topic, $sample);
  my $pidx = $eidx;
  my $html =
    CommentPlugin::Comment::_handleInput
	($sattrs,
	 "TESTTOPIC",
	 "TESTWEB",
	 \$pidx,
	 "The Message",
	 "",
	 $type);
  
  $this->assert($pidx == $eidx + 1);
  
  $html =~ s/^<form(.*?)>//sio;
  my $dattrs = $1;
  $html =~ s/<\/form>\n$//sio;
  $this->assert(scalar($dattrs =~ s/\s+name=\"(.*?)\"//), $dattrs);
  $this->assert_str_equals("${type}$eidx", $1);
  $this->assert(scalar($dattrs =~ s/\s+method\s*=\s*\"post\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s+action=\"(.*?)\"//), $dattrs);
  $this->assert_str_equals($url, $1);
  $this->assert_str_equals("", trim($dattrs));
  
  $html =~ s/<input name=\"comment_type"(.*?)\s*\/>//i;
  $dattrs = $1;
  $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s*value=\"$type\"//), $dattrs);
  $this->assert_str_equals("", trim($dattrs));
  
  $html =~ s/<input name=\"comment_anchor"(.*?)\s*\/>//i;
  $dattrs = $1;
  $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s*value=\"(.*?)\"//o), $dattrs);
  $this->assert_str_equals($anchor, $1);
  $this->assert_str_equals("", trim($dattrs));
  
  $html =~ s/<input name=\"comment_index"(.*?)\s*\/>//i;
  $dattrs = $1;
  $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s*value=\"(.*?)\"//io), $dattrs);
  $this->assert_str_equals($eidx, $1);
  $this->assert_str_equals("", trim($dattrs));
  
  $html =~ s/<input name=\"unlock\"(.*?)\s*\/>//i;
  $dattrs = $1;
  $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s*value=\"1\"//io), $dattrs);
  $this->assert_str_equals("", trim($dattrs));
  
  
  $html =~ s/<input name=\"text\"(.*?)\s*\/>//i;
  $dattrs = $1;
  $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s*value=\"dummy\"//io), $dattrs);
  $this->assert_str_equals("", trim($dattrs));
  
  $html =~ s/<textarea(.*?)>(.*?)<\/textarea>//i;
  $dattrs = $1;
  $this->assert_matches(qr/name=\"comment\"/, $dattrs);
  my $mess = $2;
  if ($locked) {
    $this->assert_str_equals("Commenting is locked out by locker for at least 0 minutes", $mess);
  } else {
    $this->assert_str_equals("The Message", $mess);
  }
  $this->assert_matches(qr/<input\s*type="submit"\s*value=\".*?"\s*\/>/i,
			$html);
  
  return if ( $locked );
  # can't save, button disabled, so no point trying
  
  $query = new CGI({
		       'comment_type' => $type,
		       'comment_index' => $eidx,
		       'comment_anchor' => $anchor,
		       'comment' => "This is the comment"
		      });
  TWiki::Func::TESTsetCGIQuery($query);
  my $text = "This will be lost!";
  # invoke the before save handler
  _doubleBlind($text, $topic, $web);
  $this->assert_matches(qr/This is the comment/, $text);
  if ($anchor ne "") {
    $this->assert_matches(qr/^$anchor/m, $text);
  }
  print "TYPE $sattrs \n$text\n";
  # Should really check placement of the comment in the output topic
  # but I can't be arsed.
}

# mirror how the plugin calls it
sub _doubleBlind() {
  CommentPlugin::Comment::save($query, @_);
}

sub test1input {
  my $this = shift;
  
  $this->inputTest("above", undef, undef, undef, 0);
}

sub test2input {
  my $this = shift;
  
  $this->inputTest("below", undef, "TargetTopic", undef, 0);
}


sub test3input {
  my $this = shift;
  
  $this->inputTest("bottom", "TargetWeb", "TargetTopic", undef, 0);
}

sub test4input {
  my $this = shift;
  
  $this->inputTest("top", "TargetWeb", "TargetTopic", "TargetAnchor", 0);
}

sub test5input_locked {
  my $this = shift;
  TWiki::Func::TESTlockTopic("TESTWEB", "TESTTOPIC", 0);
  $this->inputTest("top", undef, undef, undef, 1);
}

sub test6input_locked {
  my $this = shift;
  TWiki::Func::TESTlockTopic("TESTWEB", "TargetTopic", 0);
  $this->inputTest("above", undef, "TargetTopic", undef, 1);
}


sub test7input_locked {
  my $this = shift;
  TWiki::Func::TESTlockTopic("TargetWeb", "TargetTopic", 0);
  $this->inputTest("bottom", "TargetWeb", "TargetTopic", undef, 1);
}

1;
