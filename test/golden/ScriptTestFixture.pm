use strict;

#
# Base fixture for script tests. Provides some URL manipulation, and
# set-up for the test configuration.
#

package ScriptTestFixture;

use base qw(Test::Unit::TestCase);
use LWP;
use HTML::Diff;
use strict;

use vars qw($urlroot $old $new $olddata $newdata
			$oldpub $newpub $user $pass $userAgent);

{   package TestUserAgent;
    @TestUserAgent::ISA = qw(LWP::UserAgent);

    sub get_basic_credentials {
        return ($ScriptTestFixture::user, $ScriptTestFixture::pass);
    }
}

##############################################################
# Test environment setup
# Note that for correct operation, the runner has to be able to delete
# files from the data areas belonging to the two test installations
# read comments in the code below for hints on how it all works
# LocalSite.cfg should contain the following settings:
#$urlroot = "http://localhost";
#$old = "MAIN";
#$new = "DEVELOP";
#$olddata = "/home/twiki/MAIN/data";
#$oldpub = "/home/twiki/MAIN/pub";
#$newdata = "/home/twiki/DEVELOP/data";;
#$newpub = "/home/twiki/DEVELOP/pub";
#$user = "TWikiGuest";
#$pass = "";
#############################################################

do "LocalSite.cfg"

print STDERR "Sanitising fixtures.....\n";
`rm -rf $oldpub/Sandbox/AutoCreated*`;
`rm -f $olddata/Sandbox/AutoCreated*.*`;
`rm -rf $newpub/Sandbox/AutoCreated*`;
`rm -f $newdata/Sandbox/AutoCreated*.*`;

TestUserAgent->get_basic_credentials();
$userAgent = new TestUserAgent();
$userAgent->agent( "TestAgent" );

sub set_up {
}

sub tear_down {
}

# get a URL from $install
sub getUrl {
    my ($this, $install, $func, $web, $topic, $opts) = @_;
    if ($opts) {
        $opts =~ s/&/\\&/go;
        $opts = "?$opts";
    } else {
        $opts = "";
    }
    my $response =
      $userAgent->get("$urlroot/$install/bin/$func/$web/$topic$opts");
    $this->assert( $response->is_success,
                   "Failed to GET $func/$web/$topic$opts" .
                   $response->request->uri . " -- " .
                   $response->status_line );

    my $result = $response->content();
    #if ( $func ne "oops" ) {
    #    $this->assert_does_not_match(qr/\(oops\)/, $result, "FAILED RESULT\n$result");
    #}

    # replace the URL (which has to match $install) to canonicalise
    # the output for comparison
    $result =~ s/\/$install\//\/URL\//g;
    # get rid of anti-cache measures on edit urls
    $result =~ s/\?t=[0-9]+\b/?t=0/go;
    # canonicalise dates
    $result =~ s/-\s+\d+:\d+\s+-/- DATE -/go;

    return $result;
}

# Get a url from the old installation
sub getOld {
    my $this = shift;
    return $this->getUrl($old, @_);
}

# Get a url from the new installation
sub getNew {
    my $this = shift;
    return $this->getUrl($new, @_);
}

# Compare the results of the same URL in old and new,
# using diff
sub compareOldAndNew {
    my ($this, $func, $web, $topic, $opts, $collapseSpaces) = @_;
    my $old = $this->getOld($func, $web, $topic, $opts);
    $old =~ s/&#0/&#/g;
    my $new = $this->getNew($func, $web, $topic, $opts);
    $this->diff($old, $new, $collapseSpaces);
}

sub oldLocked {
    my ($this, $web, $topic) = @_;
    return -e "$olddata/$web/$topic.lock";
}

sub newLocked {
    my ($this, $web, $topic) = @_;
    return -e "$newdata/$web/$topic.lock";
}

