package TWiki::Contrib::CairoContrib;

use strict;

use vars qw( $VERSION );

$VERSION = 1.00;

=begin text

---++ Cairo Compatibility Module
If a plugin uses Cairo function calls, you can include this module
to ensure it is compatible with older releases of TWiki. Of course
you should instruct users to upgrade to Cairo by preference, but this
module should make sure the plugin works if they can't for some reason.

The module should NOT be used when running alongside code later than
Beijing.

Plugin authors should feel free to check in to this module, but please
be careful not to break anything.

=cut

use TWiki;

=begin text

---+++ TWiki::Func::getRegularExpression
See documentation in TWiki:Codev/FuncDotPm

=cut

sub TWiki::Func::getRegularExpression {
  my $x = shift;
  eval "return \$TWiki::$x";
}

sub TWiki::Func::formatTime {
  # always return GM time
  return TWiki::Func::formatGmTime( @_ );
}

=begin text

---+++ TWiki::expandVariablesOnTopicCreation
See documentation in TWiki:Codev/TWikiDotPm

=cut

sub TWiki::expandVariablesOnTopicCreation {
  my ( $theText, $theUser, $theWikiName, $theWikiUserName ) = @_;

  $today = TWiki::Func::formatTime(time(), "\$day \$mon \$year", "gmtime");
  $theUser         = $userName                     unless $theUser;
  $theWikiName     = TWiki::Func::userToWikiName( $theUser, 1 ) unless $theWikiName;
  $theWikiUserName = TWiki::Func::userToWikiName( $theUser )    unless $theWikiUserName;

  $theText =~ s/%DATE%/$today/go;
  $theText =~ s/%USERNAME%/$theUser/go;                     # "jdoe"
  $theText =~ s/%WIKINAME%/$theWikiName/go;                 # "JonDoe"
  $theText =~ s/%WIKIUSERNAME%/$theWikiUserName/go;         # "Main.JonDoe"
  $theText =~ s/%URLPARAM{(.*?)}%/&handleUrlParam($1)/geo;  # expand URL parameters
  $theText =~ s/%NOP{.*?}%//gos;  # Remove filler: Use it to remove access control at time of
  $theText =~ s/%NOP%//go;        # topic instantiation or to prevent search from hitting a template

  return $theText;
}

package CairoCompatibilityModule;

use TWiki::Store;

# This is a measure to let Plugins read templates from topics in
# webs as well as the templates dir.
#
# Templates are loaded by choice from the templates dir, but if the template
# isn't found, webs are searched. If a web is specified, then that web is
# searched; otherwise the template is assumed to be in the TwikiWeb.

sub _loadFile {
  my( $theName, $theSkin ) = @_;
  my $text = TWiki::Store::_readTemplateFile( $theName, $theSkin,
						$TWiki::webName );
  return $text unless ( $text eq "" );
  # wasn't a matched template, try topic
  my $theTopic = $theName;
  my $theWeb = TWiki::Func::getTwikiWebname();
  if ( $theName =~ /^(\w+)\.(\w+)$/ ) {
	$theWeb = $1;
	$theTopic = $2;
  }
  if ( TWiki::Func::topicExists( $theWeb, $theTopic )) {
	my $meta;
	( $meta, $text ) = TWiki::Func::readTopic( $theWeb, $theTopic );
  }
  return $text;
}

=begin text

---+++ Cairo<nop>CompatibilityModule::readTemplate

See documentation in TWiki:Codev/StoreDotPm

=cut

sub readTemplate {
  my( $theName, $theSkin ) = @_;

  if( ! defined($theSkin) ) {
	$theSkin = TWiki::Func::getSkin();
  }

  # recursively read template file(s)
  my $text = _loadFile( $theName, $theSkin );
  while( $text =~ /%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/s ) {
	$text =~ s/%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/&_loadFile( $1, $theSkin )/geo;
  }

  # or even if this function had been split here, and file reading separated from
  # template processing
  if( ! ( $text =~ /%TMPL\:/s ) ) {
	# no template processing
	$text =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom;  # leading spaces to tabs
	return $text;
  }

  my $result = "";
  my $key  = "";
  my $val  = "";
  my $delim = "";
  foreach( split( /(%TMPL\:)/, $text ) ) {
	if( /^(%TMPL\:)$/ ) {
	  $delim = $1;
	} elsif( ( /^DEF{[\s\"]*(.*?)[\"\s]*}%[\n\r]*(.*)/s ) && ( $1 ) ) {
	  # handle %TMPL:DEF{"key"}%
	  if( $key ) {
		$TWiki::Store::templateVars{ $key } = $val;
	  }
	  $key = $1;
	  $val = $2 || "";
	} elsif( /^END%[\n\r]*(.*)/s ) {
	  # handle %TMPL:END%
	  $TWiki::Store::templateVars{ $key } = $val;
	  $key = "";
	  $val = "";
	  $result .= $1 || "";
	} elsif( $key ) {
	  $val    .= "$delim$_";
	} else {
	  $result .= "$delim$_";
	}
  }

  # handle %TMPL:P{"..."}% recursively
  $result =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&TWiki::Store::handleTmplP($1)/geo;
  $result =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom;  # leading spaces to tabs
  return $result;
}

1;
