use strict;

#
# Unit tests for TWiki::Templates
#

package TemplatesTests;

use base qw(TWikiTestCase);

use TWiki;
use TWiki::Templates;
use File::Path;

sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
}

my $test_tmpls;
my $test_data;

my $session;
my $tmpls;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $here = Cwd::cwd();
    $test_tmpls = $here.'/fake_templates';
    $test_data = $here.'/fake_data';

    File::Path::mkpath($test_tmpls);
    File::Path::mkpath($test_data);
    

    
    $session = new TWiki();
    $tmpls = $session->{templates};
    
    $TWiki::cfg{TemplateDir} = $test_tmpls;
    $TWiki::cfg{DataDir} = $test_data;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    File::Path::rmtree( $test_tmpls );
    File::Path::rmtree( $test_data );
}

sub write_template {
    my( $tmpl, $content ) = @_;

    $content ||= $tmpl;
    if( $tmpl =~ m!^(.*)/[^/]*$! ) {
        File::Path::mkpath( "$test_tmpls/$1" ) unless -d "$test_tmpls/$1";
    }
    open(F, ">$test_tmpls/$tmpl.tmpl") || die;
    print F $content;
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

    write_template( 'script','scripttmplcontent' );

    $data = $tmpls->readTemplate('script', undef, undef );
    $this->assert_str_equals("scripttmplcontent", $data );

    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals('scripttmplcontent', $data );

    $data = $tmpls->readTemplate('script', 'skin', '' );
    $this->assert_str_equals('scripttmplcontent', $data );

    $data = $tmpls->readTemplate('script', 'skin', 'web' );
    $this->assert_str_equals('scripttmplcontent', $data );
}