# Diff two blocks of text. if collapseSpaces is true, will convert
# all sequences of spaces into a newline, permitting fine
# granularity comparison.
sub diff {
    my ($this, $old, $new, $collapseSpaces) = @_;
    my $diffs = HTML::Diff::html_word_diff($old, $new);

    if ( scalar( @$diffs )) {
        my $diffc = 0;
        foreach my $diff ( @$diffs ) {
            if ($$diff[0] ne 'u') {
                print STDERR "*** $diff->[0]\nOLD\n$diff->[1]\n/OLD NEW\n$diff->[2]\n/NEW\n";
                $diffc++;
            }
        }
        $this->assert(!$diffc, "Difference detected");
    }
}

# Unlock a topic in the old and new fixtures
sub unlock {
    my ($this, $web, $topic) = @_;

    $this->_unlock($olddata, $web, $topic);
    $this->_unlock($newdata, $web, $topic);
}

sub _unlock {
    my ($this, $data, $web, $topic) = @_;

    chmod 777, "$data/$web/$topic.lock";
    if (-e "$data/$web/$topic.lock" && !unlink("$data/$web/$topic.lock")) {
        print STDERR "WARNING! FAILED TO UNLOCK $web/$topic in $data\n";
        print STDERR `ls -l $data/$web/$topic.lock`;
        print STDERR "TEST FIXTURE IS DAMAGED - REMOVE LOCK MANUALLY\n";
    }
}

sub _deleteData {
    my ($this, $data, $web, $topic) = @_;

    chmod 777, "$data/$web/$topic.txt", "$data/$web/$topic.txt,v",
      "$data/$web/$topic.lock";

    if (-e "$data/$web/$topic.txt" && !unlink("$data/$web/$topic.txt")) {
        print STDERR "WARNING! FAILED TO DELETE TOPIC $web/$data in $data\n";
        print STDERR `ls -l $data/$web/$topic.*`;
        print STDERR "TEST FIXTURE IS DAMAGED - REMOVE TOPIC MANUALLY\n";
    }

    if (-e "$data/$web/$topic.txt" && !unlink("$data/$web/$topic.lock")) {
        print STDERR "WARNING! FAILED TO DELETE LOCK $web/$data in $data\n";
        print STDERR `ls -l $data/$web/$topic.*`;
        print STDERR "TEST FIXTURE IS DAMAGED - REMOVE TOPIC MANUALLY\n";
    }

    if (-e "$data/$web/$topic.txt" && !unlink("$data/$web/$topic.txt,v")) {
        print STDERR "WARNING! FAILED TO DELETE TOPIC $web/$data in $data\n";
        print STDERR `ls -l $data/$web/$topic.*`;
        print STDERR "TEST FIXTURE IS DAMAGED - REMOVE TOPIC MANUALLY\n";
    }
}

sub _deletePub {
    my ($this, $data, $web, $topic) = @_;

    if (-e "$data/$web/$topic") {
        `chmod -R 777 $data/$web/$topic`;
        `rm -rf $data/$web/$topic`;
    }
}

# Delete a topic from the old and new fixtures
sub deleteTopic {
    my ($this, $web, $topic) = @_;

    $this->_deleteData($olddata, $web, $topic);
    $this->_deletePub($oldpub, $web, $topic);
    $this->_deleteData($newdata, $web, $topic);
    $this->_deletePub($newpub, $web, $topic);
}

sub newExists {
    my ($this, $web, $topic) = @_;

    return -e "$newdata/$web/$topic.txt";
}

sub oldExists {
    my ($this, $web, $topic) = @_;

    return -e "$olddata/$web/$topic.txt";
}

sub newPubExists {
    my ($this, $web, $topic, $file) = @_;

    return -e "$newpub/$web/$topic/$file";
}

sub oldPubExists {
    my ($this, $web, $topic, $file) = @_;

    return -e "$oldpub/$web/$topic/$file";
}

sub createTempForUpload {
    my $this = shift;
    `cp ScriptTestFixture.pm /tmp/robot.gif`;
    $this->assert(!$!);
}

1;
