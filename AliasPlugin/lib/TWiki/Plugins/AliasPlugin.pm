# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
package TWiki::Plugins::AliasPlugin;    # change the package name and $pluginName!!!
# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION
        $aliasPattern $prefixRegExp 
        $debug $acceptNonTWikiWord
    );

$VERSION = '1.011';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between AliasPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesValue("ALIASPLUGIN_DEBUG");

    TWiki::Func::writeDebug( "Trying to start AliasPlugin, debug level = $debug" ) if $debug;

    # Get plugin flag for non-twiki aliases
    $acceptNonTWikiWord = TWiki::Func::getPreferencesFlag( "ALIASPLUGIN_ACCEPT_NON_TWIKI_WORD_ALIASES" );
    TWiki::Func::writeDebug("AliasPlugin: ".($acceptNonTWikiWord?"DOES":"Does NOT")." accept non-TWiki-word aliases") if $debug;  
  
	#$prefixRegExp = '\\s|\\)'; 
	$prefixRegExp = '[-=*#&,;.:\\/()\\]{}+_>\\s]'; # should this be set by user on AliasPlugin page ?

    TWiki::Func::writeDebug("AliasPlugin: Reg exp prefixing aliases: $prefixRegExp") if $debug;

    # get the plugin preferences text
    my $prefText = TWiki::Func::readTopicText( TWiki, AliasPlugin );
    my @prefLines = split /\n/, $prefText;


    # create alias hash
    foreach my $line ( @prefLines ) {
      if(($acceptNonTWikiWord && $line =~ /\|\s*(?:\<nop\>)?(\w+)\s*\|\s*(?:\<nop\>)?(\S*)\s*\|/) ||
         ($line =~ /\|\s*(?:\<nop\>)?($TWiki::wikiWordRegex)\s*\|\s*(?:\<nop\>)?(\S*)\s*\|/)) 
      {
          TWiki::Func::writeDebug("AliasPlugin (detail): Config match: key=$1, value=$2") if($debug>1); #heavy debug
          $aliasHash{"$1"} = "$2";       
      }
    }

    # create alias pattern
    $aliasPattern = join('|', keys(%aliasHash));
    TWiki::Func::writeDebug( "AliasPlugin: generated aliasPattern: $aliasPattern") if $debug;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::AliasPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}


# =========================
sub startRenderingHandler
{

### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    TWiki::Func::writeDebug("AliasPlugin: startRenderingHandler(...,$_[1]) was called") if $debug;

    # if a WikiWord is found, check the line for defined aliases
    # and replace them
    TWiki::Func::writeDebug("AliasPlugin: startRenderingHandler got aliasPattern = $aliasPattern") if $debug;
    $_[0] =~ s/<nop>/NOPTOKEN/g;
    
    if($debug>1)
    {
      # debug each alisa substitution  
	  $_[0] =~ s/($prefixRegExp)($aliasPattern)\b/&_debugAliasReplacement($1,$2)/eg;
    }
    else
    {
      $_[0] =~ s/($prefixRegExp)($aliasPattern)\b/$1\[\[$aliasHash{$2}\]\[$2\]\]/g;
    }
    $_[0] =~ s/NOPTOKEN/<nop>/g;
}

sub _debugAliasReplacement
{
    my($prefix,$alias) = @_;
    my $link  = $aliasHash{$alias};
    TWiki::Func::writeDebug("AliasPlugin (detail): Render '$alias' as link to '$link'");
    return "$prefix\[\[$link\]\[$alias\]\]";
}

1;