sub test_skinPathWeb {
    my $this = shift;
    my $data;

    write_template( 'script' );
    write_template( 'script.skin' );
    write_template( 'web/script' );
    write_template( 'web/script.skin' );

    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals('script', $data );

    $data = $tmpls->readTemplate('script', 'skin', '' );
    $this->assert_str_equals('script.skin', $data );

    $data = $tmpls->readTemplate('script', '', 'web' );
    $this->assert_str_equals('web/script', $data );

    $data = $tmpls->readTemplate('script', 'skin', 'web' );
    $this->assert_str_equals('web/script.skin', $data );

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

sub test_WebTopicsA {
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
}


sub test_WebTopicsB {
   my $this = shift;
   my $data;
   my $sys = $TWiki::cfg{SystemWebName};

   # $SystemWebName.${skin}Skin${name}Template
   write_topic( $sys, 'ScriptTemplate' );
   write_topic( $sys, 'BurntSkinScriptTemplate' );

   $data = $tmpls->readTemplate('script', '', '' );
   $this->assert_str_equals("$sys/ScriptTemplate", $data );
   $data = $tmpls->readTemplate('script', '', 'web' );
   $this->assert_str_equals("$sys/ScriptTemplate", $data );
   $data = $tmpls->readTemplate('script', 'burnt', 'web' );
   $this->assert_str_equals("$sys/BurntSkinScriptTemplate", $data );
   $data = $tmpls->readTemplate('script', 'burnt', '' );
   $this->assert_str_equals("$sys/BurntSkinScriptTemplate", $data );
}

sub test_WebTopicsC {
   my $this = shift;
   my $data;
   my $sys = $TWiki::cfg{SystemWebName};

    # $web.${name}Template
    write_topic( $sys, 'ScriptTemplate' );
    write_topic( $sys, 'BurntSkinScriptTemplate' );
    write_topic( 'Web', 'ScriptTemplate' );

    $data = $tmpls->readTemplate('script', '', '' );
    $this->assert_str_equals("$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', '', 'web' );
    $this->assert_str_equals("Web/ScriptTemplate", $data );
    $data = $tmpls->readTemplate('script', 'burnt', '' );
    $this->assert_str_equals("$sys/BurntSkinScriptTemplate", $data );

    #FIXME
    #This is against the spec, should return $sys/BurntSkinScriptTemplate
    #The search path should be:
    # 0 looks for topic =${skin}Skin${name}Template= (BurntSkinScriptTemplate)
    #    0 in $web  (Web/BurntSkinScriptTemplate)
    #    0 in =TWiki::cfg{SystemWebName}= ($sys/BurntSkinScriptTemplate)
    # 0 looks for topic =${name}Template=
    #     0 in $web (Web/ScriptTemplate)
    #     0 in =TWiki::cfg{SystemWebName}= ($sys/ScriptTemplate)
    #
    $data = $tmpls->readTemplate('script', 'burnt', 'web' );
    $this->assert_str_equals("Web/ScriptTemplate", $data );
}

sub test_WebTopicsD {
   my $this = shift;
   my $data;
   my $sys = $TWiki::cfg{SystemWebName};

   # $web.${skin}Skin${name}Template
   write_topic( $sys, 'ScriptTemplate' );
   write_topic( $sys, 'BurntSkinScriptTemplate' );
   write_topic( 'Web', 'ScriptTemplate' );
   write_topic( 'Web', 'BurntSkinScriptTemplate' );

   $data = $tmpls->readTemplate('script', '', '' );
   $this->assert_str_equals("$sys/ScriptTemplate", $data );
   $data = $tmpls->readTemplate('script', '', 'web' );
   $this->assert_str_equals("Web/ScriptTemplate", $data );
   $data = $tmpls->readTemplate('script', 'burnt', '' );
   $this->assert_str_equals("$sys/BurntSkinScriptTemplate", $data );
   $data = $tmpls->readTemplate('script', 'burnt', 'web' );
   $this->assert_str_equals("Web/BurntSkinScriptTemplate", $data );
}

sub test_webTopicsE {
    my $this = shift;
    my $data;
    my $sys = $TWiki::cfg{SystemWebName};

    # $web.$name
    write_topic( $sys, 'ScriptTemplate' );
    write_topic( $sys, 'BurntSkinScriptTemplate' );
    write_topic( 'Web', 'ScriptTemplate' );
    write_topic( 'Web', 'BurntSkinScriptTemplate' );
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

#Wishlist
# sub test_MixWebAndTemplates {
#
#    my $this = shift;
#    my $data;
#    my $sys = $TWiki::cfg{SystemWebName};
#
#    write_template( 'script' );
#    write_template( 'script.skinned' );
#
#    write_topic( $sys, 'ScriptTemplate' );
#    write_topic( $sys, 'BaredSkinScriptTemplate' );
#    write_topic( 'Web', 'ScriptTemplate' );
#    write_topic( 'Web', 'SkinnedSkinScriptTemplate' );
#
#
#
#    $data = $tmpls->readTemplate('script', '', '' );
#    $this->assert_str_equals("script", $data );
#
#    $data = $tmpls->readTemplate('script', '', 'web' );
#    $this->assert_str_equals("Web/ScriptTemplate", $data );
#
#    $data = $tmpls->readTemplate('script', 'skinned', '' );
#    $this->assert_str_equals("script.skinned", $data );
#
#
#    $data = $tmpls->readTemplate('script', 'skinned', 'web' );
#    $this->assert_str_equals("Web/SkinnedSkinScriptTemplate", $data );
#
#    $data = $tmpls->readTemplate('script', 'bared' );
#    $this->assert_str_equals("$sys/BaredSkinScriptTemplate", $data );
#
   #Which one makes more sense?
#    $data = $tmpls->readTemplate('script', 'bared,skinned','web' );
#    $this->assert_str_equals("Web/SkinnedSkinScriptTemplate", $data );
#    $this->assert_str_equals("Web/BaredSkinScriptTemplate", $data );
#
#}

sub language_setup {
    write_template( 'strings', '
%TMPL:DEF{"Question"}%Do you see?%TMPL:END%
%TMPL:DEF{"Yes"}%Yes%TMPL:END%
%TMPL:DEF{"No"}%No%TMPL:END%
' );
    write_template( 'strings.gaelic', '
%TMPL:DEF{"Question"}%An faca sibh?%TMPL:END%
%TMPL:DEF{"Yes"}%Chunnaic%TMPL:END%
%TMPL:DEF{"No"}%Chan fhaca%TMPL:END%
' );
    write_template("pattern", '%TMPL:INCLUDE{"strings"}%SKIN=pattern ');


    write_template( 'example', '%TMPL:INCLUDE{"pattern"}%%TMPL:P{"Question"}%
<input type="button" value="%TMPL:P{"No"}%">
<input type="button" value="%TMPL:P{"Yes"}%">
');
}

sub test_languageEnglish {
    my $this = shift;
    my $data;

    language_setup();
    $data = $tmpls->readTemplate('example', 'pattern', '' );
    $this->assert_str_equals('
SKIN=pattern Do you see?
<input type="button" value="No">
<input type="button" value="Yes">
', $data );
}

sub test_languageGaelic {
    my $this = shift;
    my $data;

    language_setup();
    $data = $tmpls->readTemplate('example', 'gaelic,pattern', '' );
    $this->assert_str_equals('
SKIN=pattern An faca sibh?
<input type="button" value="Chan fhaca">
<input type="button" value="Chunnaic">
', $data );
}

1;
