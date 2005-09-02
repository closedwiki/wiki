#
# Copyright (C) 2004 Rafael Alvarez, soronthar@yahoo.com
#
# Authors (in alphabetical order)
#   Rafael Alvarez (RAF)
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
package TWiki::Plugins::XpTrackerPlugin::Task;

#(RAF)
#If this module is load using the "use" directive before the plugin is 
#initialized, $debug will be 0
#(CC) this will not work in Dakar; TWiki::Func methods cannot be called before initPlugin.
my $debug;
#my $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );
#&TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::Task is loaded" ) if $debug;


sub new {
	my $object= {name=>"", 
				 est=>0,
				 who=>0,
				 reviewer=>"",
				 spent=>0,
				 etc=>0,
				 tstatus=>""
	};

	return bless $object;
}

sub AUTOLOAD {
	my $self=shift;
	my $field=$AUTOLOAD;
	$field =~ s/.*://;
 if (exists $self->{$field}) {
    if (@_) {
      return $self->{$field}=shift;
    } else {
      return $self->{$field};
    }
  }
}

1;
