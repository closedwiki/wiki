# Copyright (C) 2005 Martin Cleaver.

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

use strict;

=pod

---+ package TWiki::Plurals

Handle conversion of plural topic names to singular form.

=cut

package TWiki::Plurals;

use TWiki;

=pod

---++ StaticMethod singularForm($web, $pluralForm) -> $singularForm

Try to singularise plural topic name.
   * =$web= - the web the topic must be in
   * =$pluralForm= - topic name
Returns undef if no singular form exists, otherwise returns the
singular form of the topic

I18N - Only apply plural processing if site language is English, or
if a built-in English-language web (Main, TWiki or Plugins).  Plurals
apply to names ending in 's', where topic doesn't exist with plural
name.

SMELL: this is highly langauge specific, and shoud be overridable
on a per-installation basis.

=cut

sub singularForm {
    my( $web, $pluralForm ) = @_;

    # SMELL Plural processing should be set per web
    # SMELL Lang settings should be set per web
    return undef unless( $TWiki::cfg{PluralToSingular} );
    return undef unless( $pluralForm =~ /s$/ );
    return undef unless( $TWiki::siteLang eq 'en'
                         or $web eq $TWiki::cfg{UsersWebName}
                         or $web eq $TWiki::cfg{SystemWebName}
                         or $web eq 'Plugins'
                       );
    # Topic name is plural in form
    my $singularForm = $pluralForm;
    $singularForm =~ s/ies$/y/;      # plurals like policy / policies
    $singularForm =~ s/sses$/ss/;    # plurals like address / addresses
    $singularForm =~ s/([Xx])es$/$1/;# plurals like box / boxes
    $singularForm =~ s/([^s])s$/$1/; # others, excluding ss like address(es)
    return $singularForm
}

1;
