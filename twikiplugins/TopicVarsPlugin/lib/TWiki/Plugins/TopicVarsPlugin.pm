#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2001 Tripp Lilley, tripp+twiki-plugins@perspex.com
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
#
# =========================
#
# This plugin allows you to define variables within arbitrary pages
# in your TWiki, then refer to them from other arbitrary pages. It
# (currently) only supports referring to variables defined within
# the same web, but may expand to include cross-web, and possibly
# even InterWiki references in the future.



# =========================
package TWiki::Plugins::TopicVarsPlugin; 	# change the package name!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        %vars
    );

$VERSION = '1.000';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between TopicVarsPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    #$exampleCfgVar = &TWiki::Func::getPreferencesValue( "TOPICVARSPLUGIN_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "TOPICVARSPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::TopicVarsPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}


## Stolen from TWiki::Prefs::getPrefsFromTopic because I don't
## (offhand) know of an easy way to override that to make it do what I
## want. I suppose I might be able to work some kind of black magic
## with the symbol table, but I'm not up to that right now.

sub getVarsFromTopic {
	my ( $theWeb, $theTopic ) = @_;
	my $theKeyPrefix = "";


	&TWiki::Func::writeDebug( "- TWiki::Plugins::TopicVarsPlugin::getVarsFromTopic( $theWeb.$theTopic )" ) if $debug;

	my( $meta, $text ) = &TWiki::Func::readTopic( $theWeb, $theTopic );
	$text =~ s/\r/\n/go;
	$text =~ s/\n+/\n/go;

	my $keyPrefix = $theKeyPrefix || "";  # prefix is for plugin prefs
	my $key = "";
	my $value ="";
	my $isKey = 0;
	foreach( split( /\n/, $text ) ) {
		if( /^\t+\*\sSet\s([a-zA-Z0-9_]+)\s\=\s*(.*)/ ) {
			if( $isKey ) {
				$vars{$theWeb}{$theTopic}{$key} = $value;
			}
			$key = "$keyPrefix$1";
			$value = defined $2 ? $2 : "";
			$isKey = 1;
		} elsif ( $isKey ) {
			if( ( /^\t+/ ) && ( ! /^\t+\*/ ) ) {
				# follow up line, extending value
				$value .= "\n$_";
			} else {
				$vars{$theWeb}{$theTopic}{$key} = $value;
				$isKey = 0;
			}
		}
	}
	if( $isKey ) {
		$vars{$theWeb}{$theTopic}{$key} = $value;
	}
}





sub do_var_from_wiki {
### my ( $web, $topic, $varname ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
	my $theWeb = $_[0];
    if(defined($TWiki::securityFilter)) {
        $theWeb =~ s/$TWiki::securityFilter//go;
    } else {
        $theWeb =~ s/$TWiki::cfg{NameFilter}//go;
    }
	getVarsFromTopic( $theWeb, $_[1] ) unless $vars{$theWeb}{$_[1]};
	my $var = $vars{$theWeb}{$_[1]}{$_[2]};
	$var = defined $var ? $var : "\%$theWeb.$_[1].$_[2]\%";
	if ($debug) {
		&TWiki::Func::writeDebug( "- TopicVarsPlugin::do_var_from_wiki $theWeb.$_[1].$_[2]: [$var]" );
	}
	return $var;
}
sub do_var_from_web {
### my ( $topic, $varname ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
	getVarsFromTopic( $web, $_[0] ) unless $vars{$web}{$_[0]};
	my $var = $vars{$web}{$_[0]}{$_[1]};
	$var = defined $var ? $var : return "\%$_[0].$_[1]\%";
	if ($debug) {
		&TWiki::Func::writeDebug( "- TopicVarsPlugin::do_var_from_web $_[0].$_[1]: [$var]" );
	}
	return $var;
}
sub do_var_from_topic {
### my ( $varname ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
	getVarsFromTopic( $web, $topic ) unless $vars{$web}{$topic};
	my $var = $vars{$web}{$topic}{$_[0]};
	$var = defined $var ? $var : "\%$_[0]\%";
	if ($debug) {
		&TWiki::Func::writeDebug( "- TopicVarsPlugin::do_var_from_topic $_[0]: [$var]" );
	}
	return $var;
}



# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- TopicVarsPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;

		## Handle unqualified var references (will look on this page)
		$_[0] =~ s/%([a-zA-Z0-9_]+)%/&do_var_from_topic($1)/geo;

		## Handle topic-qualified var references (will look at topics on this web)
		$_[0] =~ s/%([A-Z]+[a-z]+[A-Z]+[A-Za-z0-9]*)\.([A-Za-z0-9_]+)%/&do_var_from_web($1, $2)/geo;

		## Handle fully-qualified var references (will look at webs/topics on this wiki)
		$_[0] =~ s/%([A-Z][^%]*)\.([A-Z]+[a-z]+[A-Z]+[A-Za-z0-9_]*)\.([a-zA-Z0-9_]+)%/&do_var_from_wiki($1, $2, $3)/geo;
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- TopicVarsPlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- TopicVarsPlugin::outsidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- TopicVarsPlugin::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- TopicVarsPlugin::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop

}

# =========================

1;
