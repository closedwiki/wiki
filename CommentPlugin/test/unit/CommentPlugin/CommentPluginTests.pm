use strict;

package CommentPluginTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::UI::Save;
use TWiki::Plugins::CommentPlugin;
use TWiki::Plugins::CommentPlugin::Comment;
use CGI;

my $baseweb = "TestCommentPluginTestWeb";
my $targetweb = "TestCommentPluginTargetWeb";
my $basetopic = "TestCommentPluginTopic";
my $targettopic = "TargetTopic";

my $thePathInfo = "/$baseweb/$basetopic";
my $twiki;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki( "TestUser1" );

    $twiki->{store}->createWeb($twiki->{user}, $baseweb);
    $twiki->{store}->createWeb($twiki->{user}, $targetweb);

    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $baseweb);
    $twiki->{store}->removeWeb($twiki->{user}, $targetweb);
}

sub writeTopic {
    my( $web, $topic, $text ) = @_;
    my $meta = new TWiki::Meta($twiki, $web, $topic);
    $twiki->{store}->saveTopic( $twiki->{user}, $web, $topic, $text,
                                $meta );
}

sub trim {
    my $s = shift;
    $s =~ s/^\s*(.*?)\s*$/$1/sgo;
    return $s;
}

# Not a test, a helper.
sub inputTest {
    my ($this, $type, $web, $topic, $anchor, $location) = @_;

    my $eidx = 1;
    my $sattrs = "";

    $web = $baseweb unless $web;
    $topic = $basetopic unless $topic;

    if ($web ne $baseweb || $topic ne $basetopic || $anchor) {

        $sattrs = "target=\"";

        $sattrs .= "$web." unless ($web eq $baseweb);
        $sattrs .= $topic unless ($topic eq $basetopic);

        if ( $anchor) {
            $anchor = "#$anchor";
            $sattrs .= $anchor;
        }
        $sattrs .= "\"";
    }

    my $url = "$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}/save$TWiki::cfg{ScriptSuffix}/$web/$topic";

    if ( $location ) {
        $sattrs .= " location=\"$location\"";
    }

    $type = "bottom" unless ($type);
    $sattrs .= "type=\"$type\" ";

    my $commentref = "%COMMENT{type=\"$type\" refmark=\"here\"}%";

    # Build the target topic
    my $sample = "TopOfTopic\n%COMMENT{type=\"$type\"}%\n";
    $sample .= "BeforeAnchor\n$anchor\nAfterAnchor\n" if ($anchor);
    $sample .= "BeforeLocation\nHereIsTheLocation\nAfterLocation";
    $sample .= "$commentref\n";
    $sample .= "BottomOfTopic\n";

    writeTopic($web, $topic, $sample);
    my $pidx = $eidx;
    my $html =
      TWiki::Plugins::CommentPlugin::Comment::_handleInput
          ($sattrs,
           $baseweb,
           $basetopic,
           \$pidx,
           "The Message",
           "",
           "bottom");

    $this->assert($pidx == $eidx + 1, $html);

    $this->assert(scalar($html =~ s/^<form(.*?)>//sio));
    my $dattrs = $1;
    $this->assert(scalar($html =~ s/<\/form>\s*$//sio));
    $this->assert(scalar($dattrs =~ s/\s+name=\"(.*?)\"//), $dattrs);
    $this->assert_str_equals("${type}$eidx", $1);
    $this->assert(scalar($dattrs =~ s/\s+method\s*=\s*\"post\"//i), $dattrs);
    $this->assert(scalar($dattrs =~ s/\s+action=\"(.*?)\"//), $dattrs);
    $this->assert_str_equals($url, $1);
    $this->assert_str_equals('enctype="application/x-www-form-urlencoded"', trim($dattrs));

    # no hiddens should be generated if disabled
    $this->assert(scalar($html =~ s/<input ([^>]*\bname="comment_type".*?)\/>//i),$html);
    $dattrs = $1;
    $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
    $this->assert(scalar($dattrs =~ s/\s*value=\"$type\"//), $dattrs);
    $this->assert_str_equals('name="comment_type"', trim($dattrs));

    if ( $anchor ) {
        $this->assert($html =~ s/<input ([^>]*name=\"comment_anchor".*?)\s*\/>//i,$html);
        $dattrs = $1;
        $this->assert(scalar($dattrs =~ s/\s*name=\"comment_anchor\"//io), $dattrs);
        $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
        $this->assert(scalar($dattrs =~ s/\s*value=\"(.*?)\"//o), $dattrs);
        $this->assert_str_equals($anchor, $1);
        $this->assert_str_equals("", trim($dattrs));
        $this->assert_does_not_match(qr/<input name=\"comment_index/, $html);
        $this->assert_does_not_match(qr/<input name=\"comment_location/, $html);
    } elsif ( $location ) {
        $this->assert_matches(qr/<input [^>]*name="comment_location"(.*?)\s*\/>/i, $html);
        $this->assert($html =~ s/<input ([^>]*name="comment_location".*?)\s*\/>//i);
        $dattrs = $1;
        $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
        $this->assert(scalar($dattrs =~ s/\s*name=\"comment_location\"//io), $dattrs);
        $this->assert(scalar($dattrs =~ s/\s*value=\"(.*?)\"//o), $dattrs);
        $this->assert_str_equals($location, $1);
        $this->assert_str_equals("", trim($dattrs));
        $this->assert_does_not_match(qr/<input name=\"comment_index/, $html);
        $this->assert_does_not_match(qr/<input name=\"comment_anchor/, $html);
    } else {
        $this->assert($html =~ /<input ([^>]*name=\"comment_index".*?)\s*\/>/i, $html);
        $dattrs = $1;
        $this->assert(scalar($dattrs =~ s/\s*name=\"comment_index\"//io), $dattrs);
        $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
        $this->assert(scalar($dattrs =~ s/\s*value=\"(.*?)\"//io), $dattrs);
        $this->assert_str_equals($eidx, $1);
        $this->assert_str_equals("", trim($dattrs));
        $this->assert_does_not_match(qr/<input name=\"comment_anchor/, $html);
        $this->assert_does_not_match(qr/<input name=\"comment_location/, $html);
    }

    $this->assert($html =~ s/<input ([^>]*name=\"comment_action\".*?)\s*\/>//, $html);
    $dattrs = $1;
    $this->assert($dattrs =~ s/name=\"comment_action\"//i,$dattrs);
    $this->assert(scalar($dattrs =~ s/\s*type=\"hidden\"//io), $dattrs);
    $this->assert(scalar($dattrs =~ s/\s*value=\"save\"//io), $dattrs);
    $this->assert_str_equals("", trim($dattrs));

    $html =~ s/<textarea  (.*?)>(.*?)<\/textarea>//i;
    $dattrs = $1;
    $this->assert_matches(qr/name=\"comment\"/, $dattrs);
    my $mess = $2;
    $this->assert_str_equals("The Message", $mess);
    $this->assert_matches(qr/<input\s+\s*type="submit"\s*value=\".*?"\s*\/>/i,
                          $html);

    # Compose the query
    my $comm = "This is the comment";
    my $query = new CGI(
                        {
                         'comment_action' => 'save',
                         'comment_type' => $type,
                         'comment' => $comm,
                        });
    $query->path_info("/$web/$topic");
    if ( $anchor ) {
        $query->param(-name=>'comment_anchor', -value=>$anchor);
    } elsif ( $location) {
        $query->param(-name=>'comment_location', -value=>$location);
    } else {
        $query->param(-name=>'comment_index', -value=>$eidx);
    }

    my $session = new TWiki( $TWiki::cfg{DefaultUserLoginName}, $query);
    my $text = "Ignore this text";

    # invoke the save handler
    TWiki::UI::Save::save( $session );

    $text = TWiki::Func::readTopicText($web, $topic);
    $this->assert_matches(qr/$comm/, $text, "$web.$topic: $text");

    my $refexpr;
    if ($anchor) {
        $refexpr = $anchor;
    } elsif ($location) {
        $refexpr = "HereIsTheLocation";
    } else {
        $refexpr = $commentref;
    }

    if( $topic eq $basetopic && $web eq $baseweb ) {
        if ( $type eq "top") {
            $this->assert_matches(qr/$comm.*TopOfTopic/s, $text);
        } elsif ( $type eq "bottom" ) {
            $this->assert_matches(qr/BottomOfTopic.*$comm/s, $text);
        } elsif ( $type eq "above" ) {
            $this->assert_matches(qr/TopOfTopic.*$comm.*$refexpr/s, $text);
        } elsif ( $type eq "below" ) {
            $this->assert_matches(qr/$refexpr.*$comm.*BottomOfTopic/s, $text);
        }
    }
}

sub test_above {
    my $this = shift;
    $this->inputTest("above", undef, undef, undef, undef, 0);
}

sub test_below {
    my $this = shift;
    $this->inputTest("below", undef, undef, undef, undef, 0);
}

sub test_targetTopic {
    my $this = shift;
    $this->inputTest("bottom", undef, $targettopic, undef, undef, 0);
}

sub test_targetWebTopic {
    my $this = shift;
    $this->inputTest("bottom", $targetweb, $targettopic, undef, undef, 0);
}

sub test_targetWebTopicAnchorTop {
    my $this = shift;
    $this->inputTest("top", $targetweb, $targettopic, "TargetAnchor", undef, 0);
}

sub test_targetWebTopicAnchorBottom {
    my $this = shift;
    $this->inputTest("bottom", $targetweb, $targettopic, "TargetAnchor", undef, 0);
}

sub test_location {
    my $this = shift;
    $this->inputTest("below", undef, undef, undef, "HereIsTheLocation", 0);
}

sub test_LocationRE {
    my $this = shift;

    $this->inputTest("above", undef, undef, undef, "^He.*on\$", 0);
}

sub test_reverseCompat {
    my $this = shift;
    # rows: Any number > 0 will set the rows of the text area (default is 5)
    # cols: Any number > 10 will set the columns of the textarea (default is 70)
    # mode: The word "after" tells Comment to put the posted data after the form in reverse chronological order (default = "normal" chronological order)
    # button: This lets you change the text of the submit button (default is "Add Comment")
    # id: This gives a unique name for a COMMENT, in case you have more than one COMMENT tag in a topic (mandatory with > 1 COMMENT)

    my $pidx = 0;
    my $html =
      TWiki::Plugins::CommentPlugin::Comment::_handleInput
          ("rows=99 cols=104 mode=after button=HoHo id=sausage",,
           $basetopic,
           $baseweb,
           \$pidx,
           "The Message",
	 "",
           "bottom");
    $this->assert_matches(qr/form [^>]*name=\"after0\"/, $html);
    $this->assert_matches(qr/rows=\"99\"/, $html);
    $this->assert_matches(qr/cols=\"104\"/, $html);
    $this->assert_matches(qr/type=\"submit\" value=\"HoHo\"/, $html);
}

sub test_locationOverridesAnchor {
    my $this = shift;
    my $pidx = 0;
    my $html =
      TWiki::Plugins::CommentPlugin::Comment::_handleInput
          ("target=\"$baseweb.ATopic#AAnchor\" location=\"AnRE\"",
           $basetopic,
           $baseweb,
           \$pidx,
           "The Message",
	 "",
           "bottom");
    $this->assert_matches(qr/<input ([^>]*name="comment_location".*?)\s*\/>/, $html);
}

1;
