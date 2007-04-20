# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) by TWiki Contributors. All Rights Reserved. TWiki Contributors
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


# =========================
package TWiki::Plugins::SpacedWikiWordPlugin; 

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug %dontSpaceSet
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between SpacedWikiWordPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "SPACEDWIKIWORDPLUGIN_DEBUG" );

    my $dontSpaceWords = &TWiki::Func::getPreferencesValue( "DONTSPACE" ) ||
                       &TWiki::Func::getPreferencesValue( "SPACEDWIKIWORDPLUGIN_DONTSPACE" );
    $dontSpaceWords =~ s/ //go;
    %dontSpaceSet = map { $_ => 1 } split(",", $dontSpaceWords);
    
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::SpacedWikiWord::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

=pod

---++ renderWikiWordHandler( $linkLabel, $hasExplicitLinkLabel ) -> $text


   * =$linkLabel= - the link label to be spaced out
   * =$hasExplicitLinkLabel= - in case of bracket notation: the link label is written as [[TopicName][link label]]

We use the following rules:
   - Space out in case of TopicName, Web.TopicName, [[TopicName]]
   - Do not space out [[TopicName][TopicName]] or [[TopicName][SomeOtherName]]; in these cases the topic author has used an explicit link label
Search results not so clear-cut; currently [[$web.$topic][$topic]] is not spaced
out.
    
=cut

sub renderWikiWordHandler 
{
    my ( $linkLabel, $hasExplicitLinkLabel ) = @_;
    
    # do nothing if this label is defined in the do-not-link list
    return $linkLabel if $dontSpaceSet{ $linkLabel };
    
    # switch off until TWiki::Func::spaceOutWikiWord is implemented:
    #if( $TWiki::Plugins::VERSION < 1.13 ) {
    #    return _spacedWikiWord( $linkLabel ) unless $hasExplicitLinkLabel; 
    #}
    #return TWiki::Func::spaceOutWikiWord( $linkLabel ) unless $hasExplicitLinkLabel;
    
    # instead use temporarily:
    return _spacedWikiWord( $linkLabel ) unless $hasExplicitLinkLabel;
    
    return $linkLabel;
}

=pod

---++ _spacedWikiWord( $linkLabel ) -> $text

Fallback for older Plugins version. Regexes are copied from TWiki::spaceOutWikiWord.

   * =$linkLabel= - the link label to be spaced out

=cut

sub _spacedWikiWord
{
    my ( $linkLabel ) =  @_;

    my $sep = ' ';
    my $lowerAlphaRegex = TWiki::Func::getRegularExpression('lowerAlpha');
    my $upperAlphaRegex = TWiki::Func::getRegularExpression('upperAlpha');
    my $numericRegex = TWiki::Func::getRegularExpression('numeric');

    $linkLabel =~ s/([$lowerAlphaRegex])([$upperAlphaRegex$numericRegex]+)/$1$sep$2/go;
    $linkLabel =~ s/([$numericRegex])([$upperAlphaRegex])/$1$sep$2/go;

    return $linkLabel;
}

1;
