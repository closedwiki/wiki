# Copyright (C) 2004 Crawford Currie
require 5.006;
package PrefsTests;

use base qw(TWikiTestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use TWiki;
use TWiki::Prefs;
use strict;
use Assert;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use File::Copy;

my $testsysweb = 'TemporaryTestPrefsSystemWeb';
my $testWeb = "TestPrefsWeb";
my $testUsersWeb = "TestPrefsUsersWeb";
my $testTopic = "TestPrefsTopic";
my $thePathInfo = "/$testWeb/$testTopic";
my $theUrl = "/save/$testWeb/$testTopic";
my %safe;
my $user;

my $twiki;

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
   $this->_set($testsysweb, $TWiki::cfg{SitePrefsTopicName}, $pref, $val);
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
my $original;

sub set_up {
    my $this = shift;

    $original = $TWiki::cfg{SystemWebName};
    $this->protectCFG();

    $this->assert_str_equals("TWiki",$original);
    $TWiki::cfg{UsersWebName} = $testUsersWeb;
    $TWiki::cfg{SystemWebName} = $testsysweb;

    $twiki = new TWiki( $thePathInfo, "TestUser1", $testTopic, $theUrl );
    $user = $twiki->{user};
    try {
        $twiki->{store}->createWeb($user, $testUsersWeb);
        $twiki->{store}->saveTopic($twiki->{user}, $testUsersWeb,
                                   'TWikiAdminGroup',
                                   "   * Set GROUP = TestUser1\n");
        $twiki->{store}->createWeb($user, $testsysweb, $original);
        $twiki->{store}->copyTopic( $user, $original,
                                    $TWiki::cfg{SitePrefsTopicName},
                                    $testsysweb,
                                    $TWiki::cfg{SitePrefsTopicName} );
        $twiki->{store}->createWeb($twiki->{user}, $testWeb, '_default');
        $twiki->{store}->saveTopic($twiki->{user}, $testUsersWeb,
                                   'TestUser1', "silly user page!!!");
    } catch TWiki::AccessControlException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
}

sub tear_down {
    my $this = shift;

    $this->restoreCFG();

    $twiki->{store}->removeWeb($twiki->{user}, $testsysweb);
    $twiki->{store}->removeWeb($twiki->{user}, $testWeb);
    $this->assert_str_equals($original, $TWiki::cfg{SystemWebName});
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
