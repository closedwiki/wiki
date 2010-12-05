# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2010 TWiki Contributors
# All Rights Reserved. TWiki Contributors are listed in the 
# AUTHORS file in the root of this distribution.
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

=cut

package TWiki::Plugins::EncryptPlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $installWeb $debug $privateKey $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '2010-09-18';

$SHORTDESCRIPTION = 'Securely encrypt text in TWiki topics to be accessible by selected users only';
$NO_PREFS_IN_TOPIC = 0;

# Name of this Plugin, only used in this module
$pluginName = 'EncryptPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin settings
    $debug = $TWiki::cfg{Plugins}{EncryptPlugin}{Debug} || 0;
    $privateKey = $TWiki::cfg{Plugins}{EncryptPlugin}{PrivateKey}
               || 'cryptkey.priv';

    # Plugin correctly initialized
    return 1;
}

=pod

---++ commonTagsHandler()

This handles the %ENCRYPT{...}% variable in view

=cut

sub commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $inInclude, $meta ) = @_;

#use Data::Dumper;
#print STDERR "===(START===)\n" . Dumper($_[4]) . "\n====(END)====";

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
    $_[0] =~ s/%ENCRYPT\{(.*?)\}%/_handleEncryptOnView( $1, $_[4] )/geo;
}

=pod

---++ beforeEditHandler($text, $topic, $web )

=cut

sub beforeEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    return unless( $_[0] =~ /%ENCRYPT{/ );

#    # FIXME: Hack to extract %META:ENCRYPTPLUGIN meta data from text with embedded meta data
#    # (proper solution is to enhance the plugins API with session and meta data)
#    my $metaEncrypt;
#print STDERR "start loop\n";
#    foreach my $line ( split( /[\r\n]+/, $_[0] ) ) {
#print STDERR "testing line: $line\n";
#        # Example: %META:ENCRYPTPLUGIN{name="y7t6C6MJ" allow="..." value="..."}%
#        if( $line =~ /^%META:ENCRYPTPLUGIN\{ *name=\"([^\"]*)\" *allow=\"([^\"]*)\" *value=\"([^\"]*)\" *\}%/ ) {
#        if( $line =~ /^%META:ENCRYPTPLUGIN\{(.*?)\}%/ ) {
#print STDERR "found $1 (allow $2, value $3)\n";
#            $metaEncrypt->{$1} = {
#                                     allow => TWiki::Store::dataDecode( $2 ),
#                                     value => TWiki::Store::dataDecode( $3 ),
#                                 };
#        }
#    }
#print STDERR "end loop\n";

    $_[0] =~ s/%ENCRYPT\{(.*?)\}%/_handleEncryptOnEdit( $1, $_[3] )/geo;
}

=pod

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a TWiki::Meta object.

=cut

sub beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    $_[0] =~ s/%ENCRYPT\{(.*?)\}%/_handleEncryptOnSave( $1, $_[3] )/geo;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ _handleEncryptOnView()

=cut

sub _handleEncryptOnView
{
    my ( $params, $meta ) = @_;

    my $text = '<nop>*****<nop>';
    my $attrs = new TWiki::Attrs( $params );
    if( $attrs->{_dont_change} ) {
        my $metaEncrypt = $meta->get( 'ENCRYPTPLUGIN', $attrs->{_dont_change} );
        if( $metaEncrypt ) {
            my $allow = $metaEncrypt->{allow};
            if(
                $allow eq TWiki::Func::getWikiName() ||
                $allow eq TWiki::Func::getCanonicalUserID() ||
                TWiki::Func::isGroupMember( $allow )
              ) {
                $text = "Found: $metaEncrypt->{name}, allow: $metaEncrypt->{allow}, value: $metaEncrypt->{value}";
            }
        }
    }
    return $text;
}

=pod

---++ _handleEncryptOnEdit()

=cut

sub _handleEncryptOnEdit
{
    my ( $params, $meta ) = @_;

    my $attrs = new TWiki::Attrs( $params );

    my $text = "<nop>*** edit **<nop> {$params} - " . $meta->get( 'ENCRYPTPLUGIN', $attrs->{_dont_change} )->{value};
    return $text;
}

=pod

---++ _handleEncryptOnSave()

=cut

sub _handleEncryptOnSave
{
    my ( $params, $meta ) = @_;

    my $attrs = new TWiki::Attrs( $params );
    my $rand = _randomStr();

    $meta->putKeyed( 'ENCRYPTPLUGIN', { name => $rand, allow => $attrs->{allow}, value => $attrs->{_DEFAULT} } );

    my $text = '%ENCRYPT{';
#    $text .= '"' . $attrs->{_DEFAULT} . '"';
#    $text .= ' allow="' . $attrs->{allow} . '"';
    $text .=  '_dont_change="' . $rand . '"}%';
    return $text;
}

=pod

---++ _randomStr()

=cut

sub _randomStr
{
    my @chars=('a'..'z','A'..'Z','0'..'9');
    my $str = '';
    foreach ( 1..8 ) {
        $str .= $chars[rand @chars];
    }
    return $str;
}

1;
