# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2010 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package EncryptPlugin

This is an empty TWiki plugin. It is a fully defined plugin, but is
disabled by default in a TWiki installation. Use it as a template
for your own plugins; see TWiki.TWikiPlugins for details.

This version of the !EncryptPlugin documents the handlers supported
by revision 1.2 of the Plugins API. See the documentation of =TWiki::Func=
for more information about what this revision number means, and how a
plugin can check it.

__NOTE:__ To interact with TWiki use ONLY the official API functions
in the TWiki::Func module. Do not reference any functions or
variables elsewhere in TWiki, as these are subject to change
without prior warning, and your plugin may suddenly stop
working.

For increased performance, all handlers except initPlugin are
disabled below. *To enable a handler* remove the leading DISABLE_ from
the function name. For efficiency and clarity, you should comment out or
delete the whole of handlers you don't use before you release your
plugin.

__NOTE:__ When developing a plugin it is important to remember that
TWiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %TWIKIWEB%.TWikiPlugins#FAILEDPLUGINS for error messages.

__NOTE:__ Defining deprecated handlers will cause the handlers to be 
listed in %TWIKIWEB%.TWikiPlugins#FAILEDPLUGINS. See
%TWIKIWEB%.TWikiPlugins#Handlig_deprecated_functions
for information on regarding deprecated handlers that are defined for
compatibility with older TWiki versions.

__NOTE:__ When writing handlers, keep in mind that these may be invoked
on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the afterCommonTagsHandler is run,
as at that point in the rendering loop we have lost the information that we
the text had been included from another topic.

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::EncryptPlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;       # The plugins API
require TWiki::Plugins;    # For the API version

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

use vars qw(
  $RSA_KEY_LEN
  $RSA_PRIVATE_KEY_FILE
  $RSA_PUBLIC_KEY_FILE
  $RSA_KEY_FILE
  $MY_SECRET_KEY
  $MY_META_TYPE
  $Method
  %LOOKUP_FUNCS
);

use Data::Dumper;
use FileHandle;
use Crypt::CBC;
use Crypt::OpenSSL::RSA;
use Crypt::Blowfish;
use Crypt::RC4;
use MIME::Base64;
use TWiki::Attrs;
use Digest::MD6;

$RSA_KEY_LEN          = 2048;
$RSA_KEY_FILE         = "/var/www/tw/lib/TWiki/Plugins/cryptkey.both";
$RSA_PRIVATE_KEY_FILE = "/var/www/tw/lib/TWiki/Plugins/cryptkey.priv";
$RSA_PUBLIC_KEY_FILE  = "/var/www/tw/lib/TWiki/Plugins/cryptkey.pub";

$MY_SECRET_KEY = 'This is my secret key';
$MY_META_TYPE  = 'ENCRYPTPLUGIN';

%LOOKUP_FUNCS = (
    'BLOWFISH' => 'Blowfish',
    'RSA_RC4'  => 'Crypt::RC4',
);

# This should always be $Rev: 18620 (2010-10-10) $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 18620 (2010-10-10) $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS. Add your own release number
# such as '1.3' or release date such as '2010-05-08'
$RELEASE = '0.1';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION =
'Securely encrypt text in TWiki topics to be accessible by selected users only.';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'EncryptPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle variables that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

__Note:__ Please align variables names with the Plugin name, e.g. if 
your Plugin is called FooBarPlugin, name variables FOOBAR and/or 
FOOBARSOMETHING. This avoids namespace issues.


=cut

sub errMsg {
    TWiki::Func::writeDebug( join( ' ', "$pluginName: ", @_ ) );
}    # errMsg

sub dbgMsg {
    if ($debug) {

        #        print STDERR join( ' ', @msgs ), "\n";
        TWiki::Func::writeDebug( join( ' ', "$pluginName: ", @_ ) );
    }
}    # dbgMsg

