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

---+ package TWiki::I18N

Support for strings translation and language detection.

=cut

package TWiki::I18N;

use TWiki;
use Assert;

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
  
  return '' unless $text;

  # substitute parameters:
  $text =~ s/\[\_(\d+)\]/$args[$1-1]/ge;

  # unescape escaped square brackets:
  $text =~ s/~(\[|\])/$1/g;

  #plurals:
  $text =~ s/\[\*,\_(\d+),([^,]+)(,([^,]+))?\]/_handlePlurals($args[$1-1],$2,$4)/ge;
  
  return $text;
}

sub _handlePlurals {
  my ( $number, $singular, $plural ) = @_;
  # bad hack, but Locale::Maketext does it the same way ;)
  return $number . ' ' . (($number == 1) ? $singular : ( $plural ? ($plural) : ($singular . 's') ) );
}

sub language {
  return 'en';
}

sub enabled_languages {
  my $this = shift;
  return $this->{enabled_languages};
}

# back to the right package
package TWiki::I18N;
######################################################

use vars qw( $initialised @initErrors );

=pod

---++ ClassMethod available_languages

Lists languages tags for languages available at TWiki installation. Returns a
list containing the tags of the available languages.

__Note__: the languages available to users are determined in the =configure=
interface.

=cut

sub available_languages {

    my @available ;
    
    if ( opendir( DIR, $TWiki::cfg{LocalesDir} ) ) {
        my @all = grep { m/^(.*)\.po$/ } (readdir( DIR ));
        foreach my $file ( @all ) {
            $file =~ m/^(.*)\.po$/;
            my $lang = $1;
            if ($TWiki::cfg{Languages}{$lang}{Enabled}) {
                push(@available, _normalize_language_tag($lang));
            }
        }
        closedir( DIR );
    }

    return @available;
}

# utility function: normalize language tags like ab_CD to ab-cd
# also renove any character there is not a letter [a-z] or a hyphen.
sub _normalize_language_tag {
  my $tag = shift;
  $tag = lc($tag);;
  $tag =~ s/\_/-/g;
  $tag =~ s/[^a-z-]//g;
  return $tag;
}

# initialisation block
BEGIN {
    # we only need to proceed if user wants internationalisation support
    return unless $TWiki::cfg{UserInterfaceInternationalisation};

    # no languages enabled is the same as disabling {UserInterfaceInternationalisation}
    my @languages = available_languages();
    return unless (scalar(@languages));

    # we first assume it's ok
    $initialised = 1;

    eval "use base 'Locale::Maketext'";
    if ( $@ ) {
      $initialised = 0;
      push(@initErrors, "I18N: Couldn't load required perl module Locale::Maketext: " . $@."\nInstall the module or turn off {UserInterfaceInternationalisation}");
    }

    unless( $TWiki::cfg{LocalesDir} && -e $TWiki::cfg{LocalesDir} ) {
      push(@initErrors, 'I18N: {LocalesDir} not configured. Define it or turn off {UserInterfaceInternationalisation}');
      $initialised = 0;
    }

    # dynamically build languages to be loaded according to admin-enabled
    # languages.
    my $dependencies = "use Locale::Maketext::Lexicon { 'en'    => [ 'Auto' ], ";
    foreach my $lang (@languages) {
      $dependencies .= " '$lang'     => [ 'Gettext' => '$TWiki::cfg{LocalesDir}/$lang.po' ], ";
    }
    $dependencies .= '};';

    eval $dependencies;
    if ( $@ ) {
      $initialised = 0;
      push(@initErrors, "I18N - Couldn't load required perl module Locale::Maketext::Lexicon: " . $@ . "\nInstall the module or turn off {UserInterfaceInternationalisation}");
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
            $session->writeWarning($error);
        }
    }

    # guesses the language from the CGI environment
    # TODO:
    #   web/user/session setting must override the language detected from the
    #   browser.
    my $this;
    if ($initialised) {
        $session->enterContext( 'i18n_enabled' );
        my $userLanguage = _normalize_language_tag($session->{prefs}->getPreferencesValue('LANGUAGE'));
        if ($userLanguage) {
            $this = TWiki::I18N->get_handle($userLanguage);
        } else {
            $this = TWiki::I18N->get_handle();
        }
    } else {
        $this = new TWiki::I18N::Fallback();
        # we couldn't initialise 'optional' I18N infrastructure, warn that we
        # can only use English.
        $session->writeWarning('Could not load I18N infrastructure; falling back to English');
    }
   
    # keep a reference to the session object
    $this->{session} = $session;

    # languages we know about
    $this->{enabled_languages} = { en => 'English' };
    $this->{checked_enabled}   = undef;
    
    # what to do with failed translations (only needed when already initialised
    # and language is not English);
    if ($initialised and ($this->language ne 'en')) {
        my $fallback_handle = TWiki::I18N->get_handle('en');
        $this->fail_with (sub {
                              my( $h, $text, @args ) = @_;
                              return $fallback_handle->maketext($text,@args);
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

    if ($result && $this->{session}) {
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

---++ ObjectMethod enabled_languages() -> %languages

Returns an array with language tags as keys and language (native) names as
values, for all the languages enabled in this TWiki.TWikiSite. Useful for
listing available languages to the user.

=cut

sub enabled_languages {

    my $this = shift;

    # don't need to check twice
    return $this->{enabled_languages} if $this->{checked_enabled};
  
    foreach my $tag ( available_languages() ) {
        my $h = TWiki::I18N->get_handle($tag);
        my $name = $h->maketext("_language_name");
        $name = ($this->{session}->UTF82SiteCharSet($name)) || $name ; 
        $this->_add_language($tag, $name);
    }

    $this->{checked_enabled} = 1;
    return $this->{enabled_languages};

}


# private utility method: add a pair tag/language name
sub _add_language {
  my ( $this, $tag, $name ) = @_;  
  ${$this->{enabled_languages}}{$tag} = $name;
}

1;
