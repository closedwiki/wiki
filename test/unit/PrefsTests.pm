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
    my ( $this, $web, $topic, $pref, $val, $type ) = @_;
    $this->assert_not_null($web);
    $this->assert_not_null($topic);
    $this->assert_not_null($pref);
    $type ||= 'Set';

    my $user = $twiki->{users}->findUser('AdminUser');
    my( $meta, $text) = $twiki->{store}->readTopic($user, $web, $topic);
    $text =~ s/^\s*\* $type $pref =.*$//gm;
    $text .= "\n\t* $type $pref = $val\n";
    $twiki->{store}->saveTopic($user, $web, $topic, $text, $meta);
}

sub _setDefaultPref {
   my ( $this, $pref, $val, $type ) = @_;
   $this->_set($testSysWeb, $TWiki::cfg{SitePrefsTopicName}, $pref, $val, $type);
}

sub _setSitePref {
   my ( $this, $pref, $val, $type ) = @_;
   my ( $web, $topic ) = $twiki->normalizeWebTopicName(
       '', $TWiki::cfg{LocalSitePreferences} );
   $this->assert_str_equals($web,$TWiki::cfg{UsersWebName});
   $this->_set($web, $topic, $pref, $val, $type);
}

sub _setWebPref {
   my ( $this, $pref, $val, $type ) = @_;
   $this->_set($testNormalWeb, $TWiki::cfg{WebPrefsTopicName}, $pref, $val, $type);
}

sub _setTopicPref {
   my ( $this, $pref, $val, $type ) = @_;
   $this->_set($testNormalWeb, $testTopic, $pref, $val, $type);
}

sub _setUserPref {
   my ( $this, $pref, $val, $type ) = @_;
   $this->_set($TWiki::cfg{UsersWebName}, $testUser, $pref, $val, $type);
}

sub test_system {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser );
    $this->assert_str_equals("DEFAULT",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_local {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "SITE");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser );
    $this->assert_str_equals("SITE",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_web {
    my $this = shift;

    $this->_setWebPref("SOURCE", "WEB");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_user {
    my $this = shift;

    $this->_setUserPref("SOURCE", "USER");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_topic {
    my $this = shift;
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("TOPIC",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_order {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("TOPIC",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_finalSystem {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "SOURCE");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("DEFAULT",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_finalSite {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "SOURCE");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("SITE",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_finalWeb {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "SOURCE");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_finalUser {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "SOURCE");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_nouser {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE", undef, 1));
}

sub test_local_to_default {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "GLOBAL");
    $this->_setDefaultPref("SOURCE", "LOCAL", "Local");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("GLOBAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));

    my $localquery = new CGI( "" );
    $localquery->path_info("/$testSysWeb/$TWiki::cfg{SitePrefsTopicName}");
    $t = new TWiki( $testUser, $localquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_local_to_site {
    my $this = shift;

    $this->_setSitePref("SOURCE", "GLOBAL");
    $this->_setSitePref("SOURCE", "LOCAL", "Local");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("GLOBAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    my($tw, $tt ) = $t->normalizeWebTopicName('',
                                            $TWiki::cfg{LocalSitePreferences});
    my $localquery = new CGI( "" );
    $localquery->path_info("$tw/$tt");
    $t = new TWiki( $testUser, $localquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_local_to_user {
    my $this = shift;

    $this->_setUserPref("SOURCE", "GLOBAL");
    $this->_setUserPref("SOURCE", "LOCAL", "Local");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("GLOBAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));

    my $localquery = new CGI( "" );
    $localquery->path_info("/$TWiki::cfg{UsersWebName}/$testUser");
    $t = new TWiki( $testUser, $localquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_local_to_web {
    my $this = shift;

    $this->_setWebPref("SOURCE", "GLOBAL");
    $this->_setWebPref("SOURCE", "LOCAL", "Local");

    my $t = new TWiki( $testUser, $topicquery );
    $this->assert_str_equals("GLOBAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));

    my $localquery = new CGI( "" );
    $localquery->path_info("/$testNormalWeb/$TWiki::cfg{WebPrefsTopicName}");
    $t = new TWiki( $testUser, $localquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

1;