sub checkModule ($) {
    my ($module) = @_;

    eval("require $module;");
    if ($@) {
        return (1);
    }
    return (0);
}    # checkModule

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    if ( !-f $RSA_KEY_FILE ) {
        my ( $rsa_gen, $hout );

        $rsa_gen = Crypt::OpenSSL::RSA->generate_key($RSA_KEY_LEN);

        $hout = new FileHandle(">$RSA_KEY_FILE");
        if ($hout) {
            print $hout $rsa_gen->get_private_key_string();
            print $hout $rsa_gen->get_public_key_string();
            $hout->close();
        }
        else {
            TWiki::Func::writeWarning(
                "Can't write RSA_KEY_FILE in $pluginName");
            return (0);
        }
    }

    #
    # Check if needed CPAN modules are around
    #
    my ( $module, $errors );
    $errors = 0;
    foreach $module (
        (
            'Crypt::CBC', 'Crypt::OpenSSL::RSA',
            'Crypt::RC4', 'MIME::Base64',
            'Digest::MD6'
        )
      )
    {
        if ( checkModule($module) ) {
            TWiki::Func::writeWarning("Missing Support Module [$module]");
            $errors++;
        }
    }
    if ( $errors > 0 ) {
        return (0);
    }

    # Set plugin preferences in LocalSite.cfg, like this:
    # $TWiki::cfg{Plugins}{EncryptPlugin}{ExampleSetting} = 1;
    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg. See TWiki.TWikiPlugins for help in adding your plugin
    # configuration to the =configure= interface.
    #    my $setting = $TWiki::cfg{Plugins}{EncryptPlugin}{ExampleSetting} || 0;

    $debug  = $TWiki::cfg{Plugins}{EncryptPlugin}{Debug} || 0;
    $debug  = 1;
    $Method = uc( $TWiki::cfg{Plugins}{EncryptPlugin}{Default_Method} )
      || 'BLOWFISH';
    if ( !exists( $LOOKUP_FUNCS{$Method} ) ) {
        dbgMsg("*** No such Default_Method [$Method], switching to BLOWFISH");
        $Method = 'BLOWFISH';
    }

    # register the _ENCRYPT function to handle %ENCRYPT{...}%
    TWiki::Func::registerTagHandler( 'ENCRYPT', \&_ENCRYPT );

    # Plugin correctly initialized
    return 1;
}    # initPlugin

sub readRSAKey ($$) {
    my ( $fname, $mode ) = @_;
    my ( $hin, $both_keys );

    $hin = new FileHandle("<$fname");
    if ($hin) {
        local ($/);
        $/         = undef;
        $both_keys = <$hin>;
        $hin->close();
    }
    else {
        die "Can't open [$fname]\n";
    }

    if ( uc($mode) eq 'PUBLIC' ) {
        $both_keys =~ s/^.*?--+END RSA PRIVATE KEY--+[\r\n]+//s;
    }
    elsif ( uc($mode) eq 'PRIVATE' ) {
        $both_keys =~ s/[\r\n]+--+BEGIN RSA PUBLIC KEY.*$//s;
    }
    else {
        return ($both_keys);
    }

    #    dbgMsg("readRSAKey: [$mode] [$both_keys]");
    return ($both_keys);
}    # readRSAKey

sub encrypt ($$) {
    my ( $method, $text ) = @_;
    my ( $cipher, $tmp );

    $cipher = Crypt::CBC->new(
        -key    => $MY_SECRET_KEY,
        -cipher => $LOOKUP_FUNCS{$method},
    );

    #didn't work!
    #    $tmp = Crypt::RSA->new(readRSAKey($RSA_KEY_FILE, 'BOTH'));
    #    $cipher = Crypt::CBC->new( -cipher => $tmp 	);

    $text = $cipher->encrypt($text);
    return ( MIME::Base64::encode($text) );
}    # encrypt

sub decrypt ($$) {
    my ( $method, $base64_text ) = @_;
    my ( $text, $cipher, $tmp );

    $text = MIME::Base64::decode($base64_text);

    $cipher = Crypt::CBC->new(
        -key    => $MY_SECRET_KEY,
        -cipher => $LOOKUP_FUNCS{$method},
    );

    #didn't work!
    #    $tmp = Crypt::RSA->new(readRSAKey($RSA_KEY_FILE, 'BOTH'));
    #    $cipher = Crypt::CBC->new( -cipher => $tmp 	);
    return ( $cipher->decrypt($text) );

}    # decrypt

#sub encryptRSA {
#    my ($text) = @_;
#    my ($rsa_public);
#
#    dbgMsg("encryptRSA");
#
#    $rsa_public = Crypt::OpenSSL::RSA->new_public_key(
#        readRSAKey( $RSA_KEY_FILE, 'PUBLIC' ) );
#
#    #    $rsa_public->use_sslv23_padding();
#    #    $rsa_public->use_pkcs1_padding();
#    $text = $rsa_public->encrypt($text);
#    return ( MIME::Base64::encode($text) );
#}    # encryptRSA
#
#sub decryptRSA ($) {
#    my ($base64_text) = @_;
#    my ( $text, $rsa_private );
#
#    dbgMsg("decryptRSA");
#
#    $text        = MIME::Base64::decode($base64_text);
#    $rsa_private = Crypt::OpenSSL::RSA->new_private_key(
#        readRSAKey( $RSA_KEY_FILE, 'PRIVATE' ) );
#
#    #    $rsa_private->use_sslv23_padding();
#    #    $rsa_private->use_pkcs1_padding();
#
#    return ( $rsa_private->decrypt($text) );
#}    # decryptRSA
#

