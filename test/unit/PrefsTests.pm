# Copyright (C) 2004 Crawford Currie
require 5.006;
package PrefsTests;

use base qw(TWikiTestCase);

use TWiki;
use TWiki::Prefs;
use strict;
use Assert;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $testSysWeb = 'TemporaryTestPrefsSystemWeb';
my $testNormalWeb = "TemporaryTestPrefsWeb";
my $testUsersWeb = "TemporaryTestPrefsUsersWeb";
my $testTopic = "TemporaryTestPrefsTopic";
my $testUser;

my $twiki;
my $topicquery;

my $original;
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $original = $TWiki::cfg{SystemWebName};
    $TWiki::cfg{UsersWebName} = $testUsersWeb;
    $TWiki::cfg{SystemWebName} = $testSysWeb;
    $TWiki::cfg{LocalSitePreferences} = "$testUsersWeb.TWikiPreferences";

    $topicquery = new CGI( "" );
    $topicquery->path_info("/$testNormalWeb/$testTopic");
    try {
        $twiki = new TWiki('AdminUser');
        my $twikiUserObject = $twiki->{user};
        $twiki->{store}->createWeb($twikiUserObject, $testUsersWeb);
        $twiki->{store}->saveTopic(
            $twiki->{user}, $testUsersWeb, 'TWikiAdminGroup',
            '   * Set GROUP = '.$twikiUserObject->wikiName()."\n");

        $twiki->{store}->createWeb($twikiUserObject, $testSysWeb, $original);
        $twiki->{store}->createWeb($twikiUserObject, $testNormalWeb, '_default');

        $twiki->{store}->copyTopic(
            $twikiUserObject, $original, $TWiki::cfg{SitePrefsTopicName},
            $testSysWeb, $TWiki::cfg{SitePrefsTopicName} );

        $testUser = $this->createFakeUser($twiki);
    } catch TWiki::AccessControlException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();
    $this->assert_str_equals($original, $TWiki::cfg{SystemWebName});
    $twiki->{store}->removeWeb($twiki->{user}, $testUsersWeb);
    $twiki->{store}->removeWeb($twiki->{user}, $testSysWeb);
    $twiki->{store}->removeWeb($twiki->{user}, $testNormalWeb);
    $this->assert($original, $TWiki::cfg{SystemWebName});
}

sub _set {
    my ( $this, $web, $topic, $pref, $val ) = @_;
    $this->assert_not_null($web);
    $this->assert_not_null($topic);
    $this->assert_not_null($pref);

    my $user = $twiki->{users}->findUser('AdminUser');
    my( $meta, $text) = $twiki->{store}->readTopic($user, $web, $topic);
    $text =~ s/^\s*\* Set $pref =.*$//gm;
    $text .= "\n\t* Set $pref = $val\n";
    $twiki->{store}->saveTopic($user, $web, $topic, $text, $meta);
}

sub _setTWikiPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($testSysWeb, $TWiki::cfg{SitePrefsTopicName}, $pref, $val);
}

sub _setLocalPref {
   my ( $this, $pref, $val ) = @_;
   my ( $web, $topic ) = $twiki->normalizeWebTopicName( '', $TWiki::cfg{LocalSitePreferences} );
   $this->_set($web, $topic, $pref, $val);
}

sub _setWebPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($testNormalWeb, $TWiki::cfg{WebPrefsTopicName}, $pref, $val);
}

sub _setTopicPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($testNormalWeb, $testTopic, $pref, $val);
}

sub _setUserPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($TWiki::cfg{UsersWebName}, $testUser, $pref, $val);
}

sub test_system {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser );
    $this->assert_str_equals("TWIKI",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_local {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "LOCAL");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_web {
    my $this = shift;

    $this->_setWebPref("SOURCE", "WEB");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_user {
    my $this = shift;

    $this->_setUserPref("SOURCE", "USER");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_topic {
    my $this = shift;
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("TOPIC",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_order1 {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setLocalPref("SOURCE", "LOCAL");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 0);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_order2 {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setLocalPref("SOURCE", "LOCAL");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 0);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 1);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_order3 {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setLocalPref("SOURCE", "LOCAL");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_order4 {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setLocalPref("SOURCE", "LOCAL");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 1);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("TOPIC",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_finalSystem {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setLocalPref("SOURCE", "LOCAL");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "SOURCE");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser );
    $this->assert_str_equals("TWIKI",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_finalLocal {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setLocalPref("SOURCE", "LOCAL");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "SOURCE");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_finalWeb {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setLocalPref("SOURCE", "LOCAL");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "SOURCE");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_finalUser {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");
    $this->_setLocalPref("SOURCE", "LOCAL");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 1);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setLocalPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "SOURCE");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

1;
