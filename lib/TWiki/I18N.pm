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

use vars qw( $initialised );

BEGIN {
   eval "use base 'Locale::Maketext'";
   $initialised = !$@;
}

=pod

---++ ClassMethod new ( $session )

Constructor. Creates a new language object

=cut

sub new {
    my ( $class, $session ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;

    return $this unless $initialised;

    # TODO:
    #   web/user/session setting must override the language detected from the
    #   browser.

    die '{LocalesDir} not configured - run configure' unless
      $TWiki::cfg{LocalesDir} && -e $TWiki::cfg{LocalesDir};

    my $dependencies = <<HERE;
    use Locale::Maketext::Lexicon {
        en      => ['Auto'],
        '*'     => [ Gettext => '$TWiki::cfg{LocalesDir}' . '/*.po' ]
    };
    use Text::Iconv;
HERE
    eval $dependencies;
    return $this if( $@ );

    # guesses the language from the CGI environment
    $this->{language} = $this->get_handle();

    # what to do with failed translations
    $this->{language}->{fail} = \&_identity;


    # encoding converter from utf-8 to site charset:
    $this->{converter} = new Text::Iconv('utf-8',
                                         $TWiki::cfg{Site}{CharSet});

    return $this;
}

# Function to be used as default for failed translations:
# just return the same string passed for translations.
sub _identity {
    my( $h, $text ) = @_;
    return $text;
}

=pod

---++ ObjectMethod translate( $text ) -> $translation

Translates the given string (assumed to be written in English) into the
current language, as detected in the constructor.

Return value: translated string, or the argument itself if no translation is
found for thet argument.

=cut

sub translate {
  my ( $this, $text ) = @_;

  return $text unless $this->{language};

  # translate text:
  my $result = $this->{language}->maketext($text);

  # translate encoding:
  $result = $this->{converter}->convert($result);

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

    return '' unless $this->{language};
    return $this->{language}->language_tag();
}

1;
