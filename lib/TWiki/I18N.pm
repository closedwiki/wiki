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

---+ Package TWiki::I18N

Support for strings translation and language detection.

=cut

package TWiki::I18N;

use TWiki;
use Assert;
use File::Find;

# ##########################################################
# # Initizaling default language: Engligh is an AUTO lexicon
# # please read `perldoc Locale::Maketext`
# ##########################################################
# package TWiki::I18N::en;
# use base 'TWiki::I18N';
# $TWiki::I18N::en::Lexicon{_AUTO} = 1;
# 
# # back to the right package
# package TWiki::I18N;
# ##########################################################

############################################################
# TWiki::I18N::Fallback - a fallback class for when
# Locale::Maketext isn't available.
############################################################
package TWiki::I18N::Fallback;
use base 'TWiki::I18N';

sub new {
  my $class = shift;
  my $this = bless({}, $class);;
  return $this;
}

sub maketext {
  my ( $this, $text, @args ) = @_;
  return $text;
}

sub language {
  return 'en';
}

sub available_languages {
  my $this = shift;
  return $this->{available_languages};
}

# back to the right package
package TWiki::I18N;
######################################################


use vars qw( $initialised @initErrors );

BEGIN {
    eval "use base 'Locale::Maketext'";
    $initialised = !$@;
    unless ($initialised) {
      push(@initErrors, "Couldn't load Locale::Maketext. It's needed for I18N support:\n" . $@);
    }

    unless( $TWiki::cfg{LocalesDir} && -e $TWiki::cfg{LocalesDir} ) {
      push(@initErrors, '{LocalesDir} not configured - run configure (I18N disabled).');
      $initialised &&= 0;
    }

    my $dependencies = <<HERE;
    use Locale::Maketext::Lexicon {
        'en'    => [ 'Auto' ],
        '*'     => [ 'Gettext' => '$TWiki::cfg{LocalesDir}' . '/*.po' ]
    };
HERE
    eval $dependencies;
    if ( $@ ) {
      $initialised &&= 0;
      push(@initErrors, "Couldn't load Perl Locale::Maketext::Lexicon. It's need for I18N support:\n" . $@);
    }
}

=pod

---++ ClassMethod get ( $session )

Constructor. Gets the language object corresponding to the current user's language.
5B

=cut

sub get {
    my $session  = shift;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    unless ($initialised) {
        foreach my $error (@initErrors) {
            $session->writeWarning(@initErrors);
        }
    }

    # guesses the language from the CGI environment
    # TODO:
    #   web/user/session setting must override the language detected from the
    #   browser.
    my $this;
    if ($initialised) {
        $this = TWiki::I18N->get_handle();
    } else {
        $this = new TWiki::I18N::Fallback();
        # we couldn't initialise 'optional' I18N infrastrcture, warn that we
        # can only use English.
        $session->writeWarning('TWiki::I18N: falling back to English: ' . $this);
    }
   
    # keep a reference to the session object
    $this->{session} = $session;

    # languages we know about
    $this->{available_languages} = { en => 'English' };
    $this->{checked_available}   = undef;
    
    # what to do with failed translations (only needed when already initialised
    # and language is not English);
    if ($initialised and ($this->language ne 'en')) {
        my $fallback_handle = TWiki::I18N->get_handle('en');
        $this->fail_with (sub {
                              my( $h, $text, $args ) = @_;
                              return $fallback_handle->maketext($text,$args);
                          }
                         );
    }

    # finally! :-p
    return $this;
}

=pod

---++ ObjectMethod maketext( $text ) -> $translation

Translates the given string (assumed to be written in English) into the
current language, as detected in the constructor, and converts it into
the site charset.

Wraps around Locale::Maketext's maketext method, adding charset conversion and checking

Return value: translated string, or the argument itself if no translation is
found for thet argument.

=cut

sub maketext {
    my ( $this, $text, @args ) = @_;

    # eventually translate text:
    my $result = $this->SUPER::maketext($text, @args);

    if ($this->{session}) {
      # external calls get the resultant text in the right charset:
      $result = $this->{session}->UTF82SiteCharSet($result) || $result;
    }

    return $result;
}

=pod

---++ ObjectMethod language() -> $language_tag

Indicates the language tag of the current user's language, as detected from the
information sent by the browser. Returns the empty string if the language
could not be determined.

=cut

sub language {
    my $this = shift;

    return $this->language_tag();
}

=pod

---++ ObjectMethod available_languages() -> %languages

Returns an array with language tags as keys and language (native) names as
values. Useful for listing available languages to the user.

=cut

sub available_languages {

    my $this = shift;

    # don't need to check twice
    return $this->{available_languages} if $this->{checked_available};
  
    File::Find::find( { wanted =>
                        sub {
                            if ($File::Find::name =~ /^.*\/([a-zA-Z]+(\_[a-zA-Z]+)?)\.po$/ ) {
                                my $tag = _normalize_language_tag($1);
                                my $h = TWiki::I18N->get_handle($tag);
                                my $name = $h->maketext("_language_name");
                                $name = ($this->{session}->UTF82SiteCharSet($name)) || $name ; 
                                $this->_add_language($tag, $name);
                            }
                        },
                        untaint => 1
                      },
                      $TWiki::cfg{LocalesDir}
                    );
    $this->{checked_available} = 1;
    return $this->{available_languages};

}


# private utility method: add a pair tag/language name
sub _add_language {
  my ( $this, $tag, $name ) = @_;  
  ${$this->{available_languages}}{$tag} = $name;
}

# utility function: normalize language tags like ab_CD to ab-cd
sub _normalize_language_tag {
  my $tag = shift;
  $tag = lc($tag);;
  $tag =~ s/\_/-/g;
  return $tag;
}

1;