sub sign_text ($) {
    my ($text) = @_;
    my ($rsa_private);

    $rsa_private = Crypt::OpenSSL::RSA->new_private_key(
        readRSAKey( $RSA_KEY_FILE, 'PRIVATE' ) );

    return ( MIME::Base64::encode( $rsa_private->sign($text) ) );
}    # sign_text

sub verify_signature ($$) {
    my ( $text, $signature ) = @_;
    my ($rsa_private);

    $rsa_private = Crypt::OpenSSL::RSA->new_private_key(
        readRSAKey( $RSA_KEY_FILE, 'PRIVATE' ) );

    return ( $rsa_private->verify( $text, MIME::Base64::decode($signature) ) );
}    # verify_signature

sub hash_string ($) {
    my ($text) = @_;

    return ( Digest::MD6::md6_base64($text) );
}    # hash_string

sub _inList ($$) {
    my ( $user, $allowed_str ) = @_;
    my ( @list, $name );

    @list = split( /\s*,\s*/, $allowed_str );
    foreach $name (@list) {
        $name =~ s/(Main\.|\%MAINWEB\%\.)//go;    # strip leading web.
        if (
            $name eq $user
            || (   TWiki::Func::isGroup($name)
                && TWiki::Func::isGroupMember( $name, $user ) )
          )
        {
            dbgMsg("inList: Found [$user] in [$name]");
            return (1);
        }
    }

    return (0);
}    #_inList

# CRAIG
# The function used to handle the %ENCRYPT{...}% variable
# Check if $meta is working
#

my ($encrypt_index);

sub _ENCRYPT {
    my ( $session, $params, $theTopic, $theWeb, $meta ) = @_;

    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    my ( $tmp, $key_id, $user );

    $key_id = $params->{'_dont_change'} || undef;
    $user = TWiki::Func::getWikiName();

    dbgMsg("View ENCRYPT: [$user] [$key_id]");
    dbgMsg( "Raw: [", $params->{_RAW}, "]" );
    dbgMsg( "Meta: [", $meta->stringify($MY_META_TYPE), "]" );

    if ( defined($key_id) ) {
        my ( $pinfo, $pattrs, $cipher_text, $allow_list, $display,
            $clear_text );
        $pinfo = $meta->get( $MY_META_TYPE, $key_id );
        $cipher_text = $pinfo->{value}   || '';
        $allow_list  = $pinfo->{allow}   || '';
        $display     = $pinfo->{display} || '******';

        if ( $cipher_text ne '' ) {
            if ( _inList( $user, $allow_list ) ) {
                $clear_text = decrypt( $Method, $cipher_text );
                dbgMsg("Result [$clear_text]");
                return ($clear_text);
            }
            else {
                dbgMsg("Result [$display]");
                return ($display);
            }
        }
        else {
            $tmp = join( '', '%<nop>ENCRYPT{', $params->{_RAW}, '}%' );
            errMsg("No Cipher result [$tmp]");
            return ($tmp);
        }
    }

    return ("%RED% Unexpected Finish %ENDCOLOR%");
}    # _ENCRYPT

sub _handleBeforeEdit {
    my ( $arg_string, $web, $topic, $pmeta ) = @_;
    my ( $params, $error, $key_id, $user, $result );

    $params = TWiki::Attrs->new($arg_string);
    $user   = TWiki::Func::getWikiName();
    $key_id = $params->{'_dont_change'} || undef;

    $error = 0;

    dbgMsg("_handleBeforeEdit: [$key_id] [$encrypt_index]");

    if ( defined($key_id) ) {
        my ( $pinfo, $cipher_text, $clear_text, $allow_list, $display );

        $pinfo = $pmeta->get( $MY_META_TYPE, $key_id );
        dbgMsg( "Meta: [", $pmeta->stringify($MY_META_TYPE), "]" );
        $cipher_text = $pinfo->{value} || '';

        if ( defined($cipher_text) && $cipher_text ne '' ) {
            $allow_list = $pinfo->{allow};

            if ( _inList( $user, $allow_list ) ) {
                $clear_text = decrypt( $Method, $cipher_text );
                $display    = $pinfo->{display};
                $result     = join( ' ',
                    '"' . $clear_text . '"',
                    'allow="' . $allow_list . '"',
                    'display="' . $display . '"' );

                # remove Meta data before edit
                $pmeta->remove( $MY_META_TYPE, $key_id );
            }
            else {
                $result = $arg_string;
            }
        }
        else {
            $result = $arg_string;
        }
    }
    else {
        $error++;
        $result = $arg_string;
    }

    $result = join( '', '%ENCRYPT{', $result, '}%' );
    if ( $error > 0 ) {
        $result = join( ' ', "%RED%", $result, "%ENDCOLOR%" );
    }

    dbgMsg("Done $encrypt_index: [$result]");
    dbgMsg( "Meta: [", $pmeta->stringify($MY_META_TYPE), "]" );

    $encrypt_index++;

    return ($result);
}    # _handleBeforeEdit

