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
