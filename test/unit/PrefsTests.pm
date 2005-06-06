# Copyright (C) 2004 Crawford Currie
require 5.006;
package PrefsTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use TWiki;
use TWiki::Prefs;
use strict;
use Assert;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use File::Copy;

my $testsysweb = 'TemporaryTestPrefsSystemWeb';
my $testWeb = "TestPrefsWeb";
my $testTopic = "TestPrefsTopic";
my $user = "TestUser1";
my $thePathInfo = "/$testWeb/$testTopic";
my $theUrl = "/save/$testWeb/$testTopic";
my %safe;;

my $twiki;
my $default_sys_web;
my $default_sys_topic;

BEGIN {
    $twiki = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $default_sys_web = $TWiki::cfg{SystemWebName};
    $default_sys_topic = $TWiki::cfg{SitePrefsTopicName};
}

sub _set {
    my ( $this, $web, $topic, $pref, $val ) = @_;
    ASSERT($web) if DEBUG;
    ASSERT($topic) if DEBUG;
    ASSERT($pref) if DEBUG;

    my( $meta, $text) = $twiki->{store}->readTopic(undef,$web, $topic);
    $text =~ s/^\s*\* Set $pref =.*$//gm;
    $text .= "\n\t* Set $pref = $val\n";

    $twiki->{store}->saveTopic($twiki->{user},
                               $web, $topic, $text, $meta);
}

sub _setTWikiPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($testsysweb, $default_sys_topic, $pref, $val);
}

sub _setWebPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($testWeb, $TWiki::cfg{WebPrefsTopicName}, $pref, $val);
}

sub _setTopicPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($testWeb, $testTopic, $pref, $val);
}

sub _setUserPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($TWiki::cfg{UsersWebName}, $user, $pref, $val);
}

sub set_up {
    my $this = shift;

    $this->assert_equals('TWiki',$TWiki::cfg{SystemWebName});

    $twiki = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );

    $twiki->{store}->createWeb($twiki->{user}, $testsysweb, $default_sys_web);
    $twiki->{store}->copyTopic( $user, $default_sys_web, $default_sys_topic,
                      $testsysweb, $default_sys_topic );
    $twiki->{store}->createWeb($twiki->{user}, $testWeb, '_default');
    $twiki->{store}->saveTopic($twiki->{user}, $TWiki::cfg{UsersWebName},
                               'TestUser1', "silly user page!!!");
}

sub tear_down {
    my $this = shift;

    $TWiki::cfg{SystemWebName} = $default_sys_web;

    $twiki->{store}->removeWeb($twiki->{user}, $testsysweb);
    $twiki->{store}->removeWeb($twiki->{user}, $testWeb);
}

sub test_system {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "SOURCE");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("TWIKI",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_web {
    my $this = shift;

    $this->_setWebPref("SOURCE", "WEB");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "SOURCE");
    $this->_setUserPref("FINALPREFERENCES", "");

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_user {
    my $this = shift;

    $this->_setUserPref("SOURCE", "USER");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_topic {
    my $this = shift;
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("TOPIC",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
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

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
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

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
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

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
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

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("TOPIC",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
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

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("TWIKI",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
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

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
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

    $TWiki::cfg{SystemWebName} = $testsysweb;
    my $t = new TWiki( $thePathInfo, $user, $testTopic, $theUrl );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

1;
