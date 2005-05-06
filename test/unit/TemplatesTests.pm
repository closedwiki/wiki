use strict;

#
# Unit tests for TWiki::Templates
#

package TemplatesTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use TWiki;
use TWiki::Templates;
use File::Path;

sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
}

my $test_tmpls;
my $save_tmpls;
my $test_data;
my $save_data;

my $session;
my $tmpls;

sub set_up {
    my $here = Cwd::cwd();
    $test_tmpls = $here.'/fake_templates';
    $test_data = $here.'/fake_data';

    File::Path::mkpath($test_tmpls);
    File::Path::mkpath($test_data);

    $session = new TWiki();
    $tmpls = $session->{templates};

    $save_tmpls = $TWiki::cfg{TemplateDir};
    $TWiki::cfg{TemplateDir} = $test_tmpls;
    $save_data = $TWiki::cfg{DataDir};
    $TWiki::cfg{DataDir} = $test_data;
}

sub tear_down {
    $TWiki::cfg{TemplateDir} = $save_tmpls;
    File::Path::rmtree( $test_tmpls );
    $TWiki::cfg{DataDir} = $save_data;
    File::Path::rmtree( $test_data );
}

sub write_template {
    my $tmpl = shift;

    if( $tmpl =~ m!^(.*)/[^/]*$! ) {
        File::Path::mkpath( "$test_tmpls/$1" ) unless -d "$test_tmpls/$1";
    }
    open(F, ">$test_tmpls/$tmpl.tmpl") || die;
    print F $tmpl;
    close(F);
}

sub write_topic {
    my( $web, $topic, $content ) = @_;

    File::Path::mkpath("$test_data/$web") unless -d "$test_data/$web";
    open(F, ">$test_data/$web/$topic.txt") || die;
    print F "$web/$topic";
    close(F);
}

sub test_skinPathBasic {
    my $this = shift;
    my $data;

    write_template( 'script' );

    $data = $tmpls->readTemplate('script', undef, undef );
    $this->assert_str_equals("script", $data );

    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals('script', $data );

    $data = $tmpls->readTemplate('script', 'skin', '' );
    $this->assert_str_equals('script', $data );

    $data = $tmpls->readTemplate('script', 'skin', 'web' );
    $this->assert_str_equals('script', $data );
}

sub test_skinPathWeb {
    my $this = shift;
    my $data;

    write_template( 'script' );
    write_template( 'script.skin' );
    write_template( 'web/script' );

    $data = $tmpls->readTemplate('script', 'skin', 'web' );
    $this->assert_str_equals('web/script', $data );

    $data = $tmpls->readTemplate('script', '', 'web' );
    $this->assert_str_equals('web/script', $data );

    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals('script', $data );

    $data = $tmpls->readTemplate('script', 'skin', '' );
    $this->assert_str_equals('script.skin', $data );
}

sub test_skinPathsOneSkin {
    my $this = shift;
    my $data;

    write_template( 'script' );
    write_template( 'script.scaly' );

    $data = $tmpls->readTemplate('script', undef, undef );
    $this->assert_str_equals('script', $data );

    $data = $tmpls->readTemplate('script', '', 'web' );
    $this->assert_str_equals("script", $data );

    $data = $tmpls->readTemplate('script', 'scaly', '' );
    $this->assert_str_equals("script.scaly", $data );

    $data = $tmpls->readTemplate('script', 'scaly', 'web' );
    $this->assert_str_equals("script.scaly", $data );
}

sub test_skinPathsOneSkinWeb {
    my $this = shift;
    my $data;

    write_template( 'script' );
    write_template( 'script.burnt' );
    write_template( 'web/script.burnt' );

    $data = $tmpls->readTemplate('script', 'burnt', '' );
    $this->assert_str_equals('script.burnt', $data );

    $data = $tmpls->readTemplate('script', 'burnt', 'web' );
    $this->assert_str_equals('web/script.burnt', $data );
}

sub test_skinPathsTwoSkins {
    my $this = shift;
    my $data;

    write_template( 'script' );
    write_template( 'kibble' );
    write_template( 'script.suede' );
    write_template( 'script.tanned' );
    write_template( 'kibble.tanned' );

    $data = $tmpls->readTemplate('script', 'suede', '' );
    $this->assert_str_equals("script.suede", $data );

    $data = $tmpls->readTemplate('script', 'tanned', '' );
    $this->assert_str_equals("script.tanned", $data );

    $data = $tmpls->readTemplate('script', 'suede,tanned', '' );
    $this->assert_str_equals("script.suede", $data );

    $data = $tmpls->readTemplate('script', 'tanned,suede', '' );
    $this->assert_str_equals("script.tanned", $data );

    $data = $tmpls->readTemplate('kibble', 'suede,tanned', '' );
    $this->assert_str_equals("kibble.tanned", $data );

    $data = $tmpls->readTemplate('kibble', 'tanned,suede', '' );
    $this->assert_str_equals("kibble.tanned", $data );

    $data = $tmpls->readTemplate('kibble', 'suede', '' );
    $this->assert_str_equals("kibble", $data );
}

sub test_webTopics {
    my $this = shift;
    my $data;
    my $sys = $TWiki::cfg{SystemWebName};

    # $SystemWebName.${name}Template
    write_topic( $sys, 'ScriptTemplate' );
    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', '', 'web' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', 'burnt', '' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', 'burnt', 'web' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );

    # $SystemWebName.${skin}Skin${name}Template
    write_topic( $sys, 'BurntSkinScriptTemplate' );
    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', '', 'web' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', 'burnt', 'web' );
    $this->assert_str_equals("$sys/BurntSkinScriptTemplate", $data );

    # $web.${name}Template
    write_topic( 'Web', 'ScriptTemplate' );
    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', '', 'web' );
    $this->assert_str_equals("Web/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', 'burnt', '' );
    $this->assert_str_equals("$sys/BurntSkinScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', 'burnt', 'web' );
    $this->assert_str_equals("Web/ScriptTemplate", $data );

    # $web.${skin}Skin${name}Template
    write_topic( 'Web', 'BurntSkinScriptTemplate' );
    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', '', 'web' );
    $this->assert_str_equals("Web/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', 'burnt', '' );
    $this->assert_str_equals("$sys/BurntSkinScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', 'burnt', 'web' );
    $this->assert_str_equals("Web/BurntSkinScriptTemplate", $data );

    # $web.$name
    write_topic( 'Web', 'Script' );
    $data = $tmpls->readTemplate('Web.Script', '', '' );
    $this->assert_str_equals("Web/Script", $data );
    $data = $tmpls->readTemplate('Web.Script', '', 'web' );
    $this->assert_str_equals("Web/Script", $data );
    $data = $tmpls->readTemplate('Web.Script', 'burnt', '' );
    $this->assert_str_equals("Web/Script", $data );
    $data = $tmpls->readTemplate('Web.Script', 'burnt', 'web' );
    $this->assert_str_equals("Web/Script", $data );
}

=pod

Also need to test: correct functioning of template macros, esp. include.

=cut

1;
