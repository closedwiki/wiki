# Copyright (C) 2004 Crawford Currie
package PrefsTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../lib';
    #unshift @INC, '/home/twiki/cairo/lib';
    unshift @INC, '.';
}

require '../../bin/setlib.cfg';
#require '/home/twiki/cairo/bin/setlib.cfg';
use TWiki;
use TWiki::Prefs;
use strict;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use File::Copy;

my $web = "TestPrefsWeb";
my $topic = "TestPrefsTopic";
my $user = "TestUser1";
my $thePathInfo = "/$web/$topic";
my $theUrl = "/save/$web/$topic";

sub _set {
    my ( $this, $web, $topic, $pref, $val ) = @_;
    die unless $web;
    die unless $topic;
    die unless $pref;

    my $text = "";
    if ( -e "$TWiki::dataDir/$web/$topic.txt") {
        open(F, "<$TWiki::dataDir/$web/$topic.txt") || die;
        undef $/;
        $text = <F>;
        close F;
        $text =~ s/^\s+\* Set $pref =.*$//mg;
    }

    open(F, ">$TWiki::dataDir/$web/$topic.txt") || die;
    print F "\t* Set $pref = $val\n";
    print F "$text\n";
    close F;
}

sub _setTWikiPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($TWiki::twikiWebname, $TWiki::wikiPrefsTopicname, $pref, $val);
}

sub _setWebPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($web, $TWiki::webPrefsTopicname, $pref, $val);
}

sub _setTopicPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($web, $topic, $pref, $val);
}

sub _setUserPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($TWiki::mainWebname, $user, $pref, $val);
}

sub set_up {
    my $this = shift;

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    # back up TWiki.TWikiPreferences
    my $prefs = "$TWiki::dataDir/$TWiki::twikiWebname/$TWiki::wikiPrefsTopicname.txt";
    die "Cannot run test - cannot write $prefs" unless ( -w $prefs );
    $this->{TWIKIPREFS} = $prefs;
    $this->{TWIKIPREFSBACKUP} = "$prefs.bak";
    copy($this->{TWIKIPREFS}, $this->{TWIKIPREFSBACKUP});

    `cp -r $TWiki::dataDir/_default $TWiki::dataDir/$web`;
    die "Cannot create $TWiki::dataDir/$web: $@" if $@;

    mkdir "$TWiki::pubDir/$web" ||
      die "Cannot create $TWiki::pubDir/$web";
    chmod 0777, "$TWiki::pubDir/$web" ||
      die "Cannot chmod $TWiki::pubDir/$web";

    open(F, ">$TWiki::dataDir/$TWiki::mainWebname/TestUser1.txt") ||
      die "Cant create user";
    print F "silly user page!!!";
    close(F);
}

sub tear_down {
    my $this = shift;
    # restore TWiki.TWikiPreferences
    copy( $this->{TWIKIPREFSBACKUP}, $this->{TWIKIPREFS} );
    `rm -rf $TWiki::dataDir/$web`;
    die "Could not clean fixture $?" if $!;
    `rm -rf $TWiki::pubDir/$web`;
    die "Could not clean fixture $?" if $!;
}

sub test_system {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("TWIKI",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_web {
    my $this = shift;

    $this->_setWebPref("SOURCE", "WEB");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("WEB",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_user {
    my $this = shift;

    $this->_setUserPref("SOURCE", "USER");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("USER",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_topic {
    my $this = shift;
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );
    $this->assert_str_equals("TOPIC",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_order1 {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 0);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("USER",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_order2 {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 0);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 1);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("USER",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_order3 {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("USER",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_order4 {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 1);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("TOPIC",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_finalSystem {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "SOURCE");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("TWIKI",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_finalWeb {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "SOURCE");
    $this->_setUserPref("FINALPREFERENCES", "");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("WEB",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

sub test_finalUser {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 1);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "SOURCE");

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    $this->assert_str_equals("USER",
                             $TWiki::prefsObject->getValue("SOURCE"));
}

1;
