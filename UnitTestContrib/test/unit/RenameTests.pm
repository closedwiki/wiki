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
my $othertopic = "OtherTopic";
my $notawwtopic = "random";
my $originaltext = <<THIS;
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
14 $othertopic
15 $oldweb.$othertopic
16 $newweb.$othertopic
17 MeMe${oldtopic}pick$oldweb.${oldtopic}me
18 http://site/$oldweb/$oldtopic
19 [[http://blah/$oldtopic/blah][ref]]
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

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $TWiki::cfg{EnableHierarchicalWebs} = 1;
    $TWiki::cfg{Htpasswd}{FileName} = '$TWiki::cfg{TempfileDir}/junkpasswd';
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::TWikiUserMapping';
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';      
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;

    $this->{twiki} = new TWiki( "TestUser1", new CGI({topic=>"/$oldweb/$oldtopic"}));
    
    $this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $oldweb);
    $this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $newweb);

    $TWiki::Plugins::SESSION = $this->{twiki};
    my $meta = new TWiki::Meta($this->{twiki}, $oldweb, $oldtopic);
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

    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $oldweb, $oldtopic,
                                $originaltext, $meta );
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $oldweb, $othertopic,
                                $originaltext, $meta );
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $newweb, $othertopic,
                                $originaltext, $meta );
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $newweb,
                                $TWiki::cfg{HomeTopicName},
                                "junk", $meta );
}

sub tear_down {
    my $this = shift;
    unlink $TWiki::cfg{Htpasswd}{FileName};
    $this->removeWebFixture($this->{twiki},$oldweb);
    $this->removeWebFixture($this->{twiki},$newweb);
    $this->{twiki}->finish();
    $this->SUPER::tear_down();
}

sub check {
    my($this, $web, $topic, $emeta, $expected, $num) = @_;
    my($meta,$actual) = $this->{twiki}->{store}->readTopic( undef, $web, $topic );
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
    my $ott = TWiki::spaceOutWikiWord( $oldtopic );
    my $lott = lc($ott);
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $oldweb, 'MatchMeOne',
                                <<THIS );
[[$ott]]
THIS
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $oldweb, 'MatchMeTwo',
                                <<THIS );
[[$lott]]
THIS
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $newweb, 'MatchMeThree',
                                <<THIS );
[[$oldweb.$ott]]
THIS
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $newweb, 'MatchMeFour',
                                <<THIS );
[[$oldweb.$lott]]
THIS
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $oldweb, 'NoMatch',
                                <<THIS );
Refer to $ott and $lott
THIS
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $newweb, 'NoMatch',
                                <<THIS );
Refer to $ott and $lott
THIS
    # Just $oldweb
    my $refs;
    $refs = TWiki::UI::Manage::getReferringTopics(
        $this->{twiki}, $oldweb, $oldtopic, 0);
    $this->assert_str_equals("HASH", ref($refs));
    my @expected;
    @expected =  ( "$oldweb.$othertopic",
                   "$oldweb.MatchMeOne",
                   "$oldweb.MatchMeTwo",
                  );
    @expected = sort @expected;

    my $i;
    $i  = scalar(keys %$refs);
    $this->assert_equals( scalar(@expected), $i, join(",",keys %$refs));
    $i = 0;
    foreach my $r ( sort keys %$refs ) {
        $this->assert_str_equals($expected[$i++], $r);
    }

    # All webs
    $refs = TWiki::UI::Manage::getReferringTopics(
        $this->{twiki}, $oldweb, $oldtopic, 1);
    foreach my $r ( keys %$refs ) {
        unless ($r =~ /^($oldweb|$newweb)\./) {
            delete $refs->{$r};
        }
    }
    @expected = ( "$newweb.$othertopic",
                  "$newweb.MatchMeThree",
                  "$newweb.MatchMeFour",
                  "$newweb.$TWiki::cfg{HomeTopicName}");
    @expected = sort @expected;

    $i = scalar(keys %$refs);
    $this->assert_equals( scalar(@expected), $i, join(",",keys %$refs));
    $i = 0;
    foreach my $r ( sort keys %$refs ) {
        $this->assert_str_equals($expected[$i++], $r);
    }
}