#
# Called by beforeSaveHandler()
#

sub _handleBeforeSave {
    my ( $arg_string, $web, $topic, $pmeta ) = @_;
    my (
        $params,  $error,  $clear_text,  $allow_list,
        $display, $key_id, $cipher_text, $signature,
        $hash,    $user,   $result
    );

    $params = TWiki::Attrs->new($arg_string);
    $user   = TWiki::Func::getWikiName();

    $clear_text = $params->{_DEFAULT}       || undef;
    $allow_list = $params->{allow}          || $user;
    $display    = $params->{display}        || '******';
    $key_id     = $params->{'_dont_change'} || undef;

    $error = 0;

    dbgMsg(
"_handleBeforeSave: [$clear_text] [$allow_list] [$display] [$key_id] [$encrypt_index]"
    );

    if ( defined($clear_text) && $clear_text ne '' ) {
        $cipher_text = encrypt( $Method, $clear_text );
        $signature   = sign_text( $allow_list . $clear_text . $encrypt_index );
        $hash        = hash_string($signature);
        $pmeta->putKeyed(
            $MY_META_TYPE,
            {
                name    => $hash,
                allow   => $allow_list,
                value   => $cipher_text,
                display => $display,
                index   => "$encrypt_index"
            }
        );
        $result = "_dont_change=\"$hash\"";
    }
    elsif ( defined($key_id) ) {
        my ($pinfo);
        $pinfo = $pmeta->get( $MY_META_TYPE, $key_id );
        $cipher_text = $pinfo->{value} || '';
        $hash = '';
        if ( defined($cipher_text) && $cipher_text ne '' ) {
            $clear_text = decrypt( $Method, $cipher_text );
            $allow_list = $pinfo->{allow};
            $signature =
              sign_text( $allow_list . $clear_text . $pinfo->{index} );
            $hash = hash_string($signature);
        }
        if ( $hash ne $key_id ) {
            $error = 1;
            errMsg("*** Something was modified [$arg_string]!");
        }
        $result = "_dont_change=\"$key_id\"";
    }

    $result = join( '', '%ENCRYPT{', $result, '}%' );
    if ( $error > 0 ) {
        $result = join( ' ', "%RED%", $result, "%ENDCOLOR%" );
    }

    dbgMsg("Done $encrypt_index: [$result]");
    dbgMsg( "Meta: ", $pmeta->stringify($MY_META_TYPE), "]" );

    $encrypt_index++;

    return ($result);
}    # _handleBeforeSave

=pod

---++ beforeEditHandler($text, $topic, $web )
   * =$text= - text that will be edited
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the edit script just before presenting the edit text
in the edit box. It is called once when the =edit= script is run.

__NOTE__: meta-data may be embedded in the text passed to this handler 
(using %META: tags)

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub beforeEditHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug("- ${pluginName}::beforeEditHandler( $_[2].$_[1] )")
      if $debug;

    #    my ( $text, $topic, $web, $meta );

    #    $text  = $_[0];
    #    $topic = $_[1];
    #    $web   = $_[2];
    #    $meta  = $_[3];
    $encrypt_index = 0;
    $_[0] =~ s/%ENCRYPT{(.*?)}%/_handleBeforeEdit($1, $_[2], $_[1], $_[3])/sgeo;

}    # beforeEditHandler

=pod

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a TWiki::Meta object.

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in =$text= (using %META: tags). If you modify
the =$meta= object, then it will override any changes to the meta-data
embedded in the text. Modify *either* the META in the text *or* the =$meta=
object, never both. You are recommended to modify the =$meta= object rather
than the text, as this approach is proof against changes in the embedded
text format.

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub beforeSaveHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug("- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )")
      if $debug;

    #    my ( $text, $topic, $web, $meta );
    #    $text  = $_[0];
    #    $topic = $_[1];
    #    $web   = $_[2];
    #    $meta  = $_[3];

    $encrypt_index = 0;
    $_[0] =~ s/%ENCRYPT{(.*?)}%/_handleBeforeSave($1, $_[2], $_[1], $_[3])/sgeo;
}    # beforeSaveHandler

1;
