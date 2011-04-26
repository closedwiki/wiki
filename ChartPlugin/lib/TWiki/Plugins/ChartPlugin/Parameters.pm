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
use Data::Dumper;
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
    $this->_parseParameters($parameters);
    return $this;
}

sub _parseParameters {
    my ($this, $parameterList) = @_;
    my %parameters;
    my $length = length($parameterList);
    my ($char, @field);

    # First break the parameterList into individual parameters
    my $in_quote = "";
    my $field    = "";
    my $index    = 0;
    my $escape   = 0;
    for (my $i = 0; $i < $length; $i++) {
        # Get character
        $char = substr($parameterList, $i, 1);
	if ($char eq "\\") {
	    $escape = 1;
	} else {
	    # If the beginning of a quote
	    if (($char eq "'" || $char eq '"') && $in_quote eq "") {
		$in_quote = $char;
	    } elsif ($char eq "'" && $in_quote eq "'" && ! $escape) {
		$in_quote = "";
	    } elsif ($char eq '"' && $in_quote eq '"' && ! $escape) {
		$in_quote = "";
	    } else {
		if ($char =~ /[,\s]+/) {    # A field separator only if not in quote
		    if ($in_quote ne "") {
			$field .= $char;
		    } else {
			$field[$index++] = $field if ($field ne "");
			$field = "";
		    }
		} else {
		    $field .= $char;
		}
	    }
	    $escape = 0;
	}
    } ## end for (my $i = 0; $i < $length...)
    # Deal with last field
    $field[$index++] = $field if ($field ne "");

    # Now break each parameter into a key=value pair.
    for (my $i = 0; $i < $index; $i++) {
        my ($key, $value) = split(/=/, $field[$i], 2);
        #print "field[$i] = [$field[$i]]\n";
        $parameters{$key} = $value;
    }
    $this->_setParameters(\%parameters);
} ## end sub _parseParameters

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
    if (defined $value && $value ne "") {
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
