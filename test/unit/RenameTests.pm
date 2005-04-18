use strict;

package RenameTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use strict;
use TWiki;
use TWiki::UI::Manage;
use CGI;

my $oldweb = "UnitTestRenameOldWeb";
my $newweb = "UnitTestRenameNewWeb";
my $oldtopic = "OldTopic";
my $newtopic = "NewTopic";
my $thePathInfo = "/$oldweb/$oldtopic";
my $twiki;
my $originaltext;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;


    mkdir("$TWiki::cfg{DataDir}/$oldweb",0777) ||
      die "$TWiki::cfg{DataDir}/$oldweb fixture setup failed: $!";
    mkdir("$TWiki::cfg{DataDir}/$newweb",0777) ||
      die "$TWiki::cfg{DataDir}/$newweb fixture setup failed: $!";

    $twiki = new TWiki( $thePathInfo, "TestUser1", $oldtopic, "" );
    $TWiki::Plugins::SESSION = $twiki;
    my $meta = new TWiki::Meta($twiki, $oldweb, $oldtopic);
    $meta->put( "FIELD", {name=>"$oldweb",
                          value=>"$oldweb"} );
    $meta->put( "FIELD", {name=>"$oldweb.$oldtopic",
                          value=>"$oldweb.$oldtopic"} );
    $meta->put( "FIELD", {name=>"$oldtopic",
                          value=>"$oldtopic"} );
    $meta->put( "FIELD", {name=>"OLD",
                          value=>"$oldweb.$oldtopic"} );
    $meta->put( "FIELD", {name=>"NEW",
                          value=>"$newweb.$newtopic"} );
    $meta->put( "TOPICPARENT", {name=> "$oldweb.$oldtopic"} );

    $originaltext = <<THIS;
1 $oldweb.$oldtopic
$oldweb.$oldtopic 2
3 $oldweb.$oldtopic more
$oldtopic 4
5 $oldtopic
6 $oldtopic
7 ($oldtopic)
8 [[$oldweb.$oldtopic]]
9 [[$oldtopic]]
10 [[$oldweb.$oldtopic][the text]]
11 [[$oldtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic

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
}

sub tear_down {
    `rm -rf $TWiki::cfg{DataDir}/$oldweb`;
    print STDERR "tear_down $TWiki::cfg{DataDir}/$oldweb failed: $!\n" if $!;
    `rm -rf $TWiki::cfg{DataDir}/$newweb`;
    print STDERR "tear_down $TWiki::cfg{DataDir}/$newweb failed: $!\n" if $!;
}

sub check {
    my($this, $web, $topic, $emeta, $expected) = @_;
    my($meta,$actual) = $twiki->{store}->readTopic( undef, $web, $topic );
    my @old = split(/\n+/, $expected);
    my @new = split(/\n+/, $actual);

    while (scalar(@old)) {
        $this->assert_str_equals(shift @old, shift @new);
    }
}

sub notest_rename_search {
    my $this = shift;
    my $query = new CGI({
                         'action' => [ 'rename' ],
                         currentwebonly => [ 1 ],
                        });

    $twiki = new TWiki( $thePathInfo, "TestUser1", $oldtopic, $query->url,
                        $query );
    $TWiki::Plugins::SESSION = $twiki;
    TWiki::UI::Manage::rename( $twiki );
}

sub test_rename_oldwebnewtopic {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'rename' ],
                         newweb => [ $oldweb ],
                         newtopic => [ $newtopic ],
                         local_topics => [ "$oldweb.$oldtopic",
                                           "$oldweb.OtherTopic" ],
                         global_topics => [ "$newweb.OtherTopic" ],
                        });

    $twiki = new TWiki( $thePathInfo, "TestUser1", $oldtopic, $query->url,
                        $query );
    $TWiki::Plugins::SESSION = $twiki;
    TWiki::UI::Manage::rename( $twiki );

    $this->assert( $twiki->{store}->topicExists( $oldweb, $newtopic ));
    $this->assert(!$twiki->{store}->topicExists( $oldweb, $oldtopic ));
    my $expected = <<THIS;
1 $newtopic
$newtopic 2
3 $newtopic more
$newtopic 4
5 $newtopic
6 $newtopic
7 ($newtopic)
8 [[$newtopic]]
9 [[$newtopic]]
10 [[$newtopic][the text]]
11 [[$newtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic

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
    $this->check($oldweb, $newtopic, undef, $expected);
    $this->check($oldweb, 'OtherTopic', undef, $expected);
    $expected = <<THIS;
1 $oldweb.$newtopic
$oldweb.$newtopic 2
3 $oldweb.$newtopic more
$oldtopic 4
5 $oldtopic
6 $oldtopic
7 ($oldtopic)
8 [[$oldweb.$newtopic]]
9 [[$oldtopic]]
10 [[$oldweb.$newtopic][the text]]
11 [[$oldtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic

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
    $this->check($newweb, 'OtherTopic', undef, $expected);
}

sub test_rename_newweboldtopic {
    my $this = shift;
    my $query = new CGI({
                         action => [ 'rename' ],
                         newweb => [ $newweb ],
                         newtopic => [ $oldtopic ],
                         local_topics => [ "$oldweb.$oldtopic",
                                           "$oldweb.OtherTopic" ],
                         global_topics => [ "$newweb.OtherTopic" ],
                        });

    $twiki = new TWiki( $thePathInfo, "TestUser1", $oldtopic, $query->url,
                        $query );
    $TWiki::Plugins::SESSION = $twiki;
    TWiki::UI::Manage::rename( $twiki );

    $this->assert( $twiki->{store}->topicExists( $newweb, $oldtopic ));
    $this->assert(!$twiki->{store}->topicExists( $oldweb, $oldtopic ));

    my $expected = <<THIS;
1 $oldtopic
$oldtopic 2
3 $oldtopic more
$oldtopic 4
5 $oldtopic
6 $oldtopic
7 ($oldtopic)
8 [[$oldtopic]]
9 [[$oldtopic]]
10 [[$oldtopic][the text]]
11 [[$oldtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic

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
    $this->check($newweb, $oldtopic, undef, $expected);
    $this->check($newweb, 'OtherTopic', undef, $expected);
    my $expected = <<THIS;
1 $newweb.$oldtopic
$newweb.$oldtopic 2
3 $newweb.$oldtopic more
$newweb.$oldtopic 4
5 $newweb.$oldtopic
6 $newweb.$oldtopic
7 ($newweb.$oldtopic)
8 [[$newweb.$oldtopic]]
9 [[$newweb.$oldtopic]]
10 [[$newweb.$oldtopic][the text]]
11 [[$newweb.$oldtopic][the text]]
12 $oldweb.$newtopic
13 $newweb.$oldtopic

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
    $this->check($oldweb, 'OtherTopic', undef, $expected);
}

1;
