# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
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

package TWiki::Plugins::SignaturePlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev: 0$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 0$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'SignaturePlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "This version of $pluginName works only with TWiki 4 and greater." );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;

}

sub preRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- $pluginName::preRenderingHandler" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop
    # Only bother with this plugin if viewing (i.e. not searching, etc)
    return unless ($0 =~ m/view|viewauth|render/o);

    # Get rid of CRs (we only want to deal with LFs)
    my $cnt;
    $_[0] =~ s/%SIGNATURE%/&handleSignature($cnt++)/geo;

}

sub handleSignature {
  my ( $cnt ) = @_;
  my $session = $TWiki::Plugins::SESSION;
  my $fmt = TWiki::Func::getPreferencesValue( "\U$pluginName\E_SIGNATURELABEL" ) || 'Sign';

  return "<form action=\"" . &TWiki::Func::getScriptUrl($session->{webName}, $session->{topicName}, 'digisign') . "\" /><input type=\"hidden\" name=\"nr\" value=\"$cnt\" /><input type=\"submit\" value=\"$fmt\" /></form>";

}

sub sign {
  my $session = shift;
  $TWiki::Plugins::SESSION = $session;
  my $query = $session->{cgiQuery};
  return unless ( $query );

  my $cnt = $query->param( 'nr' );

  my $webName = $session->{webName};
  my $topic = $session->{topicName};
  my $user = $session->{user};
  return unless ( &doEnableEdit ($webName, $topic, $user, $query, 'editTableRow') );

  my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );
  $text =~ s/%SIGNATURE%/&replaceSignature($cnt--, $user)/geo;

  my $error = &TWiki::Func::saveTopicText( $webName, $topic, $text, 1 );
  TWiki::Func::setTopicEditLock( $webName, $topic, 0 );  # unlock Topic
  if( $error ) {
    TWiki::Func::redirectCgiQuery( $query, $error );
    return 0;
  } else {
    # and finally display topic
    TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( $webName, $topic ) );
  }
  
}

sub replaceSignature {
  my ( $dont, $user ) = @_;

  return '%SIGNATURE%' if $dont;
  
  my $fmt = TWiki::Func::getPreferencesValue( "\U$pluginName\E_SIGNATUREFORMAT" ) || '$wikiusername - $date';

  my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my ($d, $m, $y) = (localtime)[3, 4, 5];
  $y += 1900;
  my $ourDate = sprintf('%02d %s %d', $d, $months[$m], $y);

  $fmt =~ s/\$quot/\"/go;
  $fmt =~ s/\$wikiusername/$user->webDotWikiName()/geo;
  $fmt =~ s/\$wikiname/$user->wikiName()/geo;
  $fmt =~ s/\$username/$user->login()/geo;
  $fmt =~ s/\$date/$ourDate/geo;

  return $fmt;

}

sub doEnableEdit
{
    my ( $theWeb, $theTopic, $user, $query ) = @_;

    if( ! &TWiki::Func::checkAccessPermission( "change", $user, "", $theTopic, $theWeb ) ) {
        # user does not have permission to change the topic
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'topic_access',
                                    web => $_[2],
                                    topic => $_[1],
				    params => [ 'Edit topic', 'You are not permitted to edit this topic' ] );
	return 0;
    }

    my( $oopsUrl, $lockUser ) = &TWiki::Func::checkTopicEditLock( $theWeb, $theTopic, 'edit' );
    if( $lockUser && ! ( $lockUser eq $user->login ) ) {
      # warn user that other person is editing this topic
      &TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
      return 0;
    }
    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );

    return 1;

}

1;
