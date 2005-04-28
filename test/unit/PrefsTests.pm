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
use File::Path;

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
my %safe;;

sub _set {
    my ( $this, $web, $topic, $pref, $val ) = @_;
    ASSERT($web) if DEBUG;
    ASSERT($topic) if DEBUG;
    ASSERT($pref) if DEBUG;

    my $text = "";
    if ( -e "$TWiki::cfg{DataDir}/$web/$topic.txt") {
        open(F, "<$TWiki::cfg{DataDir}/$web/$topic.txt") || die;
        undef $/;
        $text = <F>;
        close F;
        $safe{"$web.$topic"} = $text unless defined $safe{"$web.$topic"};
        $text =~ s/^\s+\* Set $pref =.*$//mg;
    }

    open(F, ">$TWiki::cfg{DataDir}/$web/$topic.txt") || die;
    print F "\t* Set $pref = $val\n";
    $text =~ s/Set $pref/Set #$pref/g;
    $text =~ s/"$pref"/"#$pref"/g;
    print F "$text\n";
    close F;
}

sub _setTWikiPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($TWiki::cfg{SystemWebName}, $TWiki::cfg{SitePrefsTopicName}, $pref, $val);
}

sub _setWebPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($web, $TWiki::cfg{WebPrefsTopicName}, $pref, $val);
}

sub _setTopicPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($web, $topic, $pref, $val);
}

sub _setUserPref {
   my ( $this, $pref, $val ) = @_;
   $this->_set($TWiki::cfg{UsersWebName}, $user, $pref, $val);
}

my $twiki;

sub set_up {
    my $this = shift;

    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl );

    # back up TWiki.TWikiPreferences
    my $prefs = "$TWiki::cfg{DataDir}/$TWiki::cfg{SystemWebName}/$TWiki::cfg{SitePrefsTopicName}.txt";
    die "Cannot run test - cannot write $prefs" unless ( -w $prefs );
    $this->{TWIKIPREFS} = $prefs;
    $this->{TWIKIPREFSBACKUP} = "$prefs.bak";
    copy($this->{TWIKIPREFS}, $this->{TWIKIPREFSBACKUP});

    File::Path::mkpath("$TWiki::cfg{DataDir}/$web");

    opendir(D,"$TWiki::cfg{DataDir}/_default");
    foreach my $file ( grep{ /\.txt$/ } readdir D ) {
        open(F,"<$TWiki::cfg{DataDir}/_default/$file");
        open(G,">$TWiki::cfg{DataDir}/$web/$file");
        undef $/;
        print G <F>;
        close(F); close(G);
    }
    closedir(D);
    File::Path::mkpath("$TWiki::cfg{PubDir}/$web");
    open(F, ">$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/TestUser1.txt") ||
      die "Can't create user $! $TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}";
    print F "silly user page!!!";
    close(F);
}

sub tear_down {
    my $this = shift;
    # restore TWiki.TWikiPreferences
    copy( $this->{TWIKIPREFSBACKUP}, $this->{TWIKIPREFS} );

    foreach my $t ( keys %safe ) {
        $t =~ /^(.*)\.(.*)$/;
        my ($w, $p) = ( $1, $2 );
        if( -e "$TWiki::cfg{DataDir}/$w/$p.txt" ) {
            open(F, ">$TWiki::cfg{DataDir}/$w/$p.txt") || die "Failed to restore $TWiki::cfg{DataDir}/$w/$p.txt";
            print F $safe{$t};
            close F;
        }
    }
    File::Path::rmtree("$TWiki::cfg{DataDir}/$web");
    File::Path::rmtree("$TWiki::cfg{PubDir}/$web");
}

sub test_system {
    my $this = shift;

    $this->_setTWikiPref("SOURCE", "TWIKI");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
    $this->assert_str_equals("TWIKI",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

sub test_web {
    my $this = shift;

    $this->_setWebPref("SOURCE", "WEB");

    $this->_setTWikiPref("READTOPICPREFS", 1);
    $this->_setTWikiPref("TOPICOVERRIDESUSER", 0);

    $this->_setTWikiPref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
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

    my $t = new TWiki( $thePathInfo, $user, $topic, $theUrl );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
}

1;