# Rename topic within the same web
sub test_rename_oldwebnewtopic {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'rename' ],
                         newweb => [ $oldweb ],
                         newtopic => [ $newtopic ],
                         referring_topics => [ "$oldweb.$newtopic",
                                               "$oldweb.$othertopic",
                                               "$newweb.$othertopic" ],
                         topic => $oldtopic
                        });

    $query->path_info( "/$oldweb/SanityCheck" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $this->{twiki};
    $this->capture(\&TWiki::UI::Manage::rename, $this->{twiki} );

    $this->assert( $this->{twiki}->{store}->topicExists( $oldweb, $newtopic ));
    $this->assert(!$this->{twiki}->{store}->topicExists( $oldweb, $oldtopic ));
    $this->check($oldweb, $newtopic, undef, <<THIS, 1);
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
14 $othertopic
15 $oldweb.$othertopic
16 $newweb.$othertopic
17 MeMe${oldtopic}pick$oldweb.${oldtopic}me
18 http://site/$oldweb/$newtopic
19 [[http://blah/$oldtopic/blah][ref]]
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
    $this->check($oldweb, $othertopic, undef, <<THIS, 2);
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
14 $othertopic
15 $oldweb.$othertopic
16 $newweb.$othertopic
17 MeMe${oldtopic}pick$oldweb.${oldtopic}me
18 http://site/$oldweb/$newtopic
19 [[http://blah/$oldtopic/blah][ref]]
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

    $this->check($newweb, $othertopic, undef, <<THIS, 3);
1 $oldweb.$newtopic
$oldweb.$newtopic 2
3 $oldweb.$newtopic more
$oldweb.$newtopic 4
5 $oldweb.$newtopic
7 ($oldweb.$newtopic)
8 [[$oldweb.$newtopic]]
9 [[$oldweb.$newtopic]]
10 [[$oldweb.$newtopic][the text]]
11 [[$oldweb.$newtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic
14 $othertopic
15 $oldweb.$othertopic
16 $newweb.$othertopic
17 MeMe${oldtopic}pick$oldweb.${oldtopic}me
18 http://site/$oldweb/$newtopic
19 [[http://blah/$oldtopic/blah][ref]]
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
}

# Rename topic to a different web, keeping the same name
sub test_rename_newweboldtopic {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'rename' ],
                         newweb => [ $newweb ],
                         newtopic => [ $oldtopic ],
                         referring_topics => [ "$oldweb.$othertopic",
                                               "$newweb.$oldtopic",
                                               "$newweb.$othertopic" ],
                         topic => $oldtopic
                        });

    $query->path_info("/$oldweb" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $this->{twiki};
    $this->capture( \&TWiki::UI::Manage::rename, $this->{twiki} );

    $this->assert( $this->{twiki}->{store}->topicExists( $newweb, $oldtopic ));
    $this->assert(!$this->{twiki}->{store}->topicExists( $oldweb, $oldtopic ));

    $this->check($newweb, $oldtopic, undef, <<THIS, 4);
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
14 $oldweb.$othertopic
15 $oldweb.$othertopic
16 $othertopic
17 MeMe${oldtopic}pick$oldweb.${oldtopic}me
18 http://site/$newweb/$oldtopic
19 [[http://blah/$oldtopic/blah][ref]]
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
    $this->check($newweb, $othertopic, undef, <<THIS, 5);
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
14 $othertopic
15 $oldweb.$othertopic
16 $newweb.$othertopic
17 MeMe${oldtopic}pick$oldweb.${oldtopic}me
18 http://site/$newweb/$oldtopic
19 [[http://blah/$oldtopic/blah][ref]]
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

    $this->check($oldweb, $othertopic, undef, <<THIS, 6);
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
14 $othertopic
15 $oldweb.$othertopic
16 $newweb.$othertopic
17 MeMe${oldtopic}pick$oldweb.${oldtopic}me
18 http://site/$newweb/$oldtopic
19 [[http://blah/$oldtopic/blah][ref]]
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
    my $meta       =  new TWiki::Meta($this->{twiki}, $oldweb, $oldtopic);
    my $topictext  =  <<THIS;
One lowercase
Twolowercase
[[lowercase]]
THIS
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $oldweb, $oldtopic,
                                $topictext, $meta );
    my $query = new CGI({
        action   => 'rename',
        topic    => $oldtopic,
        newweb   => $oldweb,
        newtopic => $newtopic,
        referring_topics => [ "$oldweb.$newtopic" ],
    });

    $query->path_info("/$oldweb" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $this->{twiki};
    my ($text,$result)  =  $this->capture( \&TWiki::UI::Manage::rename, $this->{twiki} );
    my $ext = $TWiki::cfg{ScriptSuffix};
    $this->assert_matches(qr/^Status:\s+302/s,$text);
    $this->assert_matches(qr([lL]ocation:\s+\S+?/view$ext/$oldweb/UpperCase)s,$text);
    $this->check($oldweb, 'UpperCase', $meta, <<THIS, 100);
One lowercase
Twolowercase
[[UpperCase]]
THIS
}

sub test_accessRenameRestrictedTopic {
    my $this       =  shift;
    my $oldtopic   =  'lowercase';
    my $newtopic   =  'upperCase';
    my $meta       =  new TWiki::Meta($this->{twiki}, $oldweb, $oldtopic);
    my $topictext  =  "   * Set ALLOWTOPICRENAME = GungaDin\n";
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $oldweb, $oldtopic,
                                $topictext, $meta );
    my $query = new CGI({
                         action   => 'rename',
                         topic    => $oldtopic,
                         newweb   => $oldweb,
                         newtopic => $newtopic,
                        });

    $query->path_info("/$oldweb" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $this->{twiki};
    try {
        my ($text,$result) = TWiki::UI::Manage::rename( $this->{twiki} );
        $this->assert(0);
    } catch TWiki::OopsException with {
        $this->assert_str_equals('OopsException(accessdenied/topic_access web=>TemporaryRenameOldWeb topic=>lowercase params=>[RENAME,access not allowed on topic])', shift->stringify());
    }
}

sub test_accessRenameRestrictedWeb {
    my $this       =  shift;
    my $oldtopic   =  'WebPreferences';
    my $meta       =  new TWiki::Meta($this->{twiki}, $oldweb, $oldtopic);
    my $topictext  =  "   * Set ALLOWWEBRENAME = GungaDin\n";
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $oldweb, $oldtopic,
                                $topictext, $meta );
    my $query = new CGI({
                         action   => 'rename',
                         topic    => $oldtopic,
                         newweb   => $oldweb,
                         newtopic => $newtopic,
                        });

    $query->path_info("/$oldweb" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $this->{twiki};
    try {
        my ($text,$result) = TWiki::UI::Manage::rename( $this->{twiki} );
        $this->assert(0);
    } catch TWiki::OopsException with {
        $this->assert_str_equals('OopsException(accessdenied/topic_access web=>TemporaryRenameOldWeb topic=>WebPreferences params=>[RENAME,access not allowed on web])', shift->stringify());
    }
}

# Purpose: verify that leases are removed when a topic is renamed
sub test_leaseReleasemeLetMeGo {
    my $this =  shift;

    # Grab a lease
    $this->{twiki}->{store}->setLease($oldweb, $oldtopic, $this->{twiki}->{user}, 1000);

    my $query = new CGI({
                         action   => 'rename',
                         topic    => $oldtopic,
                         newweb   => $oldweb,
                         newtopic => $newtopic,
                        });

    $query->path_info("/$oldweb" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $this->{twiki};
    $this->capture(\&TWiki::UI::Manage::rename, $this->{twiki} );

    my $lease = $this->{twiki}->{store}->getLease($oldweb, $oldtopic);
    $this->assert_null($lease, $lease);
}

1;
