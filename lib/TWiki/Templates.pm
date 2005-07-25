# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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
# As per the GPL, removal of this notice is prohibited.

use strict;

=pod

---+ package TWiki::Templates

Support for the TWiki template language.

=cut

=pod

The following tokens are supported by this language:

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

use Assert;

=pod

---++ ClassMethod new ( $session )

Constructor. Creates a new template database object.
   * $session - session (TWiki) object

=cut

sub new {
    my ( $class, $session ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;

    %{$this->{VARS}} = ();

    return $this;
}

=pod

---++ ObjectMethod haveTemplate( $name ) -> $boolean

Return true if the template exists and is loaded into the cache

=cut

sub haveTemplate {
    my ( $this, $template ) = @_;
    ASSERT($this->isa( 'TWiki::Templates')) if DEBUG;

    return exists( $this->{VARS}{ $template } );
}

# Expand only simple templates that can be expanded statically.
# Templates with conditions can only be expanded after the
# context is fully known.
sub _expandTrivialTemplate {
    my( $this, $text ) = @_;

    $text =~ /%TMPL\:P{(.*)}%/;
    my $attrs = new TWiki::Attrs( $1 );
    # Can't expand context-dependant templates
    return $text if ( $attrs->{context} );
    return $this->_tmplP( $attrs );
}

=pod

---++ ObjectMethod expandTemplate( $params  ) -> $string

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

sub expandTemplate {
    my( $this, $params ) = @_;
    ASSERT($this->isa( 'TWiki::Templates')) if DEBUG;

    my $attrs = new TWiki::Attrs( $params );
    my $value = $this->_tmplP( $attrs );
    return $value;
}

# Return value: expanded text of the named template, as found from looking
# in the register of template definitions.
# If $var is the name of a previously defined template, returns the text of
# that template after recursive expansion of any TMPL:P tags it contains.
sub _tmplP {
    my( $this, $params ) = @_;

    my $template = $params->{_DEFAULT};

    if( $params->{context} ) {
        $template = $params->{then} || $params->{_DEFAULT};
        foreach my $id ( split( /, */, $params->{context} )) {
            unless( $this->{session}->{context}->{$id} ) {
                $template = $params->{else} || '';
                last;
            }
        }
    }

    my $val = '';
    if( exists($this->{VARS}{ $template } )) {
        $val = $this->{VARS}{ $template };
        $val =~ s/%TMPL\:P{(.*?)}%/$this->expandTemplate($1)/geo;
    }
    if( ( $template eq 'sep' ) && ( ! $val ) ) {
        # set separator explicitly if not set
        $val = " | ";
    }
    return $val;
}

=pod

---++ ObjectMethod readTemplate ( $name, $skins, $web ) -> $text

Return value: expanded template text

Reads a template, constructing a candidate name for the template thus
   0 looks for file =$name.$skin.tmpl= (for each skin)
      0 in =templates/$web=
      0 in =templates=, look for
   0 looks for file =$name.tmpl=
      0 in =templates/$web=
      0 in =templates=, look for
   0 if a template is not found, tries in this order
      0 parse =$name= into a web name (default to $web) and a topic name and looks for this topic
      0 looks for topic =${skin}Skin${name}Template= 
         0 in $web (for each skin)
         0 in =TWiki::cfg{SystemWebName}= (for each skin)
      0 looks for topic =${name}Template=
         0 in $web (for each skin)
         0 in =TWiki::cfg{SystemWebName}= (for each skin)
In the event that the read fails (template not found, access permissions fail)
returns the empty string ''.

=$skin=, =$web= and =$name= are forced to an upper-case first character
when composing user topic names.

If template text is found, extracts include statements and fully expands them.
Also extracts template definitions and adds them to the
list of loaded templates, overwriting any previous definition.

=cut

sub readTemplate {
    my( $this, $name, $skins, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Templates')) if DEBUG;

    $this->{files} = ();

    # recursively read template file(s)
    my $text = $this->_readTemplateFile( $name, $skins, $web );

    while( $text =~ /%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/s ) {
        $text =~ s/%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/$this->_readTemplateFile( $1, $skins, $web )/geo;
    }

    # Kill comments, marked by %{ ... }%
    $text =~ s/%{.*?}%//sg;

    if( ! ( $text =~ /%TMPL\:/s ) ) {
        # no template processing
        $text =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom;  # leading spaces to tabs
        return $text;
    }

    my $result = '';
    my $key  = '';
    my $val  = '';
    my $delim = '';
    foreach( split( /(%TMPL\:)/, $text ) ) {
        if( /^(%TMPL\:)$/ ) {
            $delim = $1;
        } elsif( ( /^DEF{[\s\"]*(.*?)[\"\s]*}%[\n\r]*(.*)/s ) && ( $1 ) ) {
            # handle %TMPL:DEF{key}%
            if( $key ) {
                $this->{VARS}{ $key } = $val;
            }
            $key = $1;
            $val = $2;

        } elsif( /^END%[\n\r]*(.*)/s ) {
            # handle %TMPL:END%
            $this->{VARS}{ $key } = $val;
            $key = '';
            $val = '';
            $result .= $1;

        } elsif( $key ) {
            $val    .= "$delim$_";

        } else {
            $result .= "$delim$_";
        }
    }

    # handle %TMPL:P{"..."}% recursively
    $result =~ s/(%TMPL\:P{.*?}%)/$this->_expandTrivialTemplate($1)/geo;

    $result =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom;  # leading spaces to tabs
    return $result;
}

# STATIC: Return value: raw template text, or '' if read fails
sub _readTemplateFile {
    my( $this, $name, $skins, $web ) = @_;
    my $store = $this->{session}->{store};

    $skins = $this->{session}->getSkin() unless defined( $skins );
    #print STDERR "SKIN path is $skins\n";
    $web ||= $this->{session}->{webName};
    $name ||= '';

    # SMELL: not i18n-friendly (can't have accented characters in skin name)
    # zap anything suspicious
    $name =~ s/[^A-Za-z0-9_,.]//go;
    $skins =~ s/[^A-Za-z0-9_,.]//go;

    my @skinList = split( /,+/, $skins );

    unless( defined( $this->{files} )) {
        @{$this->{files}} = ();
        foreach my $tmplDir ( "$TWiki::cfg{TemplateDir}/$web",
                              $TWiki::cfg{TemplateDir} ) {

            if( opendir( DIR, $tmplDir ) ) {
                push( @{$this->{files}},
                      map { $tmplDir.'/'.$_ }
                      grep { /\.tmpl$/ }
                      readdir DIR );
                closedir( DIR );
            }
        }
    }

    # Search the web dir and the root dir for the skinned version first
    foreach my $skin ( @skinList ) {
        foreach my $file ( @{$this->{files}} ) {
            if ( $file =~ /\/$name.$skin.tmpl$/ ) {
                #print STDERR "Template $name comes from $file\n";
                return $store->readFile( $file );
            }
        }
    }

    # now search the web dir and the root dir for the unskinned version
    foreach my $file ( @{$this->{files}} ) {
        if ( $file =~ /\/$name.tmpl$/ ) {
            #print STDERR "Template $name comes from $file\n";
            return $store->readFile( $file );
        }
    }

    # See if it is web.topic
    if ( $name =~ /^(\w+)\.(\w+)$/ ) {
        my $web = $1;
        my $topic = $2;
        if ( $store->topicExists( $web, $topic ) &&
             $this->{session}->{security}->checkAccessPermission
             ( 'view', $this->{session}->{user}, '', $topic, $web )) {
            #print STDERR "Template $name comes from $web.$topic\n";
            my ( $meta, $text ) =
              $store->readTopic( undef, $web, $topic, undef );
            return $text;
        }
    }

    # See if it is a user topic. Search first in current web, then
    # twiki web.
    # See if we can parse $name into $web.$topic
    $web = ucfirst( $web );
    my $topic = ucfirst( $name );
    my $ttopic = $topic.'Template';

    foreach my $lookWeb ( $web, $TWiki::cfg{SystemWebName} ) {
        foreach my $skin ( @skinList ) {
            my $skintopic = ucfirst( $skin ).'Skin'.$topic.'Template';
            if( $store->topicExists( $lookWeb, $skintopic ) &&
                $this->{session}->{security}->checkAccessPermission
                ( 'view', $this->{session}->{user}, '', $skintopic,
                  $lookWeb )) {
                my ( $meta, $text ) =
                  $store->readTopic( undef, $lookWeb, $skintopic, undef );
                #print STDERR "Template $name comes from $lookWeb.$skintopic\n";
                return $text;
            }
        }
        if ( $store->topicExists( $lookWeb, $ttopic ) &&
             $this->{session}->{security}->checkAccessPermission
             ( 'view', $this->{session}->{user}, '', $ttopic,
               $lookWeb )) {
            my ( $meta, $text ) =
              $store->readTopic( undef, $lookWeb, $ttopic, undef );
            #print STDERR "Template $name comes from $lookWeb.$ttopic\n";
            return $text;
        }
    }

    # SMELL: should really
    #throw Error::Simple( 'Template '.$name.' was not found' );
    # instead of
    return '';
}

1;
