# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Antonio S. de A. Terceiro, asaterceiro@inf.ufrgs.br
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

# =========================
package TWiki::Plugins::TopicTranslationsPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug
        @translations
        $defaultLanguage
    );

$VERSION = '1.001';
$pluginName = 'TopicTranslationsPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.024 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # those should be preferably set in a per web basis. Defaults to the
    # corresponding plugin setting (or "en" if someone messes with it)
    my $trans = TWiki::Func::getPreferencesValue("TOPICTRANSLATIONS") || TWiki::Func::getPluginPreferencesFlag("TOPICTRANSLATIONS") || "en";
    @translations = split(/,\s*/,$trans);

    # first listed language is the default one:
    $defaultLanguage = $translations[0];

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub DISABLE_earlyInitPlugin
{
### Remove DISABLE_ for a plugin that requires early initialization, that is expects to have
### initializeUserHandler called before initPlugin, giving the plugin a chance to set the user
### See SessionPlugin for an example of this.
    return 1;
}


# =========================
sub DISABLE_initializeUserHandler
{
### my ( $loginName, $url, $pathInfo ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set the username based on cookies. Called by TWiki::initialize.
    # Return the user name, or "guest" if not logged in.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # handle all INCLUDETRANSLATION tags:
    $_[0] =~ s/%INCLUDETRANSLATION{(.*?)}%/&handleIncludeTranslation($1)/ge;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # handle our common tags:
    $_[0] =~ s/%TRANSLATIONS({(.*?)})?%/&handleTranslations($2)/ge;
    $_[0] =~ s/%CURRENTLANGUAGE%/&currentLanguage/ge;
    $_[0] =~ s/%DEFAULTLANGUAGE%/$defaultLanguage/ge;
}

sub normalizeLanguageName
{
  my $lang = shift;
  $lang =~ s/[_-]//g;
  $lang =~ s/^(.)(.*)$/\u$1\L$2/;
  return $lang;
}

sub findBaseTopicName
{
  my $base = shift || $topic;
  foreach $lang (@translations) {
    $norm = normalizeLanguageName($lang);
    if ($base =~ m/$norm$/) {
      $base =~ s/$norm$//;
    }
  }
  return $base;
}

sub currentLanguage
{
  my $norm;
  foreach $lang (@translations) {
    $norm = normalizeLanguageName($lang);
    if ($topic =~ m/$norm$/) {
      return $lang;
    }
  }
  return $defaultLanguage;
}

sub handleTranslations
{
  my $params = shift;

  my $result = "";
  my $separator = "";
  my $norm;

  
  my $format = TWiki::Func::extractNameValuePair($params, "format") || "[[\$web.\$translation][\$language]]";
  my $userSeparator = TWiki::Func::extractNameValuePair($params, "separator") || " ";

  my $baseTopicName = findBaseTopicName();
 
  # list translations
  foreach $lang (@translations) {
    $norm = ($lang eq $defaultLanguage)?'':normalizeLanguageName($lang);
    $result .= $separator;
    $separator = $userSeparator;
    $result .= formatTranslationEntry($format, "$baseTopicName$norm", $lang);
  }

  return $result;
}

sub formatTranslationEntry
{
  my ($format, $translationTopic, $lang) = @_;
  my $result = $format;

  $result =~ s/\$web/$web/g;
  $result =~ s/\$topic/$topic/g;
  $result =~ s/\$translation/$translationTopic/g;
  $result =~ s/\$language/$lang/g;

  return $result;
}

sub handleIncludeTranslation
{
  my $params = shift;

  my $theLang = currentLanguage();
  
  my $theTopic = TWiki::Func::extractNameValuePair($params);
  $theTopic = findBaseTopicName($theTopic);
  if ($theLang ne $defaultLanguage) {
    $theTopic .= normalizeLanguageName($theLang);
  }

  # undef is ok, meaning current revision:
  my $theRev = TWiki::Func::extractNameValuePair($params, "rev");

  my $args = "\"$theTopic\"";
  $args .= " rev=\"$theRev\"" if $theRev;

  return '%INCLUDE{' . $args . '}%';

}

# =========================
sub DISABLE_writeHeaderHandler
{
### my ( $query ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::writeHeaderHandler( query )" ) if $debug;

    # This handler is called by TWiki::writeHeader, just prior to writing header. 
    # Return a single result: A string containing HTTP headers, delimited by CR/LF
    # and with no blank lines. Plugin generated headers may be modified by core
    # code before they are output, to fix bugs or manage caching. Plugins should no
    # longer write headers to standard output.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_redirectCgiQueryHandler
{
### my ( $query, $url ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;

    # This handler is called by TWiki::redirect. Use it to overload TWiki's internal redirect.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

    if ($topic =~ /"TestTopic"/) {
      $_[1] = 'http://boipeba.homeip.net:8080/';
    }
    return 1;
}

# =========================
sub DISABLE_getSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;

    # This handler is called by TWiki::getSessionValue. Return the value of a key.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_setSessionValueHandler
{
### my ( $key, $value ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;

    # This handler is called by TWiki::setSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================

1;
