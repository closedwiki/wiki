# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
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
use strict;

use TWiki;
use TWiki::Store;
use TWiki::Access;

=pod

---+ package TWiki::Templates

Support for the TWiki template language. The following tokens are
supported by this language:

| %<nop>TMPL:P% | Instantiates a previously defined template |
| %<nop>TMPL:DEF% | Opens a template definition |
| %<nop>TMPL:END% | Closes a template definition |
| %<nop>TMPL:INCLUDE% | Includes another file of templates |

Note; the template cache does not get reset during initialisation, so
the haveTemplate test will return true if a template was loaded during
a previous run when used with mod_perl or speedycgi. Frustrating for
the template author, but they just have to switch off
the accelerators during development.

This is to all intents and purposes a singleton object. It could
easily be coverted into a true singleton (template manager).

=cut

package TWiki::Templates;

use vars qw( %templateVars );

=pod

---++ sub haveTemplate( $name )

Return true if the template exists and is loaded into the cache

=cut

sub haveTemplate {
    my $template = shift;

    return exists( $templateVars{ $template } );
}

=pod

---++ sub expandTemplate( $theParam  )

Expand the template named in the parameter after recursive expansion
of any TMPL:P tags it contains. Note that all other template tags
will have been expanded at template load time.

SMELL: does not support template parameters

Note that it would be trivial to add template parameters to this,
simply by iterating over the other parameters (other than __default__)
and doing a subs in the template for that parameter value. This
would add considerably to the power of templates. There is already code
to do this in the MacrosPlugin.

=cut

sub expandTemplate
{
    my( $theParam ) = @_;

    $theParam = TWiki::extractNameValuePair( $theParam );
    my $value = _tmplP( $theParam );
    return $value;
}

# Return value: expanded text of the named template, as found from looking
# in the register of template definitions.
# If $theVar is the name of a previously defined template, returns the text of
# that template after recursive expansion of any TMPL:P tags it contains.
sub _tmplP
{
    # Print template variable, called by %TMPL:P{"$theVar"}%
    my( $theVar ) = @_;

    my $val = "";
    if( ( %templateVars ) && ( exists $templateVars{ $theVar } ) ) {
        $val = $templateVars{ $theVar };
        $val =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&_tmplP($1)/geo;  # recursion
    }
    if( ( $theVar eq "sep" ) && ( ! $val ) ) {
        # set separator explicitely if not set
        $val = " | ";
    }
    return $val;
}

=pod

---++ sub readTemplate ( $theName, $theSkin, $theWeb )
Return value: expanded template text

Reads a template, constructing a candidate name for the template thus
   * look for a file =$name.$skin.tmpl=
      * first in templates/$web 
      * then if that fails in templates/.
   * If a template is not found, tries:
      * to parse $name into a web name and a topic name, and
      * read topic $Web.${Skin}Skin${Topic}Template. 
   * If $name does not contain a web specifier, $Web defaults to
     TWiki::twikiWebname.
   * If no skin is specified, topic is ${Topic}Template.
In the event that the read fails (template not found, access permissions fail)
returns the empty string "".

skin, web and topic names are forced to an upper-case first character
when composing user topic names.

If template text is found, extracts include statements and fully expands them.
Also extracts template definitions and adds them to the
list of loaded templates, overwriting any previous definition.

=cut

sub readTemplate
{
    my( $theName, $theSkin, $theWeb ) = @_;

    if( ! defined($theSkin) ) {
        $theSkin = TWiki::getSkin();
    }

    if( ! defined( $theWeb ) ) {
      $theWeb = $TWiki::webName;
    }

    # recursively read template file(s)
    my $text = _readTemplateFile( $theName, $theSkin, $theWeb );
    while( $text =~ /%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/s ) {
        $text =~ s/%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/&_readTemplateFile( $1, $theSkin, $theWeb )/geo;
    }

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
                $templateVars{ $key } = $val;
            }
            $key = $1;
            $val = $2 || "";

        } elsif( /^END%[\n\r]*(.*)/s ) {
            # handle %TMPL:END%
            $templateVars{ $key } = $val;
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
    $result =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&_tmplP($1)/geo;
    $result =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom;  # leading spaces to tabs
    return $result;
}

# Return value: raw template text, or "" if read fails
sub _readTemplateFile
{
    my( $theName, $theSkin, $theWeb ) = @_;
    $theSkin = "" unless $theSkin; # prevent 'uninitialized value' warnings

    # CrisBailiff, PeterThoeny 13 Jun 2000: Add security
    $theName =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    $theName =~ s/\.+/\./g;                      # Filter out ".." from filename
    $theSkin =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    $theSkin =~ s/\.+/\./g;                      # Filter out ".." from filename

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.skin).tmpl
    my $tmplDir = "$TWiki::templateDir/$theWeb";
    if( opendir( DIR, $tmplDir ) ) {
        # for performance use readdir, not a row of ( -e file )
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

    # if not found, search in twiki/templates dir
    $tmplDir = $TWiki::templateDir;
    if( ( ! $tmplFile ) && ( opendir( DIR, $tmplDir ) ) ) {
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
    if( $tmplFile && -e $tmplFile ) {
        return TWiki::Store::readFile( $tmplFile );
    }

    # See if it is a user topic. Search first in current web
    # twiki web. Note that neither web nor topic may be variables
    # when used in a template name.
    if ( $theSkin ne "" ) {
        $theSkin = ucfirst( $theSkin ) . "Skin";
    }

    my $theTopic;

    if ( $theName =~ /^(\w+)\.(\w+)$/ ) {
        $theWeb = ucfirst( $1 );
        $theTopic = ucfirst( $2 );
    } else {
        $theWeb = $TWiki::webName;
        $theTopic = $theSkin . ucfirst( $theName ) . "Template";
        if ( !TWiki::Store::topicExists( $theWeb, $theTopic )) {
            $theWeb = $TWiki::twikiWebname;
        }
    }

    if ( TWiki::Store::topicExists( $theWeb, $theTopic ) &&
         TWiki::Access::checkAccessPermission( "view",
                                               $TWiki::wikiUserName, "", $theTopic, $theWeb )) {
        my ( $meta, $text ) = TWiki::Store::readTopic( $theWeb, $theTopic, 1 );
        return $text;
    }

    return "";
}

1;
