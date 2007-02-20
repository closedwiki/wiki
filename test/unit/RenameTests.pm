use strict;

package RenameTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::UI::Manage;
use CGI;
use Error ':try';

my $oldweb = "TemporaryRenameOldWeb";
my $newweb = "TemporaryRenameNewWeb";
my $oldtopic = "OldTopic";
my $newtopic = "NewTopic";
my $twiki;
my $originaltext;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki( "TestUser1", new CGI({topic=>"/$oldweb/$oldtopic"}));

    $twiki->{store}->createWeb($twiki->{user}, $oldweb);
    $twiki->{store}->createWeb($twiki->{user}, $newweb);

    $TWiki::Plugins::SESSION = $twiki;
    my $meta = new TWiki::Meta($twiki, $oldweb, $oldtopic);
    $meta->putKeyed( "FIELD", {name=>"$oldweb",
                          value=>"$oldweb"} );
    $meta->putKeyed( "FIELD", {name=>"$oldweb.$oldtopic",
                          value=>"$oldweb.$oldtopic"} );
    $meta->putKeyed( "FIELD", {name=>"$oldtopic",
                          value=>"$oldtopic"} );
    $meta->putKeyed( "FIELD", {name=>"OLD",
                          value=>"$oldweb.$oldtopic"} );
    $meta->putKeyed( "FIELD", {name=>"NEW",
                          value=>"$newweb.$newtopic"} );
    $meta->put( "TOPICPARENT", {name=> "$oldweb.$oldtopic"} );

    $originaltext = <<THIS;
1 $oldweb.$oldtopic
$oldweb.$oldtopic 2
3 $oldweb.$oldtopic more
$oldtopic 4
5 $oldtopic
7 ($oldtopic)
8 [[$oldweb.$oldtopic]]
9 [[$oldtopic]]
10 [[$oldweb.$oldtopic][the text]]
11 [[$oldtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic
14 OtherTopic
15 $oldweb.OtherTopic
16 $newweb.OtherTopic

<verbatim>
protected $oldweb.$oldtopic
</verbatim>
<pre>
pre $oldweb.$oldtopic
</pre>
<noautolink>
protected $oldweb.$oldtopic
</noautolink>

THIS

    $twiki->{store}->saveTopic( $twiki->{user}, $oldweb, $oldtopic,
                                $originaltext, $meta );
    $twiki->{store}->saveTopic( $twiki->{user}, $oldweb, "OtherTopic",
                                $originaltext, $meta );
    $twiki->{store}->saveTopic( $twiki->{user}, $newweb, "OtherTopic",
                                $originaltext, $meta );
    $twiki->{store}->saveTopic( $twiki->{user}, $newweb,
                                $TWiki::cfg{HomeTopicName},
                                "junk", $meta );
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($twiki,$oldweb);
    $this->removeWebFixture($twiki,$newweb);
    eval {$twiki->finish()};
    $this->SUPER::tear_down();
}

sub check {
    my($this, $web, $topic, $emeta, $expected, $num) = @_;
    my($meta,$actual) = $twiki->{store}->readTopic( undef, $web, $topic );
    my @old = split(/\n+/, $expected);
    my @new = split(/\n+/, $actual);

    while (scalar(@old)) {
        my $o = "$num: ".shift(@old);
        my $n = "$num: ".shift(@new);
        $this->assert_str_equals($o, $n, "Expect $o\nActual $n\n".join(",",caller));
    }
}

sub test_referringtopics {
    my $this = shift;
    my $refs = TWiki::UI::Manage::getReferringTopics($twiki,
                                                     $oldweb, $oldtopic, 0);
    $this->assert_str_equals("HASH", ref($refs));
    my @expected = ( "$oldweb.OtherTopic" );
    @expected = sort(@expected);

    my $i = scalar(keys %$refs);
    $this->assert_equals( scalar(@expected), $i, join(",",keys %$refs));
    $i = 0;
    foreach my $r ( sort keys %$refs ) {
        $this->assert_str_equals($expected[$i++], $r);
    }
    $refs = TWiki::UI::Manage::getReferringTopics(
        $twiki, $oldweb, $oldtopic, 1);
    $this->assert( $refs->{"$newweb.OtherTopic"});
    $this->assert( !$refs->{"$oldweb.OtherTopic"});
    $this->assert( !$refs->{"$newweb.$oldtopic"}) ;
}

sub test_rename_oldwebnewtopic {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'rename' ],
                         newweb => [ $oldweb ],
                         newtopic => [ $newtopic ],
                         referring_topics => [ "$oldweb.$newtopic",
                                               "$oldweb.OtherTopic",
                                               "$newweb.OtherTopic" ],
                         topic => $oldtopic
                        });

    $query->path_info( "/$oldweb/SanityCheck" );
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;
    $this->capture(\&TWiki::UI::Manage::rename, $twiki );

    $this->assert( $twiki->{store}->topicExists( $oldweb, $newtopic ));
    $this->assert(!$twiki->{store}->topicExists( $oldweb, $oldtopic ));
    my $expected = <<THIS;
