use strict;

package CommentTest;

use TWiki::Plugins::CommentPlugin::Comment;
require 'FuncFixture.pm';
require 'StoreFixture.pm';
import TWiki::Func;
import TWiki::Store;

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
  my ($this, $type, $web, $topic, $anchor, $location, $locked) = @_;

  my $eidx = 1;
  my $sattrs = "";

  $web = "TESTWEB" unless $web;
  $topic = "TESTTOPIC" unless $topic;

  if ($web ne "TESTWEB" || $topic ne "TESTTOPIC" || $anchor) {

    $sattrs = "target=\"";

    $sattrs .= "$web." unless ($web eq "TESTWEB");
    $sattrs .= $topic unless ($topic eq "TESTTOPIC");

    if ( $anchor) {
      $anchor = "#$anchor";
      $sattrs .= $anchor;
    }
    $sattrs .= "\"";
  }

  my $url = "http://twiki/save.cgi/$web/$topic";

  if ( $location ) {
    $sattrs .= " location=\"$location\"";
  }

  my $disabled = "";
  if ($locked) {
    $disabled = "disabled";
  }

  $sattrs .= "\" ";
  $type = "bottom" unless ($type);
  $sattrs .= "type=\"$type\" ";

  my $commentref = "%COMMENT{type=\"$type\" refmark=\"here\"}%";

  # Build the target topic
  my $sample = "TopOfTopic\n%COMMENT{type=\"$type\"}%\n";
  $sample .= "BeforeAnchor\n$anchor\nAfterAnchor\n" if ($anchor);
  $sample .= "BeforeLocation\nHereIsTheLocation\nAfterLocation";
  $sample .= "$commentref\n";
  $sample .= "BottomOfTopic\n";

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
	 "bottom");

  $this->assert($pidx == $eidx + 1, $html);

  $html =~ s/^<form(.*?)>//sio;
  my $dattrs = $1;
  $html =~ s/<\/form>\n$//sio;
  $this->assert(scalar($dattrs =~ s/\s+name=\"(.*?)\"//), $dattrs);
  $this->assert_str_equals("$disabled${type}$eidx", $1);
  $this->assert(scalar($dattrs =~ s/\s+method\s*=\s*\"${disabled}post\"//i), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s+action=\"(.*?)\"//), $dattrs);
  $this->assert_str_equals("${disabled}$url", $1);
  $this->assert_str_equals("", trim($dattrs));

  $html =~ s/<input ${disabled} name=\"${disabled}comment_type"(.*?)\s*\/>//i;
  $dattrs = $1;
  $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s*value=\"$type\"//), $dattrs);
  $this->assert_str_equals("", trim($dattrs));

  if ( $anchor ) {
    $html =~ s/<input ${disabled} name=\"${disabled}comment_anchor"(.*?)\s*\/>//i;
    $dattrs = $1;
    $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
    $this->assert(scalar($dattrs =~ s/\s*value=\"(.*?)\"//o), $dattrs);
    $this->assert_str_equals($anchor, $1);
    $this->assert_str_equals("", trim($dattrs));
    $this->assert_does_not_match(qr/<input name=\"comment_index/, $html);
    $this->assert_does_not_match(qr/<input name=\"comment_location/, $html);
  } elsif ( $location) {
    $html =~ s/<input ${disabled} name=\"${disabled}comment_location"(.*?)\s*\/>//i;
    $dattrs = $1;
    $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
    $this->assert(scalar($dattrs =~ s/\s*value=\"(.*?)\"//o), $dattrs);
    $this->assert_str_equals($location, $1);
    $this->assert_str_equals("", trim($dattrs));
    $this->assert_does_not_match(qr/<input name=\"comment_index/, $html);
    $this->assert_does_not_match(qr/<input name=\"comment_anchor/, $html);
  } else {
    $html =~ s/<input ${disabled} name=\"${disabled}comment_index"(.*?)\s*\/>//i;
    $dattrs = $1;
    $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
    $this->assert(scalar($dattrs =~ s/\s*value=\"(.*?)\"//io), $dattrs);
    $this->assert_str_equals($eidx, $1);
    $this->assert_str_equals("", trim($dattrs));
    $this->assert_does_not_match(qr/<input name=\"comment_anchor/, $html);
    $this->assert_does_not_match(qr/<input name=\"comment_location/, $html);
  }
  $this->assert_matches(qr/<input ${disabled} name=\"${disabled}unlock\"(.*?)\s*\/>/, $html);
  $html =~ s/<input ${disabled} name=\"${disabled}unlock\"(.*?)\s*\/>//i;
  $dattrs = $1;
  $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s*value=\"1\"//io), $dattrs);
  $this->assert_str_equals("", trim($dattrs));

  $html =~ s/<input ${disabled} name=\"${disabled}text\"(.*?)\s*\/>//i;
  $dattrs = $1;
  $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
  $this->assert(scalar($dattrs =~ s/\s*value=\"dummy\"//io), $dattrs);
  $this->assert_str_equals("", trim($dattrs));

  $html =~ s/<textarea ${disabled} (.*?)>(.*?)<\/textarea>//i;
  $dattrs = $1;
  $this->assert_matches(qr/name=\"comment\"/, $dattrs);
  my $mess = $2;
  if ($locked) {
    $this->assert_matches(qr/\Wlocker for at least 0 /, $mess);
  } else {
    $this->assert_str_equals("The Message", $mess);
  }
  $this->assert_matches(qr/<input\s+$disabled\s*type="submit"\s*value=\".*?"\s*\/>/i,
			$html);

  return if ( $locked );
  # can't save, button disabled, so no point trying

  my $comm = "This is the comment";
  $query = new CGI({
		    'comment_type' => $type,
		    'comment' => $comm });
  if ( $anchor ) {
    $query->param(-name=>'comment_anchor', -value=>$anchor);
  } elsif ( $location) {
    $query->param(-name=>'comment_location', -value=>$location);
  } else {
    $query->param(-name=>'comment_index', -value=>$eidx);
  }

  TWiki::Func::TESTsetCGIQuery($query);
  my $text = "This will be lost!";
  # invoke the before save handler
  _doubleBlind($text, $topic, $web);
  $this->assert_matches(qr/$comm/, $text);

  my $refexpr;
  if ($anchor) {
    $refexpr = $anchor;
  } elsif ($location) {
    $refexpr = "HereIsTheLocation";
  } else {
    $refexpr = $commentref;
  }

  if ( $type eq "top" ) {
    $this->assert_matches(qr/$comm.*TopOfTopic/s, $text);
  } elsif ( $type eq "bottom" ) {
    $this->assert_matches(qr/BottomOfTopic.*$comm/s, $text);
  } elsif ( $type eq "above" ) {
    $this->assert_matches(qr/TopOfTopic.*$comm.*$refexpr/s, $text);
  } elsif ( $type eq "below" ) {
    $this->assert_matches(qr/$refexpr.*$comm.*BottomOfTopic/s, $text);
  }
}

# mirror how the plugin calls it
sub _doubleBlind() {
  CommentPlugin::Comment::save($query, @_);
}

sub test1default {
  my $this = shift;
  
  $this->inputTest("above", undef, undef, undef, undef, 0);
}

sub test2topicOnly {
  my $this = shift;
  
  $this->inputTest("below", undef, "TargetTopic", undef, undef, 0);
}


sub test3topicAndWeb {
  my $this = shift;
  
  $this->inputTest("bottom", "TargetWeb", "TargetTopic", undef, undef, 0);
}

sub test4topicWebAndAnchor {
  my $this = shift;
  
  $this->inputTest("top", "TargetWeb", "TargetTopic", "TargetAnchor", undef, 0);
}

sub test5topicWebAndAnchor {
  my $this = shift;
  
  $this->inputTest("above", "TargetWeb", "TargetTopic", "TargetAnchor", undef, 0);
}

sub test6topicWebAndAnchor {
  my $this = shift;
  
  $this->inputTest("below", "TargetWeb", "TargetTopic", "TargetAnchor", undef, 0);
}

sub test7location {
  my $this = shift;
  
  $this->inputTest("below", undef, undef, undef, "HereIsTheLocation", 0);
}

sub test8location {
  my $this = shift;

  $this->inputTest("above", undef, undef, undef, "^He.*on\$", 0);
}

sub test5input_locked {
  my $this = shift;
  TWiki::Func::TESTlockTopic("TESTWEB", "TESTTOPIC", 0);
  $this->inputTest("top", undef, undef, undef, undef, 1);
}

sub test6input_locked {
  my $this = shift;
  TWiki::Func::TESTlockTopic("TESTWEB", "TargetTopic", 0);
  $this->inputTest("above", undef, "TargetTopic", undef, undef, 1);
}


sub test7input_locked {
  my $this = shift;
  TWiki::Func::TESTlockTopic("TargetWeb", "TargetTopic", 0);
  $this->inputTest("bottom", "TargetWeb", "TargetTopic", undef, undef, 1);
}

sub testReverseCompat {
  my $this = shift;
   # rows: Any number > 0 will set the rows of the text area (default is 5)
   # cols: Any number > 10 will set the columns of the textarea (default is 70)
   # mode: The word "after" tells Comment to put the posted data after the form in reverse chronological order (default = "normal" chronological order)
   # button: This lets you change the text of the submit button (default is "Add Comment")
   # id: This gives a unique name for a COMMENT, in case you have more than one COMMENT tag in a topic (mandatory with > 1 COMMENT)

  my $pidx = 0;
  my $html =
    CommentPlugin::Comment::_handleInput
	("rows=99 cols=104 mode=after button=HoHo id=sausage",,
	 "TESTTOPIC",
	 "TESTWEB",
	 \$pidx,
	 "The Message",
	 "",
	 "bottom");
  $this->assert_matches(qr/form name=\"after0\"/, $html);
  $this->assert_matches(qr/rows=\"99\"/, $html);
  $this->assert_matches(qr/cols=\"104\"/, $html);
  $this->assert_matches(qr/type=\"submit\" value=\"HoHo\"/, $html);
}

sub test_locationOverridesAnchor {
  my $this = shift;
  my $pidx = 0;
  my $html =
    CommentPlugin::Comment::_handleInput
	("target=\"AWeb.ATopic#AAnchor\" location=\"AnRE\"",
	 "TESTTOPIC",
	 "TESTWEB",
	 \$pidx,
	 "The Message",
	 "",
	 "bottom");
  $this->assert_matches(qr/<input\s+name="comment_location"(.*?)\s*\/>/, $html);
}

1;
