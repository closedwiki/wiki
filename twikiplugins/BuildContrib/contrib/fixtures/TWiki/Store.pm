=begin text

---++ Package TWiki::Store - test fixture
A test fixture module that provides an ultra-thin implementation of the
functions of the TWiki::Store module that are required by plugins and add-ons.

Only the methods encountered in testing to date are implemented.

For full details, read the code.

=cut
use strict;

package TWiki::Store;

use vars qw( %templateVars );

use BaseFixture;

sub readTemplateFile {
    my( $theName, $theSkin ) = @_;
    $theSkin = "" unless $theSkin; # prevent 'uninitialized value' warnings

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.skin).tmpl
    my $tmplDir = BaseFixture::getTemplatesDir();
    if( opendir( DIR, $tmplDir ) ) {
        my @filelist = grep /^$theName\..*tmpl$/, readdir DIR;
        closedir DIR;
        $tmplFile = "$theName.$theSkin.tmpl";
        if( ! grep { /^$tmplFile$/ } @filelist ) {
            $tmplFile = "$theName.tmpl";
            if( ! grep { /^$tmplFile$/ } @filelist ) {
                $tmplFile = "";
            }
        }
        if( $tmplFile ) {
            $tmplFile = "$tmplDir/$tmplFile";
        }
    }

    # read the template file
    if( -e $tmplFile ) {
        return BaseFixture::readFile( $tmplFile );
    } elsif ( $theName =~ /(\w+)\.(\w+)/ ) {
        my $theWeb = TWiki::Func::getTwikiWebname();
        my $theTopic = $theName;
        if ( $theName =~ /^(\w+)\.(\w+)$/ ) {
            $theWeb = $1;
            $theTopic = $2;
        }
        if ( TWiki::Func::topicExists( $theWeb, $theTopic )) {
            my ( $meta, $text ) = TWiki::Func::readTopic( $theWeb, $theTopic );
            return $text;
        }
    }
    return "";
}

sub readTemplate {
  my( $theName, $theSkin ) = @_;

  if( ! defined($theSkin) ) {
	$theSkin = TWiki::Func::getSkin() || "";
  }

  # recursively read template file(s)
  my $text = readTemplateFile( $theName, $theSkin );
  while( $text =~ /%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/s ) {
	$text =~ s/%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/&readTemplateFile( $1, $theSkin )/geo;
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

sub getAllWebs {
    return BaseFixture::webList();
}

sub handleTmplP
{
    # Print template variable, called by %TMPL:P{"$theVar"}%
    my( $theVar ) = @_;

    my $val = "";
    if( ( %templateVars ) && ( exists $templateVars{ $theVar } ) ) {
        $val = $templateVars{ $theVar };
        $val =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&handleTmplP($1)/geo;  # recursion
    } else {
        die "Template $theVar not defined\n";
    }
    if( ( $theVar eq "sep" ) && ( ! $val ) ) {
        # set separator explicitely if not set
        $val = " | ";
    }
    return $val;
}

1;