1 $newtopic
$newtopic 2
3 $newtopic more
$newtopic 4
5 $newtopic
7 ($newtopic)
8 [[$newtopic]]
9 [[$newtopic]]
10 [[$newtopic][the text]]
11 [[$newtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic
14 OtherTopic
15 $oldweb.OtherTopic
16 $newweb.OtherTopic

<verbatim>
protected $oldweb.$oldtopic
</verbatim>
<pre>
pre $newtopic
</pre>
<noautolink>
protected $oldweb.$oldtopic
</noautolink>
THIS
    $this->check($oldweb, $newtopic, undef, $expected, 1);
    $this->check($oldweb, 'OtherTopic', undef, $expected, 2);
    $expected = <<THIS;
1 $oldweb.$newtopic
$oldweb.$newtopic 2
3 $oldweb.$newtopic more
$oldtopic 4
5 $oldtopic
7 ($oldtopic)
8 [[$oldweb.$newtopic]]
9 [[$oldtopic]]
10 [[$oldweb.$newtopic][the text]]
11 [[$oldtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic
14 OtherTopic
15 $oldweb.OtherTopic
16 $newweb.OtherTopic

<verbatim>
protected $oldweb.$oldtopic
</verbatim>
<pre>
pre $oldweb.$newtopic
</pre>
<noautolink>
protected $oldweb.$oldtopic
</noautolink>
THIS
    $this->check($newweb, 'OtherTopic', undef, $expected, 3);
}

sub test_rename_newweboldtopic {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'rename' ],
                         newweb => [ $newweb ],
                         newtopic => [ $oldtopic ],
                         referring_topics => [ "$oldweb.OtherTopic",
                                               "$newweb.$oldtopic",
                                               "$newweb.OtherTopic" ],
                         topic => $oldtopic
                        });

    $query->path_info("/$oldweb" );
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;
    $this->capture( \&TWiki::UI::Manage::rename, $twiki );

    $this->assert( $twiki->{store}->topicExists( $newweb, $oldtopic ));
    $this->assert(!$twiki->{store}->topicExists( $oldweb, $oldtopic ));

    my $expected = <<THIS;
1 $oldtopic
$oldtopic 2
3 $oldtopic more
$oldtopic 4
5 $oldtopic
7 ($oldtopic)
8 [[$oldtopic]]
9 [[$oldtopic]]
10 [[$oldtopic][the text]]
11 [[$oldtopic][the text]]
12 $oldweb.$newtopic
13 $oldtopic
14 $oldweb.OtherTopic
15 $oldweb.OtherTopic
16 OtherTopic

<verbatim>
protected $oldweb.$oldtopic
</verbatim>
<pre>
pre $oldtopic
</pre>
<noautolink>
protected $oldweb.$oldtopic
</noautolink>
THIS
    $this->check($newweb, $oldtopic, undef, $expected, 4);
    $expected = <<THIS;
1 $oldtopic
$oldtopic 2
3 $oldtopic more
$oldtopic 4
5 $oldtopic
7 ($oldtopic)
8 [[$oldtopic]]
9 [[$oldtopic]]
10 [[$oldtopic][the text]]
11 [[$oldtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic
14 OtherTopic
15 $oldweb.OtherTopic
16 $newweb.OtherTopic

<verbatim>
protected $oldweb.$oldtopic
</verbatim>
<pre>
pre $oldtopic
</pre>
<noautolink>
protected $oldweb.$oldtopic
</noautolink>
THIS
    $this->check($newweb, 'OtherTopic', undef, $expected, 5);
    $expected = <<THIS;
1 $newweb.$oldtopic
$newweb.$oldtopic 2
3 $newweb.$oldtopic more
$newweb.$oldtopic 4
5 $newweb.$oldtopic
7 ($newweb.$oldtopic)
8 [[$newweb.$oldtopic]]
9 [[$newweb.$oldtopic]]
10 [[$newweb.$oldtopic][the text]]
11 [[$newweb.$oldtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic
14 OtherTopic
15 $oldweb.OtherTopic
16 $newweb.OtherTopic

<verbatim>
protected $oldweb.$oldtopic
</verbatim>
<pre>
pre $newweb.$oldtopic
</pre>
<noautolink>
protected $oldweb.$oldtopic
</noautolink>
THIS
    $this->check($oldweb, 'OtherTopic', undef, $expected, 6);
}


# Purpose:  Rename a topic which starts with a lowercase letter
# Verifies:
#    * Return status is a redirect
#    * New script is view, not oops
#    * New topic name is changed
#    * In the new topic, the initial letter is changed to upper case
sub test_rename_from_lowercase {
    my $this       =  shift;
    my $oldtopic   =  'lowercase';
    my $newtopic   =  'upperCase';
    my $meta       =  new TWiki::Meta($twiki, $oldweb, $oldtopic);
    my $topictext  =  'Dummy';
    $twiki->{store}->saveTopic( $twiki->{user}, $oldweb, $oldtopic,
                                $topictext, $meta );
    my $query = new CGI({
                         action   => 'rename',
                         topic    => $oldtopic,
                         newweb   => $oldweb,
                         newtopic => $newtopic,
                        });

    $query->path_info("/$oldweb" );
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;
    my ($text,$result)  =  $this->capture( \&TWiki::UI::Manage::rename, $twiki );
    my $ext = $TWiki::cfg{ScriptSuffix};
    $this->assert_matches(qr/^Status:\s+302/s,$text);
    $this->assert_matches(qr(Location:\s+\S+?/view$ext/$oldweb/UpperCase)s,$text)
}

sub test_accessRenameRestrictedTopic {
    my $this       =  shift;
    my $oldtopic   =  'lowercase';
    my $newtopic   =  'upperCase';
    my $meta       =  new TWiki::Meta($twiki, $oldweb, $oldtopic);
    my $topictext  =  "   * Set ALLOWTOPICRENAME = GungaDin\n";
    $twiki->{store}->saveTopic( $twiki->{user}, $oldweb, $oldtopic,
                                $topictext, $meta );
    my $query = new CGI({
                         action   => 'rename',
                         topic    => $oldtopic,
                         newweb   => $oldweb,
                         newtopic => $newtopic,
                        });

    $query->path_info("/$oldweb" );
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;
    try {
        my ($text,$result) = TWiki::UI::Manage::rename( $twiki );
        $this->assert(0);
    } catch TWiki::OopsException with {
        $this->assert_str_equals('OopsException(accessdenied/topic_access web=>TemporaryRenameOldWeb topic=>lowercase params=>[RENAME,access not allowed on topic])', shift->stringify());
    }
}

sub test_accessRenameRestrictedWeb {
    my $this       =  shift;
    my $oldtopic   =  'WebPreferences';
    my $meta       =  new TWiki::Meta($twiki, $oldweb, $oldtopic);
    my $topictext  =  "   * Set ALLOWWEBRENAME = GungaDin\n";
    $twiki->{store}->saveTopic( $twiki->{user}, $oldweb, $oldtopic,
                                $topictext, $meta );
    my $query = new CGI({
                         action   => 'rename',
                         topic    => $oldtopic,
                         newweb   => $oldweb,
                         newtopic => $newtopic,
                        });

    $query->path_info("/$oldweb" );
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;
    try {
        my ($text,$result) = TWiki::UI::Manage::rename( $twiki );
        $this->assert(0);
    } catch TWiki::OopsException with {
        $this->assert_str_equals('OopsException(accessdenied/topic_access web=>TemporaryRenameOldWeb topic=>WebPreferences params=>[RENAME,access not allowed on web])', shift->stringify());
    }
}

1;
