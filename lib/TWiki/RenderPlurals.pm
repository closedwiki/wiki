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

package TWiki::RenderPlurals;

# I18N - Only apply plural processing if site language is English, or
# if a built-in English-language web (Main, TWiki or Plugins).  Plurals
# apply to names ending in 's', where topic doesn't exist with plural
# name.


sub singularForm {
   my ($this, $exist, $pluralForm, $theWeb) = @_;
   my $theTopic = $pluralForm;
   # SMELL Plural processing should be set per web
   # SMELL Lang settings should be set per web
   # SMELL web names should not be hardcoded!
   # SMELL - better factored out into a plurals system
   if(  ( $TWiki::cfg{PluralToSingular} )
	and ( $TWiki::siteLang eq 'en' 
	      or $theWeb eq $TWiki::cfg{UsersWebName}
	      or $theWeb eq $TWiki::cfg{SystemWebName}
	      or $theWeb eq 'Plugins' 
	    )
     ) {
     # Topic name is plural in form and doesn't exist as written
     my $tmp = $theTopic;
     $tmp =~ s/ies$/y/;       # plurals like policy / policies
     $tmp =~ s/sses$/ss/;     # plurals like address / addresses
     $tmp =~ s/([Xx])es$/$1/; # plurals like box / boxes
     $tmp =~ s/([A-Za-rt-z])s$/$1/; # others, excluding ending ss like address(es)
     if( $this->store()->topicExists( $theWeb, $tmp ) ) {
       $theTopic = $tmp;
       $exist = 1;
     }
   }
   return ($exist, $theTopic);
 }

1;
