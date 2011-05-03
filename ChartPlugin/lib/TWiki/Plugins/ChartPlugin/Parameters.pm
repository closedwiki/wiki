# ChartPlugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2010 Peter Thoeny, Peter@Thoeny.org
# Plugin written by http://TWiki.org/cgi-bin/view/Main/TaitCyrus
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This file contains routines for dealing with TWiki plugin parameters.
#
# Access is via object oriented Perl and is as follows.
#
# Constructor
#    new($params)		- Create a 'Parameters' object which
#    				  contains data from '$params'
# Getters/Setters
#    getAllParameters		- Returns hash containing all set parameters
#    getParameter($param,$default) - Get the value of the parameter $param.
#    				  If not found, then return $default as the
#    				  default value for the parameter

# =========================
package TWiki::Plugins::ChartPlugin::Parameters;

use Exporter;
use TWiki::Attrs;
@ISA    = ();
@EXPORT = qw(
    getParameter
    getAllParameters
    printParameters
    );

use strict;

sub new {
    my ($class, $parameters) = @_;
    my $this = {};
    bless $this, $class;
    $this->_setParameters(new TWiki::Attrs($parameters, 1));
    return $this;
}

sub _setParameters {
    my ($this, $parameters) = @_;
    $$this{"PARAMETERS"} = $parameters;
}

sub getAllParameters {
    my ($this) = @_;
    return %{$$this{"PARAMETERS"}};
}

# Return the value for the specified TWiki plugin parameter.  If the
# parameter does not exist, then return the specified default value.  The
# parameter is deleted from the list of specified parameters allowing the
# code to determine what parameters remain and were not requested.
sub getParameter {
    my ($this, $var_name, $default) = @_;
    my $parametersRef = $$this{"PARAMETERS"};
    my $value         = delete $$parametersRef{$var_name};    # Delete since already parsed.
    if (defined($value) && $value ne "") {
        return $value;
    } else {
        return $default;
    }
}

sub printParameters {
    my ($this) = @_;
    my %parameters = $this->getAllParameters();
    for my $key (keys %parameters) {
        my $val = $parameters{$key};
        &TWiki::Func::writeDebug("- TWiki::Plugins::ChartPlugin::Parameters::[$key]=[$val]");
    }
}

1;
